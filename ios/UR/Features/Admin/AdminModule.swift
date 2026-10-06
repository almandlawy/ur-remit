import Foundation
import Observation
import Security
import SwiftUI

private struct AdminEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value
}

private struct AdminSession: Decodable, Sendable {
    let token: String
    let expiresAt: String
}

private struct AdminDashboard: Decodable, Sendable {
    let activeRoutes: Int?
    let activeOffices: Int?
    let verifiedAgents: Int?
    let pushSubscribers: Int?
    let lastRateUpdate: String?
}

private enum AdminAPIError: LocalizedError {
    case unauthorized
    case forbidden
    case invalidResponse
    case requestFailed
    case secureStorage

    var errorDescription: String? {
        switch self {
        case .unauthorized: "انتهت جلسة الإدارة. سجّل الدخول مجدداً."
        case .forbidden: "لا تملك صلاحية تنفيذ هذا الإجراء."
        case .invalidResponse: "استجابة الخادم غير صالحة."
        case .requestFailed: "تعذّر الاتصال بخدمة الإدارة."
        case .secureStorage: "تعذّر حفظ جلسة الإدارة بأمان."
        }
    }
}

private actor AdminAPI {
    static let shared = AdminAPI(configuration: .current)

    private let configuration: APIConfiguration
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    init(configuration: APIConfiguration) {
        self.configuration = configuration
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = ISO8601DateParser.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
            }
            return date
        }
    }

    func login(username: String, password: String, mfaCode: String) async throws -> AdminSession {
        try await send(
            to: configuration.adminBaseURL.appending(path: "auth/login"),
            method: "POST",
            body: ["username": username, "password": password, "mfaCode": mfaCode],
            token: nil
        )
    }

    func logout(token: String) async throws {
        let _: AdminLogoutResult = try await send(
            to: configuration.adminBaseURL.appending(path: "auth/logout"),
            method: "POST",
            body: Optional<EmptyBody>.none,
            token: token
        )
    }

    func dashboard(token: String) async throws -> AdminDashboard {
        try await send(
            to: configuration.adminBaseURL.appending(path: "dashboard"),
            method: "GET",
            body: Optional<EmptyBody>.none,
            token: token
        )
    }

    func rates() async throws -> [Rate] {
        try await send(
            to: configuration.baseURL.appending(path: "rates"),
            method: "GET",
            body: Optional<EmptyBody>.none,
            token: nil
        )
    }

    func updateRate(id: UUID, buy: String?, sell: String?, feeFixed: String?, token: String) async throws {
        let _: AdminRateUpdateResult = try await send(
            to: configuration.adminBaseURL.appending(path: "rates/\(id.uuidString)"),
            method: "PATCH",
            body: RateUpdateBody(buy: buy, sell: sell, feeFixed: feeFixed),
            token: token
        )
    }

    private func send<Value: Decodable & Sendable, Body: Encodable>(
        to url: URL,
        method: String,
        body: Body?,
        token: String?
    ) async throws -> Value {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AdminAPIError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            do { return try decoder.decode(AdminEnvelope<Value>.self, from: data).data }
            catch { throw AdminAPIError.invalidResponse }
        case 401: throw AdminAPIError.unauthorized
        case 403: throw AdminAPIError.forbidden
        default: throw AdminAPIError.requestFailed
        }
    }
}

private struct EmptyBody: Encodable, Sendable {}
private struct AdminLogoutResult: Decodable, Sendable { let success: Bool }
private struct AdminRateUpdateResult: Decodable, Sendable { let id: UUID? }
private struct RateUpdateBody: Encodable, Sendable {
    let buy: String?
    let sell: String?
    let feeFixed: String?

    private enum CodingKeys: String, CodingKey {
        case buy
        case sell
        case feeFixed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(buy, forKey: .buy)
        try container.encode(sell, forKey: .sell)
        try container.encode(feeFixed, forKey: .feeFixed)
    }
}

@Observable
@MainActor
private final class AdminAuth {
    static let shared = AdminAuth()

    private let keychainAccount = "com.urremit.mobile.admin.session"
    private(set) var sessionToken: String?
    var isAuthenticated: Bool { sessionToken != nil }

    private init() {
        sessionToken = Self.readToken(account: keychainAccount)
    }

    func login(username: String, password: String, mfaCode: String) async throws {
        let session = try await AdminAPI.shared.login(username: username, password: password, mfaCode: mfaCode)
        try Self.storeToken(session.token, account: keychainAccount)
        sessionToken = session.token
    }

    func logout() async throws {
        let token = sessionToken
        defer {
            Self.deleteToken(account: keychainAccount)
            sessionToken = nil
        }
        if let token {
            try await AdminAPI.shared.logout(token: token)
        }
    }

    func clearExpiredSession() {
        Self.deleteToken(account: keychainAccount)
        sessionToken = nil
    }

    private static func readToken(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func storeToken(_ token: String, account: String) throws {
        deleteToken(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(token.utf8)
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw AdminAPIError.secureStorage
        }
    }

    private static func deleteToken(account: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ] as CFDictionary)
    }
}

struct AdminEntryView: View {
    @State private var auth = AdminAuth.shared

    var body: some View {
        Group {
            if auth.isAuthenticated {
                AdminDashboardView(auth: auth)
            } else {
                AdminLoginView(auth: auth)
            }
        }
        .background(URColor.ivory.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdminLoginView: View {
    let auth: AdminAuth
    @State private var username = ""
    @State private var password = ""
    @State private var mfaCode = ""
    @State private var errorMessage: String?
    @State private var isLoggingIn = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                URPageTitle(title: "لوحة الإدارة", subtitle: "دخول آمن لفريق UR", symbol: "lock.shield.fill")

                URCard {
                    VStack(alignment: .trailing, spacing: 14) {
                        TextField("اسم المستخدم", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .padding(14)
                            .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12))

                        SecureField("كلمة المرور", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .padding(14)
                            .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12))

                        TextField("رمز المصادقة (6 أرقام)", text: $mfaCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .multilineTextAlignment(.center)
                            .padding(14)
                            .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12))

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(URColor.error)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        Button {
                            Task { await login() }
                        } label: {
                            if isLoggingIn {
                                ProgressView().tint(.white)
                            } else {
                                Label("دخول آمن", systemImage: "arrow.right.circle.fill")
                            }
                        }
                        .buttonStyle(URPrimaryButtonStyle(isEnabled: !username.isEmpty && !password.isEmpty && mfaCode.count == 6))
                        .disabled(username.isEmpty || password.isEmpty || mfaCode.count != 6 || isLoggingIn)
                    }
                }
            }
            .padding(14)
        }
    }

    private func login() async {
        isLoggingIn = true
        errorMessage = nil
        defer { isLoggingIn = false }
        do {
            try await auth.login(username: username, password: password, mfaCode: mfaCode)
            password = ""
            mfaCode = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminDashboardView: View {
    let auth: AdminAuth
    @State private var canViewAnalytics = false
    @State private var dashboard: AdminDashboard?
    @State private var rates: [Rate] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isLoggingOut = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                URPageTitle(title: "لوحة الإدارة", subtitle: "إدارة الأسعار على الخادم", symbol: "slider.horizontal.3")

                if canViewAnalytics, let token = auth.sessionToken {
                    NavigationLink { AdminAnalyticsView(token: token) } label: {
                        Label("مراقبة التطبيق", systemImage: "chart.xyaxis.line").font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(.bordered)
                }
                if let dashboard {
                    HStack(spacing: 8) {
                        metric("المسارات", value: dashboard.activeRoutes)
                        metric("المكاتب", value: dashboard.activeOffices)
                        metric("الوكلاء", value: dashboard.verifiedAgents)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(URColor.error)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if isLoading && rates.isEmpty {
                    ProgressView().padding(30)
                } else if rates.isEmpty {
                    Text("لا توجد أسعار متاحة.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(24)
                } else {
                    ForEach(rates) { rate in
                        AdminRateEditor(rate: rate, token: auth.sessionToken ?? "") {
                            await reload()
                        }
                    }
                }

                Button {
                    Task { await reload() }
                } label: {
                    Label("تحديث البيانات", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)

                Button {
                    Task { await logout() }
                } label: {
                    if isLoggingOut {
                        ProgressView()
                    } else {
                        Label("تسجيل الخروج", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(URColor.error)
                .disabled(isLoggingOut)
            }
            .padding(14)
        }
        .task { await reload() }
        .task { if let token = auth.sessionToken { canViewAnalytics = await URAdminAnalyticsAPI.canAccess(token: token) } }
    }

    private func metric(_ title: String, value: Int?) -> some View {
        VStack(spacing: 5) {
            Text(value.map(String.init) ?? "—")
                .font(.title3.weight(.black))
                .foregroundStyle(URColor.deepNavy)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    private func reload() async {
        guard let token = auth.sessionToken else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let metrics = AdminAPI.shared.dashboard(token: token)
            async let latestRates = AdminAPI.shared.rates()
            dashboard = try await metrics
            rates = try await latestRates
        } catch AdminAPIError.unauthorized {
            auth.clearExpiredSession()
            errorMessage = "انتهت جلسة الإدارة. سجّل الدخول مجدداً."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logout() async {
        isLoggingOut = true
        errorMessage = nil
        defer { isLoggingOut = false }
        do {
            try await auth.logout()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminRateEditor: View {
    let rate: Rate
    let token: String
    let onSaved: () async -> Void

    @State private var buy: String
    @State private var sell: String
    @State private var feeFixed: String
    @State private var message: String?
    @State private var isSaving = false

    init(rate: Rate, token: String, onSaved: @escaping () async -> Void) {
        self.rate = rate
        self.token = token
        self.onSaved = onSaved
        _buy = State(initialValue: rate.buy.map { "\($0)" } ?? "")
        _sell = State(initialValue: rate.sell.map { "\($0)" } ?? "")
        _feeFixed = State(initialValue: rate.feeFixed.map { "\($0)" } ?? "")
    }

    var body: some View {
        URCard {
            VStack(alignment: .trailing, spacing: 10) {
                Text(rate.routeNameArabic)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(URColor.deepNavy)
                Text("\(rate.sourceCurrency) / \(rate.destinationCurrency)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    valueField("شراء", text: $buy)
                    valueField("بيع", text: $sell)
                    valueField("العمولة", text: $feeFixed)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("حفظ نسخة سعر جديدة")
                    }
                }
                .font(.caption.weight(.bold))
                .disabled(isSaving)

                if let message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(message == "تم حفظ التعديل وتسجيله." ? URColor.success : URColor.error)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func valueField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title).font(.caption2.weight(.bold))
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .padding(8)
                .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
    }

    private func save() async {
        isSaving = true
        message = nil
        defer { isSaving = false }
        do {
            try await AdminAPI.shared.updateRate(
                id: rate.id,
                buy: normalized(buy),
                sell: normalized(sell),
                feeFixed: normalized(feeFixed),
                token: token
            )
            message = "تم حفظ التعديل وتسجيله."
            await onSaved()
        } catch {
            message = error.localizedDescription
        }
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
