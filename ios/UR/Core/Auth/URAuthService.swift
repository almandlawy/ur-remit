import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit
import UserNotifications

private struct URAuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private struct URAuthUser: Decodable { let email: String? }

@MainActor
final class URAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let live = URAuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var email: String?
    @Published private(set) var isLoading = false
    @Published var message: String?
    @Published private(set) var isGuest: Bool = false

    private let projectURL: URL
    private let publishableKey: String
    private let sessionKey = "com.urremit.mobile.supabase.session"
    private var webSession: ASWebAuthenticationSession?

    private override init() {
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let projectURL = URL(string: rawURL),
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty else { preconditionFailure("Supabase client configuration is missing") }
        self.projectURL = projectURL
        self.publishableKey = key
        super.init()
        Task { await restoreSession() }
    }

    // MARK: - Apple Sign In

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest, nonce: String) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func signInWithApple(authorization: ASAuthorization, nonce: String) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            message = "تعذر قراءة بيانات Apple. حاول مرة أخرى."
            return
        }
        await perform {
            let endpoint = projectURL.appending(path: "auth/v1/token")
                .appending(queryItems: [.init(name: "grant_type", value: "id_token")])
            let body = try JSONSerialization.data(withJSONObject: ["provider": "apple", "id_token": token, "nonce": nonce])
            let authSession: URAuthSession = try await request(endpoint, method: "POST", body: body)
            try save(authSession)
            try await loadUser(using: authSession)
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        guard var components = URLComponents(url: projectURL.appending(path: "auth/v1/authorize"), resolvingAgainstBaseURL: false) else { return }
        components.queryItems = [.init(name: "provider", value: "google"), .init(name: "redirect_to", value: "urremit://auth/callback")]
        guard let url = components.url else { return }

        isLoading = true
        message = nil
        let result = await withCheckedContinuation { continuation in
            webSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "urremit") { callback, error in
                continuation.resume(returning: (callback, error))
            }
            webSession?.presentationContextProvider = self
            webSession?.prefersEphemeralWebBrowserSession = true
            webSession?.start()
        }
        defer { isLoading = false; webSession = nil }
        guard result.1 == nil, let callback = result.0, let authSession = Self.session(from: callback) else {
            if (result.1 as? ASWebAuthenticationSessionError)?.code != .canceledLogin { message = "لم يكتمل تسجيل الدخول بواسطة Google." }
            return
        }
        do {
            try save(authSession)
            try await loadUser(using: authSession)
        } catch { message = "تعذر حفظ جلسة الدخول بأمان." }
    }

    // MARK: - Guest Mode

    /// يسمح للمستخدم باستخدام التطبيق بدون إنشاء حساب
    func continueAsGuest() {
        isGuest = true
        message = nil
    }

    /// خروج من نمط الزائر
    func leaveGuestMode() {
        isGuest = false
    }

    // MARK: - Sign Out

    func signOut() async {
        if let current = try? load() {
            var urlRequest = URLRequest(url: projectURL.appending(path: "auth/v1/logout"))
            urlRequest.httpMethod = "POST"
            urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
            urlRequest.setValue("Bearer \(current.accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: urlRequest)
        }
        deleteSession()
        isAuthenticated = false
        email = nil
        isGuest = false
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            // 1. احذف الحساب من السيرفر
            try await DeleteAccountService.shared.deleteAccount()

            // 2. نظّف الجلسة المحلية وأرجع المستخدم لشاشة الدخول
            signOutCompletely()
        } catch {
            message = error.localizedDescription
            throw error
        }
    }

    /// تنظيف كامل بعد حذف الحساب — يمسح الجلسة المحلية ويحدّث الحالة
    func signOutCompletely() {
        deleteSession()
        isAuthenticated = false
        email = nil
        message = nil
        isGuest = false

        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("UR") || key.hasPrefix("user_") { defaults.removeObject(forKey: key) }
        if let shared = UserDefaults(suiteName: "group.com.urremit.shared") {
            for key in shared.dictionaryRepresentation().keys { shared.removeObject(forKey: key) }
        }
        URLCache.shared.removeAllCachedResponses()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// يرجّع التوكن الحالي (للعمليات اللي تحتاج مصادقة)
    func currentAccessToken() -> String? {
        try? load().accessToken
    }

    // MARK: - URL Handling

    func handle(url: URL) {
        guard url.scheme == "urremit", url.host == "auth", url.path == "/callback" else { return }
        guard let authSession = Self.session(from: url) else { return }
        do {
            try save(authSession)
            Task { try? await loadUser(using: authSession) }
        } catch { message = "تعذر حفظ جلسة الدخول بأمان." }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    // MARK: - Private

    private func restoreSession() async {
        guard let authSession = try? load() else { return }
        do { try await loadUser(using: authSession) }
        catch URAuthError.requestFailed(let status) where status == 401 || status == 403 {
            do {
                let refreshed = try await refresh(authSession)
                try save(refreshed)
                try await loadUser(using: refreshed)
            } catch URAuthError.requestFailed(let refreshStatus) where refreshStatus == 400 || refreshStatus == 401 || refreshStatus == 403 {
                deleteSession(); isAuthenticated = false; email = nil
            } catch { message = "تعذر الاتصال مؤقتاً. احتفظنا بجلسة الدخول وحاول لاحقاً." }
        } catch { message = "تعذر الاتصال مؤقتاً. احتفظنا بجلسة الدخول وحاول لاحقاً." }
    }

    private func refresh(_ current: URAuthSession) async throws -> URAuthSession {
        let endpoint = projectURL.appending(path: "auth/v1/token").appending(queryItems: [.init(name: "grant_type", value: "refresh_token")])
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": current.refreshToken])
        return try await request(endpoint, method: "POST", body: body)
    }

    private func loadUser(using authSession: URAuthSession) async throws {
        let user: URAuthUser = try await request(projectURL.appending(path: "auth/v1/user"), bearer: authSession.accessToken)
        isAuthenticated = true
        email = user.email
        message = nil
    }

    private func request<T: Decodable>(_ url: URL, method: String = "GET", body: Data? = nil, bearer: String? = nil) async throws -> T {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body
        urlRequest.timeoutInterval = 20
        urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { urlRequest.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw URAuthError.requestFailed(0) }
        guard 200..<300 ~= http.statusCode else { throw URAuthError.requestFailed(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func perform(_ operation: () async throws -> Void) async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do { try await operation() } catch { message = "تعذر إكمال تسجيل الدخول الآن. حاول لاحقاً." }
    }

    private func save(_ value: URAuthSession) throws {
        let data = try JSONEncoder().encode(value)
        deleteSession()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: sessionKey,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw URAuthError.keychain }
    }

    private func load() throws -> URAuthSession {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: sessionKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { throw URAuthError.keychain }
        return try JSONDecoder().decode(URAuthSession.self, from: data)
    }

    private func deleteSession() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: sessionKey
        ] as CFDictionary)
    }

    static func randomNonce(length: Int = 32) -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func session(from url: URL) -> URAuthSession? {
        guard url.scheme == "urremit", url.host == "auth", url.path == "/callback" else { return nil }
        guard let fragment = URLComponents(string: "?" + (url.fragment ?? "")) else { return nil }
        let values = Dictionary(uniqueKeysWithValues: (fragment.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } })
        guard let access = values["access_token"], let refresh = values["refresh_token"] else { return nil }
        return URAuthSession(accessToken: access, refreshToken: refresh)
    }
}

private enum URAuthError: Error { case requestFailed(Int), keychain }
