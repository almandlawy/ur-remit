import SwiftUI

struct TrackingView: View {
    let api: any APIClient
    @State private var reference = ""
    @State private var result: TransferTracking?
    @State private var message = ""
    @State private var loading = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                URPageTitle(title: "تتبع الحوالة", subtitle: "تابع حالة حوالتك بأمان", symbol: "shippingbox.fill")
                VStack(spacing: 14) {
                    Image(systemName: "location.magnifyingglass").font(.system(size: 38, weight: .bold)).foregroundStyle(URColor.premiumGold)
                    Text("أدخل رقم الحوالة").font(.title3.weight(.black)).foregroundStyle(URColor.deepNavy)
                    Text("ستجده في إيصال UR ويبدأ عادةً بـ UR-").font(.caption).foregroundStyle(.secondary)
                    TextField("UR-XXXXXXXX", text: $reference)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled().multilineTextAlignment(.center)
                        .font(.title3.weight(.bold)).padding().background(URColor.ivory, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(URColor.hairline))
                    Button(loading ? "جارٍ التحقق…" : "تتبع الحوالة") { Task { await track() } }.buttonStyle(URPrimaryButtonStyle()).disabled(loading || !validReference)
                }
                .padding(18).background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(URColor.hairline))

                if let result {
                    URCard {
                        VStack(alignment: .trailing, spacing: 12) {
                            Label(statusLabel(result.status), systemImage: statusSymbol(result.status)).font(.headline.weight(.black)).foregroundStyle(result.status == "COMPLETED" ? URColor.success : URColor.royalBlue)
                            Divider()
                            detail("من", result.origin); detail("إلى", result.destination)
                            detail("آخر تحديث", result.lastUpdate.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                if !message.isEmpty { Label(message, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary).padding() }
                Label("لا تشارك رقم التتبع أو رمز الاستلام إلا مع الشخص المخوّل.", systemImage: "lock.shield.fill").font(.caption).foregroundStyle(URColor.deepNavy.opacity(0.66)).padding(14)
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ label: String, _ value: String) -> some View { HStack { Text(value).foregroundStyle(URColor.deepNavy); Spacer(); Text(label).foregroundStyle(.secondary) }.font(.subheadline) }
    private var validReference: Bool { reference.uppercased().range(of: #"^UR-[A-Z0-9]{8}$"#, options: .regularExpression) != nil }
    private func track() async { loading = true; message = ""; result = nil; defer { loading = false }; do { result = try await api.track(reference: reference.uppercased()) } catch { message = "تعذر العثور على معلومات التتبع أو الاتصال بالخدمة." } }
    private func statusLabel(_ value: String) -> String { ["ISSUED":"تم الإصدار","ASSIGNED":"تم التعيين","READY_FOR_PICKUP":"جاهزة للاستلام","COMPLETED":"مكتملة","CANCELLED":"ملغاة","REFUNDED":"مستردة","HELD":"قيد المراجعة"][value] ?? value }
    private func statusSymbol(_ value: String) -> String { value == "COMPLETED" ? "checkmark.seal.fill" : value == "HELD" ? "exclamationmark.shield.fill" : "clock.badge.checkmark" }
}
