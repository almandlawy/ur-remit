import SwiftUI
import UIKit

struct AgentPortalEntryView: View {
    @ObservedObject private var api = URNativeAPI.agent
    @State private var checking = true
    var body: some View {
        Group {
            if checking { ProgressView("التحقق من جلسة الوكيل…") }
            else if api.profile["role"] == "agent" { AgentDashboardView() }
            else { AgentLoginView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(URColor.ivory.ignoresSafeArea())
        .task { do { try await api.refreshProfile() } catch {}; checking = false }
        .navigationTitle("بوابة الوكلاء").navigationBarTitleDisplayMode(.inline)
    }
}

struct AgentJoinView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var officeName = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var whatsapp = ""
    @State private var location = ""
    private let businessType = "حوالات وصرافة"
    @State private var busy = false
    @State private var message = ""
    @FocusState private var officeFocused: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 16) {
                AgentJoinGraphicHero(reduceMotion: reduceMotion) { officeFocused = true }
                VStack(spacing: 12) {
                    field("اسم المكتب", text: $officeName).focused($officeFocused)
                    field("اسم المسؤول", text: $fullName)
                    field("البريد الإلكتروني", text: $email, keyboard: .emailAddress)
                    field("واتساب مع رمز الدولة", text: $whatsapp, keyboard: .phonePad)
                    field("الدولة، المدينة", text: $location)
                    Button(busy ? "جاري الإرسال…" : "إرسال طلب الانضمام") { Task { await submit() } }
                        .buttonStyle(.borderedProminent).tint(URColor.premiumGold).foregroundStyle(URColor.deepNavy).disabled(busy)
                    if !message.isEmpty { Text(message).font(.footnote.weight(.semibold)).foregroundStyle(message.hasPrefix("تم") ? URColor.success : .red) }
                }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
                Text("بعد مراجعة الإدارة وقبول الطلب، تُصدر بيانات الدخول وتُحدد المكاتب والمسارات والحدود بشكل مستقل.").font(.caption).foregroundStyle(.secondary)
            }.padding()
        }.background(URColor.ivory).navigationTitle("انضم كوكيل").navigationBarTitleDisplayMode(.inline)
    }
    private func field(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View { TextField(title, text: text).textFieldStyle(.roundedBorder).keyboardType(keyboard).textInputAutocapitalization(.never) }
    private func submit() async {
        busy = true; message = ""; defer { busy = false }
        do {
            _ = try await URNativeAPI.agent.request("/api/agents", method: "POST", body: ["officeName": officeName, "fullName": fullName, "email": email, "whatsapp": whatsapp, "location": location, "businessType": businessType])
            message = "تم استلام الطلب. ستراجعه الإدارة قبل إنشاء الحساب أو منحه أي صلاحية مالية."
        } catch { message = error.localizedDescription }
    }
}

private struct AgentJoinGraphicHero: View {
    let reduceMotion: Bool
    let startApplication: () -> Void
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                Image("AgentPremiumOffice").resizable().scaledToFill().frame(width: proxy.size.width, height: 230).clipped()
                LinearGradient(colors: [URColor.deepNavy.opacity(0.05), URColor.deepNavy.opacity(0.98)], startPoint: .leading, endPoint: .trailing)
                VStack(alignment: .trailing, spacing: 7) {
                        Text("UR GLOBAL").font(.caption.weight(.black)).tracking(1.1)
                        Text("انضم إلى شبكة وكلاء أور").font(.system(size: 23, weight: .black, design: .rounded)).lineLimit(2).minimumScaleFactor(0.78).multilineTextAlignment(.trailing)
                        Text("قدّم طلبك وتابع حالته من التطبيق").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.84)).lineLimit(2).multilineTextAlignment(.trailing)
                        Button("قدّم طلب الانضمام", action: startApplication)
                            .font(.subheadline.weight(.black)).foregroundStyle(URColor.deepNavy)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(LinearGradient(colors: [Color(red: 0.96, green: 0.78, blue: 0.42), URColor.premiumGold], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 12))
                        NavigationLink("عندك حساب وكيل؟ تسجيل الدخول", destination: AgentPortalEntryView())
                            .font(.caption2.weight(.bold)).foregroundStyle(URColor.premiumGold).underline().lineLimit(1).minimumScaleFactor(0.75)
                }.foregroundStyle(.white)
                    .frame(width: proxy.size.width * 0.56, height: 200)
                    .position(x: proxy.size.width * 0.30, y: 115)
                    .environment(\.layoutDirection, .rightToLeft)
            }.frame(width: proxy.size.width, height: 230).clipped()
                .environment(\.layoutDirection, .leftToRight)
        }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.32)))
        .shadow(color: URColor.deepNavy.opacity(0.22), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("انضم إلى شبكة أور. طلب اعتماد مكتب جديد")
    }
}

private struct AgentLoginView: View {
    @ObservedObject private var api = URNativeAPI.agent
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message = ""
    @State private var recoverySent = false
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                agentHero(title: "دخول الوكلاء", subtitle: "استخدم حساب الموقع نفسه", symbol: "person.badge.key.fill")
                VStack(spacing: 13) {
                    TextField("البريد أو اسم المستخدم", text: $username).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("كلمة المرور", text: $password).textFieldStyle(.roundedBorder).submitLabel(.done)
                    Button(busy ? "جاري الدخول…" : "دخول آمن") { Task { await login() } }.buttonStyle(.borderedProminent).tint(URColor.deepNavy).disabled(busy || username.isEmpty || password.isEmpty)
                    Button(recoverySent ? "تم إرسال التعليمات إن كان الحساب مسجلاً" : "استعادة الحساب") { Task { await recover() } }.font(.footnote.weight(.bold)).disabled(username.isEmpty || recoverySent)
                    if !message.isEmpty { Text(message).font(.footnote.weight(.semibold)).foregroundStyle(.red).multilineTextAlignment(.center) }
                }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
                NavigationLink("مكتب جديد؟ أرسل طلب انضمام", destination: AgentJoinView()).font(.subheadline.weight(.bold))
            }.padding()
        }
    }
    private func login() async {
        busy = true; message = ""; defer { busy = false }
        do {
            let result = try await api.request("/api/auth/login", method: "POST", body: ["username": username, "password": password])
            if result["requiresMfa"] as? Bool == true { throw NSError(domain: "UR", code: 1, userInfo: [NSLocalizedDescriptionKey: "هذا الحساب يتطلب تحققاً إضافياً. راجع الإدارة."]) }
            try await api.refreshProfile()
            guard api.profile["role"] == "agent" else { await api.logout(); throw NSError(domain: "UR", code: 2, userInfo: [NSLocalizedDescriptionKey: "الحساب ليس حساب وكيل. استخدم المدخل الصحيح."]) }
        } catch { message = error.localizedDescription }
    }
    private func recover() async { do { _ = try await api.request("/api/auth/recovery", method: "POST", body: ["email": username]); recoverySent = true } catch { message = error.localizedDescription } }
}

private struct AgentDashboardView: View {
    @ObservedObject private var api = URNativeAPI.agent
    @State private var data: [String: Any] = [:]
    @State private var busy = false
    @State private var message = ""
    private var wallet: [String: Any] { data["wallet"] as? [String: Any] ?? [:] }
    private var op: [String: Any] { data["operator"] as? [String: Any] ?? [:] }
    private var offices: [[String: Any]] { data["offices"] as? [[String: Any]] ?? [] }
    private var transfers: [[String: Any]] { data["transfers"] as? [[String: Any]] ?? [] }
    private var vaults: [[String: Any]] { data["vaults"] as? [[String: Any]] ?? [] }
    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 15) {
                agentHero(title: text(op,"full_name", fallback: api.profile["fullName"] ?? "مكتب أور"), subtitle: "لوحة عمل الوكيل", symbol: "building.columns.fill")
                if !message.isEmpty { Text(message).foregroundStyle(.red).font(.footnote) }
                HStack(spacing: 10) {
                    metric("الرصيد المتاح", text(wallet,"balance_usdt", fallback: "—") + " USD", .blue)
                    metric("المحجوز", text(wallet,"locked_usdt", fallback: "—") + " USD", .orange)
                }
                metric("الصندوق النقدي", vaults.isEmpty ? "غير مُدار أو تعذر الجلب" : vaults.map { text($0,"balance_micros") }.joined(separator: " · "), .purple)
                HStack(spacing: 8) {
                    NavigationLink { AgentStatementView(rows: data["ledger"] as? [[String: Any]] ?? []) } label: { dashboardButton("كشف الحساب", "list.bullet.rectangle") }
                    NavigationLink { AgentTopupView() } label: { dashboardButton("طلب تعزيز", "arrow.up.circle") }
                    NavigationLink { AgentHelpView() } label: { dashboardButton("الدعم", "headphones") }
                }
                VStack(alignment: .trailing, spacing: 9) {
                    Text("المكاتب المسموحة").font(.headline.weight(.black))
                    if offices.isEmpty { Text("لم تحدد الإدارة مكاتب مسموحة لهذا الحساب.").foregroundStyle(.secondary) }
                    ForEach(offices.indices, id: \.self) { i in Text("\(text(offices[i],"name")) · \(text(offices[i],"city"))، \(text(offices[i],"country"))").font(.subheadline.weight(.semibold)) }
                }.card()
                VStack(alignment: .trailing, spacing: 9) {
                    Text("آخر العمليات").font(.headline.weight(.black))
                    if transfers.isEmpty { Text("لا توجد عمليات ضمن صلاحياتك.").foregroundStyle(.secondary) }
                    ForEach(transfers.indices, id: \.self) { i in HStack { Text(text(transfers[i],"amount") + " " + text(transfers[i],"currency")); Spacer(); VStack(alignment: .trailing) { Text(text(transfers[i],"status")).font(.caption.weight(.bold)); Text(text(transfers[i],"tracking_code")).font(.caption2.monospaced()) } } }
                }.card()
                Button("تسجيل الخروج") { Task { await api.logout() } }.foregroundStyle(.red)
            }.padding()
        }.refreshable { await load() }.task { await load() }
    }
    private func load() async { guard !busy else { return }; busy = true; defer { busy = false }; do { data = try await api.request("/api/native/agent-portal"); message = "" } catch { message = error.localizedDescription } }
    private func metric(_ title: String, _ value: String, _ color: Color) -> some View { VStack(alignment: .trailing, spacing: 5) { Text(title).font(.caption.weight(.bold)); Text(value).font(.title3.weight(.black)).monospacedDigit() }.foregroundStyle(color).padding(15).frame(maxWidth: .infinity, alignment: .trailing).background(.white, in: RoundedRectangle(cornerRadius: 17)) }
    private func dashboardButton(_ title: String, _ icon: String) -> some View { VStack(spacing: 6) { Image(systemName: icon); Text(title).font(.caption.weight(.bold)) }.foregroundStyle(URColor.deepNavy).frame(maxWidth: .infinity, minHeight: 66).background(.white, in: RoundedRectangle(cornerRadius: 15)) }
}

private struct AgentStatementView: View { let rows: [[String: Any]]; var body: some View { List { if rows.isEmpty { Text("لا توجد حركات") }; ForEach(rows.indices,id:\.self) { i in VStack(alignment:.trailing) { Text(text(rows[i],"type")).font(.headline); Text(text(rows[i],"amount_usdt") + " USD · الرصيد " + text(rows[i],"balance_after")).monospacedDigit(); Text(text(rows[i],"reference")).font(.caption).foregroundStyle(.secondary) } } }.navigationTitle("كشف الحساب") } }
private struct AgentTopupView: View {
    @State private var amount = ""
    @State private var reference = ""
    @State private var message = ""
    var body: some View {
        Form {
            Section("طلب تعزيز") {
                TextField("المبلغ USD", text: $amount).keyboardType(.decimalPad)
                TextField("مرجع الإثبات", text: $reference)
                Button("إرسال للمراجعة") {
                    Task {
                        do {
                            _ = try await URNativeAPI.agent.request("/api/topups", method: "POST", body: ["amountUsdt": amount, "method": "manual", "reference": reference])
                            message = "تم إرسال الطلب للمراجعة؛ لم يزد الرصيد بعد."
                        } catch { message = error.localizedDescription }
                    }
                }
            }
            if !message.isEmpty { Text(message) }
        }.navigationTitle("طلب تعزيز")
    }
}
private struct AgentHelpView: View { var body: some View { List { Section("دعم الوكلاء") { Text("تظهر قنوات الدعم وساعات العمل المعتمدة من إعدادات الإدارة. لا نعد بزمن استجابة غير منشور."); Link("فتح مركز دعم أور", destination: URL(string:"https://urremit.com/contact")!) } }.navigationTitle("الدعم") } }

private func agentHero(title: String, subtitle: String, symbol: String) -> some View { HStack(spacing: 14) { Spacer(); VStack(alignment: .trailing, spacing: 5) { Text(title).font(.title2.weight(.black)); Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.78)) }; Image(systemName: symbol).font(.largeTitle).foregroundStyle(URColor.premiumGold) }.foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, minHeight: 125).background(LinearGradient(colors:[URColor.deepNavy,URColor.royalBlue],startPoint:.topTrailing,endPoint:.bottomLeading),in:RoundedRectangle(cornerRadius:24)) }
private func text(_ row: [String: Any], _ key: String, fallback: String = "—") -> String { guard let value=row[key], !(value is NSNull) else { return fallback }; return String(describing:value) }
private extension View { func card() -> some View { padding(16).frame(maxWidth:.infinity,alignment:.trailing).background(.white,in:RoundedRectangle(cornerRadius:18)) } }
