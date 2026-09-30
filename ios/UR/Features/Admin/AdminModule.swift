import Foundation
import Observation
import Security
import SwiftUI

/// Mirrors the backend's `decimal` schema (`backend/src/admin-routes.ts`): an optional leading `-`,
/// up to 16 integer digits and up to 8 fractional digits. Validating client-side avoids a round trip
/// to the server for obviously malformed input and stops the misleading "server unreachable" message
/// a raw 400 used to surface for what was actually a formatting mistake. Internal (not private) so it
/// stays unit-testable.
enum AdminRateInputValidator {
    static func normalizedDecimalInput(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var result = ""
        var hasDecimalSeparator = false
        var hasSign = false
        for (index, character) in trimmed.enumerated() {
            if character == "-", index == 0 {
                hasSign = true
                result.append("-")
            } else if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                result.append(String(digit))
            } else if character == "." || character == "\u{066B}" {
                guard !hasDecimalSeparator else { return nil }
                hasDecimalSeparator = true
                result.append(".")
            } else {
                return nil
            }
        }
        let digitsPattern = hasSign ? "^-\\d{1,16}(\\.\\d{1,8})?$" : "^\\d{1,16}(\\.\\d{1,8})?$"
        return result.range(of: digitsPattern, options: .regularExpression) == nil
            ? nil
            : result
    }

    static func isValidDecimalOrAbsent(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || normalizedDecimalInput(value) != nil
    }
}

struct AdminRateChange: Equatable {
    let title: String
    let previousValue: String
    let newValue: String
}

enum AdminRateDraft {
    static func changes(for rate: Rate, buy: String, sell: String, feeFixed: String) -> [AdminRateChange] {
        [
            change("شراء", current: rate.buy, edited: buy),
            change("بيع", current: rate.sell, edited: sell),
            change("العمولة", current: rate.feeFixed, edited: feeFixed)
        ].compactMap { $0 }
    }

    static func hasAnyValue(for rate: Rate, buy: String, sell: String, feeFixed: String) -> Bool {
        rate.feePercent != nil || [buy, sell, feeFixed].contains { normalized($0) != nil }
    }

    static func summary(of changes: [AdminRateChange]) -> String {
        changes.map { "\($0.title): \($0.previousValue) ← \($0.newValue)" }.joined(separator: "\n")
    }

    private static func change(_ title: String, current: Decimal?, edited: String) -> AdminRateChange? {
        let normalizedValue = normalized(edited)
        let parsedValue: Decimal?
        if let normalizedValue {
            guard let canonical = AdminRateInputValidator.normalizedDecimalInput(normalizedValue),
                  let parsed = Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX")) else {
                return AdminRateChange(
                    title: title,
                    previousValue: current.map { NSDecimalNumber(decimal: $0).stringValue } ?? "—",
                    newValue: normalizedValue
                )
            }
            parsedValue = parsed
        } else {
            parsedValue = nil
        }
        guard parsedValue != current else { return nil }
        return AdminRateChange(
            title: title,
            previousValue: current.map { NSDecimalNumber(decimal: $0).stringValue } ?? "—",
            newValue: normalizedValue ?? "—"
        )
    }

    private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

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

enum AdminAPIError: LocalizedError {
    case unauthorized
    case invalidCredentials
    case forbidden
    case invalidInput
    case notFound
    case invalidResponse
    case networkUnavailable
    case serverFailure(statusCode: Int)
    case unexpectedStatus(statusCode: Int)
    case requestFailed
    case secureStorage

    static func loginFailure(for error: Self) -> Self {
        switch error {
        case .unauthorized: .invalidCredentials
        default: error
        }
    }

    var errorDescription: String? {
        switch self {
        case .unauthorized: "انتهت جلسة الإدارة. سجّل الدخول مجدداً."
        case .invalidCredentials: "بيانات الدخول غير صحيحة أو الحساب غير متاح."
        case .forbidden: "لا تملك صلاحية تنفيذ هذا الإجراء."
        case .invalidInput: "القيمة غير صالحة. استخدم الأرقام العربية أو الإنجليزية وبحد أقصى 8 خانات عشرية."
        case .notFound: "هذا السعر لم يعد متاحاً. حدّث القائمة وحاول مجدداً."
        case .invalidResponse: "استجابة الخادم غير صالحة."
        case .networkUnavailable: "تعذر الوصول إلى الإنترنت. تحقق من اتصالك وحاول مجدداً."
        case .serverFailure(let statusCode):
            "الخادم واجه مشكلة مؤقتة (رمز \(statusCode)). حاول مرة أخرى بعد قليل."
        case .unexpectedStatus(let statusCode):
            "تعذر تنفيذ الطلب (رمز \(statusCode)). راجع البيانات وحاول مجدداً."
        case .requestFailed: "تعذّر الاتصال بخدمة الإدارة. تحقق من الشبكة وحاول مجدداً."
        case .secureStorage: "تعذّر حفظ جلسة الإدارة بأمان."
        }
    }
}

enum AdminRateRetryPolicy {
    static let maximumAttempts = 3

    static func shouldRetry(_ error: AdminAPIError, attempt: Int) -> Bool {
        guard attempt < maximumAttempts else { return false }
        switch error {
        case .networkUnavailable, .serverFailure, .requestFailed:
            return true
        default:
            return false
        }
    }

    static func delayMilliseconds(after attempt: Int) -> Int {
        500 * (1 << max(0, attempt - 1))
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

    func login(username: String, password: String) async throws -> AdminSession {
        do {
            return try await send(
                to: configuration.adminBaseURL.appending(path: "auth/login"),
                method: "POST",
                body: ["username": username, "password": password],
                token: nil
            )
        } catch let error as AdminAPIError {
            throw AdminAPIError.loginFailure(for: error)
        }
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

    func updateRate(
        id: UUID,
        buy: String?,
        sell: String?,
        feeFixed: String?,
        requestID: UUID,
        token: String
    ) async throws {
        for attempt in 1...AdminRateRetryPolicy.maximumAttempts {
            do {
                let _: AdminRateUpdateResult = try await send(
                    to: configuration.adminBaseURL.appending(path: "rates/\(id.uuidString)"),
                    method: "PATCH",
                    body: RateUpdateBody(
                        buy: buy,
                        sell: sell,
                        feeFixed: feeFixed,
                        requestID: requestID.uuidString
                    ),
                    token: token
                )
                return
            } catch let error as AdminAPIError {
                guard AdminRateRetryPolicy.shouldRetry(error, attempt: attempt) else { throw error }
                try await Task.sleep(for: .milliseconds(AdminRateRetryPolicy.delayMilliseconds(after: attempt)))
            }
        }
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw AdminAPIError.networkUnavailable
        }
        guard let http = response as? HTTPURLResponse else { throw AdminAPIError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            do { return try decoder.decode(AdminEnvelope<Value>.self, from: data).data }
            catch { throw AdminAPIError.invalidResponse }
        case 400: throw AdminAPIError.invalidInput
        case 401: throw AdminAPIError.unauthorized
        case 403: throw AdminAPIError.forbidden
        case 404: throw AdminAPIError.notFound
        case 408, 429: throw AdminAPIError.requestFailed
        case 500...599: throw AdminAPIError.serverFailure(statusCode: http.statusCode)
        default: throw AdminAPIError.unexpectedStatus(statusCode: http.statusCode)
        }
    }
}

private struct EmptyBody: Encodable, Sendable {}
private struct AdminLogoutResult: Decodable, Sendable { let success: Bool }
private struct AdminRateUpdateResult: Decodable, Sendable { let id: UUID? }
struct RateUpdateBody: Encodable, Sendable {
    let buy: String?
    let sell: String?
    let feeFixed: String?
    let requestID: String

    private enum CodingKeys: String, CodingKey {
        case buy
        case sell
        case feeFixed
        case requestID = "requestId"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(buy, forKey: .buy)
        try container.encode(sell, forKey: .sell)
        try container.encode(feeFixed, forKey: .feeFixed)
        try container.encode(requestID, forKey: .requestID)
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

    func login(username: String, password: String) async throws {
        let session = try await AdminAPI.shared.login(username: username, password: password)
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
    @State private var errorMessage: String?
    @State private var isLoggingIn = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                URPageTitle(title: "لوحة الإدارة", subtitle: "دخول آمن لفريق UR", symbol: "lock.shield.fill")

                URCard {
                    VStack(alignment: .trailing, spacing: 14) {
                        TextField("اسم المستخدم أو البريد الإداري", text: $username)
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
                        .buttonStyle(URPrimaryButtonStyle(isEnabled: !username.isEmpty && !password.isEmpty))
                        .disabled(username.isEmpty || password.isEmpty || isLoggingIn)
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
            try await auth.login(username: username, password: password)
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminDashboardView: View {
    let auth: AdminAuth
    @FocusState private var isRateInputFocused: Bool
    @State private var dashboard: AdminDashboard?
    @State private var rates: [Rate] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isLoggingOut = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                URPageTitle(title: "لوحة الإدارة", subtitle: "إدارة الأسعار على الخادم", symbol: "slider.horizontal.3")

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
                        AdminRateEditor(
                            rate: rate,
                            token: auth.sessionToken ?? "",
                            isValueFieldFocused: $isRateInputFocused,
                            onUnauthorized: { auth.clearExpiredSession() }
                        ) {
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
        .numericKeyboardDoneToolbar(focused: $isRateInputFocused)
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
    let onUnauthorized: () -> Void
    let onSaved: () async -> Void

    @FocusState.Binding private var isValueFieldFocused: Bool
    @State private var buy: String
    @State private var sell: String
    @State private var feeFixed: String
    @State private var message: String?
    @State private var isSaving = false
    @State private var isConfirmingSave = false
    private var changes: [AdminRateChange] {
        AdminRateDraft.changes(for: rate, buy: buy, sell: sell, feeFixed: feeFixed)
    }

    init(
        rate: Rate,
        token: String,
        isValueFieldFocused: FocusState<Bool>.Binding,
        onUnauthorized: @escaping () -> Void,
        onSaved: @escaping () async -> Void
    ) {
        self.rate = rate
        self.token = token
        self.onUnauthorized = onUnauthorized
        self.onSaved = onSaved
        _isValueFieldFocused = isValueFieldFocused
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
                    requestSave()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else if changes.isEmpty {
                        Text("لا توجد تغييرات")
                    } else {
                        Text("حفظ نسخة سعر جديدة")
                    }
                }
                .font(.caption.weight(.bold))
                .disabled(isSaving || changes.isEmpty)

                if let message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(message == "تم حفظ التعديل وتسجيله." ? URColor.success : URColor.error)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .onTapGesture { isValueFieldFocused = false }
        .alert("تأكيد تحديث السعر", isPresented: $isConfirmingSave) {
            Button("إلغاء", role: .cancel) {}
            Button("تأكيد وحفظ") {
                Task { await save() }
            }
        } message: {
            Text(AdminRateDraft.summary(of: changes))
        }
    }

    private func valueField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title).font(.caption2.weight(.bold))
            HStack(spacing: 4) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    toggleSign(text)
                } label: {
                    Image(systemName: "plusminus.circle.fill")
                        .foregroundStyle(text.wrappedValue.hasPrefix("-") ? URColor.error : URColor.deepNavy.opacity(0.45))
                }
                .accessibilityLabel("عكس إشارة \(title)")
                TextField("—", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .padding(8)
                    .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(title)
                    .focused($isValueFieldFocused)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleSign(_ text: Binding<String>) {
        if text.wrappedValue.hasPrefix("-") {
            text.wrappedValue.removeFirst()
        } else {
            text.wrappedValue = "-" + text.wrappedValue
        }
    }

    private func requestSave() {
        message = nil
        guard [buy, sell, feeFixed].allSatisfy({ AdminRateInputValidator.isValidDecimalOrAbsent($0) }) else {
            message = AdminAPIError.invalidInput.errorDescription
            return
        }
        guard AdminRateDraft.hasAnyValue(for: rate, buy: buy, sell: sell, feeFixed: feeFixed) else {
            message = "أدخل قيمة واحدة على الأقل للسعر أو العمولة."
            return
        }
        guard !changes.isEmpty else {
            message = "ماكو تغييرات لحفظها."
            return
        }
        isConfirmingSave = true
    }

    private func save() async {
        message = nil
        let buyValue = normalized(buy)
        let sellValue = normalized(sell)
        let feeValue = normalized(feeFixed)
        isSaving = true
        defer { isSaving = false }
        do {
            try await AdminAPI.shared.updateRate(
                id: rate.id,
                buy: buyValue,
                sell: sellValue,
                feeFixed: feeValue,
                requestID: UUID(),
                token: token
            )
            message = "تم حفظ التعديل وتسجيله."
            await onSaved()
        } catch AdminAPIError.unauthorized {
            onUnauthorized()
            message = AdminAPIError.unauthorized.errorDescription
        } catch {
            message = error.localizedDescription
        }
    }

    private func normalized(_ value: String) -> String? {
        AdminRateInputValidator.normalizedDecimalInput(value)
    }
}
