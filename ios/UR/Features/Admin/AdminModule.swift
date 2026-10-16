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
    case invalidInput
    case invalidCredentials
    case accountLocked
    case unauthorized
    case forbidden
    case invalidResponse
    case serviceUnavailable
    case offline
    case timedOut
    case requestFailed
    case secureStorage

    var errorDescription: String? {
        switch self {
        case .invalidInput: "تحقق من اسم المستخدم وكلمة المرور ثم حاول مرة أخرى."
        case .invalidCredentials: "اسم المستخدم أو كلمة المرور غير صحيحة."
        case .accountLocked: "تم إيقاف محاولات الدخول مؤقتاً لحماية الحساب. انتظر 15 دقيقة أو تواصل مع الدعم."
        case .unauthorized: "انتهت جلسة الإدارة. سجّل الدخول مجدداً."
        case .forbidden: "لا تملك صلاحية تنفيذ هذا الإجراء."
        case .invalidResponse: "استجابة الخادم غير صالحة."
        case .serviceUnavailable: "خدمة الإدارة غير متاحة حالياً. حاول بعد قليل."
        case .offline: "لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم حاول مرة أخرى."
        case .timedOut: "استغرق الاتصال وقتاً طويلاً. تحقق من الشبكة ثم أعد المحاولة."
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

    func login(username: String, password: String) async throws -> AdminSession {
        try await send(
            to: URL(string: "https://yqvcoomjunwokyxwofvt.supabase.co/functions/v1/admin-password-auth")!,
            method: "POST",
            body: ["username": username, "password": password],
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost: throw AdminAPIError.offline
            case .timedOut: throw AdminAPIError.timedOut
            default: throw AdminAPIError.requestFailed
            }
        }
        guard let http = response as? HTTPURLResponse else { throw AdminAPIError.invalidResponse }

        switch http.statusCode {
        case 200..<300:
            do { return try decoder.decode(AdminEnvelope<Value>.self, from: data).data }
            catch { throw AdminAPIError.invalidResponse }
        case 401:
            if url.lastPathComponent == "admin-password-auth" { throw AdminAPIError.invalidCredentials }
            throw AdminAPIError.unauthorized
        case 403: throw AdminAPIError.forbidden
        case 400: throw AdminAPIError.invalidInput
        case 423, 429: throw AdminAPIError.accountLocked
        case 503: throw AdminAPIError.serviceUnavailable
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
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct AdminLoginView: View {
    let auth: AdminAuth
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoggingIn = false
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }
    private var cleanUsername: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }
    // Password policy belongs to the authentication service. Older authorised
    // accounts may use a shorter numeric password, so the client must not
    // reject a non-empty credential before it reaches the server.
    private var canSubmit: Bool { cleanUsername.count >= 4 && !password.isEmpty && !isLoggingIn }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                URPageTitle(title: "لوحة الإدارة", subtitle: "دخول آمن لفريق UR", symbol: "lock.shield.fill")

                URCard {
                    VStack(alignment: .trailing, spacing: 14) {
                        TextField("اسم المستخدم أو البريد", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .username)
                            .onSubmit { focusedField = .password }
                            .foregroundStyle(URColor.deepNavy)
                            .multilineTextAlignment(.trailing)
                            .padding(14)
                            .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12))

                        SecureField("كلمة المرور", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .foregroundStyle(URColor.deepNavy)
                            .submitLabel(.go)
                            .onSubmit {
                                guard canSubmit else { return }
                                Task { await login() }
                            }
                            .multilineTextAlignment(.trailing)
                            .padding(14)
                            .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12))

                        Label("يمكن استخدام التعبئة التلقائية المحفوظة لهذا الحساب. لا تُشارك كلمة المرور أو رمز الجلسة.", systemImage: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(URColor.deepNavy.opacity(0.65))
                            .frame(maxWidth: .infinity, alignment: .trailing)

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
                        .buttonStyle(URPrimaryButtonStyle(isEnabled: canSubmit))
                        .disabled(!canSubmit)

                        Link(destination: URL(string: "https://urremit.com/contact")!) {
                            Label("استرجاع حساب الإدارة عبر الدعم المعتمد", systemImage: "person.crop.circle.badge.questionmark")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
            .padding(14)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("تم") { focusedField = nil }
            }
        }
    }

    private func login() async {
        guard canSubmit else {
            errorMessage = cleanUsername.count < 4
                ? "أدخل اسم مستخدم أو بريداً صحيحاً."
                : "أدخل كلمة المرور."
            return
        }
        isLoggingIn = true
        errorMessage = nil
        defer { isLoggingIn = false }
        do {
            try await auth.login(username: cleanUsername, password: password)
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// ═══════════════════════════════════════════════════
//  Admin Dashboard — مع زر النشرة
// ═══════════════════════════════════════════════════

private struct AdminDashboardView: View {
    let auth: AdminAuth
    @State private var dashboard: AdminDashboard?
    @State private var rates: [Rate] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isLoggingOut = false
    @State private var showNewsletterSheet = false
    @State private var search = ""
    @State private var selectedCategory = "all"
    @State private var workspace = "overview"

    private var filteredRates: [Rate] {
        rates.filter { rate in
            let categoryMatches = selectedCategory == "all" || rate.category == selectedCategory
            let searchMatches = search.isEmpty
                || rate.routeNameArabic.localizedCaseInsensitiveContains(search)
                || rate.routeNameEnglish.localizedCaseInsensitiveContains(search)
                || rate.destinationCurrency.localizedCaseInsensitiveContains(search)
            return categoryMatches && searchMatches
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    LinearGradient(colors: [URColor.deepNavy, URColor.royalBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(URColor.premiumGold.opacity(0.18)).frame(width: 150).offset(x: -210, y: -45)
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                            Text("جلسة إدارية آمنة").font(.caption.weight(.bold))
                        }.foregroundStyle(URColor.premiumGold)
                        Text("مركز إدارة UR").font(.title2.weight(.black)).foregroundStyle(.white)
                        Text("الأسعار، العمليات والنشرة اليومية في مكان واحد")
                            .font(.caption).foregroundStyle(.white.opacity(0.82))
                    }.padding(18).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(height: 145)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Picker("قسم الإدارة", selection: $workspace) {
                    Label("الرئيسية", systemImage: "square.grid.2x2.fill").tag("overview")
                    Label("الأسعار", systemImage: "chart.line.uptrend.xyaxis").tag("rates")
                    Label("العمليات", systemImage: "arrow.left.arrow.right.circle.fill").tag("operations")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("أقسام لوحة الإدارة")

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

                if workspace == "overview" {
                    VStack(alignment: .trailing, spacing: 12) {
                        Text("اختصارات الإدارة").font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
                        HStack(spacing: 10) {
                            Button { withAnimation { workspace = "rates" } } label: {
                                adminShortcut("تعديل الأسعار", "chart.line.uptrend.xyaxis")
                            }
                            Button { withAnimation { workspace = "operations" } } label: {
                                adminShortcut("العمليات", "chart.bar.doc.horizontal.fill")
                            }
                            Button { showNewsletterSheet = true } label: {
                                adminShortcut("نشرة اليوم", "doc.text.fill")
                            }.disabled(rates.isEmpty)
                        }
                        Text("اختَر القسم من الأعلى؛ كل أدوات الإدارة أصبحت ضمن مركز واحد.")
                            .font(.caption).foregroundStyle(URColor.deepNavy.opacity(0.62))
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(URColor.hairline))
                }

                if workspace == "rates" {
                  VStack(alignment: .trailing, spacing: 10) {
                    Text("إدارة الأسعار").font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
                    Text("ابحث، راجع ثم عدّل سعر الشراء أو البيع من نفس المكان.")
                        .font(.caption).foregroundStyle(URColor.deepNavy.opacity(0.62))
                    TextField("ابحث باسم الدولة أو العملة", text: $search)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryButton("الكل", value: "all")
                            categoryButton("العراق", value: "iraq")
                            categoryButton("الخليج", value: "gulf")
                            categoryButton("إيران وتركيا", value: "iran_turkey")
                            categoryButton("التحويلات", value: "transfers")
                            categoryButton("البنوك", value: "uae_banks")
                            categoryButton("دولي", value: "international")
                        }
                    }
                  }

                  if isLoading && rates.isEmpty {
                    ProgressView("جاري تحميل الأسعار الفعلية…").padding(30)
                  } else if rates.isEmpty {
                    ContentUnavailableView("لا توجد أسعار متاحة", systemImage: "wifi.exclamationmark", description: Text(errorMessage ?? "اسحب للأسفل أو اضغط تحديث البيانات."))
                  } else if filteredRates.isEmpty {
                    ContentUnavailableView.search(text: search)
                  } else {
                    ForEach(filteredRates) { rate in
                        AdminRateEditor(rate: rate, token: auth.sessionToken ?? "") {
                            await reload()
                        }
                    }
                  }
                }

                if workspace == "operations" {
                    VStack(alignment: .trailing, spacing: 14) {
                        HStack {
                            Image(systemName: "waveform.path.ecg.rectangle.fill")
                                .font(.title2).foregroundStyle(URColor.premiumGold)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("مساحة العمليات").font(.headline.weight(.black))
                                Text("الحوالات، العملاء، الإيداعات والإشعارات")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        NavigationLink { URNativeOperationsView() } label: {
                            Label("فتح مركز العمليات الكامل", systemImage: "arrow.up.left.circle.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(LinearGradient(colors: [URColor.premiumGold, URColor.royalBlue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 14))
                        }
                        HStack(spacing: 8) {
                            operationBadge("الحوالات", "arrow.left.arrow.right")
                            operationBadge("الإيداعات", "creditcard.fill")
                            operationBadge("الدعم", "bell.badge.fill")
                        }
                        Text("بعد ربط حساب المالك أول مرة تبقى أدوات العمليات متاحة من داخل مركز الإدارة.")
                            .font(.caption).foregroundStyle(URColor.deepNavy.opacity(0.62))
                    }
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(URColor.hairline))
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
        .refreshable { await reload() }
        .task { await reload() }
        .sheet(isPresented: $showNewsletterSheet) {
            NewsletterSheet(rates: rates)
        }
    }

    private func adminShortcut(_ title: String, _ symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2)
            Text(title).font(.caption.weight(.bold))
        }
        .foregroundStyle(URColor.deepNavy)
        .frame(maxWidth: .infinity, minHeight: 82)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline))
    }

    private func operationBadge(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(URColor.deepNavy)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 11))
    }

    private func categoryButton(_ title: String, value: String) -> some View {
        Button(title) { selectedCategory = value }
            .font(.caption.weight(.bold))
            .foregroundStyle(selectedCategory == value ? .white : URColor.deepNavy)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(selectedCategory == value ? URColor.royalBlue : .white, in: Capsule())
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
    @FocusState private var focusedField: Bool

    private var hasChanges: Bool {
        buy != (rate.buy.map { "\($0)" } ?? "") || sell != (rate.sell.map { "\($0)" } ?? "") || feeFixed != (rate.feeFixed.map { "\($0)" } ?? "")
    }

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

                valueField("سعر الشراء", text: $buy, color: URColor.success)
                valueField("سعر البيع", text: $sell, color: URColor.royalBlue)
                valueField("العمولة لكل 10,000$", text: $feeFixed, color: URColor.premiumGold)

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Label("حفظ السعر ونشره", systemImage: "checkmark.circle.fill")
                    }
                }
                .font(.caption.weight(.bold))
                .buttonStyle(.borderedProminent).tint(URColor.deepNavy)
                .disabled(isSaving || !hasChanges)

                if let message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(message == "تم حفظ التعديل وتسجيله." ? URColor.success : URColor.error)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("تم") { focusedField = false } } }
    }

    private func valueField(_ title: String, text: Binding<String>, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(title).font(.caption.weight(.black)).foregroundStyle(color)
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .focused($focusedField)
                .font(.title3.weight(.black)).monospacedDigit()
                .multilineTextAlignment(.trailing)
                .padding(12)
                .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.28)))
        }
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

// ═══════════════════════════════════════════════════
//  Newsletter Generator — مُنشئ النشرة التلقائي
// ═══════════════════════════════════════════════════

@Observable
@MainActor
final class NewsletterGenerator {
    private(set) var generatedText: String = ""
    private(set) var isGenerating: Bool = false

    func generate(from rates: [Rate]) {
        isGenerating = true
        defer { isGenerating = false }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "EEEE yyyy-MM-dd"
        let today = formatter.string(from: Date())

        var text = "📢 نشرة أسعار الحوالات اليومية\n"
        text += "🏢 شركة أُور للحوالات العالمية\n"
        text += "📅 \(today)\n\n"

        text += "━━━━━━━━━━━━━━━━━━\n"
        text += "💵 أسعار صرف الدولار\n"
        text += "━━━━━━━━━━━━━━━━━━\n"
        if let mainRate = rates.first(where: {
            $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD"
        }) {
            text += "🟢 شراء: \(formatNumber(mainRate.buy)) دينار\n"
            text += "🔴 بيع:  \(formatNumber(mainRate.sell)) دينار\n"
        }
        text += "\n"

        if let rmb = rates.first(where: {
            $0.routeNameArabic.contains("الصين") || $0.routeNameArabic.contains("يوان")
        }), let buy = rmb.buy {
            text += "🇨🇳 يوان صيني (رنمينبي): \(formatNumber(buy))\n\n"
        }

        let categories: [(String, String, String)] = [
            ("iraq", "🏛 داخل العراق", "📍"),
            ("gulf", "🏙 دول الخليج", "🌐"),
            ("iran_turkey", "🕌 إيران وتركيا", "🕌"),
            ("europe", "🏛 أوروبا وكندا", "🌍"),
            ("arab", "🌍 الدول العربية", "🌍"),
            ("transfers", "💸 التحويلات العالمية", "💸"),
            ("uae_banks", "🏦 بنوك الإمارات", "🏦"),
            ("india", "🇮🇳 الهند", "🇮🇳"),
            ("international", "🌐 أسعار دولية", "🌐"),
        ]

        for (cat, header, prefix) in categories {
            let catRates = rates.filter { $0.category == cat && !($0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD") }
            guard !catRates.isEmpty else { continue }

            text += "━━━━━━━━━━━━━━━━━━\n"
            text += "\(header)\n"
            text += "━━━━━━━━━━━━━━━━━━\n"

            for rate in catRates.sorted(by: { ($0.categoryOrder ?? 999) < ($1.categoryOrder ?? 999) }) {
                let amount = rate.feeFixed ?? rate.buy ?? rate.sell
                guard let value = amount else { continue }
                let sign = value >= 0 ? "+" : ""
                let suffix = rate.feeFixed != nil ? "$" : ""
                text += "\(prefix) \(rate.routeNameArabic): \(sign)\(formatNumber(value))\(suffix)\n"
            }
            text += "\n"
        }

        text += """
        ━━━━━━━━━━━━━━━━━━
        📞 تواصل معنا
        ━━━━━━━━━━━━━━━━━━
        🇮🇶 بغداد: +964 770 458 3730
        🇬🇧 لندن: +44 7915 387858
        💬 واتساب: +971 55 175 4032

        ✨ أموالك تصل أبعد في كل مكان ✨
        """

        generatedText = text
    }

    private func formatNumber(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Double(truncating: value as NSNumber))) ?? "\(value)"
    }
}

// ═══════════════════════════════════════════════════
//  Newsletter Sheet — عرض + نسخ + مشاركة
// ═══════════════════════════════════════════════════

struct NewsletterSheet: View {
    let rates: [Rate]
    @State private var text = ""
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .background(URColor.ivory)
            .navigationTitle("النشرة الجاهزة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = text
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            Label(copied ? "✓ تم النسخ" : "📋 نسخ",
                                  systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.subheadline.weight(.bold))
                        }
                        .tint(URColor.premiumGold)

                        Spacer()

                        Button {
                            shareNewsletter(text)
                        } label: {
                            Label("📱 مشاركة", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.bold))
                        }
                        .tint(URColor.deepNavy)
                    }
                    .padding(.horizontal)
                }
            }
            .onAppear {
                let gen = NewsletterGenerator()
                gen.generate(from: rates)
                text = gen.generatedText
            }
        }
    }

    private func shareNewsletter(_ text: String) {
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = root.view
            root.present(av, animated: true)
        }
    }
}
