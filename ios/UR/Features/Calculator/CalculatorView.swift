import SwiftUI

struct CalculatorView: View {
    let repository: any RatesRepository
    @State private var rates: [Rate] = []; @State private var selectedRateID: UUID?
    @State private var amount = ""; @State private var loading = true

    private var selectedRate: Rate? { rates.first { $0.id == selectedRateID } }
    private var result: Decimal? {
        guard let rate = selectedRate, let value = Decimal(string: amount), let exchange = rate.sell ?? rate.buy else { return nil }
        return value * exchange
    }

    var body: some View {
        Form {
            Section("الحسبة") {
                Picker("المسار", selection: $selectedRateID) {
                    Text("اختر المسار").tag(UUID?.none)
                    ForEach(rates) { Text($0.routeNameArabic).tag(Optional($0.id)) }
                }
                TextField("المبلغ", text: $amount).keyboardType(.decimalPad).accessibilityLabel("المبلغ المراد حسابه")
            }
            if let rate = selectedRate, let result {
                Section("النتيجة التقديرية") {
                    LabeledContent("سعر الصرف", value: (rate.sell ?? rate.buy ?? 0).formatted())
                    LabeledContent("الاستلام المتوقع", value: result.formatted())
                    Text("هذه حسبة تقديرية وقد يتغير السعر قبل تثبيت العملية مع مكتب UR.").font(.footnote).foregroundStyle(.secondary)
                    Link("تواصل مع مكتب UR لتثبيت السعر", destination: URL(string: "https://urremit.com/contact")!)
                }
            }
            if !loading && rates.isEmpty { ContentUnavailableView("لا توجد أسعار للحساب", systemImage: "function") }
        }
        .navigationTitle("calculator")
        .task { defer { loading = false }; rates = (try? await repository.loadRates())?.rates ?? [] }
    }
}
