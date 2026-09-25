import SwiftUI

struct TrackingView: View {
    let api: any APIClient
    @State private var reference = ""; @State private var result: TransferTracking?
    @State private var message = ""; @State private var loading = false

    var body: some View {
        Form {
            Section("رقم الحوالة") {
                TextField("UR-XXXXXXXX", text: $reference).textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button(loading ? "جارٍ التحقق…" : "تتبع الحوالة") { Task { await track() } }.disabled(loading || !validReference)
            }
            if let result {
                Section("الحالة") {
                    Label(statusLabel(result.status), systemImage: statusSymbol(result.status)).font(.headline)
                    LabeledContent("من", value: result.origin); LabeledContent("إلى", value: result.destination)
                    LabeledContent("آخر تحديث", value: result.lastUpdate.formatted(date: .abbreviated, time: .shortened))
                    if result.status == "HELD" { Text("الحوالة قيد المراجعة. يرجى التواصل مع الدعم إذا استمرت الحالة.") }
                }
            }
            if !message.isEmpty { Text(message).foregroundStyle(.secondary).accessibilityLabel(message) }
            Section { Text("لا تشارك رقم التتبع أو رمز الاستلام مع أي شخص غير مخول.").font(.footnote) }
        }.navigationTitle("tracking")
    }

    private var validReference: Bool { reference.uppercased().range(of: #"^UR-[A-Z0-9]{8}$"#, options: .regularExpression) != nil }
    private func track() async {
        loading = true; message = ""; result = nil; defer { loading = false }
        do { result = try await api.track(reference: reference.uppercased()) }
        catch { message = "تعذر العثور على معلومات التتبع أو الاتصال بالخدمة." }
    }
    private func statusLabel(_ value: String) -> String { ["ISSUED":"تم الإصدار","ASSIGNED":"تم التعيين","READY_FOR_PICKUP":"جاهزة للاستلام","COMPLETED":"مكتملة","CANCELLED":"ملغاة","REFUNDED":"مستردة","HELD":"قيد المراجعة"][value] ?? value }
    private func statusSymbol(_ value: String) -> String { value == "COMPLETED" ? "checkmark.seal.fill" : value == "HELD" ? "exclamationmark.shield.fill" : "clock.badge.checkmark" }
}
