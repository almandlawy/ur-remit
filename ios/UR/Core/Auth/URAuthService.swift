import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

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
    }

    func handle(url: URL) {
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

    private func restoreSession() async {
        guard let authSession = try? load() else { return }
        do { try await loadUser(using: authSession) } catch { deleteSession() }
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
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URAuthError.requestFailed }
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
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: sessionKey, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, kSecValueData as String: data]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw URAuthError.keychain }
    }

    private func load() throws -> URAuthSession {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: sessionKey, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { throw URAuthError.keychain }
        return try JSONDecoder().decode(URAuthSession.self, from: data)
    }

    private func deleteSession() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: sessionKey] as CFDictionary)
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
        guard let fragment = URLComponents(string: "?" + (url.fragment ?? "")) else { return nil }
        let values = Dictionary(uniqueKeysWithValues: (fragment.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } })
        guard let access = values["access_token"], let refresh = values["refresh_token"] else { return nil }
        return URAuthSession(accessToken: access, refreshToken: refresh)
    }
}

private enum URAuthError: Error { case requestFailed, keychain }
