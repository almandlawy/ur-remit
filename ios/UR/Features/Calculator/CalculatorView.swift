import SwiftUI

struct SupportView: View {
    let repository: any RatesRepository
    let api: any APIClient

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    LinearGradient(colors: [URColor.royalBlue, URColor.deepNavy], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(URColor.premiumGold.opacity(0.16)).frame(width: 150, height: 150).offset(x: -110, y: -55)
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack { Spacer(); URBrandLogo(size: 38) }
                        Spacer()
                        Text("الدعم والمعلومات").font(.title2.weight(.black))
                        Text("إجابات واضحة ومساعدة مباشرة من فريق أور").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.78))
                    }.padding(15)
                }
                .foregroundStyle(.white).frame(height: 142)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(URColor.premiumGold.opacity(0.35)))
                .shadow(color: URColor.deepNavy.opacity(0.16), radius: 12, y: 6)
                NavigationLink { RatesView(repository: repository) } label: { SupportRow(title: "دليل الأسعار", detail: "تصفح أسعار الدول والمدن", symbol: "chart.bar.fill", color: URColor.royalBlue) }
                NavigationLink { CalculatorView(repository: repository) } label: { SupportRow(title: "حاسبة العملات", detail: "قارن القيمة بشكل تقديري", symbol: "function", color: URColor.premiumGold) }
                NavigationLink { OfficesView(api: api) } label: { SupportRow(title: "معلومات التواصل", detail: "الدليل العام ومعلومات المراكز", symbol: "info.circle.fill", color: URColor.success) }
                URCard {
                    VStack(alignment: .trailing, spacing: 12) {
                        Text("تحتاج مساعدة مباشرة؟").font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
                        Text("فريق UR جاهز للإجابة عن استفسارات الأسعار والمعلومات العامة.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        HStack(spacing: 10) {
                            Link(destination: URL(string: "https://wa.me/971551754032?text=%D9%85%D8%B1%D8%AD%D8%A8%D8%A7%D9%8B%20%D8%AF%D8%B9%D9%85%20UR%20Global")!) { Label("واتساب", systemImage: "message.fill").frame(maxWidth: .infinity, minHeight: 43).background(URColor.success, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }
                            Link(destination: URL(string: "https://urremit.com/contact")!) { Label("مركز الدعم", systemImage: "headphones").frame(maxWidth: .infinity, minHeight: 43).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }
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
    @State private var isReverse = false

    private var selectedRate: Rate? { rates.first { $0.id == selectedRateID } }
    private var result: Decimal? {
        guard let rate = selectedRate, let value = Decimal(string: amount), let exchange = rate.sell ?? rate.buy else { return nil }
        return isReverse ? value / exchange : value * exchange
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
                        HStack {
                            Button { withAnimation { isReverse.toggle(); amount = "" } } label: {
                                Label("تبديل", systemImage: "arrow.up.arrow.down.circle.fill")
                            }.buttonStyle(.bordered).tint(URColor.royalBlue)
                            Spacer()
                            Text(isReverse ? "المبلغ بالعملة المحلية" : "المبلغ بالدولار").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        }
                        HStack { Text(isReverse ? (selectedRate?.destinationCurrency ?? "LOCAL") : "USD").font(.headline.weight(.black)).foregroundStyle(URColor.premiumGold); TextField("0.00", text: $amount).keyboardType(.decimalPad).font(.title2.weight(.bold)).multilineTextAlignment(.trailing) }
                    }
                }
                if let rate = selectedRate, let result {
                    VStack(spacing: 9) {
                        Text("القيمة التقديرية").font(.caption).foregroundStyle(.white.opacity(0.70))
                        Text(result.formatted(.number.grouping(.automatic))).font(.system(size: 38, weight: .black, design: .rounded)).monospacedDigit()
                        Text(isReverse ? "USD" : rate.destinationCurrency).font(.headline.weight(.bold)).foregroundStyle(URColor.premiumGold)
                        Divider().overlay(.white.opacity(0.20))
                        HStack { Text((rate.sell ?? rate.buy ?? 0).formatted()); Spacer(); Text("سعر الصرف") }.font(.caption).foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white).padding(20).frame(maxWidth: .infinity).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 18))
                }
                Text("الحسبة معلوماتية وتقريبية فقط، وقد يختلف السعر الفعلي حسب السوق والوقت.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
        .task { defer { loading = false }; rates = ((try? await repository.loadRates())?.rates ?? []).filter { $0.buy != nil || $0.sell != nil }; selectedRateID = rates.first?.id }
    }
}
