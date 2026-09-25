import SwiftUI

struct MoreView: View {
    let api: any APIClient
    @EnvironmentObject private var auth: URAuthService
    var body: some View {
        List {
            Section {
                NavigationLink { AccountView() } label: {
                    Label(auth.isAuthenticated ? "حسابي" : "تسجيل الدخول الاختياري", systemImage: "person.crop.circle")
                }
            } footer: {
                Text("لا تحتاج إلى حساب لاستخدام الأسعار أو الحاسبة أو التتبع أو المكاتب.")
            }
            Section {
                NavigationLink { OfficesView(api: api) } label: { Label("المكاتب", systemImage: "building.2") }
                NavigationLink { AgentVerificationView(api: api) } label: { Label("تحقق من وكيل", systemImage: "checkmark.shield") }
                NavigationLink { SecurityCenterView() } label: { Label("مركز الأمان", systemImage: "lock.shield") }
            }
            Section {
                Link(destination: URL(string: "https://urremit.com/privacy")!) { Label("سياسة الخصوصية", systemImage: "hand.raised") }
                Link(destination: URL(string: "https://urremit.com/terms")!) { Label("الشروط والأحكام", systemImage: "doc.text") }
                Link(destination: URL(string: "https://urremit.com/contact")!) { Label("الاتصال", systemImage: "phone") }
            }
            Section { LabeledContent("الإصدار", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") }
        }.navigationTitle("more")
    }
}

private struct OfficesView: View {
    let api: any APIClient; @State private var offices: [Office] = []; @State private var failed = false
    var body: some View { List {
        if failed { ContentUnavailableView("تعذر تحميل المكاتب", systemImage: "wifi.exclamationmark") }
        ForEach(offices) { office in URCard {
            Label(office.nameArabic, systemImage: office.verified ? "checkmark.seal.fill" : "building.2").font(.headline)
            Text("\(office.cityArabic)، \(office.countryArabic)"); Text(office.addressArabic).foregroundStyle(.secondary)
            if let phone = office.phone, let url = URL(string: "tel:\(phone)") { Link("اتصال", destination: url) }
        }.listRowSeparator(.hidden) }
    }.listStyle(.plain).navigationTitle("المكاتب").task { do { offices = try await api.offices() } catch { failed = true } } }
}

private struct AgentVerificationView: View {
    let api: any APIClient; @State private var code = ""; @State private var result: AgentVerification?; @State private var loading = false
    var body: some View { Form {
        Section { TextField("رمز الوكيل", text: $code).autocorrectionDisabled(); Button("تحقق") { Task { await verify() } }.disabled(code.count < 4 || loading) }
        if let result { Section("النتيجة") { Label(result.status == "VERIFIED" ? "وكيل معتمد" : result.status, systemImage: result.status == "VERIFIED" ? "checkmark.seal.fill" : "xmark.shield"); if let name = result.tradeName { Text(name) }; if let city = result.city { Text(city.ar) } } }
        Section { Text("لا تسلم أي مبلغ مالي قبل التأكد من أن المكتب أو الوكيل ظاهر كمعتمد داخل تطبيق UR الرسمي.").font(.footnote) }
    }.navigationTitle("تحقق من وكيل") }
    private func verify() async { loading = true; defer { loading = false }; result = try? await api.verifyAgent(code: code) }
}

private struct SecurityCenterView: View {
    var body: some View { List {
        Label("تحقق من اعتماد الوكيل قبل الدفع", systemImage: "checkmark.shield")
        Label("لا تشارك رمز التتبع أو OTP", systemImage: "number.square")
        Label("استخدم قنوات UR المنشورة فقط", systemImage: "link.badge.plus")
        Link("الإبلاغ عن حساب مزيف", destination: URL(string: "https://urremit.com/contact")!)
    }.navigationTitle("مركز الأمان") }
}
