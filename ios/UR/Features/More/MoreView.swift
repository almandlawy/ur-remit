import SwiftUI

struct MoreView: View {
    let api: any APIClient
    @EnvironmentObject private var auth: URAuthService
    @State private var adminTapCount = 0
    @State private var showAdminLogin = false
    @State private var showQRScanner = false
    @State private var scannedQR = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                GeometryReader { proxy in
                  ZStack(alignment: .bottomTrailing) {
                    Image("DubaiSkyline").resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: 142).clipped()
                    LinearGradient(colors: [.clear, URColor.deepNavy.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Button {
                                adminTapCount += 1
                                guard adminTapCount == 5 else { return }
                                adminTapCount = 0
                                showAdminLogin = true
                            } label: {
                                URBrandLogo(size: 34)
                            }.buttonStyle(.plain).accessibilityLabel("UR")
                            Spacer()
                            Image(systemName: "ellipsis.circle.fill").font(.title2).foregroundStyle(URColor.premiumGold)
                        }
                        Spacer()
                        Text("المزيد").font(.system(size: 25, weight: .black)).foregroundStyle(.white)
                        Text("حسابك، خدمات أور، الأمان والإعدادات بمكان واحد")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.82)).lineLimit(1)
                    }.padding(14).frame(width: proxy.size.width, height: 142, alignment: .bottomTrailing)
                  }
                }
                .frame(height: 142)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.35)))
                .shadow(color: URColor.deepNavy.opacity(0.16), radius: 14, y: 7)
                NavigationLink { URNativeAccountView() } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "chevron.left").font(.caption.weight(.bold)); Spacer()
                        VStack(alignment: .trailing, spacing: 3) { Text("حسابي").font(.headline.weight(.bold)); Text("الدخول والخروج وحذف الحساب").font(.caption).foregroundStyle(.secondary) }
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 38)).foregroundStyle(URColor.royalBlue)
                    }.padding(16).foregroundStyle(URColor.deepNavy).background(URColor.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(URColor.hairline))
                }
                MoreGroup(title: "الخدمات") {
                    NavigationLink { CustomerRemittanceView() } label: { MoreRow("طلب حوالة والدفع والوصولات", "arrow.left.arrow.right.circle.fill") }
                    Divider()
                    NavigationLink { OfficesView(api: api) } label: { MoreRow("المراكز المعتمدة", "building.2.fill") }
                    Divider(); NavigationLink { DailyReminderView() } label: { MoreRow("تذكير يومي بالأسعار", "bell.badge.fill") }
                    Divider(); NavigationLink { ShareTemplatesGallery() } label: { MoreRow("قوالب المشاركة", "square.and.arrow.up.on.square.fill") }
                    Divider(); NavigationLink { URWeeklyLeaderboardView() } label: { MoreRow("الأكثر طلبًا هذا الأسبوع", "trophy.fill") }
                    Divider(); Button { showQRScanner = true } label: { MoreRow("مسح رمز QR", "qrcode.viewfinder") }
                    if !scannedQR.isEmpty { Text(scannedQR).font(.caption2.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .trailing).padding(.vertical, 8) }
                    Divider(); NavigationLink { SecurityCenterView() } label: { MoreRow("عن الأسعار", "info.circle.fill") }
                }
                MoreGroup(title: "حول UR") {
                    Link(destination: URL(string: "https://urremit.com/privacy")!) { MoreRow("سياسة الخصوصية", "hand.raised.fill") }
                    Divider(); Link(destination: URL(string: "https://urremit.com/terms")!) { MoreRow("الشروط والأحكام", "doc.text.fill") }
                    Divider(); Link(destination: URL(string: "https://urremit.com/contact")!) { MoreRow("اتصل بنا", "phone.fill") }
                }
                Text("UR Remit  •  الإصدار \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")").font(.caption2).foregroundStyle(.secondary).padding(.top, 8)
            }.padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 14)
        }
        .background(URColor.ivory.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdminLogin) {
            NavigationStack {
                AdminEntryView()
            }
        }
        .fullScreenCover(isPresented: $showQRScanner) {
            QRScannerView { scannedQR = $0 }
        }
    }
}

private struct MoreGroup<Content: View>: View {
    let title: String; @ViewBuilder let content: Content
    var body: some View { VStack(alignment: .trailing, spacing: 8) { Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary).padding(.trailing, 5); VStack(spacing: 0) { content }.padding(.horizontal, 14).background(URColor.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline)) } }
}

private struct MoreRow: View {
    let title: String; let symbol: String
    init(_ title: String, _ symbol: String) { self.title = title; self.symbol = symbol }
    var body: some View { HStack { Image(systemName: "chevron.left").font(.caption2.weight(.bold)).foregroundStyle(.secondary); Spacer(); Text(title).font(.subheadline.weight(.semibold)); Image(systemName: symbol).foregroundStyle(URColor.premiumGold).frame(width: 28) }.foregroundStyle(URColor.deepNavy).frame(height: 52) }
}

struct OfficesView: View {
    let api: any APIClient
    @State private var offices: [Office] = []
    @State private var isLoading = true
    @State private var isOffline = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                URPageTitle(title: "مراكزنا", subtitle: "مراكز ووكلاء UR المعتمدون", symbol: "mappin.and.ellipse")
                HStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("الدليل الرسمي المباشر").font(.subheadline.weight(.black))
                        Text(isOffline ? "تعذّر تحميل الدليل؛ لا نعرض مكاتب غير موثقة" : "أي مكتب يُضاف إلى نظام UR يظهر هنا تلقائياً").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(spacing: 5) {
                        URIconBadge(symbol: "building.2.crop.circle.fill", size: 48)
                        Text("\(offices.count) مراكز")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(URColor.deepNavy)
                    }
                }
                .padding(14).background(URColor.premiumGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                if isOffline {
                    HStack(spacing: 10) {
                        Button("إعادة المحاولة") { Task { await loadOffices() } }.font(.caption.weight(.bold)).foregroundStyle(URColor.royalBlue)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) { Text("الاتصال غير متاح").font(.caption.weight(.bold)); Text("أعد المحاولة لعرض المراكز المعتمدة").font(.caption2).foregroundStyle(.secondary) }
                        Image(systemName: "wifi.slash").foregroundStyle(.orange)
                    }
                    .padding(11)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(.orange.opacity(0.22)))
                } else if isLoading {
                    HStack { ProgressView(); Text("تحديث دليل المراكز…").font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 4)
                }
                ForEach(offices) { office in
                    OfficeCard(office: office)
                }
                if !isLoading && offices.isEmpty {
                    ContentUnavailableView("لا توجد مراكز موثقة متاحة", systemImage: "building.2.crop.circle", description: Text("لا نعرض بيانات احتياطية غير صادرة من نظام UR."))
                }
                NavigationLink { ServiceDestinationsView() } label: {
                    HStack { Image(systemName: "chevron.left"); Spacer(); VStack(alignment: .trailing, spacing: 3) { Text("شبكة الأسعار العالمية").font(.headline.weight(.bold)); Text("دول ومدن تتوفر لها معلومات سعرية إرشادية").font(.caption).foregroundStyle(.secondary) }; Image(systemName: "globe.europe.africa.fill").font(.title2).foregroundStyle(URColor.premiumGold) }
                        .foregroundStyle(URColor.deepNavy).padding(16).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline))
                }
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .task { await loadOffices() }
    }

    private func loadOffices() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let remote = try await api.offices()
            if !remote.isEmpty { offices = remote }
            isOffline = false
        } catch {
            isOffline = true
        }
    }
}

private struct OfficeCard: View {
    let office: Office

    var body: some View {
        URCard {
            VStack(alignment: .trailing, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    if office.verified {
                        Label("معتمد", systemImage: "checkmark.seal.fill").font(.caption2.weight(.bold)).foregroundStyle(URColor.success)
                            .padding(.horizontal, 9).padding(.vertical, 6).background(URColor.success.opacity(0.09), in: Capsule())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(office.nameArabic).font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
                        Text(office.publicCode).font(.caption2.monospaced().weight(.semibold)).foregroundStyle(.secondary)
                    }
                    URIconBadge(symbol: office.countryArabic == "العراق" ? "building.columns.fill" : "building.2.fill", size: 48, tint: .white, background: URColor.royalBlue)
                }
                Divider()
                Label("\(office.cityArabic)، \(office.countryArabic)", systemImage: "mappin.circle.fill").font(.subheadline.weight(.bold)).foregroundStyle(URColor.deepNavy)
                Text(office.addressArabic).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
                HStack(spacing: 8) {
                    if let phone = office.phone, let url = URL(string: "tel:\(phone)") {
                        Link(destination: url) { Label("اتصال", systemImage: "phone.fill").frame(maxWidth: .infinity, minHeight: 40).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 11)).foregroundStyle(.white) }
                    }
                    if let latitude = office.latitude, let longitude = office.longitude,
                       let mapURL = URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)") {
                        Link(destination: mapURL) { Label("الخريطة", systemImage: "map.fill").frame(maxWidth: .infinity, minHeight: 40).background(URColor.premiumGold, in: RoundedRectangle(cornerRadius: 11)).foregroundStyle(URColor.deepNavy) }
                    }
                }.font(.caption.weight(.bold))
            }
        }
    }
}

private struct ServiceDestinationsView: View {
    private let groups: [(String, String, [String])] = [
        ("العراق", "🇮🇶", ["بغداد", "أربيل", "السليمانية", "البصرة", "الموصل", "كربلاء"]),
        ("الخليج", "🏙️", ["دبي", "السعودية", "الكويت", "قطر", "البحرين", "سلطنة عُمان"]),
        ("تركيا — نقاط خدمة", "🇹🇷", ["إسطنبول", "أنقرة", "غازي عنتاب"]),
        ("سوريا — المحافظات", "🇸🇾", ["دمشق", "ريف دمشق", "حلب", "حمص", "حماة", "اللاذقية", "طرطوس", "إدلب", "درعا", "السويداء", "دير الزور", "الرقة", "الحسكة", "القنيطرة"]),
        ("الشرق الأوسط", "🌍", ["طهران", "مشهد", "قم", "الأردن", "بيروت", "مصر"]),
        ("دولية", "🌐", ["مصر", "الصين", "بريطانيا", "فرنسا", "ألمانيا", "كندا"])
    ]
    var body: some View {
        ScrollView { VStack(spacing: 12) {
            URPageTitle(title: "شبكة الأسعار", subtitle: "معلومات إرشادية حسب الدولة والمدينة", symbol: "globe.europe.africa.fill")
            ForEach(groups, id: \.0) { group in
                URCard { VStack(alignment: .trailing, spacing: 10) {
                    HStack { Spacer(); Text(group.0).font(.headline.weight(.black)); Text(group.1).font(.title3) }
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
                        ForEach(group.2, id: \.self) { Text($0).font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 36).background(URColor.ivory, in: RoundedRectangle(cornerRadius: 10)) }
                    }
                } }
            }
            Text("هذه قائمة معلومات سعرية وليست عرضًا لتنفيذ حوالة أو معاملة مالية. قد تتغير الأسعار حسب السوق والوقت.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
        }.padding(14) }.background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
    }
}

struct AgentVerificationView: View {
    let api: any APIClient
    @State private var code = ""
    @State private var result: AgentVerification?
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                URPageTitle(title: "تحقق من وكيل", subtitle: "تأكد من الاعتماد قبل تسليم المبلغ", symbol: "checkmark.shield.fill")
                URCard { VStack(alignment: .trailing, spacing: 12) {
                    Text("رمز الوكيل").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    TextField("أدخل الرمز", text: $code).autocorrectionDisabled().textInputAutocapitalization(.characters).multilineTextAlignment(.center).padding().background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12))
                    Button(loading ? "جارٍ التحقق…" : "تحقق الآن") { Task { await verify() } }.buttonStyle(URPrimaryButtonStyle()).disabled(code.count < 4 || loading)
                } }
                if let result { Label(result.status == "VERIFIED" ? "وكيل معتمد" : "الوكيل غير معتمد", systemImage: result.status == "VERIFIED" ? "checkmark.seal.fill" : "xmark.shield.fill").font(.title3.weight(.black)).foregroundStyle(result.status == "VERIFIED" ? URColor.success : .red).padding(20).frame(maxWidth: .infinity).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16)) }
                Label("لا تسلم أي مبلغ إلا بعد ظهور حالة «وكيل معتمد».", systemImage: "exclamationmark.shield.fill").font(.caption).foregroundStyle(.secondary).padding()
            }.padding(14)
        }.background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
    }
    private func verify() async { loading = true; defer { loading = false }; result = try? await api.verifyAgent(code: code) }
}

struct SecurityCenterView: View {
    var body: some View {
        ScrollView { VStack(spacing: 12) {
            URPageTitle(title: "عن الأسعار", subtitle: "معلومات مهمة قبل استخدام البيانات", symbol: "info.circle.fill")
            SafetyRow("الأسعار المعروضة إرشادية وليست عرضًا ملزمًا", "chart.line.uptrend.xyaxis")
            SafetyRow("قد تتغير الأسعار حسب السوق والوقت", "clock.fill")
            SafetyRow("تأكد من تفاصيل الحوالة والإيداع قبل الإرسال", "checkmark.shield.fill")
            Link(destination: URL(string: "https://urremit.com/contact")!) { Label("الإبلاغ عن حساب مزيف", systemImage: "exclamationmark.bubble.fill").frame(maxWidth: .infinity, minHeight: 48).background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.red).font(.subheadline.weight(.bold)) }
        }.padding(14) }.background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
    }
}

private struct SafetyRow: View {
    let title: String; let symbol: String
    init(_ title: String, _ symbol: String) { self.title = title; self.symbol = symbol }
    var body: some View { HStack { Spacer(); Text(title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing); Image(systemName: symbol).font(.title3).foregroundStyle(URColor.success).frame(width: 42, height: 42).background(URColor.success.opacity(0.10), in: RoundedRectangle(cornerRadius: 12)) }.foregroundStyle(URColor.deepNavy).padding(14).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline)) }
}

// BEGIN UR_NATIVE_FLOW
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Security
import UIKit
import QuickLook
import AuthenticationServices
import UserNotifications

// Native customer and owner screens. PayPal approval uses a secure authentication session.
@MainActor
final class URNativeAPI: ObservableObject {
    static let customer = URNativeAPI(scope: "customer")
    static let owner = URNativeAPI(scope: "owner")
    @Published var profile: [String: String] = [:]
    private let account: String
    private let session: URLSession
    private var token: String?
    private var sessionGeneration = 0
    private init(scope: String) {
        account = "com.urremit.native." + scope
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data { token = String(data: data, encoding: .utf8) }
    }
    func request(_ path: String, method: String = "GET", body: [String: Any]? = nil, bytes: Data? = nil, contentType: String = "application/json", idempotencyKey: String? = nil) async throws -> [String: Any] {
        guard let url = URL(string: "https://urremit.com" + path), url.host == "urremit.com" else { throw URNativeError.message("عنوان غير صحيح") }
        let generation = sessionGeneration
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("URGlobal-iOS/Native", forHTTPHeaderField: "User-Agent")
        if let idempotencyKey { request.setValue(idempotencyKey, forHTTPHeaderField: "X-Idempotency-Key") }
        if let token { request.setValue("ur_session=" + token, forHTTPHeaderField: "Cookie") }
        request.httpBody = try body.map { try JSONSerialization.data(withJSONObject: $0) } ?? bytes
        let (data, response) = try await send(request)
        try Task.checkCancellation()
        guard generation == sessionGeneration else { throw CancellationError() }
        guard let http = response as? HTTPURLResponse else { throw URNativeError.message("استجابة غير صحيحة") }
        let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let json = parsed ?? [:]
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { clear() }
            throw URNativeError.message(json["error"] as? String ?? "تعذر تنفيذ الطلب (\(http.statusCode))")
        }
        guard ["urremit.com", "www.urremit.com", "ur-remit.taha-112.chatgpt.site"].contains(http.url?.host ?? "") else { throw URNativeError.message("تغير عنوان الاستجابة؛ لم يتم تأكيد العملية") }
        guard http.statusCode == 204 || parsed != nil else { throw URNativeError.message("استجابة الخادم غير مكتملة؛ راجع سجل الطلبات قبل إعادة الإرسال") }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: http.allHeaderFields.reduce(into: [String: String]()) { result, entry in result[String(describing: entry.key)] = String(describing: entry.value) }, for: url)
        if let cookie = cookies.first(where: { $0.name == "ur_session" }), !cookie.value.isEmpty {
            let data = Data(cookie.value.utf8)
            SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account] as CFDictionary)
            let status = SecItemAdd([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, kSecValueData as String: data] as CFDictionary, nil)
            guard status == errSecSuccess else { throw URNativeError.message("تعذر حفظ الدخول بأمان") }
            token = cookie.value
        }
        return json
    }
    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await session.data(for: request) }
        catch let error as URLError where error.code == .cannotFindHost || error.code == .dnsLookupFailed {
            guard let original = request.url, var components = URLComponents(url: original, resolvingAgainstBaseURL: false) else { throw error }
            components.host = "ur-remit.taha-112.chatgpt.site"
            guard let fallback = components.url else { throw error }
            var retry = request; retry.url = fallback
            return try await session.data(for: retry)
        }
    }
    func refreshProfile() async throws {
        let result = try await request("/api/customer/profile")
        profile = (result["profile"] as? [String: Any] ?? [:]).reduce(into: [:]) { result, entry in result[entry.key] = String(describing: entry.value) }
    }
    func resumeCustomerAccount(appEmail: String? = nil) async {
        if let linked = UserDefaults.standard.string(forKey: "URNativeLinkedAppEmail"), appEmail == nil || linked.lowercased() != appEmail?.lowercased() { await logout() }
        do {
            try await refreshProfile()
            if let appEmail, profile["email"]?.lowercased() != appEmail.lowercased() { await logout() } else { return }
        } catch {}
        guard !Task.isCancelled && appEmail != nil else { return }
        do { try await connectAppAccount() } catch {}
    }
    func downloadEvidence(_ path: String) async throws -> URL {
        guard path.hasPrefix("/api/customer/evidence?"), let url = URL(string: "https://urremit.com" + path) else { throw URNativeError.message("عنوان إثبات غير صحيح") }
        var request = URLRequest(url: url); request.timeoutInterval = 30
        if let token { request.setValue("ur_session=" + token, forHTTPHeaderField: "Cookie") }
        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URNativeError.message("تعذر فتح إثبات الإيداع") }
        let ext = http.mimeType == "application/pdf" ? "pdf" : http.mimeType == "image/png" ? "png" : "jpg"
        let file = FileManager.default.temporaryDirectory.appending(path: "UR-proof-" + UUID().uuidString + "." + ext)
        try data.write(to: file, options: .atomic); return file
    }
    func connectAppAccount(name: String = "", phone: String = "", accepted: Bool = false) async throws {
        let access = try await URAuthService.live.refreshedAccessToken()
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else { throw URNativeError.message("إعداد المصادقة غير مكتمل") }
        _ = try await request("/api/customer/link-app-account", method: "POST", body: ["accessToken": access, "publishableKey": key, "fullName": name, "phone": phone, "acceptTerms": accepted])
        try await refreshProfile()
        UserDefaults.standard.set(profile["email"], forKey: "URNativeLinkedAppEmail")
    }
    func connectOwnerAccount() async throws -> [String: Any] {
        let access = try await URAuthService.live.refreshedAccessToken()
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else { throw URNativeError.message("إعداد المصادقة غير مكتمل") }
        return try await request("/api/native/owner-session", method: "POST", body: ["accessToken": access, "publishableKey": key])
    }
    func clear() {
        sessionGeneration += 1
        token = nil; profile = [:]
        if account.hasSuffix(".customer") { UserDefaults.standard.removeObject(forKey: "URNativeLinkedAppEmail") }
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account] as CFDictionary)
    }
    func logout() async { _ = try? await request("/api/auth/logout", method: "POST"); clear() }
}
private enum URNativeError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
@MainActor
enum URNativeTelemetry {
    static func send(_ event: String) async {
        let defaults = UserDefaults.standard
        let installation = defaults.string(forKey: "URNativeInstallation") ?? UUID().uuidString
        defaults.set(installation, forKey: "URNativeInstallation")
        do {
            _ = try await URNativeAPI.customer.request("/api/native/events", method: "POST", body: ["installationId": installation, "event": event])
            if event == "app_first_open" { defaults.set(true, forKey: "URNativeFirstOpenSent") }
        } catch { /* Telemetry never blocks the customer's task. */ }
    }
    static func launch() async {
        if !UserDefaults.standard.bool(forKey: "URNativeFirstOpenSent") { await send("app_first_open") }
        await send("app_open")
    }
}

private struct URWeeklyLeaderboardView: View {
    @State private var rows: [[String: Any]] = []
    @State private var loading = true
    @State private var message = ""
    var body: some View {
        List {
            if loading { ProgressView("تحميل البيانات الفعلية…") }
            else if rows.isEmpty { ContentUnavailableView("لا توجد إحصائية منشورة", systemImage: "trophy", description: Text(message.isEmpty ? "لا نعرض ترتيباً تقديرياً." : message)) }
            else {
                ForEach(rows.indices, id: \.self) { index in
                    HStack { Text("\(index + 1)").font(.title2.weight(.black)).foregroundStyle(URColor.premiumGold); VStack(alignment: .leading) { Text(urText(rows[index], "name")).font(.headline); Text("\(urText(rows[index], "requests")) طلبات مؤكدة").font(.caption).foregroundStyle(.secondary) }; Spacer() }
                }
            }
        }
        .navigationTitle("الأكثر طلبًا")
        .task {
            do { rows = try await URNativeAPI.customer.request("/api/native/leaderboard?period=week")["routes"] as? [[String: Any]] ?? []; message = rows.isEmpty ? "الخادم لم ينشر بيانات أسبوعية بعد." : "" }
            catch { message = "الإحصائية غير متاحة حالياً؛ لم يُعرض رقم تقديري." }
            loading = false
        }
    }
}

struct URNativeLoginView: View {
    @ObservedObject var api: URNativeAPI
    var owner = false
    @State private var register = false
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var username = ""
    @State private var password = ""
    @State private var acceptTerms = false
    @State private var challenge = ""
    @State private var code = ""
    @State private var message = ""
    @State private var busy = false
    @State private var changePassword = false
    @State private var newPassword = ""
    var body: some View {
        Form {
            Section(owner ? "دخول لوحة العمليات" : "حساب أور") {
                if owner && challenge.isEmpty && !changePassword {
                    Text("ادخل بحساب مالك أور المسجل في التطبيق. بيانات إدارة العمليات مستقلة عن كلمة مرور إدارة الأسعار.").font(.footnote).foregroundStyle(.secondary)
                    Button("الدخول بحساب التطبيق — المالك") { Task { await enterAsOwner() } }.buttonStyle(.borderedProminent).disabled(busy)
                }
                if !owner { Toggle("إنشاء حساب جديد", isOn: $register).disabled(!challenge.isEmpty) }
                if register && !owner {
                    TextField("الاسم الكامل", text: $name).textContentType(.name)
                    TextField("البريد الإلكتروني", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField("الهاتف مع رمز الدولة +964…", text: $phone).keyboardType(.phonePad)
                }
                if changePassword {
                    SecureField("كلمة المرور الحالية", text: $password)
                    SecureField("كلمة المرور الجديدة", text: $newPassword).textContentType(.newPassword)
                    Text("12 خانة على الأقل: حرف كبير وصغير ورقم ورمز.").font(.footnote)
                } else if challenge.isEmpty {
                    TextField(owner ? "اسم مستخدم إدارة العمليات" : "اسم المستخدم", text: $username).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("كلمة المرور", text: $password).textContentType(register ? .newPassword : .password)
                } else { TextField("رمز التحقق أو رمز الاسترجاع", text: $code).textContentType(.oneTimeCode).keyboardType(.asciiCapable).textInputAutocapitalization(.never).autocorrectionDisabled() }
                if register && !owner {
                    Text("اسم المستخدم: 5–32 خانة بحروف إنجليزية. كلمة المرور: 12 خانة على الأقل، حرف كبير وصغير ورقم ورمز.").font(.footnote)
                    Toggle("أوافق على الشروط وسياسة الخصوصية", isOn: $acceptTerms)
                    Link("الشروط", destination: URL(string: "https://www.urremit.com/terms")!)
                    Link("الخصوصية", destination: URL(string: "https://www.urremit.com/privacy")!)
                }
                Button(busy ? "جاري التحقق…" : changePassword ? "تغيير كلمة المرور ومتابعة" : register ? "إنشاء حساب ومتابعة" : "تسجيل الدخول") { Task { await authenticate() } }
                    .disabled(busy || (register && !acceptTerms) || (changePassword ? password.isEmpty || newPassword.isEmpty : challenge.isEmpty && (username.isEmpty || password.isEmpty)))
                if !challenge.isEmpty { Button("إعادة تسجيل الدخول") { challenge = ""; code = "" } }
                if !message.isEmpty { Text(message).foregroundStyle(.red) }
            }
        }.scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle(owner ? "الإدارة" : "التسجيل داخل التطبيق")
    }
    private func enterAsOwner() async {
        busy = true; message = ""; defer { busy = false }
        do {
            let result = try await api.connectOwnerAccount()
            if result["requiresMfa"] as? Bool == true { challenge = result["challengeToken"] as? String ?? ""; code = ""; password = ""; return }
            try await api.refreshProfile()
            guard api.profile["role"] == "super_admin" else { await api.logout(); throw URNativeError.message("هذا الحساب ليس حساب المالك") }
        } catch { message = error.localizedDescription }
    }
    private func authenticate() async {
        guard !busy else { return }
        busy = true; message = ""; defer { busy = false }
        do {
            let result: [String: Any]
            if changePassword {
                result = try await api.request("/api/auth/change-password", method: "POST", body: ["currentPassword": password, "newPassword": newPassword])
            } else if !challenge.isEmpty {
                result = try await api.request("/api/auth/mfa/verify", method: "POST", body: ["challengeToken": challenge, "code": code])
            } else {
                if register && !owner {
                    _ = try await api.request("/api/customer/register", method: "POST", body: ["fullName": name, "email": email, "phone": phone, "username": username, "password": password, "acceptTerms": acceptTerms])
                    register = false
                }
                result = try await api.request("/api/auth/login", method: "POST", body: ["username": username, "password": password])
            }
            if result["requiresMfa"] as? Bool == true { challenge = result["challengeToken"] as? String ?? ""; password = ""; return }
            if result["mustChangePassword"] as? Bool == true { changePassword = true; challenge = ""; code = ""; message = "غيّر كلمة المرور المؤقتة للمتابعة"; return }
            try await api.refreshProfile()
            guard api.profile["role"] == (owner ? "super_admin" : "customer") else { await api.logout(); throw URNativeError.message("استخدم حساب " + (owner ? "المالك" : "عميل")) }
            password = ""; newPassword = ""; changePassword = false; code = ""; challenge = ""
        } catch { message = error.localizedDescription }
    }
}

struct URNativeAccountView: View {
    @ObservedObject private var api = URNativeAPI.customer
    @EnvironmentObject private var auth: URAuthService
    @State private var name = ""
    @State private var phone = ""
    @State private var accepted = false
    @State private var message = ""
    @State private var confirmDelete = false
    @State private var busy = false
    var body: some View {
        Form {
            Section("حساب التطبيق") {
                if auth.isAuthenticated {
                    LabeledContent("البريد", value: auth.email ?? "حساب UR")
                    NavigationLink("التفضيلات وإعدادات حساب التطبيق") { AccountView() }
                } else {
                    NavigationLink("تسجيل الدخول Apple / Google") { AccountView() }
                    Text("تقدر تتصفح الأسعار والحاسبة بدون حساب.").font(.footnote)
                }
            }
            Section("حساب الحوالات") {
                if api.profile.isEmpty {
                    if auth.isAuthenticated {
                        Text("حساب التطبيق نفسه يستخدم للحوالات. نأخذ اسم المرسل ورقم هاتفه من أول طلب، بدون تسجيل ثاني.").font(.footnote)
                        NavigationLink("إنشاء أول حوالة بحسابي") { URNativeTransferForm() }
                    }
                    NavigationLink("الدخول ببيانات حساب الحوالات") { URNativeLoginView(api: api) }
                } else {
                    LabeledContent("الاسم", value: api.profile["name"] ?? "")
                    LabeledContent("البريد", value: api.profile["email"] ?? "")
                    LabeledContent("الهاتف", value: api.profile["phone"] ?? "")
                    NavigationLink("حوالاتي والوصولات") { CustomerRemittanceView() }
                }
            }
            Section("إدارة الحساب والخصوصية") {
                if auth.isAuthenticated {
                    NavigationLink { URNativeDeleteAccountView() } label: { Label("حذف حسابي نهائياً", systemImage: "trash.fill").foregroundStyle(URColor.error) }
                } else if !api.profile.isEmpty {
                    Button("حذف حساب الحوالات نهائياً", role: .destructive) { confirmDelete = true }.disabled(busy)
                } else {
                    Text("خيارات الحذف تظهر بعد الدخول إلى حسابك.").font(.footnote)
                }
                if auth.isAuthenticated || !api.profile.isEmpty {
                    Button(busy ? "جاري تسجيل الخروج…" : "تسجيل الخروج من كل الحسابات", role: .destructive) { Task { await logoutAll() } }.disabled(busy)
                }
                Text("حذف الحساب نهائي. السجلات المالية التي يلزم الاحتفاظ بها تبقى ضمن النظام المحاسبي.").font(.footnote).foregroundStyle(.secondary)
            }
            if !message.isEmpty { Section { Text(message).foregroundStyle(.red) } }
        }.scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle("حسابي")
            .environment(\.layoutDirection, .rightToLeft)
            .task(id: auth.isAuthenticated) { if !busy { await api.resumeCustomerAccount(appEmail: auth.isAuthenticated ? auth.email : nil) } }
            .alert("حذف حساب الحوالات نهائياً؟", isPresented: $confirmDelete) {
                Button("حذف الحساب", role: .destructive) { Task { await deleteCustomer() } }
                Button("إلغاء", role: .cancel) {}
            } message: { Text("سيُحذف الدخول وملف العميل. السجلات المالية تبقى محفوظة. هذا الإجراء لا يمكن التراجع عنه.") }
    }
    private func connect() async {
        busy = true; message = ""; defer { busy = false }
        do { try await api.connectAppAccount(name: name, phone: urPhone(phone), accepted: accepted) } catch { message = error.localizedDescription }
    }
    private func logoutAll() async {
        busy = true; message = ""; defer { busy = false }
        await auth.signOut()
        await api.logout()
        await URNativeAPI.owner.logout()
        api.clear(); URNativeAPI.owner.clear()
    }
    private func deleteCustomer() async {
        busy = true; message = ""; defer { busy = false }
        do {
            let result = try await api.request("/api/customer/profile", method: "DELETE", body: ["confirm": true])
            guard result["success"] as? Bool == true else { throw URNativeError.message("لم يؤكد الخادم حذف الحساب") }
            api.clear(); message = "تم حذف حساب الحوالات"
        } catch { message = error.localizedDescription }
    }
}
private struct URNativeDeleteAccountView: View {
    @EnvironmentObject private var auth: URAuthService
    @ObservedObject private var api = URNativeAPI.customer
    @State private var confirmation = ""
    @State private var busy = false
    @State private var customerRemoved = false
    @State private var done = false
    @State private var message = ""
    var body: some View {
        Form {
            Section("حذف حسابي نهائياً") {
                Text("حذف حساب التطبيق وحساب الحوالات المتصل بهذه الجلسة إجراء نهائي. تبقى السجلات المالية اللازمة للمحاسبة؛ لا تُحذف الحوالات أو الوصولات من سجل الشركة.")
                if api.profile.isEmpty && !customerRemoved { Text("لا توجد جلسة حوالات متصلة حالياً. إذا عندك حساب حوالات مستقل أو محمي بتحقق بخطوتين، سجل دخوله أولاً حتى يشمله الحذف.").font(.footnote) }
                if !done {
                    TextField("اكتب حذف للتأكيد", text: $confirmation).autocorrectionDisabled()
                    Button(busy ? "جاري الحذف…" : "حذف حسابي نهائياً", role: .destructive) { Task { await remove() } }.disabled(busy || confirmation.trimmingCharacters(in: .whitespacesAndNewlines) != "حذف" || !auth.isAuthenticated)
                }
                if !message.isEmpty { Text(message) }
                if done { Text("تقدر تستمر بتصفح الأسعار بدون حساب.").font(.footnote) }
            }
        }.navigationTitle("حذف الحساب").interactiveDismissDisabled(busy).navigationBarBackButtonHidden(busy)
    }
    private func remove() async {
        guard auth.isAuthenticated else { return }
        busy = true; message = ""; defer { busy = false }
        do {
            if !customerRemoved && api.profile["role"] == "customer" {
                let result = try await api.request("/api/customer/profile", method: "DELETE", body: ["confirm": true])
                guard result["success"] as? Bool == true else { throw URNativeError.message("لم يؤكد الخادم حذف حساب الحوالات") }
                customerRemoved = true; api.clear()
            }
            try await auth.deleteAccount()
            await api.logout(); await URNativeAPI.owner.logout()
            done = true; message = "تم حذف حساب التطبيق" + (customerRemoved ? " وحساب الحوالات المتصل به" : "")
        } catch {
            message = (customerRemoved ? "تم حذف حساب الحوالات؛ حذف حساب التطبيق لم يكتمل. أعد المحاولة: " : "لم يكتمل حذف الحساب: ") + error.localizedDescription
        }
    }
}

struct CustomerRemittanceView: View {
    @EnvironmentObject private var auth: URAuthService
    @ObservedObject private var api = URNativeAPI.customer
    @State private var orders: [[String: Any]] = []
    @State private var message = ""
    @State private var loading = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                GeometryReader { proxy in
                  ZStack(alignment: .bottomTrailing) {
                    Image("MyTransfersHero").resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: 158).clipped()
                    LinearGradient(colors: [.clear, URColor.deepNavy.opacity(0.97)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Label("متابعة آمنة", systemImage: "checkmark.shield.fill")
                                .font(.caption2.weight(.black)).foregroundStyle(URColor.premiumGold)
                                .padding(.horizontal, 10).padding(.vertical, 6).background(.black.opacity(0.28), in: Capsule())
                            Spacer()
                            URBrandLogo(size: 34)
                        }
                        Spacer()
                        Text("حوالاتي").font(.system(size: 25, weight: .black)).foregroundStyle(.white)
                        Text("أنشئ الطلب، تابع حالته، وافتح الوصولات من مكان واحد")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.86)).lineLimit(1)
                    }.padding(14).frame(width: proxy.size.width, height: 158, alignment: .bottomTrailing)
                  }
                }
                .frame(height: 158).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.34)))
                .shadow(color: URColor.deepNavy.opacity(0.18), radius: 14, y: 7)

                HStack(spacing: 10) {
                    NavigationLink { URNativeNotificationView(api: api) } label: {
                        URRemittanceAction(title: "الإشعارات", subtitle: "آخر التحديثات", symbol: "bell.badge.fill", filled: false)
                    }
                    NavigationLink { URNativeTransferForm() } label: {
                        URRemittanceAction(title: "حوالة جديدة", subtitle: "الحسبة والإصدار", symbol: "plus.circle.fill", filled: true)
                    }
                }.buttonStyle(.plain)

                if api.profile.isEmpty && !auth.isAuthenticated {
                    NavigationLink { URNativeAccountView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chevron.left").font(.caption.weight(.black))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("سجل الدخول لمتابعة حوالاتك").font(.headline.weight(.black))
                                Text("تقدر تتصفح وتحسب السعر قبل تسجيل الدخول").font(.caption).foregroundStyle(.secondary)
                            }
                            URIconBadge(symbol: "person.crop.circle.badge.checkmark", size: 45)
                        }.foregroundStyle(URColor.deepNavy).padding(14)
                            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 17))
                            .overlay(RoundedRectangle(cornerRadius: 17).stroke(URColor.hairline))
                    }
                }

                HStack { Spacer(); Text("طلباتك والوصولات").font(.title3.weight(.black)).foregroundStyle(URColor.deepNavy); Image(systemName: "doc.text.magnifyingglass").foregroundStyle(URColor.premiumGold) }
                    .padding(.top, 2)
                if loading { ProgressView("جاري تحديث حوالاتك…").frame(maxWidth: .infinity).padding(24) }
                if !message.isEmpty {
                    Label(message, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
                        .padding(14).frame(maxWidth: .infinity).background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                }
                if !api.profile.isEmpty && orders.isEmpty && !loading && message.isEmpty {
                    VStack(spacing: 9) {
                        Image(systemName: "arrow.left.arrow.right.circle").font(.system(size: 34)).foregroundStyle(URColor.royalBlue)
                        Text("ما عندك طلبات حالياً").font(.headline.weight(.black))
                        Text("ابدأ حوالة جديدة، وبعد الإرسال تظهر هنا الحالة والوصولات.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding(24).frame(maxWidth: .infinity).background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(URColor.hairline))
                }
                ForEach(orders.indices, id: \.self) { index in
                    NavigationLink { URNativeOrderView(order: orders[index], api: api) } label: {
                        URRemittanceOrderCard(order: orders[index])
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 20)
        }.background(URColor.ivory.ignoresSafeArea()).tint(URColor.royalBlue).toolbar(.hidden, for: .navigationBar).environment(\.layoutDirection, .rightToLeft)
            .task(id: auth.isAuthenticated) { await api.resumeCustomerAccount(appEmail: auth.isAuthenticated ? auth.email : nil); await reload(); await URNativeTelemetry.send("app_remittance_open") }
            .refreshable { await reload() }
            .onAppear { Task { await reload() } }
            .onChange(of: api.profile) { _, _ in Task { await reload() } }
    }
    private func reload() async {
        guard !api.profile.isEmpty else { orders = []; return }
        guard !loading else { return }
        loading = true; message = ""; defer { loading = false }
        do { orders = try await api.request("/api/customer/checkout")["orders"] as? [[String: Any]] ?? [] }
        catch { message = error.localizedDescription }
    }
}

private struct URRemittanceAction: View {
    let title: String; let subtitle: String; let symbol: String; let filled: Bool
    var body: some View {
        VStack(alignment: .trailing, spacing: 7) {
            Image(systemName: symbol).font(.title2).foregroundStyle(filled ? URColor.premiumGold : URColor.royalBlue)
            Text(title).font(.subheadline.weight(.black))
            Text(subtitle).font(.caption2).opacity(0.70)
        }.frame(maxWidth: .infinity, alignment: .trailing).padding(13)
            .foregroundStyle(filled ? Color.white : URColor.deepNavy)
            .background(filled ? URColor.deepNavy : Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(filled ? URColor.premiumGold.opacity(0.35) : URColor.hairline))
    }
}

private struct URRemittanceOrderCard: View {
    let order: [String: Any]
    var body: some View {
        let payload = urObject(order["payload"])
        let office = urObject(payload["office"])
        VStack(alignment: .trailing, spacing: 11) {
            HStack {
                Image(systemName: "chevron.left").font(.caption.weight(.black)).foregroundStyle(.secondary)
                Spacer()
                Text(urStatus(urText(order, "status"))).font(.caption.weight(.black)).foregroundStyle(URColor.royalBlue)
                    .padding(.horizontal, 10).padding(.vertical, 6).background(URColor.royalBlue.opacity(0.08), in: Capsule())
                Image(systemName: "arrow.left.arrow.right.circle.fill").font(.title2).foregroundStyle(URColor.premiumGold)
            }
            Text(urText(payload, "receiverName", fallback: "طلب حوالة")).font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
            HStack {
                Text(urText(payload, "amount") + " USD").font(.subheadline.weight(.black)).monospacedDigit()
                Spacer()
                Text(urText(payload, "senderCountry") + " ← " + urText(office, "country")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Divider()
            Label(urText(order, "transfer_tracking", fallback: urText(order, "id")), systemImage: "number")
                .font(.caption2.monospaced()).foregroundStyle(.secondary)
        }.padding(15).background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(URColor.hairline))
    }
}
@MainActor
private func urText(_ row: [String: Any], _ key: String, fallback: String = "—") -> String {
    guard let value = row[key], !(value is NSNull) else { return fallback }
    return String(describing: value)
}
@MainActor
private func urObject(_ value: Any?) -> [String: Any] {
    if let object = value as? [String: Any] { return object }
    if let text = value as? String, let data = text.data(using: .utf8) { return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:] }
    return [:]
}
private func urStatus(_ value: String) -> String {
    ["review": "مراجعة بيانات الطلب", "awaiting_payment": "عرض السعر جاهز — بانتظار الإيداع", "payment_review": "بانتظار مراجعة الدفع", "needs_payment_info": "مطلوب إثبات أو معلومات إضافية", "payment_rejected": "الإثبات مرفوض — يمكنك تصحيحه", "confirmed": "تم تأكيد قبض المبلغ", "issued": "تم إصدار الحوالة", "rejected": "الطلب مرفوض", "paypal_pending": "دفع PayPal قيد التحقق — لا تدفع مرة ثانية", "paypal_test_complete": "اكتمل اختبار PayPal — لا أموال حقيقية", "payment_hold": "الدفع محجوز للمراجعة — تواصل مع أور"][value] ?? value
}
private func urDigits(_ text: String) -> String {
    let normalized = String(text.map { character in
        if let number = character.wholeNumberValue, (0...9).contains(number) { return Character(String(number)) }
        if character == "٫" { return "." }
        if character == "−" || character == "﹣" { return "-" }
        return character
    })
    return normalized.replacingOccurrences(of: "٬", with: "").replacingOccurrences(of: ",", with: "")
}
private func urPhone(_ text: String) -> String {
    urDigits(text).filter { !$0.isWhitespace && !"()-.".contains($0) }
}
private func urGroupedAmount(_ value: String) -> String {
    guard let number = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else { return value }
    return number.formatted(.number.precision(.fractionLength(0...2)).grouping(.automatic).locale(Locale(identifier: "en_US")))
}
@MainActor
private func urReceiptDate(_ value: Any?) -> String {
    guard let value, !(value is NSNull), let timestamp = Double(String(describing: value)) else { return "—" }
    let date = Date(timeIntervalSince1970: timestamp > 1_000_000_000_000 ? timestamp / 1000 : timestamp)
    return date.formatted(.dateTime.locale(Locale(identifier: "ar_IQ")).year().month().day().hour().minute())
}

private struct URNativeTransferForm: View {
    private enum TransferField: Hashable { case senderName, senderPhone, senderAddress, receiverName, receiverPhone, receiverAddress, purpose, amount }
    @EnvironmentObject private var auth: URAuthService
    @ObservedObject private var api = URNativeAPI.customer
    @AppStorage("URTransferDraft.amount") private var amount = ""
    @AppStorage("URTransferDraft.senderName") private var senderName = ""
    @AppStorage("URTransferDraft.senderPhone") private var senderPhone = ""
    @AppStorage("URTransferDraft.senderAddress") private var senderAddress = ""
    @AppStorage("URTransferDraft.senderCountry") private var senderCountry = ""
    @AppStorage("URTransferDraft.receiverCountry") private var receiverCountry = ""
    @AppStorage("URTransferDraft.feeMode") private var feeMode = "added"
    @State private var bankAccountId = "fab-aed"
    @AppStorage("URTransferDraft.receiverName") private var receiverName = ""
    @AppStorage("URTransferDraft.receiverPhone") private var receiverPhone = ""
    @AppStorage("URTransferDraft.receiverAddress") private var receiverAddress = ""
    @AppStorage("URTransferDraft.purpose") private var purpose = ""
    @AppStorage("URTransferDraft.payout") private var payout = 0
    @State private var collection = 0
    @AppStorage("URTransferDraft.method") private var method = ""
    @State private var accountTermsAccepted = false
    @State private var methods: [[String: Any]] = []
    @State private var offices: [[String: Any]] = []
    @State private var routes: [[String: Any]] = []
    @State private var quote: [String: Any] = [:]
    @State private var message = ""
    @State private var busy = false
    @State private var submitted = false
    @State private var createdOrder: [String: Any]?
    @FocusState private var focusedField: TransferField?
    @AppStorage("URTransferDraft.requestId") private var requestId = UUID().uuidString
    @AppStorage("URTransferDraft.owner") private var draftOwner = ""
    private var receivingOffices: [[String: Any]] { offices.filter { urText($0, "country") == receiverCountry } }
    private var sendingOffices: [[String: Any]] { offices.filter { urText($0, "country") == senderCountry } }
    private var origins: [String] { Array(Set(offices.compactMap { $0["country"] as? String })).sorted() }
    private var destinations: [String] { origins }
    private var hasPricedRoute: Bool { routes.contains { urText($0, "origin") == senderCountry && urText($0, "destination") == receiverCountry } }
    private var quoteWithinLimits: Bool { quote["withinLimits"] as? Bool == true }
    private var bankAccounts: [[String: Any]] { methods.first { urText($0, "id") == "bank" }?["accounts"] as? [[String: Any]] ?? [] }
    private var payoutOffice: [String: Any] { offices.first { ($0["id"] as? Int ?? 0) == payout } ?? [:] }
    private func officeLabel(_ office: [String: Any]) -> String {
        let city = urText(office, "city", fallback: urText(office, "region"))
        return city + " · " + urText(office, "name")
    }
    private var receiverSection: some View {
        Section("٢ · دولة الاستلام وبيانات المستفيد") {
            Picker("دولة الاستلام", selection: $receiverCountry) { Text("اختر الدولة").tag(""); ForEach(destinations, id: \.self) { Text($0).tag($0) } }.pickerStyle(.navigationLink).disabled(senderCountry.isEmpty)
            TextField("اسم المستلم الكامل", text: $receiverName).focused($focusedField, equals: .receiverName)
            TextField("هاتف المستلم مع رمز الدولة", text: $receiverPhone).keyboardType(.phonePad).focused($focusedField, equals: .receiverPhone)
            TextField("عنوان المستلم", text: $receiverAddress).focused($focusedField, equals: .receiverAddress)
            TextField("غرض الحوالة", text: $purpose).focused($focusedField, equals: .purpose)
            if !receiverCountry.isEmpty {
                Picker("مكتب الاستلام المعتمد", selection: $payout) { Text("اختر").tag(0); ForEach(receivingOffices.indices, id: \.self) { i in Text(officeLabel(receivingOffices[i])).tag(receivingOffices[i]["id"] as? Int ?? 0) } }.pickerStyle(.navigationLink)
                if receivingOffices.isEmpty { Text("لا يوجد مكتب استلام معتمد في هذه الدولة حالياً.").foregroundStyle(.red) }
                if payout > 0 { Text(urText(payoutOffice, "details")); Text("هاتف المكتب: " + urText(payoutOffice, "phone")) }
            }
            Text("تظهر مكاتب دولة الاستلام المختارة فقط. لا يلزم مكتب قبض عند الدفع الإلكتروني.").font(.footnote).foregroundStyle(.secondary)
        }
    }
    private var senderSection: some View {
        Section("١ · دولة الإرسال وبيانات المرسل") {
            Picker("جهة الإرسال", selection: $senderCountry) { Text("اختر").tag(""); ForEach(origins, id: \.self) { Text($0).tag($0) } }.pickerStyle(.navigationLink)
            TextField("اسم المرسل الكامل", text: $senderName).focused($focusedField, equals: .senderName)
            TextField("هاتف المرسل مع رمز الدولة", text: $senderPhone).keyboardType(.phonePad).focused($focusedField, equals: .senderPhone)
            TextField("عنوان المرسل", text: $senderAddress).focused($focusedField, equals: .senderAddress)
        }
    }
    private var amountSection: some View {
        Section("٣ · المبلغ والعمولة") {
            TextField("المبلغ بالدولار USD", text: $amount).keyboardType(.decimalPad).focused($focusedField, equals: .amount)
            Picker("احتساب العمولة", selection: $feeMode) { Text("فوق المبلغ").tag("added"); Text("تنخصم من المبلغ").tag("deducted") }.pickerStyle(.segmented)
            Text(feeMode == "added" ? "المستفيد يستلم قيمة المبلغ كاملة، وتدفع العمولة فوقها." : "تدفع المبلغ المحدد، وتُخصم العمولة قبل تحويل الصافي للمستفيد.").font(.footnote).foregroundStyle(.secondary)
            if !senderCountry.isEmpty && !receiverCountry.isEmpty && !hasPricedRoute { Text("هذا المسار غير موجود في قائمة الأسعار المعتمدة حالياً؛ لا يمكن إنشاء مبلغ أو طلب دفع له.").font(.footnote).foregroundStyle(.red) }
            Button("احسب السعر والرسوم") { focusedField = nil; Task { await calculate() } }.buttonStyle(.borderedProminent).controlSize(.large).disabled(busy || payout == 0 || senderCountry.isEmpty || receiverCountry.isEmpty || urDigits(amount).isEmpty)
            if !quote.isEmpty {
                LabeledContent("سعر الصرف", value: urText(quote, "rate"))
                LabeledContent("عمولة المسار لكل 10,000$", value: urText(quote, "routeCommission") + " USD")
                LabeledContent("رسوم طريقة الدفع", value: urText(quote, "paymentFee") + " USD")
                LabeledContent("إجمالي الرسوم", value: urText(quote, "fee"))
                LabeledContent("تدفع إجمالاً", value: urText(quote, "total") + " USD")
                LabeledContent("يستلم المستفيد", value: urText(quote, "net") + " " + urText(quote, "targetCurrency"))
                Text("السعر بتاريخ " + urText(quote, "sourceTimestamp")).font(.footnote)
                Text("هذا عرض الخادم المعتمد؛ عند التأكيد ينتقل الطلب مباشرة إلى انتظار الدفع.").font(.footnote)
                Text("حدود التنفيذ المباشر: " + urText(quote, "minAmount") + " — " + urText(quote, "maxAmount") + " USD").font(.caption)
                if !quoteWithinLimits { Text("المبلغ خارج الحدود المعتمدة لهذا المسار؛ عدّله قبل الانتقال للدفع.").font(.footnote.weight(.semibold)).foregroundStyle(.red) }
            }
        }
    }
    private var paymentSection: some View {
        Section("٤ · طريقة الإيداع") {
            Picker("طريقة الدفع", selection: $method) { Text("اختر طريقة الإيداع").tag(""); ForEach(methods.indices, id: \.self) { i in if methods[i]["available"] as? Bool == true { Text(urText(methods[i], "name")).tag(urText(methods[i], "id")) } } }.pickerStyle(.navigationLink)
            ForEach(methods.indices, id: \.self) { i in
                Button { focusedField = nil; method = urText(methods[i], "id") } label: { URNativePaymentBrandRow(method: methods[i], selected: method == urText(methods[i], "id")) }.buttonStyle(.plain)
            }
            if method == "bank" {
                Picker("حساب الإيداع AED", selection: $bankAccountId) { ForEach(bankAccounts.indices, id: \.self) { i in Text(urText(bankAccounts[i], "bankName")).tag(urText(bankAccounts[i], "id")) } }
                Text("يظهر مبلغ الإيداع بالدرهم بعد اعتماد عرض السعر، مع اسم المستفيد والآيبان.").font(.footnote)
            }
        }
    }
    var body: some View {
        Form {
            Group {
            senderSection
            receiverSection
            amountSection
            paymentSection
            }.disabled(submitted)
            Section {
                if api.profile.isEmpty && !auth.isAuthenticated { NavigationLink("تسجيل الدخول لإرسال الطلب") { URNativeAccountView() } }
                else {
                    if api.profile.isEmpty { Toggle("أوافق على شروط خدمة الحوالات", isOn: $accountTermsAccepted) }
                    Button(submitted ? "تم إنشاء الطلب" : busy ? "جاري الإنشاء…" : "تأكيد الطلب والانتقال للدفع") { Task { await submitTransfer() } }.buttonStyle(.borderedProminent).controlSize(.large).disabled(busy || submitted || quote.isEmpty || !quoteWithinLimits || method.isEmpty || (api.profile.isEmpty && !accountTermsAccepted)) }
                if submitted {
                    Text("رقم الطلب: " + requestId).font(.footnote).textSelection(.enabled)
                    Text("الطلب محفوظ وعرض السعر جاهز. إثبات أو TXID لا يعني أن الدفع تحقق.").font(.footnote)
                    if let createdOrder { URNativeInlinePaymentCompletion(order: createdOrder, api: api) }
                    Button("بدء حوالة جديدة", action: startNewTransfer)
                }
                if !message.isEmpty { Text(message).foregroundStyle(.red) }
            }
        }.disabled(busy).scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle("حسبة وحوالة جديدة")
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("تم") { focusedField = nil } } }
            .task(id: auth.email) {
                let owner = auth.isAuthenticated ? (auth.email?.lowercased() ?? "anonymous") : "anonymous"
                if !draftOwner.isEmpty && draftOwner != owner { clearDraftForDifferentUser() }
                draftOwner = owner
                await api.resumeCustomerAccount(appEmail: auth.isAuthenticated ? auth.email : nil); await load()
            }
            .onChange(of: amount) { _, _ in quote = [:] }
            .onChange(of: payout) { _, _ in quote = [:] }
            .onChange(of: senderCountry) { _, _ in quote = [:]; collection = 0; receiverCountry = ""; payout = 0 }
            .onChange(of: receiverCountry) { _, _ in quote = [:]; payout = 0 }
            .onChange(of: feeMode) { _, _ in quote = [:] }
    }
    private func load() async {
        do {
            methods = try await api.request("/api/payment-methods")["methods"] as? [[String: Any]] ?? []
            offices = try await api.request("/api/offices")["offices"] as? [[String: Any]] ?? []
            routes = try await api.request("/api/routes")["routes"] as? [[String: Any]] ?? []
            if !origins.contains(senderCountry) { senderCountry = ""; collection = 0 }
            if !destinations.contains(receiverCountry) { receiverCountry = ""; payout = 0 }
            if !method.isEmpty && !methods.contains(where: { urText($0, "id") == method && $0["available"] as? Bool == true }) { method = ""; message = "طريقة الإيداع السابقة غير متوفرة؛ اختر طريقة أخرى" }
            if senderName.isEmpty { senderName = api.profile["name"] ?? "" }; if senderPhone.isEmpty { senderPhone = api.profile["phone"] ?? "" }
        } catch is CancellationError { return }
        catch { message = error.localizedDescription }
    }
    private func calculate() async {
        guard !busy && !submitted else { return }
        busy = true; message = ""; quote = [:]; defer { busy = false }
        do {
            guard hasPricedRoute else { throw URNativeError.message("المسار غير متاح بسعر معتمد حالياً") }
            var components = URLComponents(); components.path = "/api/quote"
            components.queryItems = [.init(name: "origin", value: senderCountry), .init(name: "destination", value: urText(payoutOffice, "country")), .init(name: "amount", value: urDigits(amount)), .init(name: "feeMode", value: feeMode)]
            let input = [senderCountry, receiverCountry, String(payout), urDigits(amount), feeMode]
            let result = try await api.request(components.string ?? "")["quote"] as? [String: Any] ?? [:]
            guard input == [senderCountry, receiverCountry, String(payout), urDigits(amount), feeMode] else { throw URNativeError.message("تغيرت بيانات الحسبة؛ احسب مرة ثانية") }
            guard !result.isEmpty else { throw URNativeError.message("لم يصل عرض السعر") }; quote = result
            if result["withinLimits"] as? Bool != true { message = "المبلغ المسموح لهذا المسار من " + urText(result, "minAmount") + " إلى " + urText(result, "maxAmount") + " دولار." }
        } catch { message = error.localizedDescription }
    }
    private func submitTransfer() async {
        guard !busy && !submitted && !quote.isEmpty && hasPricedRoute else { return }
        busy = true; message = ""; defer { busy = false }
        do {
            guard !method.isEmpty else { throw URNativeError.message("اختر طريقة الإيداع") }
            if api.profile.isEmpty {
                guard auth.isAuthenticated else { throw URNativeError.message("سجل الدخول بحساب التطبيق") }
                try await api.connectAppAccount(name: senderName, phone: urPhone(senderPhone), accepted: accountTermsAccepted)
            }
            guard !senderAddress.trimmingCharacters(in: .whitespaces).isEmpty, !receiverAddress.trimmingCharacters(in: .whitespaces).isEmpty else { throw URNativeError.message("أكمل عناوين المرسل والمستفيد") }
            let result = try await api.request("/api/customer/checkout", method: "POST", body: ["id": requestId, "feeMode": feeMode, "bankAccountId": bankAccountId, "amount": urDigits(amount), "senderName": senderName, "senderPhone": urPhone(senderPhone), "senderCountry": senderCountry, "senderAddress": senderAddress, "receiverCountry": receiverCountry, "receiverName": receiverName, "receiverPhone": urPhone(receiverPhone), "receiverAddress": receiverAddress, "purpose": purpose, "payoutOfficeId": payout - 2_000_000, "collectionOfficeId": 0, "method": method], idempotencyKey: requestId)
            guard result["success"] as? Bool == true, urText(result, "id") == requestId else { throw URNativeError.message("لم يؤكد الخادم حفظ الطلب؛ راجع حوالاتي قبل إعادة الإرسال") }
            submitted = true
            do {
                let saved = try await api.request("/api/customer/checkout")["orders"] as? [[String: Any]] ?? []
                createdOrder = saved.first { urText($0, "id") == requestId }
            } catch { message = "تم حفظ الطلب؛ تعذر تحميل تفاصيله الآن. رقمه ظاهر أعلاه." }
        } catch { message = error.localizedDescription }
    }
    private func clearDraftForDifferentUser() {
        amount = ""; senderName = ""; senderPhone = ""; senderAddress = ""; senderCountry = ""; receiverCountry = ""; receiverName = ""; receiverPhone = ""; receiverAddress = ""; purpose = ""; payout = 0; method = ""; feeMode = "added"; requestId = UUID().uuidString; quote = [:]; submitted = false; createdOrder = nil
    }
    private func startNewTransfer() { clearDraftForDifferentUser(); draftOwner = auth.email?.lowercased() ?? "anonymous" }
}

private struct URNativeInlinePaymentCompletion: View {
    @State private var order: [String: Any]
    @ObservedObject var api: URNativeAPI
    @State private var methods: [[String: Any]] = []
    @State private var reference = ""
    @State private var accepted = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var fileData: Data?
    @State private var fileType = "image/jpeg"
    @State private var importFile = false
    @State private var busy = false
    @State private var message = ""
    init(order: [String: Any], api: URNativeAPI) { _order = State(initialValue: order); self.api = api }
    private var quote: [String: Any] { urObject(order["quote"]) }
    private var payload: [String: Any] { urObject(order["payload"]) }
    private var method: [String: Any] { methods.first { urText($0, "id") == urText(order, "method") } ?? [:] }
    private var orderStatus: String { urText(order, "status") }
    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            Divider()
            Text("إكمال الدفع").font(.title2.weight(.black)).foregroundStyle(URColor.deepNavy)
            VStack(alignment: .trailing, spacing: 5) {
                Text("المبلغ المطلوب دفعه").font(.subheadline.weight(.bold)).foregroundStyle(.white.opacity(0.82))
                Text(urGroupedAmount(urText(quote, "total")) + " " + urText(quote, "paymentCurrency"))
                    .font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.yellow)
                    .environment(\.layoutDirection, .leftToRight).textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .trailing).padding(16)
            .background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 8) {
                Text(urStatus(orderStatus)).font(.headline.weight(.black))
                Spacer()
                Text("الحالة").font(.headline.weight(.bold))
            }
            .foregroundStyle(URColor.deepNavy).padding(13)
            .background(Color.yellow.opacity(0.42), in: RoundedRectangle(cornerRadius: 14))
            HStack {
                Text(urText(method, "name", fallback: urText(order, "method"))).font(.headline.weight(.bold))
                Spacer()
                Text("طريقة الدفع").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
            }
            .padding(13).background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            paymentDetails
            if urText(quote, "paymentCurrency") == "IQD" {
                LabeledContent("سعر شراء الدولار المعتمد", value: urGroupedAmount(urText(quote, "paymentRate")) + " IQD / USD")
                    .font(.subheadline.weight(.bold))
            }
            if ["awaiting_payment", "needs_payment_info", "payment_rejected"].contains(orderStatus) {
                if !urText(order, "review_reason", fallback: "").isEmpty { Text("ملاحظة الإدارة: " + urText(order, "review_reason")).foregroundStyle(.red) }
                Toggle("راجعت المبلغ وبيانات الحساب وأوافق عليها", isOn: $accepted)
                TextField("مرجع الإيداع / TXID", text: $reference).textInputAutocapitalization(.never).environment(\.layoutDirection, .leftToRight)
                PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("إرفاق صورة الإثبات", systemImage: "photo") }
                Button("رفع PDF أو صورة من الملفات") { importFile = true }
                if let fileData { Text("الإثبات جاهز: \(fileData.count / 1024) KB").font(.caption) }
                Button(busy ? "جاري إرسال الإثبات…" : "إرسال الإثبات للمراجعة") { Task { await upload() } }
                    .buttonStyle(.borderedProminent).disabled(busy || !accepted || reference.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
            } else if orderStatus == "payment_review" {
                Text("تم إرسال الإثبات. الطلب الآن بانتظار مراجعة الإدارة واعتماد وصول المبلغ.").font(.subheadline.weight(.semibold)).foregroundStyle(URColor.deepNavy)
            }
            if ["confirmed", "issued"].contains(orderStatus) {
                Text("تم اعتماد وصول المبلغ.").font(.headline).foregroundStyle(.green)
                Link("فتح وصل قبض المبلغ", destination: URL(string: "https://www.urremit.com/customer/receipts/\(urText(order, "id"))/payment")!)
                if order["delivered_at"] != nil && !(order["delivered_at"] is NSNull) { Link("فتح وصل استلام المستفيد", destination: URL(string: "https://www.urremit.com/customer/receipts/\(urText(order, "id"))/payout")!) }
            }
            Button("تحديث الحالة") { Task { await reload() } }.disabled(busy)
            if !message.isEmpty { Text(message).foregroundStyle(.red).font(.footnote) }
        }
        .task { await loadMethods(); await reload() }
        .onChange(of: selectedPhoto) { _, photo in Task { await loadPhoto(photo) } }
        .fileImporter(isPresented: $importFile, allowedContentTypes: [.pdf, .jpeg, .png]) { result in loadFile(result) }
    }
    @ViewBuilder private var paymentDetails: some View {
        let id = urText(order, "method")
        if id == "superqi" || id == "fib" || id == "zaincash" {
            paymentValueCard(title: "اسم صاحب الحساب", value: urText(method, "beneficiary", fallback: "غير مكتمل"), systemImage: "person.crop.circle.fill", accent: .orange)
            paymentValueCard(title: "رقم الحساب / المحفظة", value: urText(method, "account", fallback: "غير مكتمل"), systemImage: "number.circle.fill", accent: URColor.royalBlue)
            Button { UIPasteboard.general.string = urText(method, "account", fallback: "") } label: {
                Label("نسخ رقم الحساب", systemImage: "doc.on.doc.fill").font(.headline.weight(.black)).frame(maxWidth: .infinity).padding(.vertical, 7)
            }.buttonStyle(.borderedProminent).tint(URColor.royalBlue)
            Text(urText(method, "instructions", fallback: "راجع الدعم قبل التحويل.")).font(.footnote).foregroundStyle(.secondary)
        } else if id == "bank" {
            let account = urObject(quote["bankAccount"] ?? payload["bankAccount"])
            paymentValueCard(title: "اسم المستفيد", value: urText(account, "beneficiary", fallback: urText(method, "beneficiary")), systemImage: "person.crop.circle.fill", accent: .orange)
            paymentValueCard(title: "البنك", value: urText(account, "bankName"), systemImage: "building.columns.fill", accent: URColor.royalBlue)
            paymentValueCard(title: "رقم IBAN", value: urText(account, "iban", fallback: urText(account, "account")), systemImage: "number.circle.fill", accent: URColor.royalBlue)
            Button { UIPasteboard.general.string = urText(account, "iban", fallback: urText(account, "account", fallback: "")) } label: {
                Label("نسخ رقم IBAN", systemImage: "doc.on.doc.fill").font(.headline.weight(.black)).frame(maxWidth: .infinity).padding(.vertical, 7)
            }.buttonStyle(.borderedProminent).tint(URColor.royalBlue)
        } else if id.hasPrefix("usdt_") {
            let deposit = urObject(quote["deposit"]), address = urText(deposit, "address", fallback: urText(method, "instructions", fallback: ""))
            paymentValueCard(title: "شبكة التحويل", value: id == "usdt_trc20" ? "TRON · TRC20" : "Ethereum · ERC20", systemImage: "network", accent: .orange)
            paymentValueCard(title: "عنوان المحفظة", value: address, systemImage: "wallet.bifold.fill", accent: URColor.royalBlue)
            Button { UIPasteboard.general.string = address } label: {
                Label("نسخ عنوان المحفظة", systemImage: "doc.on.doc.fill").font(.headline.weight(.black)).frame(maxWidth: .infinity).padding(.vertical, 7)
            }.buttonStyle(.borderedProminent).tint(URColor.royalBlue)
        }
        Text("لا ترسل إلى بيانات مختلفة عن الظاهرة هنا. رفع الإثبات لا يعني اعتماد وصول الأموال.").font(.footnote.weight(.semibold)).foregroundStyle(URColor.deepNavy)
    }
    private func paymentValueCard(title: String, value: String, systemImage: String, accent: Color) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            Label(title, systemImage: systemImage).font(.headline.weight(.black)).foregroundStyle(.white)
            Text(value).font(.system(size: 27, weight: .black, design: .rounded)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing).environment(\.layoutDirection, .leftToRight).textSelection(.enabled)
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 104, alignment: .trailing)
        .background(accent, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.55), lineWidth: 2))
        .shadow(color: accent.opacity(0.38), radius: 8, y: 4)
    }
    private func loadMethods() async { do { methods = try await api.request("/api/payment-methods")["methods"] as? [[String: Any]] ?? [] } catch { message = error.localizedDescription } }
    private func reload() async { do { let rows = try await api.request("/api/customer/checkout")["orders"] as? [[String: Any]] ?? []; if let latest = rows.first(where: { urText($0, "id") == urText(order, "id") }) { order = latest } } catch is CancellationError {} catch { message = error.localizedDescription } }
    private func upload() async {
        busy = true; message = ""; defer { busy = false }
        do {
            var evidence = reference.trimmingCharacters(in: .whitespacesAndNewlines)
            if let fileData {
                let boundary = "UR-" + UUID().uuidString; var data = Data()
                for (name, value) in [("id", urText(order, "id")), ("version", urText(order, "version"))] { data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)) }
                data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"deposit\"\r\nContent-Type: \(fileType)\r\n\r\n".utf8)); data.append(fileData); data.append(Data("\r\n--\(boundary)--\r\n".utf8))
                let result = try await api.request("/api/customer/evidence", method: "POST", bytes: data, contentType: "multipart/form-data; boundary=" + boundary)
                evidence += " · " + urText(result, "evidenceUrl", fallback: "")
            }
            _ = try await api.request("/api/customer/checkout", method: "PATCH", body: ["id": urText(order, "id"), "version": order["version"] as? Int ?? -1, "evidence": evidence, "acceptQuote": true])
            fileData = nil; reference = ""; accepted = false; await reload()
        } catch { message = error.localizedDescription }
    }
    private func loadPhoto(_ photo: PhotosPickerItem?) async { do { guard let data = try await photo?.loadTransferable(type: Data.self), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.8), jpeg.count <= 8 * 1024 * 1024 else { throw URNativeError.message("تعذر تجهيز الصورة أو حجمها أكبر من 8MB") }; fileData = jpeg; fileType = "image/jpeg" } catch { message = error.localizedDescription } }
    private func loadFile(_ result: Result<URL, Error>) { do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; let data = try Data(contentsOf: url); guard !data.isEmpty && data.count <= 8 * 1024 * 1024 else { throw URNativeError.message("الحد الأقصى 8MB") }; fileData = data; fileType = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg" } catch { message = error.localizedDescription } }
}

private struct URNativeOrderView: View {
    @State var order: [String: Any]
    @ObservedObject var api: URNativeAPI
    @State private var reference = ""
    @State private var accepted = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var fileData: Data?
    @State private var fileType = "image/jpeg"
    @State private var importFile = false
    @State private var message = ""
    @State private var busy = false
    @State private var instructions = ""
    @State private var paymentMethods: [[String: Any]] = []
    @State private var receipt: URL?
    private var payload: [String: Any] { urObject(order["payload"]) }
    private var quote: [String: Any] { urObject(order["quote"]) }
    private var deposit: [String: Any] { urObject(quote["deposit"]) }
    private var paymentMethod: [String: Any] { paymentMethods.first { urText($0, "id") == urText(order, "method") } ?? [:] }
    private var walletAddress: String { urText(deposit, "address", fallback: "").isEmpty ? urText(paymentMethod, "instructions", fallback: "") : urText(deposit, "address", fallback: "") }
    private var depositReady: Bool {
        if urText(order, "method") == "bank" { return (quote["bankAccount"] ?? payload["bankAccount"]) is [String: Any] }
        if urText(order, "method") == "usdt_trc20" { return walletAddress.hasPrefix("T") && walletAddress.count == 34 }
        if urText(order, "method") == "usdt_erc20" { return walletAddress.hasPrefix("0x") && walletAddress.count == 42 }
        return true
    }
    var body: some View {
        Form {
            Section("الحالة") { Text(urStatus(urText(order, "status"))); Text(urText(order, "id")).font(.caption).textSelection(.enabled) }
            Section("الأطراف والوجهة") {
                LabeledContent("المرسل", value: urText(payload, "senderName")); LabeledContent("هاتف المرسل", value: urText(payload, "senderPhone"))
                LabeledContent("المستفيد", value: urText(payload, "receiverName")); LabeledContent("هاتف المستفيد", value: urText(payload, "receiverPhone"))
                Text(urText(payload, "receiverAddress")); Text(urText(urObject(payload["office"]), "address"))
                LabeledContent("هاتف مكتب التسليم", value: urText(urObject(payload["office"]), "phone"))
            }
            if !quote.isEmpty {
                Section("عرض السعر") {
                    LabeledContent("المبلغ", value: urText(quote, "amount")); LabeledContent("الرسوم", value: urText(quote, "fee"))
                    LabeledContent("الإجمالي", value: urText(quote, "total") + " " + urText(quote, "paymentCurrency"))
                    LabeledContent("طريقة العمولة", value: urText(quote, "feeMode", fallback: "added") == "deducted" ? "تنخصم من المبلغ" : "فوق المبلغ")
                    LabeledContent("صافي التسليم", value: urText(quote, "payout") + " " + urText(quote, "payoutCurrency"))
                    if let expiry = quote["expiresAt"] as? Double { Text("صالح حتى " + Date(timeIntervalSince1970: expiry / 1000).formatted(date: .omitted, time: .shortened)) }
                }
            }
            if urText(order, "method") == "paypal" && ["awaiting_payment", "paypal_pending", "paypal_test_complete", "confirmed"].contains(urText(order, "status")) {
                Section("PayPal") { URNativePayPalPaymentView(api: api, order: order, refresh: { await reload() }) }
            }
            if ["awaiting_payment", "needs_payment_info", "payment_rejected"].contains(urText(order, "status")) && urText(order, "method") != "paypal" {
                if !urText(order, "review_reason", fallback: "").isEmpty { Text("ملاحظة الإدارة: " + urText(order, "review_reason")).foregroundStyle(.red) }
                Section("تفاصيل الإيداع") {
                    LabeledContent("طريقة الدفع", value: urText(paymentMethod, "name", fallback: urText(order, "method")))
                    legacyPaymentCard(title: "المبلغ المطلوب دفعه", value: urGroupedAmount(urText(quote, "total")) + " " + urText(quote, "paymentCurrency"), color: URColor.deepNavy, valueColor: .yellow, icon: "dollarsign.circle.fill")
                    if urText(quote, "paymentCurrency") == "IQD" {
                        LabeledContent("سعر شراء الدولار المعتمد", value: urGroupedAmount(urText(quote, "paymentRate")) + " IQD / USD").font(.subheadline.weight(.bold))
                    }
                    if urText(order, "method") == "superqi" {
                        let beneficiary = urText(paymentMethod, "beneficiary", fallback: "")
                        let account = urText(paymentMethod, "account", fallback: "")
                        if !beneficiary.isEmpty && !account.isEmpty {
                            legacyPaymentCard(title: "اسم صاحب الحساب", value: beneficiary, color: .orange, valueColor: .white, icon: "person.crop.circle.fill")
                            legacyPaymentCard(title: "رقم حساب SuperQi", value: account, color: URColor.royalBlue, valueColor: .white, icon: "number.circle.fill")
                            Button { UIPasteboard.general.string = account } label: {
                                Label("نسخ رقم الحساب", systemImage: "doc.on.doc.fill").font(.headline.weight(.black)).frame(maxWidth: .infinity).padding(.vertical, 7)
                            }.buttonStyle(.borderedProminent).tint(URColor.royalBlue)
                            Text(urText(paymentMethod, "instructions", fallback: "حوّل المبلغ الظاهر فقط، ثم أرفق المرجع والإثبات.")).font(.footnote).foregroundStyle(.secondary)
                            Text("الإيداع يدوي وتراجعه الإدارة. رفع الإثبات وحده لا يعني وصول المبلغ.").font(.footnote.weight(.semibold)).foregroundStyle(URColor.deepNavy)
                        } else { Text("بيانات حساب SuperQi غير مكتملة. لا تحوّل المبلغ وراجع الدعم.").foregroundStyle(.red) }
                    } else if urText(order, "method").hasPrefix("usdt_") {
                        Text(urText(order, "method") == "usdt_trc20" ? "شبكة TRON · TRC20" : "شبكة Ethereum · ERC20").font(.headline)
                        if depositReady {
                            Text(walletAddress).font(.system(.body, design: .monospaced)).environment(\.layoutDirection, .leftToRight).textSelection(.enabled)
                            Button("نسخ عنوان المحفظة") { UIPasteboard.general.string = walletAddress }
                            Text("أرسل USDT على الشبكة المحددة فقط، ثم أرفق TXID وإثبات التحويل.").font(.footnote)
                        } else { Text("تعذر تحميل عنوان الإيداع. لا ترسل المبلغ؛ حدّث الحالة أو راجع الدعم.").foregroundStyle(.red) }
                    } else if urText(order, "method") == "cash" {
                        let office = urObject(payload["collectionOffice"])
                        Text("تسليم النقد في مكتب الإرسال")
                        Text(urText(office, "name")); Text(urText(office, "address")).textSelection(.enabled)
                        Text(urText(office, "phone")).textSelection(.enabled)
                    }
                    if let account = (quote["bankAccount"] ?? payload["bankAccount"]) as? [String: Any] {
                        legacyPaymentCard(title: "اسم صاحب الحساب", value: urText(account, "beneficiary"), color: .orange, valueColor: .white, icon: "person.crop.circle.fill")
                        Text(urText(account, "bankName"))
                        legacyPaymentCard(title: "رقم IBAN", value: urText(account, "iban"), color: URColor.royalBlue, valueColor: .white, icon: "number.circle.fill")
                        Text("Account: " + urText(account, "account")).environment(\.layoutDirection, .leftToRight).textSelection(.enabled)
                        if !urText(account, "bic", fallback: "").isEmpty { Text("BIC: " + urText(account, "bic")).textSelection(.enabled) }
                    } else if urText(order, "method") == "bank" { Text("تعذر عرض الحساب البنكي المعتمد؛ راجع الدعم قبل الإيداع.").foregroundStyle(.red) }
                }
                Section("إثبات الدفع") {
                    Toggle("راجعت العرض وأوافق عليه", isOn: $accepted)
                    TextField("مرجع الإيداع / TXID", text: $reference).textInputAutocapitalization(.never)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("صورة إثبات الإيداع", systemImage: "photo") }
                    Button("رفع PDF أو صورة من الملفات") { importFile = true }
                    if let data = fileData { Text("الإثبات جاهز: \(data.count / 1024) KB") }
                    Button(busy ? "جاري الرفع…" : "إرسال الإثبات للمراجعة") { Task { await upload() } }.disabled(!accepted || reference.count < 4 || busy || !depositReady)
                }
            }
            if ["confirmed", "issued"].contains(urText(order, "status")) {
                Section("الوصولات") {
                    Button("وصل قبض المبلغ PDF") { makeReceipt(beneficiary: false) }
                    if order["delivered_at"] != nil && !(order["delivered_at"] is NSNull) { Button("وصل استلام المستفيد PDF") { makeReceipt(beneficiary: true) } }
                    else { Text("وصل المستفيد يظهر بعد تسجيل التسليم الفعلي").font(.footnote) }
                    if let receipt { ShareLink("حفظ أو مشاركة الوصل", item: receipt) }
                }
            }
            if !message.isEmpty { Text(message).foregroundStyle(.red) }
            Button("تحديث الحالة") { Task { await reload() } }.disabled(busy)
        }.scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle("تفاصيل الحوالة").environment(\.layoutDirection, .rightToLeft)
            .task {
                await reload()
                let result = try? await api.request("/api/payment-methods")
                let methods = result?["methods"] as? [[String: Any]] ?? []
                paymentMethods = methods
                instructions = methods.first { urText($0, "id") == urText(order, "method") }?["instructions"] as? String ?? ""
            }
            .onChange(of: selectedPhoto) { _, photo in Task {
                do {
                    guard let data = try await photo?.loadTransferable(type: Data.self), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.8) else { return }
                    guard jpeg.count <= 8 * 1024 * 1024 else { throw URNativeError.message("الصورة تتجاوز 8MB") }
                    fileData = jpeg; fileType = "image/jpeg"
                } catch { message = error.localizedDescription }
            } }
            .fileImporter(isPresented: $importFile, allowedContentTypes: [.pdf, .jpeg, .png]) { result in
                do {
                    let url = try result.get(); let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0 && size <= 8 * 1024 * 1024 else { throw URNativeError.message("الحد الأقصى 8MB") }
                    fileData = try Data(contentsOf: url); fileType = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
                } catch { message = error.localizedDescription }
            }
    }
    private func legacyPaymentCard(title: String, value: String, color: Color, valueColor: Color, icon: String) -> some View {
        VStack(alignment: .trailing, spacing: 9) {
            Label(title, systemImage: icon).font(.headline.weight(.black)).foregroundStyle(.white)
            Text(value).font(.system(size: 29, weight: .black, design: .rounded)).foregroundStyle(valueColor)
                .frame(maxWidth: .infinity, alignment: .trailing).environment(\.layoutDirection, .leftToRight).textSelection(.enabled)
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 108, alignment: .trailing)
        .background(color, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.6), lineWidth: 2))
        .shadow(color: color.opacity(0.42), radius: 9, y: 4)
    }
    private func reload() async {
        do { let result = try await api.request("/api/customer/checkout"); if let rows = result["orders"] as? [[String: Any]], let latest = rows.first(where: { urText($0, "id") == urText(order, "id") }) { order = latest } }
        catch { message = error.localizedDescription }
    }
    private func upload() async {
        busy = true; message = ""; defer { busy = false }
        do {
            var evidence = reference
            if let fileData {
                let boundary = "UR-" + UUID().uuidString
                var data = Data()
                for (name, value) in [("id", urText(order, "id")), ("version", urText(order, "version"))] { data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)) }
                data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"deposit\"\r\nContent-Type: \(fileType)\r\n\r\n".utf8)); data.append(fileData); data.append(Data("\r\n--\(boundary)--\r\n".utf8))
                let result = try await api.request("/api/customer/evidence", method: "POST", bytes: data, contentType: "multipart/form-data; boundary=" + boundary)
                evidence += " · " + urText(result, "evidenceUrl", fallback: "")
            }
            _ = try await api.request("/api/customer/checkout", method: "PATCH", body: ["id": urText(order, "id"), "version": order["version"] as? Int ?? -1, "evidence": evidence, "acceptQuote": accepted])
            fileData = nil; await reload()
        } catch { message = error.localizedDescription }
    }
    private func makeReceipt(beneficiary: Bool) {
        let title = beneficiary ? "وصل استلام المستفيد" : "وصل قبض المبلغ"
        let lines = ["UR | أور للحوالات العالمية", title, "رقم الطلب: " + urText(order, "id"), "رقم الحوالة: " + urText(order, "transfer_tracking"), "المرسل: " + urText(payload, "senderName"), "المستفيد: " + urText(payload, "receiverName"), "المبلغ: " + (beneficiary ? urText(quote, "payout") + " " + urText(quote, "payoutCurrency") : urText(quote, "total") + " " + urText(quote, "paymentCurrency")), "مرجع القبض: " + urText(order, "payment_reference"), "نقطة التسليم: " + urText(urObject(payload["office"]), "name"), "تاريخ " + (beneficiary ? "التسليم: " + urReceiptDate(order["delivered_at"]) : "القبض: " + urReceiptDate(order["confirmed_at"]))]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let data = renderer.pdfData { context in
            context.beginPage()
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .right; paragraph.baseWritingDirection = .rightToLeft
            for (index, line) in lines.enumerated() {
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: index < 2 ? 23 : 17, weight: index < 2 ? .bold : .regular), .foregroundColor: UIColor(red: 0.03, green: 0.10, blue: 0.23, alpha: 1), .paragraphStyle: paragraph]
                (line as NSString).draw(in: CGRect(x: 35, y: 45 + index * 65, width: 525, height: 60), withAttributes: attributes)
            }
        }
        do { let url = FileManager.default.temporaryDirectory.appending(path: "UR-" + (beneficiary ? "beneficiary-" : "payment-") + urText(order, "id") + ".pdf"); try data.write(to: url, options: .atomic); receipt = url }
        catch { message = error.localizedDescription }
    }
}

struct URNativeOperationsView: View {
    @ObservedObject private var api = URNativeAPI.owner
    @State private var hours = 6
    @State private var metrics: [String: Any] = [:]
    @State private var overview: [String: Any] = [:]
    @State private var orders: [[String: Any]] = []
    @State private var message = ""
    @State private var busy = false
    @State private var search = ""
    @State private var orderStatus = "all"
    @State private var security: [String: Any] = [:]
    @State private var paymentMethods: [[String: Any]] = []
    private var filteredOrders: [[String: Any]] {
        orders.filter { order in
            let payload = urObject(order["payload"])
            let text = [urText(order, "id"), urText(payload, "senderName"), urText(payload, "receiverName"), urText(payload, "senderPhone"), urText(payload, "receiverPhone")].joined(separator: " ")
            return (orderStatus == "all" || urText(order, "status") == orderStatus) && (search.isEmpty || text.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        Group {
            if api.profile["role"] != "super_admin" { URNativeLoginView(api: api, owner: true) }
            else {
                List {
                    Section {
                        ZStack(alignment: .bottomTrailing) {
                            LinearGradient(colors: [URColor.deepNavy, URColor.royalBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Circle().fill(URColor.premiumGold.opacity(0.20)).frame(width: 120).offset(x: -210, y: -35)
                            VStack(alignment: .trailing, spacing: 7) {
                                Label("متصل بحساب المالك", systemImage: "checkmark.shield.fill")
                                    .font(.caption.weight(.bold)).foregroundStyle(URColor.premiumGold)
                                Text("مركز العمليات").font(.title2.weight(.black)).foregroundStyle(.white)
                                Text("راقب الطلبات والحوالات والعملاء من شاشة واحدة")
                                    .font(.caption).foregroundStyle(.white.opacity(0.82))
                            }
                            .padding(18).frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .frame(height: 135)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    Section("مركز العمليات") {
                        LabeledContent("حساب الإدارة", value: api.profile["email"] ?? "")
                        LabeledContent("التحقق بخطوتين", value: security["enabled"] == nil ? "جاري التحقق" : security["enabled"] as? Bool == true ? "مفعّل" : "غير مفعّل")
                        Text("آخر تحديث: " + urReceiptDate(overview["refreshedAt"])).font(.caption)
                        let insights = urObject(overview["insights"])
                        LabeledContent("حوالات تجاوزت 24 ساعة", value: urText(insights, "overdueTransfers"))
                        LabeledContent("عملاء جدد — آخر 24 ساعة", value: urText(insights, "todayCustomers"))
                        LabeledContent("حوالات جديدة — آخر 24 ساعة", value: urText(insights, "todayTransfers"))
                    }
                    Section("حركة التطبيق") {
                        Picker("الفترة", selection: $hours) { Text("ساعة").tag(1); Text("5 ساعات").tag(5); Text("6 ساعات").tag(6); Text("24 ساعة").tag(24); Text("7 أيام").tag(168) }
                        let summary = urObject(metrics["summary"])
                        LabeledContent("مرات فتح التطبيق", value: urText(summary, "opens"))
                        LabeledContent("أجهزة نشطة", value: urText(summary, "activeInstallations"))
                        LabeledContent("أول فتح بعد التثبيت", value: urText(summary, "firstOpens"))
                        LabeledContent("تنزيلات App Store", value: urText(metrics, "downloadsSource"))
                    }
                    Section("العملاء والعمليات") {
                        let stats = urObject(overview["stats"])
                        ForEach(["customers", "agents", "openTransfers", "pendingTopups", "openTickets"], id: \.self) { key in
                            LabeledContent(["customers": "العملاء", "agents": "الوكلاء", "openTransfers": "حوالات مفتوحة", "pendingTopups": "إيداعات تحتاج مراجعة", "openTickets": "تذاكر الدعم"][key] ?? key, value: urText(stats, key))
                        }
                        NavigationLink { AdminEntryView() } label: {
                            Label("العودة لمركز الإدارة والأسعار", systemImage: "rectangle.3.group.fill")
                        }
                        NavigationLink("تفعيل المسارات وحدود المبالغ") { URNativeRouteAdminView() }
                        NavigationLink("إعدادات ودفع PayPal") { URNativePayPalSettingsView() }
                        NavigationLink { URNativeNotificationView(api: api) } label: { Label("مركز إشعارات العمليات", systemImage: "bell.badge.fill") }
                    }
                    Section("طلبات الحوالات والدفع") {
                        TextField("بحث برقم الطلب أو الاسم أو الهاتف", text: $search).autocorrectionDisabled()
                        Picker("حالة الطلب", selection: $orderStatus) { Text("الكل").tag("all"); ForEach(["review", "awaiting_payment", "payment_review", "confirmed", "issued", "rejected"], id: \.self) { Text(urStatus($0)).tag($0) } }
                        Text("\(filteredOrders.count) طلب ضمن النتائج المحمّلة").font(.caption)
                        if filteredOrders.isEmpty { Text("لا توجد طلبات مطابقة") }
                        ForEach(filteredOrders.indices, id: \.self) { index in NavigationLink { URNativeOwnerOrderView(order: filteredOrders[index], api: api) } label: { VStack(alignment: .leading) { Text(urText(urObject(filteredOrders[index]["payload"]), "senderName")); Text(urText(filteredOrders[index], "id")).font(.caption); Text(urStatus(urText(filteredOrders[index], "status"))).font(.footnote) } } }
                    }
                    Section("الحوالات الأخيرة") {
                        let rows = overview["transfers"] as? [[String: Any]] ?? []
                        ForEach(rows.indices, id: \.self) { i in NavigationLink { URNativeDeliveryView(transfer: rows[i], api: api) } label: { VStack(alignment: .leading) { Text(urText(rows[i], "tracking_code")); Text(urText(rows[i], "sender_name") + " ← " + urText(rows[i], "receiver_name")); Text(urText(rows[i], "amount") + " " + urText(rows[i], "currency") + " · " + urText(rows[i], "status")) } } }
                    }
                    Section("تعزيزات الوكلاء") {
                        let rows = overview["topups"] as? [[String: Any]] ?? []
                        ForEach(rows.indices, id: \.self) { i in NavigationLink { URNativeTopupView(topup: rows[i], api: api) } label: { VStack(alignment: .leading) { Text(urText(rows[i], "full_name")); Text(urText(rows[i], "amount_usdt") + " USDT · " + urText(rows[i], "network") + " · " + urText(rows[i], "status")) } } }
                    }
                    Section("المسجلون حديثاً") {
                        let rows = overview["users"] as? [[String: Any]] ?? []
                        ForEach(rows.indices, id: \.self) { i in VStack(alignment: .leading) { Text(urText(rows[i], "full_name")); Text(urText(rows[i], "phone")); Text(urText(rows[i], "email")).font(.footnote); Text(urText(rows[i], "role") + " · " + urText(rows[i], "status")).font(.footnote) } }
                    }
                    Section("طلبات انضمام الوكلاء الأخيرة") {
                        let applications = overview["applications"] as? [[String: Any]] ?? []
                        if applications.isEmpty { Text("لا توجد طلبات انضمام ضمن النتائج الأخيرة") }
                        ForEach(applications.indices, id: \.self) { i in VStack(alignment: .leading, spacing: 6) { Text(urText(applications[i], "full_name")); Text(urText(applications[i], "location") + " · " + urText(applications[i], "business_type")).font(.footnote); Text(urText(applications[i], "whatsapp")).textSelection(.enabled); Text(urText(applications[i], "status")).font(.caption) } }
                    }
                    Section("الحركة ساعة بساعة — UTC") {
                        let rows = metrics["hourly"] as? [[String: Any]] ?? []
                        ForEach(rows.indices, id: \.self) { i in LabeledContent(urText(rows[i], "hour"), value: urText(rows[i], "opens") + " فتح · " + urText(rows[i], "activeInstallations") + " أجهزة") }
                    }
                    Section("طرق الإيداع") {
                        ForEach(paymentMethods.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 6) {
                                LabeledContent(urText(paymentMethods[i], "name"), value: urText(paymentMethods[i], "id") == "paypal" ? "الربط داخل التطبيق قيد التجهيز" : paymentMethods[i]["available"] as? Bool == true ? "متوفر" : "غير متوفر")
                                Text(urText(paymentMethods[i], "instructions")).font(.footnote).textSelection(.enabled)
                            }
                        }
                    }
                    Section("حجم الحوالات حسب العملة") {
                        let volumes = urObject(overview["insights"])["volumes"] as? [[String: Any]] ?? []
                        ForEach(volumes.indices, id: \.self) { i in LabeledContent(urText(volumes[i], "currency"), value: urText(volumes[i], "total") + " · " + urText(volumes[i], "count") + " حوالة") }
                        Text("إجمالي الحوالات غير الملغاة؛ ليس رصيد الحساب البنكي.").font(.caption)
                    }
                    Section("سجل إجراءات الإدارة") {
                        let activity = urObject(overview["insights"])["activity"] as? [[String: Any]] ?? []
                        ForEach(activity.indices, id: \.self) { i in VStack(alignment: .leading) { Text(urText(activity[i], "action")); Text(urText(activity[i], "actor_email")).font(.caption); Text(urText(activity[i], "entity_type") + " · " + urText(activity[i], "entity_id")).font(.caption); Text(urReceiptDate(activity[i]["created_at"])).font(.caption) } }
                    }
                    if !message.isEmpty { Text(message).foregroundStyle(.red) }
                    Button("تحديث") { Task { await reload() } }.disabled(busy)
                    Button("تسجيل الخروج من الإدارة", role: .destructive) { Task { await api.logout() } }
                }.refreshable { await reload() }
            }
        }.scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle("العمليات").environment(\.layoutDirection, .rightToLeft)
            .listStyle(.insetGrouped)
            .task { try? await api.refreshProfile(); await reload() }
            .onChange(of: hours) { _, _ in Task { await reload() } }
            .onChange(of: api.profile) { _, _ in Task { await reload() } }
    }
    private func reload() async {
        guard api.profile["role"] == "super_admin", !busy else { return }
        busy = true; message = ""; defer { busy = false }
        var failures: [String] = []
        do { orders = try await api.request("/api/admin/payments")["orders"] as? [[String: Any]] ?? [] } catch { failures.append("طلبات الحوالات: " + error.localizedDescription) }
        do { overview = try await api.request("/api/admin/mobile-overview") } catch { failures.append("ملخص العمليات: " + error.localizedDescription) }
        do { metrics = try await api.request("/api/native/operations?hours=\(hours)") } catch { failures.append("الإحصائيات: " + error.localizedDescription) }
        do { security = try await api.request("/api/auth/mfa") } catch { failures.append("حالة الحماية: " + error.localizedDescription) }
        do { paymentMethods = try await api.request("/api/payment-methods")["methods"] as? [[String: Any]] ?? [] } catch { failures.append("طرق الدفع: " + error.localizedDescription) }
        message = failures.joined(separator: "\n")
    }
}
private struct URNativeTopupView: View {
    @State var topup: [String: Any]
    @ObservedObject var api: URNativeAPI
    @State private var received = false
    @State private var message = ""
    @State private var busy = false
    @State private var approveKey = UUID().uuidString
    @State private var rejectKey = UUID().uuidString
    var body: some View {
        Form {
            Section("التعزيز") {
                LabeledContent("الوكيل", value: urText(topup, "full_name"))
                LabeledContent("المبلغ", value: urText(topup, "amount_usdt") + " USDT")
                LabeledContent("الشبكة", value: urText(topup, "network"))
                Text("TXID: " + urText(topup, "txid")).textSelection(.enabled)
                LabeledContent("الحالة", value: urText(topup, "status"))
            }
            if urText(topup, "status") == "pending" {
                Toggle("طابقت وصول المبلغ والشبكة وTXID فعلياً", isOn: $received)
                Button("اعتماد التعزيز وإضافة الرصيد") { Task { await decide("approved") } }.disabled(!received || busy)
                Button("رفض التعزيز", role: .destructive) { Task { await decide("rejected") } }.disabled(busy)
            }
            if !message.isEmpty { Text(message) }
        }.scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle("تعزيز رصيد")
    }
    private func decide(_ status: String) async {
        busy = true; defer { busy = false }
        do {
            _ = try await api.request("/api/topups/" + urText(topup, "id"), method: "PATCH", body: ["status": status], idempotencyKey: status == "approved" ? approveKey : rejectKey)
            topup["status"] = status; message = "تم تسجيل القرار"
        } catch { message = error.localizedDescription }
    }
}
private struct URNativeDeliveryView: View {
    @State var transfer: [String: Any]
    @ObservedObject var api: URNativeAPI
    @State private var code = ""
    @State private var identity = ""
    @State private var checked = false
    @State private var message = ""
    @State private var busy = false
    @State private var key = UUID().uuidString
    @State private var nextStatus = "قيد المعالجة"
    var body: some View {
        Form {
            Section("الحوالة") {
                Text(urText(transfer, "tracking_code"))
                LabeledContent("المرسل", value: urText(transfer, "sender_name"))
                LabeledContent("المستفيد", value: urText(transfer, "receiver_name"))
                LabeledContent("الحالة", value: urText(transfer, "status"))
                    LabeledContent("صافي التسليم", value: urText(transfer, "netAmountFiat", fallback: urText(transfer, "net_amount_fiat")) + " " + urText(transfer, "payoutCurrency", fallback: urText(transfer, "payout_currency")))
            }
            if !["تم التسليم", "ملغاة"].contains(urText(transfer, "status")) {
                Section("إدارة التنفيذ") {
                    Picker("حالة التنفيذ", selection: $nextStatus) { ForEach(["قيد المعالجة", "جاهزة للتسليم", "موقوفة"], id: \.self) { Text($0).tag($0) } }
                    Button("تحديث حالة التنفيذ") { Task { await updateStatus() } }.disabled(busy)
                }
            }
            if urText(transfer, "status") == "جاهزة للتسليم" {
                Section("تسليم المستفيد") {
                    SecureField("رمز الاستلام", text: $code).keyboardType(.numberPad)
                    TextField("مرجع الهوية المطابقة", text: $identity)
                    Toggle("طابقت الهوية وأسلم كامل المبلغ للمستفيد", isOn: $checked)
                    Button("تسجيل التسليم الفعلي") { Task { await deliver() } }.disabled(!checked || code.count != 6 || identity.count < 4 || busy)
                }
            } else if urText(transfer, "status") != "تم التسليم" { Text("يلزم تجهيز الحوالة وتخصيص المكتب والسيولة قبل التسليم.") }
            if !message.isEmpty { Text(message) }
        }.scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle("تنفيذ حوالة").task { await reload() }
    }
    private func deliver() async {
        busy = true; defer { busy = false }
        do {
            _ = try await api.request("/api/transfers/" + urText(transfer, "id") + "/deliver", method: "POST", body: ["pickupCode": urDigits(code), "identityReference": identity], idempotencyKey: key)
            transfer["status"] = "تم التسليم"; code = ""; message = "تم تسجيل التسليم وإتاحة وصل المستفيد"
        } catch { message = error.localizedDescription }
    }
    private func reload() async {
        do {
            let result = try await api.request("/api/transfers/" + urText(transfer, "id"))
            if let latest = result["transfer"] as? [String: Any] {
                transfer.merge(latest) { _, fresh in fresh }
                for (snake, camel) in [("tracking_code", "trackingCode"), ("sender_name", "senderName"), ("receiver_name", "receiverName")] { if let value = latest[camel] { transfer[snake] = value } }
            }
        } catch { message = error.localizedDescription }
    }
    private func updateStatus() async {
        busy = true; defer { busy = false }
        do { _ = try await api.request("/api/transfers/" + urText(transfer, "id"), method: "PATCH", body: ["status": nextStatus]); await reload() }
        catch { message = error.localizedDescription }
    }
}
private struct URNativeOwnerOrderView: View {
    @State var order: [String: Any]
    @ObservedObject var api: URNativeAPI
    @State private var identity = false
    @State private var received = false
    @State private var reference = ""
    @State private var reason = ""
    @State private var message = ""
    @State private var busy = false
    @State private var proofURL: URL?
    var body: some View {
        Form {
            Section("مراجعة الطلب") {
                Text(urText(order, "id")); Text(urStatus(urText(order, "status")))
                let payload = urObject(order["payload"])
                ForEach(["senderName", "senderPhone", "senderAddress", "receiverName", "receiverPhone", "receiverAddress", "amount", "purpose"], id: \.self) { key in Text(urText(payload, key)) }
                Text("إثبات: " + urText(order, "evidence"))
                if let path = urText(order, "evidence").components(separatedBy: " · ").first(where: { $0.hasPrefix("/api/customer/evidence?") }) {
                    Button("عرض صورة أو PDF الإيداع") { Task { do { proofURL = try await api.downloadEvidence(path) } catch { message = error.localizedDescription } } }
                }
            }
            if ["review", "awaiting_payment"].contains(urText(order, "status")) {
                Toggle("راجعت هوية المرسل والمستفيد", isOn: $identity)
                Button("إصدار / تحديث عرض السعر من المصدر") { Task { await action("quote") } }.disabled(!identity || busy)
                Button("رفض الطلب قبل الدفع", role: .destructive) { Task { await action("reject") } }.disabled(busy)
            }
            if urText(order, "status") == "payment_review" && urText(order, "method") != "paypal" {
                TextField("مرجع قبض المبلغ من البنك أو المحفظة", text: $reference)
                Toggle("طابقت وصول كامل المبلغ فعلياً", isOn: $received)
                TextField("سبب طلب المعلومات أو رفض الإثبات", text: $reason, axis: .vertical)
                Button("طلب معلومات أو إثبات إضافي") { Task { await action("request_more") } }.disabled(reason.count < 5 || busy)
                Button("رفض الإثبات مع السماح بالتصحيح", role: .destructive) { Task { await action("reject_evidence") } }.disabled(reason.count < 5 || busy)
                Button("تأكيد قبض المبلغ") { Task { await action("confirm") } }.disabled(!received || reference.count < 4 || busy)
            }
            if urText(order, "status") == "confirmed" { Button("إصدار الحوالة") { Task { await action("issue") } }.disabled(busy) }
            if !message.isEmpty { Text(message) }
        }.scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle("عملية عميل").quickLookPreview($proofURL)
    }
    private func action(_ name: String) async {
        busy = true; message = ""; defer { busy = false }
        do {
            let result = try await api.request("/api/admin/payments", method: "PATCH", body: ["id": urText(order, "id"), "version": order["version"] as? Int ?? -1, "action": name, "reference": reference, "reason": reason, "confirmReceived": received, "confirmIdentity": identity])
            message = "تم اعتماد الإجراء"
            if let pin = result["plainPin"] as? String { message += " · رمز الاستلام (احفظه بأمان): " + pin }
            let rows = try await api.request("/api/admin/payments")["orders"] as? [[String: Any]] ?? []
            if let latest = rows.first(where: { urText($0, "id") == urText(order, "id") }) { order = latest }
        } catch { message = error.localizedDescription }
    }
}

struct URRatesWorkspace<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .background(URColor.ivory)
            .tint(URColor.royalBlue)
    }
}
private struct URNativeRatesBoard: View {
    @State private var rows: [[String: Any]] = []
    @State private var query = ""
    @State private var category = "all"
    @State private var favoritesOnly = false
    @State private var favorites = Set(UserDefaults.standard.stringArray(forKey: "URNativeRateFavorites") ?? [])
    @State private var busy = false
    @State private var message = ""
    private var categories: [String] { Array(Set(rows.map { urText($0, "category", fallback: "other") })).sorted() }
    private var visible: [[String: Any]] {
        rows.filter { row in
            let text = ["routeNameArabic", "routeNameEnglish", "sourceCurrency", "destinationCurrency"].map { urText(row, $0) }.joined(separator: " ")
            return (category == "all" || urText(row, "category", fallback: "other") == category) && (!favoritesOnly || favorites.contains(urText(row, "id"))) && (query.isEmpty || text.localizedCaseInsensitiveContains(query))
        }
    }
    private func label(_ key: String) -> String {
        ["iraq":"العراق", "gulf":"الخليج", "iran_turkey":"إيران وتركيا", "europe":"أوروبا وكندا", "arab":"الدول العربية", "transfers":"خدمات التحويل", "uae_banks":"بنوك الإمارات", "india":"الهند", "international":"خدمات دولية", "other":"أسعار أخرى"][key] ?? key
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("UR | أور").font(.title2.bold())
                    Text("نشرة أسعار الصرف").font(.largeTitle.bold())
                    Text("شراء · بيع · عمولات التحويل").font(.subheadline)
                }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(22).background(LinearGradient(colors: [URColor.deepNavy, URColor.royalBlue], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 22))
                TextField("ابحث عن دولة أو مدينة أو بنك أو عملة", text: $query).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                Picker("القسم", selection: $category) { Text("كل الأقسام").tag("all"); ForEach(categories, id: \.self) { Text(label($0)).tag($0) } }
                Toggle("المفضلة فقط", isOn: $favoritesOnly)
                HStack { Text("\(visible.count) سعر وخدمة").font(.footnote); Spacer(); Button(busy ? "جاري التحديث…" : "تحديث") { Task { await load() } }.disabled(busy) }
                if !message.isEmpty { Text(message).foregroundStyle(.red).font(.footnote) }
                if busy && rows.isEmpty { ProgressView() }
                ForEach(visible.indices, id: \.self) { index in
                    let row = visible[index]
                    URNativeRateCard(row: row, favorite: favorites.contains(urText(row, "id"))) {
                        let id = urText(row, "id")
                        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
                        UserDefaults.standard.set(Array(favorites).sorted(), forKey: "URNativeRateFavorites")
                    }
                }
                if !busy && visible.isEmpty { Text("لا توجد أسعار مطابقة. غيّر البحث أو القسم.").foregroundStyle(.secondary) }
                Text("القيم كما نشرها مصدر الأسعار. العمولة الثابتة لكل 10,000 دولار؛ راجع وحدة الشراء والبيع قبل الحسبة.").font(.caption).foregroundStyle(.secondary)
            }.padding()
        }.environment(\.layoutDirection, .rightToLeft).navigationTitle("بحث ومقارنة الأسعار").task { await load() }.refreshable { await load() }
    }
    private func load() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            let result = try await URNativeAPI.customer.request("/api/public-rates")
            guard let data = result["data"] as? [[String: Any]] else { throw URNativeError.message("بيانات الأسعار غير مكتملة") }
            rows = data; message = ""
        } catch { message = "تعذر التحديث؛ الأرقام الظاهرة آخر بيانات وصلت. " + error.localizedDescription }
    }
}
private struct URNativeRateCard: View {
    let row: [String: Any]
    let favorite: Bool
    let toggle: () -> Void
    private func value(_ key: String) -> String {
        guard let number = row[key] as? NSNumber else { return "—" }
        let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.numberStyle = .decimal; formatter.maximumFractionDigits = 8
        return formatter.string(from: number) ?? "—"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(urText(row, "routeNameArabic")).font(.headline); Spacer(); Button(action: toggle) { Image(systemName: favorite ? "star.fill" : "star") }.accessibilityLabel(favorite ? "إزالة من المفضلة" : "إضافة إلى المفضلة") }
            Text(urText(row, "sourceCurrency") + " / " + urText(row, "destinationCurrency")).font(.caption).environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 24) {
                VStack(alignment: .leading) { Text("شراء").font(.caption).foregroundStyle(.secondary); Text(value("buy")).font(.title2.bold()).monospacedDigit().foregroundStyle(URColor.deepNavy) }
                VStack(alignment: .leading) { Text("بيع").font(.caption).foregroundStyle(.secondary); Text(value("sell")).font(.title2.bold()).monospacedDigit().foregroundStyle(URColor.royalBlue) }
            }
            if row["feeFixed"] is NSNumber { LabeledContent("عمولة / 10,000 USD", value: value("feeFixed") + " USD") }
            if row["feePercent"] is NSNumber { LabeledContent("العمولة النسبية", value: value("feePercent") + "%") }
            Text("تاريخ المصدر: " + urText(row, "sourceTimestamp")).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(URColor.premiumGold.opacity(0.25))).foregroundStyle(URColor.deepNavy)
    }
}
private struct URNativePayPalConnectionView: View {
    @ObservedObject var api: URNativeAPI
    @State private var status: [String: Any] = [:]
    @State private var message = ""
    @State private var busy = false
    var body: some View {
        Form {
            Section("PayPal Live — فحص الاتصال") {
                LabeledContent("الحساب", value: "SOGNA LTD")
                LabeledContent("العملة", value: "GBP")
                LabeledContent("مفاتيح السيرفر", value: status["hasCredentials"] as? Bool == true ? "مهيأة بشكل سري" : "بانتظار التحقق")
                LabeledContent("آخر نجاح فحص", value: urReceiptDate(status["checkedAt"]))
                Text("هذا الفحص لا يخصم مبلغاً ولا ينشئ حوالة. الدفع داخل التطبيق يحتاج إكمال التكامل وأهلية الحساب.").font(.footnote)
                Button(busy ? "جاري فحص الاتصال…" : "فحص اتصال Live بدون دفع") { Task { await test() } }.disabled(busy || status["hasCredentials"] as? Bool != true)
                if !message.isEmpty { Text(message) }
            }
        }.navigationTitle("اتصال PayPal").task { do { status = try await api.request("/api/admin/paypal-live") } catch { message = error.localizedDescription } }
    }
    private func test() async {
        busy = true; defer { busy = false }
        do { let result = try await api.request("/api/admin/paypal-live", method: "POST", body: [:]); message = urText(result, "message"); status = try await api.request("/api/admin/paypal-live") } catch { message = error.localizedDescription }
    }
}

@MainActor
private final class URPayPalApprovalSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL?, Error>?
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
    private func finish(_ callback: URL?, _ error: Error?) {
        guard let pending = continuation else { return }; continuation = nil; session = nil
        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin { pending.resume(returning: nil) }
        else if let error { pending.resume(throwing: error) }
        else { pending.resume(returning: callback) }
    }
    func approve(_ url: URL) async throws -> URL? {
        guard continuation == nil else { throw URNativeError.message("موافقة PayPal مفتوحة بالفعل") }
        return try await withCheckedThrowingContinuation { pending in
            continuation = pending
            session = ASWebAuthenticationSession(url: url, callbackURLScheme: "urremit-paypal") { [weak self] callback, error in
                Task { @MainActor in self?.finish(callback, error) }
            }
            session?.presentationContextProvider = self
            if session?.start() != true { finish(nil, URNativeError.message("تعذر فتح موافقة PayPal")) }
        }
    }
}
private struct URNativePayPalPaymentView: View {
    @ObservedObject var api: URNativeAPI
    let order: [String: Any]
    let refresh: () async -> Void
    @State private var browser = URPayPalApprovalSession()
    @State private var busy = false
    @State private var accepted = false
    @State private var confirmCancel = false
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        Text("الموافقة تتم على صفحة PayPal الآمنة؛ إنشاء الطلب والتحقق من القبض داخل تطبيق أور.").font(.footnote)
        if urText(order, "status") == "paypal_test_complete" { Text("اختبار Sandbox مكتمل. لم تستلم أور أموالاً فعلية ولا يصدر وصل قبض.").foregroundStyle(.orange) }
        else if urText(order, "status") == "confirmed" { Text("تم التحقق من قبض الدفعة على الخادم.").foregroundStyle(.green) }
        else {
            Toggle("راجعت المبلغ والعملة وأوافق على الدفع", isOn: $accepted)
            Button(busy ? "جاري التحقق…" : "متابعة الدفع عبر PayPal") { Task { await pay() } }.buttonStyle(.borderedProminent).disabled(busy || !accepted)
            Button("تحقق من حالة الدفع بدون خصم جديد") { Task { await verify() } }.disabled(busy)
            if urText(order, "status") == "paypal_pending" { Button("إلغاء جلسة غير مدفوعة", role: .destructive) { confirmCancel = true }.disabled(busy) }
        }
        if !message.isEmpty { Text(message).font(.footnote) }
        }.alert("إلغاء جلسة الدفع؟", isPresented: $confirmCancel) {
            Button("تحقق وألغِ إذا لم يُقبض المبلغ", role: .destructive) { Task { await cancel() } }
            Button("رجوع", role: .cancel) {}
        } message: { Text("الخادم يتحقق من PayPal أولاً. إذا المبلغ مقبوض أو قيد المعالجة ما راح ينلغى كطلب غير مدفوع.") }
    }
    private func cancel() async {
        guard !busy else { return }; busy = true; message = ""; defer { busy = false }
        do { let result = try await api.request("/api/customer/paypal", method: "POST", body: ["id": urText(order, "id"), "action": "cancel", "confirmCancel": true]); message = result["message"] as? String ?? "تم التحقق من الدفع؛ حدّث الطلب"; await refresh() }
        catch { message = error.localizedDescription }
    }
    private func verify() async {
        guard !busy else { return }; busy = true; message = ""; defer { busy = false }
        do { let result = try await api.request("/api/customer/paypal", method: "POST", body: ["id": urText(order, "id"), "action": "status"]); show(result); await refresh() }
        catch { message = error.localizedDescription }
    }
    private func show(_ result: [String: Any]) {
        if result["testOnly"] as? Bool == true && result["captureId"] != nil { message = "نجح اختبار Sandbox؛ لا أموال حقيقية." }
        else if result["paid"] as? Bool == true { message = "تم التحقق من قبض المبلغ. تابع الحوالة من طلباتك." }
        else { message = "لم يتأكد القبض بعد. الحالة: " + urText(result, "status") }
    }
    private func pay() async {
        guard !busy && accepted else { return }; busy = true; message = ""; defer { busy = false }
        do {
            let result = try await api.request("/api/customer/paypal", method: "POST", body: ["id": urText(order, "id"), "action": "start", "version": order["version"] as? Int ?? 0, "acceptQuote": true])
            if result["captureId"] != nil { show(result); await refresh(); return }
            if let link = result["approvalUrl"] as? String, let url = URL(string: link) {
                guard url.scheme == "https", ["www.paypal.com", "www.sandbox.paypal.com"].contains(url.host ?? "") else { throw URNativeError.message("رابط PayPal غير صالح") }
                guard let callback = try await browser.approve(url), let components = URLComponents(url: callback, resolvingAgainstBaseURL: false) else { message = "تم إلغاء الموافقة. لا يظهر الدفع مؤكداً إلا بعد تحقق الخادم."; await refresh(); return }
                let values = components.queryItems ?? []
                guard callback.scheme == "urremit-paypal", callback.host == "checkout", values.first(where: { $0.name == "state" })?.value == (result["state"] as? String) else { throw URNativeError.message("رجوع الدفع لا يطابق الطلب؛ تحقق من الحالة") }
                if values.first(where: { $0.name == "cancel" })?.value == "1" { message = "تم إلغاء الموافقة؛ تقدر ترجع تكمل نفس الطلب."; await refresh(); return }
                guard values.first(where: { $0.name == "token" })?.value == (result["providerOrderId"] as? String) else { throw URNativeError.message("رقم دفعة PayPal لا يطابق الطلب") }
            } else if urText(result, "status") != "APPROVED" { throw URNativeError.message("لا توجد موافقة PayPal جاهزة؛ تحقق من حالة الدفع") }
            let captured = try await api.request("/api/customer/paypal", method: "POST", body: ["id": urText(order, "id"), "action": "capture"])
            show(captured); await refresh()
        } catch { message = error.localizedDescription + " — لا تدفع مرة ثانية قبل فحص الحالة."; await refresh() }
    }
}
private struct URNativePayPalSettingsView: View {
    @ObservedObject private var api = URNativeAPI.owner
    @State private var sandboxClientId = ""
    @State private var sandboxSecret = ""
    @State private var merchantId = ""
    @State private var enabled = false
    @State private var busy = false
    @State private var message = ""
    @State private var readiness = ""
    var body: some View {
        Form {
            Section("PayPal Live") {
                NavigationLink("فحص اتصال حساب Live") { URNativePayPalConnectionView(api: api) }
                Text("اتصال المفاتيح وحده لا يفعّل التحصيل. Live يحتاج معرّف التاجر وموافقة PayPal على نشاط أور.").font(.footnote)
            }
            Section("تجربة دفع Sandbox كاملة") {
                TextField("Sandbox Client ID", text: $sandboxClientId).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Sandbox Secret — محفوظ مشفراً بالخادم", text: $sandboxSecret)
                TextField("Sandbox Merchant ID", text: $merchantId).textInputAutocapitalization(.characters).autocorrectionDisabled()
                Toggle("إظهار PayPal Sandbox للاختبار", isOn: $enabled)
                Text("لا تستخدم بيانات Live هنا. الاختبار لا يصدر حوالة ولا وصل قبض حقيقي.").font(.footnote)
                Button(busy ? "جاري الحفظ…" : "حفظ إعدادات الاختبار") { Task { await save() } }.disabled(busy)
                Text(readiness)
            }
            if !message.isEmpty { Section { Text(message) } }
        }.scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle("إعدادات PayPal").task { await load() }
    }
    private func load() async {
        do { let sandbox = urObject(try await api.request("/api/admin/paypal-sandbox")["config"]); sandboxClientId = urText(sandbox, "clientId", fallback: "")
            let checkout = try await api.request("/api/admin/paypal-checkout"), settings = urObject(checkout["settings"])
            merchantId = urText(settings, "sandboxMerchantId", fallback: ""); enabled = settings["enabled"] as? Bool == true && urText(settings, "environment") == "sandbox"; readiness = urText(urObject(checkout["readiness"]), "reason")
        } catch { message = error.localizedDescription }
    }
    private func save() async {
        guard !busy else { return }; busy = true; message = ""; defer { busy = false }
        do {
            _ = try await api.request("/api/admin/paypal-sandbox", method: "POST", body: ["action": "save", "clientId": sandboxClientId, "clientSecret": sandboxSecret, "company": "SOGNA LTD", "currency": "GBP"])
            sandboxSecret = ""
            let result = try await api.request("/api/admin/paypal-checkout", method: "POST", body: ["environment": "sandbox", "enabled": enabled, "sandboxMerchantId": merchantId])
            guard result["success"] as? Bool == true else { throw URNativeError.message("لم يتأكد حفظ إعدادات الدفع") }; readiness = urText(urObject(result["readiness"]), "reason"); message = "تم حفظ إعدادات الاختبار."
        } catch { message = error.localizedDescription }
    }
}

private struct URNativePaymentBrandRow: View {
    let method: [String: Any]
    var selected = false
    private var id: String { urText(method, "id") }
    private var brand: String { ["usdt_trc20": "tron", "usdt_erc20": "ethereum"][id] ?? id }
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if ["tron", "ethereum", "paypal", "superqi", "zaincash", "fib"].contains(brand) { Image("URPayment-" + brand).resizable().scaledToFit() }
                else { Image(systemName: id == "cash" ? "banknote" : "creditcard").resizable().scaledToFit().foregroundStyle(URColor.royalBlue) }
            }
                .frame(width: 48, height: 40).padding(5).background(id == "zaincash" ? URColor.deepNavy : Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(urText(method, "name")).font(.subheadline.weight(.semibold)).foregroundStyle(URColor.deepNavy)
                if id == "usdt_trc20" { Text("شبكة TRON").font(.caption).foregroundStyle(.secondary) }
                if id == "usdt_erc20" { Text("شبكة Ethereum").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(URColor.royalBlue) }
            else { Text(method["available"] as? Bool == true ? (urText(method, "environment", fallback: "") == "sandbox" ? "اختبار فقط" : "متوفر") : "غير متوفر").font(.caption.weight(.semibold)).padding(8).background(URColor.ivory).clipShape(Capsule()) }
        }.padding(.vertical, 5).contentShape(Rectangle())
    }
}
private struct URNativePayPalPreview: View {
    var body: some View {
        List {
            Section { URNativePaymentBrandRow(method: ["id": "paypal", "name": "PayPal — شرح التجربة", "available": false]); Text("هذه معاينة للخطوات؛ لا تنشئ دفعة ولا تؤكد وصول أموال.").font(.footnote) }
            Section("١ · اعتماد الطلب") { Text("تراجع أور بيانات الحوالة، المبلغ والعمولة وصافي الاستلام. تختار PayPal عندما تتوفر بيئة الاختبار.") }
            Section("٢ · موافقتك على الدفع") { Text("يفتح PayPal داخل جلسة مصادقة آمنة. تسجل بحساب Sandbox المشتري وتراجع المبلغ والعملة قبل الموافقة.") }
            Section("٣ · الرجوع للتطبيق") { Text("يرجع PayPal إلى التطبيق، والخادم يتحقق من عملية الدفع والمبلغ ومعرف التاجر. الرجوع وحده لا يؤكد القبض.") }
            Section("٤ · نتيجة الاختبار") { Text("تظهر حالة: اكتمل اختبار PayPal — لا أموال حقيقية. لا يصدر وصل قبض حقيقي أو حوالة مالية من دفعة Sandbox.") }
            Section("إعداد التجربة الفعلية") { Text("من لوحة العمليات ← إعدادات ودفع PayPal: أدخل Sandbox Client ID وSecret ومعرف تاجر Sandbox، اختبر الاتصال ثم فعّل الاختبار. حساب Live لا يصلح بدل Sandbox.") }
        }.scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).navigationTitle("تجربة PayPal").environment(\.layoutDirection, .rightToLeft)
    }
}
struct URNativeNotificationView: View {
    @ObservedObject var api: URNativeAPI
    @Environment(\.scenePhase) private var scenePhase
    @State private var rows: [[String: Any]] = []
    @State private var message = ""
    @State private var seen = Set<String>()
    @State private var baselineLoaded = false
    @State private var localAlerts = false
    var body: some View {
        List {
            Section {
                Button("تفعيل تنبيه تحديث الطلب أثناء المتابعة") { Task {
                    do { localAlerts = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
                    catch { message = error.localizedDescription }
                } }
                Text("الإشعارات محفوظة داخل حسابك. التنبيه المحلي يعمل أثناء فتح شاشة المتابعة؛ تنبيه الدفع والتسليم في الخلفية يحتاج ربط APNs.").font(.caption)
            }
            if rows.isEmpty { Text("لا توجد إشعارات؛ حدّث القائمة") }
            ForEach(rows.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 6) {
                    Text(urText(rows[i], "title")).font(.headline).foregroundStyle(URColor.deepNavy)
                    Text(rows[i]["status"] == nil ? urText(rows[i], "body") : urStatus(urText(rows[i], "status"))).font(.subheadline)
                    if rows[i]["orderId"] != nil { Text(urText(rows[i], "orderId")).font(.caption).textSelection(.enabled) }
                }.padding(.vertical, 5)
            }
            if !message.isEmpty { Text(message).foregroundStyle(.red) }
        }.refreshable { await reload() }.scrollContentBackground(.hidden).background(URColor.ivory).navigationTitle("الإشعارات").environment(\.layoutDirection, .rightToLeft)
        .task { while !Task.isCancelled { if scenePhase == .active { await reload() }; do { try await Task.sleep(for: .seconds(20)) } catch { break } } }
    }
    private func reload() async {
        guard !api.profile.isEmpty else { rows = []; message = "سجل الدخول لعرض إشعارات حسابك"; return }
        do {
            let next = try await api.request("/api/native/notifications")["notifications"] as? [[String: Any]] ?? []
            if baselineLoaded && localAlerts {
                for row in next where !seen.contains(urText(row, "id")) {
                    let content = UNMutableNotificationContent(); content.title = "UR Global"; content.body = "وصل تحديث جديد إلى حسابك. افتح الإشعارات لمراجعته."; content.sound = .default
                    try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ur-notice-" + urText(row, "id"), content: content, trigger: nil))
                }
            }
            rows = next; seen.formUnion(next.map { urText($0, "id") }); baselineLoaded = true; message = ""
        } catch { message = error.localizedDescription }
    }
}

private struct URNativePriceAdminView: View {
    @ObservedObject private var api = URNativeAPI.owner
    @State private var rates: [[String: Any]] = []
    @State private var query = ""
    @State private var message = ""
    private var visible: [[String: Any]] { rates.filter { query.isEmpty || urText($0, "routeNameArabic").localizedCaseInsensitiveContains(query) } }
    var body: some View {
        List {
            Section { TextField("ابحث عن السعر", text: $query); Text("نفس مصدر أسعار التطبيق، وصلاحية لوحة العمليات نفسها.").font(.caption) }
            ForEach(visible.indices, id: \.self) { i in NavigationLink { URNativePriceEditor(row: visible[i], api: api) } label: { VStack(alignment: .leading) { Text(urText(visible[i], "routeNameArabic")).font(.headline); Text("شراء " + urText(visible[i], "buy") + " · بيع " + urText(visible[i], "sell")).font(.subheadline) } } }
            if !message.isEmpty { Text(message).foregroundStyle(.red) }
        }.navigationTitle("إدارة الأسعار").scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).environment(\.layoutDirection, .rightToLeft).task { await load() }.refreshable { await load() }.onAppear { Task { await load() } }
    }
    private func load() async { do { rates = try await api.request("/api/native/prices")["data"] as? [[String: Any]] ?? []; message = "" } catch { message = error.localizedDescription } }
}
private struct URNativePriceEditor: View {
    let row: [String: Any]
    @ObservedObject var api: URNativeAPI
    @State private var buy = ""
    @State private var sell = ""
    @State private var fee = ""
    @State private var busy = false
    @State private var saved = false
    @State private var message = ""
    var body: some View {
        Form {
            Section { Text(urText(row, "routeNameArabic")).font(.headline); Text("وحدة السعر الحالية: " + urText(row, "sourceCurrency") + " / " + urText(row, "destinationCurrency")).font(.caption); Text("حافظ على وحدة السعر المنشورة؛ مثلاً الرمبي 7.01، والدينار العراقي بالنشرة لكل 100 دولار.").font(.footnote) }
            Section("القيم المنشورة") { TextField("شراء", text: $buy).keyboardType(.decimalPad); TextField("بيع", text: $sell).keyboardType(.decimalPad); TextField("عمولة ثابتة لكل 10,000 دولار", text: $fee).keyboardType(.decimalPad); Text("الخانة الفارغة تعني لا توجد قيمة لهذا النوع.").font(.caption) }
            Button(busy ? "جاري الحفظ…" : saved ? "تم الحفظ" : "حفظ في مصدر التطبيق") { Task { await save() } }.disabled(busy || saved)
            if !message.isEmpty { Text(message).foregroundStyle(saved ? URColor.royalBlue : .red) }
        }.navigationTitle("تعديل السعر").scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).environment(\.layoutDirection, .rightToLeft).disabled(busy || saved)
        .onAppear { buy = urText(row, "buy", fallback: ""); sell = urText(row, "sell", fallback: ""); fee = urText(row, "feeFixed", fallback: "") }
    }
    private func save() async {
        guard !busy && !saved else { return }; busy = true; message = ""; defer { busy = false }
        do {
            let result = try await api.request("/api/native/prices", method: "PATCH", body: ["id": urText(row, "id"), "expectedVersion": row["version"] ?? 0, "buy": buy.isEmpty ? NSNull() : urDigits(buy) as Any, "sell": sell.isEmpty ? NSNull() : urDigits(sell) as Any, "feeFixed": fee.isEmpty ? NSNull() : urDigits(fee) as Any])
            guard result["success"] as? Bool == true else { throw URNativeError.message("لم يؤكد المصدر الحفظ") }; saved = true; message = "تم تحديث السعر في مصدر التطبيق. ارجع وحدّث القائمة."
        } catch { message = error.localizedDescription }
    }
}

private struct URNativeRouteAdminView: View {
    @ObservedObject private var api = URNativeAPI.owner
    @State private var data: [String: Any] = [:]
    @State private var origin = ""
    @State private var destination = ""
    @State private var source = ""
    @State private var basis = 1
    @State private var min = "1"
    @State private var max = "100000"
    @State private var confirmed = false
    @State private var busy = false
    @State private var message = ""
    private var countries: [String] { (data["countries"] as? [[String: Any]] ?? []).map { urText($0, "country") } }
    private var rates: [[String: Any]] { (data["rates"] as? [[String: Any]] ?? []).filter { urText($0, "sourceCurrency") == "USD" && urText($0, "destinationCurrency") != "USD" && ($0["sell"] as? Double ?? 0) > 0 } }
    var body: some View {
        Form {
            Section("المكاتب والمسار") {
                Picker("دولة الإرسال", selection: $origin) { Text("اختر").tag(""); ForEach(countries, id: \.self) { Text($0).tag($0) } }
                Picker("دولة الاستلام", selection: $destination) { Text("اختر").tag(""); ForEach(countries, id: \.self) { Text($0).tag($0) } }
                Text("تفعيل هذا المسار يتيح الحسبة والإصدار بين جميع المكاتب المعتمدة في الدولتين، ضمن الحدود المحددة.").font(.footnote)
            }
            Section("مصدر السعر ووحدته") {
                Picker("سعر التسليم", selection: $source) { Text("اختر السعر الصحيح للدولة").tag(""); ForEach(rates.indices, id: \.self) { i in Text(urText(rates[i], "routeNameArabic") + " · " + urText(rates[i], "destinationCurrency")).tag(urText(rates[i], "id")) } }
                Picker("السعر المنشور مقابل", selection: $basis) { Text("1 دولار").tag(1); Text("100 دولار").tag(100); Text("10,000 دولار").tag(10000) }
                Text("مثال: الرمبي 7.01 لكل دولار؛ التومان 25,000,000 لكل 100 دولار. اختيار الوحدة يحدد الحسبة الفعلية.").font(.caption)
            }
            Section("حدود الطلب بالدولار") { TextField("أقل مبلغ", text: $min).keyboardType(.decimalPad); TextField("أعلى مبلغ", text: $max).keyboardType(.decimalPad); Text("الحد العام 100,000 دولار للطلب. حدود الوكيل اليومية والشهرية تبقى مطبقة عند الإصدار.").font(.caption) }
            Toggle("راجعت الدولة والعملة ووحدة السعر والحدود", isOn: $confirmed)
            Button(busy ? "جاري التفعيل…" : "حفظ وتفعيل المسار") { Task { await save() } }.disabled(busy || !confirmed || origin.isEmpty || destination.isEmpty || source.isEmpty)
            if !message.isEmpty { Text(message) }
        }.disabled(busy).navigationTitle("المسارات وحدود التنفيذ").scrollContentBackground(.hidden).background(URColor.ivory).tint(URColor.royalBlue).environment(\.layoutDirection, .rightToLeft)
        .task { do { data = try await api.request("/api/native/routes") } catch { message = error.localizedDescription } }
    }
    private func save() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { let result = try await api.request("/api/native/routes", method: "POST", body: ["origin": origin, "destination": destination, "sourceId": source, "basis": basis, "min": urDigits(min), "max": urDigits(max), "confirm": confirmed]); guard result["success"] as? Bool == true else { throw URNativeError.message("لم يؤكد الخادم التفعيل") }; message = "تم تفعيل المسار. حدّث الحسبة ثم اعتمد الطلب." } catch { message = error.localizedDescription }
    }
}
