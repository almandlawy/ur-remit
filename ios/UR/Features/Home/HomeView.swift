import SwiftUI

struct HomeView: View {
    let repository: any RatesRepository
    let api: any APIClient
    @State private var heroRate: Rate?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                homeHeader
                welcomeCard
                sectionTitle("مكتب الصيرفة", subtitle: "العملات الرئيسية بتجربة بصرية فاخرة")
                CurrencyDeskShowcase()
                sectionTitle("معلوماتك السريعة", subtitle: "الأسعار وأدوات المقارنة في مكان واحد")
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                    NavigationLink { CalculatorView(repository: repository) } label: {
                        QuickService(title: "حاسبة العملات", subtitle: "قارن القيمة تقديريًا", symbol: "function", color: URColor.premiumGold)
                    }
                    NavigationLink { RatesView(repository: repository).analyticsScreen(.ratesViewed) } label: {
                        QuickService(title: "أسعار السوق", subtitle: "تصفح كل الأسعار", symbol: "chart.line.uptrend.xyaxis", color: URColor.royalBlue)
                    }
                    NavigationLink { OfficesView(api: api) } label: {
                        QuickService(title: "دليل المعلومات", subtitle: "بيانات التواصل العامة", symbol: "mappin.and.ellipse", color: .teal)
                    }
                    NavigationLink { SecurityCenterView() } label: {
                        QuickService(title: "عن الأسعار", subtitle: "معلومات وتنبيهات مهمة", symbol: "info.circle.fill", color: URColor.success)
                    }
                }
                sectionTitle("سعر اليوم", subtitle: "الدولار الأمريكي مقابل الدينار العراقي")
                liveRateCard
                safetyCard
            }
            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 18)
        }
        .analyticsScreen(.homeViewed)
        .background(URColor.ivory.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard heroRate == nil else { return }
            heroRate = (try? await repository.loadRates())?.rates.first { $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD" }
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 10) {
            Button(action: {}) { Image(systemName: "bell").frame(width: 40, height: 40).background(.white, in: Circle()).overlay(Circle().stroke(URColor.hairline)) }
            Button(action: {}) { Label("العربية", systemImage: "globe").font(.subheadline.weight(.bold)).padding(.horizontal, 13).frame(height: 40).background(.white, in: Capsule()).overlay(Capsule().stroke(URColor.hairline)) }
            Spacer()
            VStack(alignment: .trailing, spacing: -2) {
                HStack(spacing: 5) { Text("UR").font(.system(size: 31, weight: .black)); Rectangle().fill(URColor.premiumGold).frame(width: 1, height: 25); Text("أور").font(.system(size: 25, weight: .black)) }
                Text("لأسعار العملات العالمية").font(.caption2.weight(.bold))
            }
        }
        .foregroundStyle(URColor.deepNavy).environment(\.layoutDirection, .leftToRight)
    }

    private var welcomeCard: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(colors: [Color(red: 0.02, green: 0.20, blue: 0.34), URColor.deepNavy], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image("DubaiSkyline").resizable().scaledToFit().opacity(0.22).offset(y: 18)
            VStack(alignment: .trailing, spacing: 8) {
                Text("معكم في كل وجهة").font(.title2.weight(.black))
                Text("أسعار صرف ومعلومات تحويلات عالمية بين يديك").font(.subheadline).foregroundStyle(.white.opacity(0.78)).multilineTextAlignment(.trailing)
                HStack(spacing: 6) { Circle().fill(.green).frame(width: 7, height: 7); Text("الأسعار متاحة الآن").font(.caption.weight(.semibold)) }
                HStack(spacing: 8) {
                    NavigationLink { RatesView(repository: repository).analyticsScreen(.ratesViewed) } label: {
                        Label("الأسعار", systemImage: "chart.bar.fill").frame(maxWidth: .infinity, minHeight: 36).background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
                    }
                    NavigationLink { CalculatorView(repository: repository) } label: {
                        Label("حاسبة العملات", systemImage: "function").frame(maxWidth: .infinity, minHeight: 36).background(URColor.premiumGold, in: RoundedRectangle(cornerRadius: 10))
                    }
                }.font(.caption.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .trailing).padding(18)
        }
        .foregroundStyle(.white).frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(URColor.premiumGold.opacity(0.45)))
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        HStack { Spacer(); VStack(alignment: .trailing, spacing: 1) { Text(title).font(.headline.weight(.black)); Text(subtitle).font(.caption).foregroundStyle(.secondary) } }
            .foregroundStyle(URColor.deepNavy).padding(.top, 2)
    }

    private var liveRateCard: some View {
        URCard {
            HStack(spacing: 14) {
                Text("🇺🇸").font(.system(size: 35))
                VStack(alignment: .leading, spacing: 2) { Text("USD / IQD").font(.caption).foregroundStyle(.secondary); Text("الدولار ← الدينار العراقي").font(.subheadline.weight(.bold)) }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text((heroRate?.sell ?? 1573).formatted(.number.grouping(.automatic))).font(.title2.weight(.black)).monospacedDigit().foregroundStyle(URColor.deepNavy)
                    Text("سعر البيع").font(.caption2).foregroundStyle(.secondary)
                }
            }.environment(\.layoutDirection, .leftToRight)
        }
    }

    private var safetyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill").font(.title2).foregroundStyle(URColor.success)
            VStack(alignment: .trailing, spacing: 2) { Text("معلومة مهمة").font(.subheadline.weight(.bold)); Text("الأسعار إرشادية وقد تتغير حسب السوق والوقت.").font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }
        .environment(\.layoutDirection, .rightToLeft).padding(14).background(URColor.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct CurrencyDeskShowcase: View {
    private let currencies = [
        ("DollarStack", "الدولار", "USD", Color(red: 0.02, green: 0.20, blue: 0.34)),
        ("PoundStack", "الباوند", "GBP", Color(red: 0.23, green: 0.10, blue: 0.17)),
        ("EuroStack", "اليورو", "EUR", Color(red: 0.10, green: 0.17, blue: 0.34))
    ]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(currencies, id: \.1) { item in
                GeometryReader { proxy in
                    ZStack(alignment: .bottomTrailing) {
                        LinearGradient(colors: [item.3.opacity(0.86), URColor.deepNavy], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(item.0)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: 104)
                            .clipped()
                            .opacity(0.83)
                        LinearGradient(colors: [.clear, URColor.deepNavy.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .trailing, spacing: 0) { Text(item.1).font(.caption.weight(.black)); Text(item.2).font(.caption2.weight(.bold)).foregroundStyle(URColor.premiumGold) }.padding(9)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(URColor.premiumGold.opacity(0.45)))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 104)
            }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}

private struct QuickService: View {
    let title: String; let subtitle: String; let symbol: String; let color: Color
    var body: some View {
        VStack(alignment: .trailing, spacing: 9) {
            Image(systemName: symbol).font(.system(size: 21, weight: .bold)).foregroundStyle(.white).frame(width: 42, height: 42).background(color, in: RoundedRectangle(cornerRadius: 13))
            Text(title).font(.subheadline.weight(.bold)).foregroundStyle(URColor.deepNavy)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 115, alignment: .trailing).padding(14).background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline))
    }
}
