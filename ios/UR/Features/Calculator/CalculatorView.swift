import SwiftUI

struct SupportView: View {
    let repository: any RatesRepository
    let api: any APIClient

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                URPageTitle(title: "الدعم والمعلومات", subtitle: "نساعدك على فهم الأسعار", symbol: "headphones")
                NavigationLink { RatesView(repository: repository).analyticsScreen(.ratesViewed) } label: { SupportRow(title: "دليل الأسعار", detail: "تصفح أسعار الدول والمدن", symbol: "chart.bar.fill", color: URColor.royalBlue) }
                NavigationLink { CalculatorView(repository: repository) } label: { SupportRow(title: "حاسبة العملات", detail: "قارن القيمة بشكل تقديري", symbol: "function", color: URColor.premiumGold) }
                NavigationLink { OfficesView(api: api) } label: { SupportRow(title: "معلومات التواصل", detail: "الدليل العام ومعلومات المراكز", symbol: "info.circle.fill", color: URColor.success) }
                URCard {
                    VStack(alignment: .trailing, spacing: 12) {
                        Text("تحتاج مساعدة مباشرة؟").font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
                        Text("فريق UR جاهز للإجابة عن استفسارات الأسعار والمعلومات العامة.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        HStack(spacing: 10) {
                            Link(destination: URL(string: "https://www.urremit.com/contact")!) { Label("راسلنا", systemImage: "message.fill").frame(maxWidth: .infinity, minHeight: 43).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }
                            Link(destination: URL(string: "https://www.urremit.com/contact")!) { Label("اتصل بنا", systemImage: "phone.fill").frame(maxWidth: .infinity, minHeight: 43).background(URColor.premiumGold, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }
                        }.font(.caption.weight(.bold))
                    }
                }
                HStack(spacing: 9) { Image(systemName: "info.circle"); Text("التطبيق معلوماتي ولا ينفذ أو يعالج أي معاملة مالية.") }
                    .font(.caption).foregroundStyle(URColor.deepNavy.opacity(0.65)).padding(14)
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
    }
}

private struct SupportRow: View {
    let title: String; let detail: String; let symbol: String; let color: Color
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "chevron.left").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) { Text(title).font(.headline.weight(.bold)); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Image(systemName: symbol).font(.system(size: 20, weight: .bold)).foregroundStyle(.white).frame(width: 46, height: 46).background(color, in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(URColor.deepNavy).padding(15).background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline))
    }
}

struct CalculatorView: View {
    let repository: any RatesRepository
    @State private var rates: [Rate] = []
    @State private var selectedRateID: UUID?
    @State private var amount = ""
    @State private var loading = true
    @State private var calculationEventTask: Task<Void, Never>?

    private var selectedRate: Rate? { rates.first { $0.id == selectedRateID } }
    private var result: Decimal? {
        guard let rate = selectedRate, let value = Decimal(string: amount), let exchange = rate.sell ?? rate.buy else { return nil }
        return value * exchange
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                URPageTitle(title: "حاسبة العملات", subtitle: "مقارنة تقديرية حسب آخر سعر", symbol: "function")
                URCard {
                    VStack(alignment: .trailing, spacing: 14) {
                        Text("زوج العملات").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Picker("المسار", selection: $selectedRateID) {
                            Text("اختر المسار").tag(UUID?.none)
                            ForEach(rates) { Text($0.routeNameArabic).tag(Optional($0.id)) }
                        }.pickerStyle(.menu).tint(URColor.deepNavy).frame(maxWidth: .infinity, alignment: .trailing)
                        Divider()
                        Text("المبلغ بالدولار").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        HStack { Text("USD").font(.headline.weight(.black)).foregroundStyle(URColor.premiumGold); TextField("0.00", text: $amount).keyboardType(.decimalPad).font(.title2.weight(.bold)).multilineTextAlignment(.trailing) }
                    }
                }
                if let rate = selectedRate, let result {
                    VStack(spacing: 9) {
                        Text("القيمة التقديرية").font(.caption).foregroundStyle(.white.opacity(0.70))
                        Text(result.formatted(.number.grouping(.automatic))).font(.system(size: 38, weight: .black, design: .rounded)).monospacedDigit()
                        Text(rate.destinationCurrency).font(.headline.weight(.bold)).foregroundStyle(URColor.premiumGold)
                        Divider().overlay(.white.opacity(0.20))
                        HStack { Text((rate.sell ?? rate.buy ?? 0).formatted()); Spacer(); Text("سعر الصرف") }.font(.caption).foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white).padding(20).frame(maxWidth: .infinity).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 18))
                }
                Text("الحسبة معلوماتية وتقريبية فقط، وقد يختلف السعر الفعلي حسب السوق والوقت.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(14)
        }
        .analyticsScreen(.calculatorViewed)
        .onChange(of: amount) { _, _ in
            calculationEventTask?.cancel()
            guard result != nil else { return }
            calculationEventTask = Task {
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                URAnalytics.shared.track(.calculatorUsed)
            }
        }
        .onChange(of: selectedRateID) { old, new in
            guard old != nil, new != nil, !loading else { return }
            URAnalytics.shared.track(.currencySelected)
            if result != nil { URAnalytics.shared.track(.calculatorUsed) }
        }
        .onDisappear { calculationEventTask?.cancel() }
        .background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
        .task { defer { loading = false }; rates = ((try? await repository.loadRates())?.rates ?? []).filter { $0.buy != nil || $0.sell != nil }; selectedRateID = rates.first?.id }
    }
}
