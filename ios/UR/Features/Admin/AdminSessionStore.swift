import Foundation
import Security
import CryptoKit

/// Drives the whole "hidden admin" flow: full Supabase email/password sign-in the first time on a
/// device, then a quick 4-6 digit PIN unlock afterwards (the Supabase session itself, including its
/// refresh token, stays in the Keychain the whole time — the PIN only gates *this app* from using it,
/// it is never sent anywhere).
@MainActor
final class AdminSessionStore: ObservableObject {
    enum Screen: Equatable {
        case loginForm
        case pinUnlock
        case setUpPIN
        case unlocked
    }

    @Published private(set) var screen: Screen = .loginForm
    @Published var message: String?
    @Published private(set) var isLoading = false

    private var session: AdminSupabaseSession?
    private let client: any AdminAPIClient
    private let sessionAccount = "com.urremit.mobile.admin.session"
    private let pinAccount = "com.urremit.mobile.admin.pin"
    private let maxPINAttempts = 5
    private var pinAttempts = 0

    init(client: (any AdminAPIClient)? = nil) {
        self.client = client ?? URLSessionAdminAPIClient() ?? UnavailableAdminAPIClient()
        if let stored = try? Self.loadSession(account: sessionAccount) {
            session = stored
            screen = Self.pinHashExists(account: pinAccount) ? .pinUnlock : .setUpPIN
        }
    }

    var isAuthenticated: Bool { screen == .unlocked }

    // MARK: - Full sign-in

    func signIn(email: String, password: String) async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let newSession = try await client.signIn(email: email, password: password)
            guard try await client.verifyAdmin(accessToken: newSession.accessToken) else {
                message = String(localized: "admin_not_authorized")
                return
            }
            session = newSession
            try? Self.save(newSession, account: sessionAccount)
            pinAttempts = 0
            screen = Self.pinHashExists(account: pinAccount) ? .unlocked : .setUpPIN
        } catch AdminAPIError.invalidCredentials, AdminAPIError.forbidden {
            message = String(localized: "admin_login_invalid")
        } catch AdminAPIError.missingConfiguration {
            message = String(localized: "admin_login_failed")
        } catch {
            message = String(localized: "admin_login_failed")
        }
    }

    func requestPasswordReset(email: String) async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        guard !email.isEmpty else { return }
        do {
            try await client.requestPasswordReset(email: email)
            message = String(localized: "admin_reset_email_sent")
        } catch {
            message = String(localized: "admin_reset_request_failed")
        }
    }

    // MARK: - PIN

    func setUpPIN(_ pin: String) {
        guard pin.count >= 4, pin.count <= 6, pin.allSatisfy(\.isNumber) else {
            message = String(localized: "admin_pin_invalid_format")
            return
        }
        try? Self.savePINHash(Self.hash(pin), account: pinAccount)
        message = nil
        screen = .unlocked
    }

    func unlock(withPIN pin: String) async {
        guard let session, let storedHash = try? Self.loadPINHash(account: pinAccount) else {
            screen = .loginForm
            return
        }
        guard Self.hash(pin) == storedHash else {
            pinAttempts += 1
            if pinAttempts >= maxPINAttempts {
                message = String(localized: "admin_pin_locked")
                signOut()
            } else {
                message = String(localized: "admin_pin_incorrect")
            }
            return
        }
        pinAttempts = 0
        message = nil
        if session.isExpired {
            isLoading = true
            defer { isLoading = false }
            do {
                self.session = try await client.refresh(refreshToken: session.refreshToken, email: session.email)
                try? Self.save(self.session!, account: sessionAccount)
            } catch {
                message = String(localized: "admin_session_expired")
                screen = .loginForm
                return
            }
        }
        screen = .unlocked
    }

    /// Falls back to the full email/password form (e.g. the operator forgot their PIN).
    func useEmailInstead() {
        clearPIN()
        screen = .loginForm
    }

    func signOut() {
        session = nil
        message = nil
        Self.delete(account: sessionAccount)
        clearPIN()
        screen = .loginForm
    }

    // MARK: - Rate writes

    func updateRate(id: UUID, update: AdminRateUpdate) async throws {
        guard var current = session else { throw AdminAPIError.sessionExpired }
        if current.isExpired {
            current = try await client.refresh(refreshToken: current.refreshToken, email: current.email)
            session = current
            try? Self.save(current, account: sessionAccount)
        }
        try await client.updateRate(id: id, update: update, accessToken: current.accessToken)
    }

    private func clearPIN() {
        pinAttempts = 0
        Self.delete(account: pinAccount)
    }

    // MARK: - Hashing (local-only comparison, never transmitted)

    private static func hash(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data((pin + "urremit.admin.pin.salt.v1").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Keychain

    private static func save(_ session: AdminSupabaseSession, account: String) throws {
        let data = try JSONEncoder().encode(session)
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, kSecValueData as String: data
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw AdminAPIError.transport }
    }

    private static func loadSession(account: String) throws -> AdminSupabaseSession {
        guard let data = loadData(account: account) else { throw AdminAPIError.sessionExpired }
        return try JSONDecoder().decode(AdminSupabaseSession.self, from: data)
    }

    private static func savePINHash(_ hash: String, account: String) throws {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(hash.utf8)
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw AdminAPIError.transport }
    }

    private static func loadPINHash(account: String) throws -> String {
        guard let data = loadData(account: account) else { throw AdminAPIError.sessionExpired }
        return String(decoding: data, as: UTF8.self)
    }

    private static func pinHashExists(account: String) -> Bool { loadData(account: account) != nil }

    private static func loadData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    private static func delete(account: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account] as CFDictionary)
    }
}

/// Used only if the app is somehow missing its Supabase configuration, so the UI can show a clear
/// error instead of force-unwrapping a nil client.
private struct UnavailableAdminAPIClient: AdminAPIClient {
    func signIn(email: String, password: String) async throws -> AdminSupabaseSession { throw AdminAPIError.missingConfiguration }
    func refresh(refreshToken: String, email: String) async throws -> AdminSupabaseSession { throw AdminAPIError.missingConfiguration }
    func verifyAdmin(accessToken: String) async throws -> Bool { throw AdminAPIError.missingConfiguration }
    func requestPasswordReset(email: String) async throws { throw AdminAPIError.missingConfiguration }
    func updateRate(id: UUID, update: AdminRateUpdate, accessToken: String) async throws { throw AdminAPIError.missingConfiguration }
}
