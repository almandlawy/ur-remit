import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

private struct URAuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval?

    init(accessToken: String, refreshToken: String, expiresAt: TimeInterval? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

private struct URAuthUser: Decodable { let email: String? }

struct SupabaseOAuthCallback {
    let code: String?
    let accessToken: String?
    let refreshToken: String?
    let hasError: Bool

    static func parse(_ url: URL) -> SupabaseOAuthCallback? {
        guard url.scheme?.lowercased() == "urremit",
              url.host?.lowercased() == "auth",
              url.path == "/callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        let items = (components.queryItems ?? [])
            + (URLComponents(string: "?" + (components.fragment ?? ""))?.queryItems ?? [])
        func value(for name: String) -> String? {
            items.first(where: { $0.name == name })?.value.flatMap { $0.isEmpty ? nil : $0 }
        }

        return SupabaseOAuthCallback(
            code: value(for: "code"),
            accessToken: value(for: "access_token"),
            refreshToken: value(for: "refresh_token"),
            hasError: value(for: "error") != nil || value(for: "error_description") != nil
        )
    }
}

@MainActor
final class URAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let live = URAuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var email: String?
    @Published private(set) var isLoading = true
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
            message = String(localized: "apple_token_read_failed")
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
        isLoading = true
        message = nil
        defer { isLoading = false; webSession = nil }

        let verifier = Self.randomNonce(length: 64)
        guard var components = URLComponents(url: projectURL.appending(path: "auth/v1/authorize"), resolvingAgainstBaseURL: false) else {
            message = String(localized: "google_sign_in_start_failed")
            return
        }
        components.queryItems = [
            .init(name: "provider", value: "google"),
            .init(name: "redirect_to", value: "urremit://auth/callback"),
            .init(name: "code_challenge", value: Self.pkceChallenge(verifier)),
            .init(name: "code_challenge_method", value: "S256")
        ]
        guard let url = components.url else {
            message = String(localized: "google_sign_in_start_failed")
            return
        }

        do {
            let callback = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "urremit") { callback, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let callback {
                        continuation.resume(returning: callback)
                    } else {
                        continuation.resume(throwing: URAuthError.invalidCallback)
                    }
                }
                webSession = session
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                guard session.start() else {
                    continuation.resume(throwing: URAuthError.authenticationUnavailable)
                    return
                }
            }

            guard let parsed = SupabaseOAuthCallback.parse(callback), !parsed.hasError else {
                throw URAuthError.invalidCallback
            }
            let authSession: URAuthSession
            if let code = parsed.code {
                let endpoint = projectURL.appending(path: "auth/v1/token")
                    .appending(queryItems: [.init(name: "grant_type", value: "pkce")])
                let body = try JSONSerialization.data(withJSONObject: ["auth_code": code, "code_verifier": verifier])
                authSession = try await request(endpoint, method: "POST", body: body)
            } else if let accessToken = parsed.accessToken, let refreshToken = parsed.refreshToken {
                authSession = URAuthSession(accessToken: accessToken, refreshToken: refreshToken)
            } else {
                throw URAuthError.invalidCallback
            }
            try save(authSession)
            try await loadUser(using: authSession)
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                message = String(localized: "google_sign_in_failed")
            }
        }
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

    func deleteAccount() async throws {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            try await DeleteAccountService.shared.deleteAccount()
        } catch {
            message = error.localizedDescription
            throw error
        }
    }

    func handle(url: URL) {
        guard let callback = SupabaseOAuthCallback.parse(url),
              let accessToken = callback.accessToken,
              let refreshToken = callback.refreshToken,
              !callback.hasError else { return }
        let authSession = URAuthSession(accessToken: accessToken, refreshToken: refreshToken)
        do {
            try save(authSession)
            Task { try? await loadUser(using: authSession) }
        } catch { message = String(localized: "secure_session_save_failed") }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private func restoreSession() async {
        defer { isLoading = false }
        guard let authSession = try? load() else { return }
        do {
            try await loadUser(using: authSession)
        } catch URAuthError.unauthorized {
            deleteSession()
        } catch {
            message = String(localized: "session_restore_failed")
        }
    }

    private func loadUser(using authSession: URAuthSession) async throws {
        var activeSession = try await sessionWithValidAccessToken(authSession)
        let user: URAuthUser
        do {
            user = try await request(projectURL.appending(path: "auth/v1/user"), bearer: activeSession.accessToken)
        } catch let error as URAuthError {
            guard case .httpStatus(401) = error else { throw error }
            activeSession = try await refreshSession(authSession)
            user = try await request(projectURL.appending(path: "auth/v1/user"), bearer: activeSession.accessToken)
        }
        isAuthenticated = true
        email = user.email
        message = nil
    }

    private func sessionWithValidAccessToken(_ authSession: URAuthSession) async throws -> URAuthSession {
        guard let expiresAt = authSession.expiresAt,
              expiresAt <= Date().addingTimeInterval(30).timeIntervalSince1970 else { return authSession }
        return try await refreshSession(authSession)
    }

    private func refreshSession(_ authSession: URAuthSession) async throws -> URAuthSession {
        let endpoint = projectURL.appending(path: "auth/v1/token")
            .appending(queryItems: [.init(name: "grant_type", value: "refresh_token")])
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": authSession.refreshToken])
        let refreshed: URAuthSession
        do {
            refreshed = try await request(endpoint, method: "POST", body: body)
        } catch let error as URAuthError {
            if case .httpStatus(400) = error { throw URAuthError.unauthorized }
            if case .httpStatus(401) = error { throw URAuthError.unauthorized }
            throw error
        }
        try save(refreshed)
        return refreshed
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
        guard let http = response as? HTTPURLResponse else { throw URAuthError.requestFailed }
        guard 200..<300 ~= http.statusCode else { throw URAuthError.httpStatus(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func perform(_ operation: () async throws -> Void) async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do { try await operation() } catch { message = String(localized: "sign_in_failed") }
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

    private static func pkceChallenge(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private enum URAuthError: Error { case requestFailed, unauthorized, httpStatus(Int), keychain, invalidCallback, authenticationUnavailable }
