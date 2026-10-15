import SwiftUI
import Charts

struct RatesView: View {
    @StateObject private var model: RatesViewModel
    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.openURL) private var openURL
    @State private var collapsedSections: Set<String> = []

    init(repository: any RatesRepository) { _model = StateObject(wrappedValue: RatesViewModel(repository: repository)) }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(max((geometry.size.width / 430) * 0.88, 0.78), 1.0)
            Group {
                switch model.state {
                case .idle, .loading: RatesSkeletonView()
                case .loaded(let snapshot): content(snapshot, scale: scale)
                case .failed:
                    ContentUnavailableView { Label("تعذر تحميل الأسعار", systemImage: "exclamationmark.triangle") } actions: {
                        Button("إعادة المحاولة") { Task { await model.load() } }
                    }
                }
            }
        }
        .background(Palette.ivory.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { if case .idle = model.state { await model.load() } }
    }

    private func content(_ snapshot: RatesSnapshot, scale: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 6 * scale) {
                BrandHeader(scale: scale)
                FeaturedServicesStrip(rates: featuredRates(snapshot.rates), scale: scale)
                HStack(spacing: 6) {
                    Image(systemName: "banknote.fill")
                    Text("العمولة محسوبة لكل 10,000$")
                }
                .font(.system(size: 10 * scale, weight: .bold))
                .foregroundStyle(Palette.gold)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 4)
                HeroRateCard(rate: snapshot.rates.first { $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD" }, isCached: snapshot.isFromCache, fetchedAt: snapshot.fetchedAt, scale: scale)
                ForEach(orderedSections(snapshot.rates), id: \.title) { section in
                    RateSectionCard(
                        section: section,
                        collapsed: collapsedSections.contains(section.title),
                        scale: scale,
                        favoriteIDs: favorites.favoriteIDs,
                        onToggleFavorite: { favorites.toggle($0) }
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            if collapsedSections.contains(section.title) { collapsedSections.remove(section.title) }
                            else { collapsedSections.insert(section.title) }
                        }
                    }
                }
                WhatsAppSupportButton(scale: scale) {
                    guard let url = URL(string: "https://wa.me/971551754032?text=%D9%85%D8%B1%D8%AD%D8%A8%D8%A7%D9%8B%20%D8%AF%D8%B9%D9%85%20UR%20Global") else { return }
                    openURL(url)
                }
            }
            .padding(.horizontal, 11 * scale).padding(.top, 2).padding(.bottom, 100 * scale)
        }
        .refreshable { await model.load() }
    }

    private func featuredRates(_ rates: [Rate]) -> [Rate] {
        let brandWords = ["المشرق", "Mashreq", "ويسترن", "Western", "موني", "MoneyGram"]
        return rates.filter { rate in
            rate.isFeatured == true || brandWords.contains { rate.routeNameArabic.localizedCaseInsensitiveContains($0) || rate.routeNameEnglish.localizedCaseInsensitiveContains($0) }
        }
        .sorted { ($0.categoryOrder ?? 999) < ($1.categoryOrder ?? 999) }
    }

    private func orderedSections(_ rates: [Rate]) -> [DisplaySection] {
        let featuredIDs = Set(featuredRates(rates).map(\.id))
        let sections = makeSections(rates.filter { !featuredIDs.contains($0.id) })
        return sections.filter { !$0.title.contains("العراق") } + sections.filter { $0.title.contains("العراق") }
    }

    private func makeSections(_ rates: [Rate]) -> [DisplaySection] {
        let visible = rates.filter { !($0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD") }

        // ترتيب حسب category إذا متوفر، وإلا fallback على القائمة اليدوية
        if visible.contains(where: { $0.category != nil && $0.category != "" }) {
            return makeSectionsFromCategories(visible)
        }

        let definitions: [(String, String, [String])] = [
            ("العراق — المدن الرئيسية", "🇮🇶", ["بغداد", "أربيل", "السليمانية", "البصرة"]),
            ("بقية مدن العراق", "🗺️", ["دهوك", "الموصل", "زاخو", "كركوك", "تكريت", "كربلاء", "النجف", "الناصرية", "العمارة", "الكوت", "الحلة", "الديوانية"]),
            ("الخليج", "🏙️", ["السعودية", "قطر", "دبي", "الكويت", "سلطنة عمان", "البحرين"]),
            ("إيران وتركيا", "🕌", ["طهران", "مشهد", "قم", "تومان", "تركيا"]),
            ("أوروبا وكندا", "🏛️", ["فرنسا", "بريطانيا", "كندا", "ألمانيا", "إيطاليا", "كرواتيا"]),
            ("الدول العربية", "🌍", ["الأردن", "لبنان", "مصر"]),
            ("التحويلات العالمية", "💸", ["ويسترن يونين", "Western Union", "موني غرام", "MoneyGram", "ويو بنك", "Wio", "المشرق", "Mashreq"]),
            ("بنوك الإمارات", "🏦", ["بنك دبي", "بنك أبو ظبي الإسلامي", "ADIB"]),
            ("الهند", "🇮🇳", ["الهند"]),
            ("أسعار دولية", "🌐", ["الحوالات البنكية", "الصين"])
        ]
        var used = Set<UUID>()
        var sections: [DisplaySection] = definitions.compactMap { title, icon, names in
            let matched = names.compactMap { name in
                visible.first { !used.contains($0.id) && $0.routeNameArabic.contains(name) }
            }.map { rate -> DisplayRow in
                used.insert(rate.id); return DisplayRow(rate: rate)
            }
            return matched.isEmpty ? nil : DisplaySection(title: title, icon: icon, rows: matched)
        }
        let remaining = visible.filter { !used.contains($0.id) }.map(DisplayRow.init(rate:))
        if !remaining.isEmpty { sections.append(.init(title: "أسعار أخرى", icon: "✨", rows: remaining)) }
        return sections
    }

    private func makeSectionsFromCategories(_ rates: [Rate]) -> [DisplaySection] {
        let categoryNames: [String: (String, String)] = [
            "iraq": ("العراق", "🇮🇶"),
            "gulf": ("الخليج", "🏙️"),
            "iran_turkey": ("إيران وتركيا", "🕌"),
            "europe": ("أوروبا وكندا", "🏛️"),
            "arab": ("الدول العربية", "🌍"),
            "transfers": ("التحويلات العالمية", "💸"),
            "uae_banks": ("بنوك الإمارات", "🏦"),
            "india": ("الهند", "🇮🇳"),
            "international": ("أسعار دولية", "🌐"),
            "other": ("أسعار أخرى", "✨")
        ]

        let grouped = Dictionary(grouping: rates) { $0.category ?? "other" }

        let sortedCategories: [String] = grouped.keys.sorted { a, b in
                let orderA = rates.first { ($0.category ?? "other") == a }?.categoryOrder ?? 999
                let orderB = rates.first { ($0.category ?? "other") == b }?.categoryOrder ?? 999
                return orderA < orderB
            }
        var sections: [DisplaySection] = []
        for category in sortedCategories {
            let categoryRates: [Rate] = grouped[category] ?? []
            let sortedRates = categoryRates.sorted { ($0.categoryOrder ?? 999) < ($1.categoryOrder ?? 999) }
            let rows: [DisplayRow] = sortedRates.map { DisplayRow(rate: $0) }
            guard !rows.isEmpty else { continue }
            let meta: (String, String) = categoryNames[category] ?? (category, "✨")
            sections.append(DisplaySection(title: meta.0, icon: meta.1, rows: rows))
        }
        let nonIraq: [DisplaySection] = sections.filter { $0.title != "العراق" }
        let iraq: [DisplaySection] = sections.filter { $0.title == "العراق" }
        return nonIraq + iraq
    }
}

private enum Palette {
    static let navy = URColor.deepNavy
    static let blue = URColor.royalBlue
    static let gold = URColor.premiumGold
    static let ivory = URColor.ivory
    static let line = URColor.hairline
    static let green = URColor.success
    static let red = URColor.error
}

// ═══════════════════════════════════════════════════
//  Brand Badge — يعرض الشعار الحقيقي أو fallback
// ═══════════════════════════════════════════════════

private struct BrandBadge: View {
    let name: String
    let logoUrl: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let logoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.72, height: size * 0.72)
                    case .failure, .empty:
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
                .frame(width: size, height: size)
                .background(URColor.surface, in: Circle())
                .overlay(Circle().stroke(Palette.gold.opacity(0.25), lineWidth: 1))
            } else {
                fallbackView
            }
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(brandColor.opacity(0.14))
                .frame(width: size, height: size)
            if let text = brandText {
                Text(text)
                    .font(.system(size: size * 0.30, weight: .black, design: .rounded))
                    .foregroundStyle(brandColor)
            } else {
                Text(emoji)
                    .font(.system(size: size * 0.45))
            }
        }
        .overlay(Circle().stroke(brandColor.opacity(0.28), lineWidth: 1))
    }

    private var brandColor: Color {
        if name.contains("ويسترن") || name.contains("Western") { return Color(red: 1.0, green: 0.78, blue: 0.0) }
        if name.contains("موني") || name.contains("Money") { return Color(red: 0.90, green: 0.15, blue: 0.15) }
        if name.contains("ويو") || name.contains("Wio") { return Color(red: 0.55, green: 0.30, blue: 0.95) }
        if name.contains("المشرق") || name.contains("Mashreq") { return Color(red: 0.85, green: 0.10, blue: 0.15) }
        if name.contains("أبو ظبي") || name.contains("ADIB") { return Color(red: 0.60, green: 0.00, blue: 0.40) }
        if name.contains("دبي الإسلامي") { return Color(red: 0.00, green: 0.55, blue: 0.35) }
        if name.contains("بنك دبي") { return Color(red: 0.00, green: 0.35, blue: 0.70) }
        if name.contains("الهند") { return Color(red: 1.0, green: 0.55, blue: 0.0) }
        return Palette.gold
    }

    private var brandText: String? {
        if name.contains("ويسترن") || name.contains("Western") { return "WU" }
        if name.contains("موني") || name.contains("Money") { return "MG" }
        if name.contains("ويو") || name.contains("Wio") { return "WIO" }
        if name.contains("المشرق") || name.contains("Mashreq") { return "MQ" }
        if name.contains("أبو ظبي") || name.contains("ADIB") { return "ADIB" }
        if name.contains("دبي الإسلامي") { return "DIB" }
        if name.contains("بنك دبي") { return "BD" }
        return nil
    }

    private var emoji: String {
        let flags: [(String, String)] = [
            ("السعود", "🇸🇦"), ("قطر", "🇶🇦"), ("دبي", "🇦🇪"), ("الكويت", "🇰🇼"),
            ("عمان", "🇴🇲"), ("البحرين", "🇧🇭"), ("طهران", "🇮🇷"), ("مشهد", "🇮🇷"),
            ("قم", "🇮🇷"), ("تومان", "🇮🇷"), ("تركيا", "🇹🇷"), ("فرنسا", "🇫🇷"),
            ("بريطانيا", "🇬🇧"), ("كندا", "🇨🇦"), ("ألمانيا", "🇩🇪"), ("إيطاليا", "🇮🇹"),
            ("كرواتيا", "🇭🇷"), ("الأردن", "🇯🇴"), ("لبنان", "🇱🇧"), ("مصر", "🇪🇬"),
            ("الصين", "🇨🇳"), ("الحوالات", "🌐"), ("الهند", "🇮🇳")
        ]
        return flags.first { name.contains($0.0) }?.1 ?? "🇮🇶"
    }
}

private struct BrandHeader: View {
    let scale: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("DubaiSkyline").resizable().scaledToFit().frame(maxWidth: .infinity).offset(y: 18 * scale)
            HStack(spacing: 8 * scale) {
                CircleButton(symbol: "bell", scale: scale)
                HStack(spacing: 7 * scale) {
                    Image(systemName: "globe"); Text("العربية").fontWeight(.bold); Image(systemName: "chevron.down").font(.system(size: 10 * scale, weight: .bold))
                }
                .font(.system(size: 14 * scale)).foregroundStyle(Palette.navy).padding(.horizontal, 12 * scale).frame(height: 38 * scale)
                .background(URColor.surface.opacity(0.90), in: Capsule()).overlay(Capsule().stroke(Palette.line))
            }
            .environment(\.layoutDirection, .leftToRight).offset(x: 4 * scale, y: 7 * scale)
            VStack(alignment: .trailing, spacing: -1) {
                HStack(spacing: 5 * scale) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("أور جلوبال").font(.system(size: 21 * scale, weight: .black))
                        Text("UR GLOBAL").font(.system(size: 7 * scale, weight: .black)).tracking(0.7)
                    }
                    URBrandLogo(size: 38 * scale)
                }
                Text("لأسعار العملات العالمية").font(.system(size: 10 * scale, weight: .bold))
                Text("GLOBAL REMITTANCES").font(.system(size: 6.5 * scale, weight: .bold)).tracking(0.8)
            }
            .foregroundStyle(Palette.navy).frame(maxWidth: .infinity, alignment: .trailing).offset(x: -2 * scale, y: 1 * scale)
            VStack(alignment: .leading, spacing: 1 * scale) {
                Text("معكم في كل وجهة").font(.system(size: 20 * scale, weight: .black))
                Text("أموالك تصل أبعد في كل مكان").font(.system(size: 13 * scale, weight: .medium))
                Text("WITH YOU EVERYWHERE").font(.system(size: 9 * scale, weight: .bold)).tracking(1.25 * scale).foregroundStyle(Palette.gold)
            }
            .foregroundStyle(Palette.navy).offset(x: 4 * scale, y: 66 * scale)
            VStack(spacing: 0) {
                Text("ثقة\nتربط\nالعالم").font(.system(size: 9 * scale, weight: .bold))
                Text("TRUST\nCONNECTS\nTHE WORLD").font(.system(size: 6.5 * scale, weight: .bold))
            }
            .multilineTextAlignment(.center).foregroundStyle(Palette.navy).frame(maxWidth: .infinity, alignment: .trailing).offset(x: -1 * scale, y: 69 * scale)
        }
        .frame(height: 154 * scale).clipped()
    }
}

private struct CircleButton: View {
    let symbol: String; let scale: CGFloat
    var body: some View {
        Image(systemName: symbol).font(.system(size: 15 * scale, weight: .semibold)).foregroundStyle(Palette.navy)
            .frame(width: 38 * scale, height: 38 * scale).background(URColor.surface.opacity(0.90), in: Circle()).overlay(Circle().stroke(Palette.line))
    }
}

private struct FeaturedServicesStrip: View {
    let rates: [Rate]
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 8 * scale) {
            HStack {
                Text("خدمات مميزة").font(.system(size: 15 * scale, weight: .black))
                Image(systemName: "sparkles").foregroundStyle(Palette.gold)
            }
            .foregroundStyle(Palette.navy)

            if rates.isEmpty {
                HStack(spacing: 8 * scale) {
                    fallbackBrand("المشرق", "MQ", .red)
                    fallbackBrand("Western Union", "WU", .yellow)
                    fallbackBrand("MoneyGram", "MG", .red)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8 * scale) {
                        ForEach(rates) { rate in
                            VStack(alignment: .trailing, spacing: 4 * scale) {
                                HStack(spacing: 7 * scale) {
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(rate.routeNameArabic).font(.system(size: 11 * scale, weight: .black)).lineLimit(1)
                                        Text(rate.destinationCurrency).font(.system(size: 8 * scale, weight: .bold)).foregroundStyle(.secondary)
                                    }
                                    BrandBadge(name: rate.routeNameArabic, logoUrl: rate.logoUrl, size: 35 * scale)
                                }
                                Text(featuredValue(rate)).font(.system(size: 16 * scale, weight: .black, design: .rounded)).monospacedDigit()
                                    .foregroundStyle((rate.feeFixed ?? rate.sell ?? rate.buy ?? 0) < 0 ? Palette.red : Palette.green)
                                Text(rate.feeFixed == nil ? "سعر الصرف" : "لكل 10,000$").font(.system(size: 8 * scale)).foregroundStyle(.secondary)
                            }
                            .frame(width: 126 * scale, height: 88 * scale, alignment: .trailing)
                            .padding(.horizontal, 10 * scale)
                            .background(URColor.surface, in: RoundedRectangle(cornerRadius: 15 * scale))
                            .overlay(RoundedRectangle(cornerRadius: 15 * scale).stroke(Palette.gold.opacity(0.28)))
                        }
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .padding(11 * scale)
        .background(LinearGradient(colors: [Palette.navy.opacity(0.08), Palette.gold.opacity(0.10)], startPoint: .topTrailing, endPoint: .bottomLeading), in: RoundedRectangle(cornerRadius: 18 * scale))
    }

    private func fallbackBrand(_ name: String, _ letters: String, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Text(letters).font(.system(size: 15 * scale, weight: .black)).foregroundStyle(color)
            Text(name).font(.system(size: 8 * scale, weight: .bold)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 56 * scale)
        .background(URColor.surface, in: RoundedRectangle(cornerRadius: 12 * scale))
    }

    private func featuredValue(_ rate: Rate) -> String {
        guard let value = rate.feeFixed ?? rate.sell ?? rate.buy else { return "—" }
        let prefix = rate.feeFixed != nil && value > 0 ? "+" : ""
        return prefix + value.formatted(.number.grouping(.automatic)) + (rate.feeFixed == nil ? "" : "$")
    }
}

private struct WhatsAppSupportButton: View {
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color(red: 0.05, green: 0.68, blue: 0.36))
                Image(systemName: "message.fill").font(.system(size: 25 * scale, weight: .bold)).foregroundStyle(.white)
                Image(systemName: "phone.fill").font(.system(size: 10 * scale, weight: .black)).foregroundStyle(Color(red: 0.05, green: 0.68, blue: 0.36)).offset(y: -1)
            }
            .frame(width: 46 * scale, height: 46 * scale)
            .shadow(color: Color.green.opacity(0.24), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("التواصل مع دعم أور عبر واتساب دبي")
    }
}

private struct SearchBar: View {
    @Binding var query: String; let scale: CGFloat
    var body: some View {
        HStack(spacing: 8 * scale) {
            TextField("ابحث عن دولة أو عملة ...", text: $query).multilineTextAlignment(.trailing).font(.system(size: 13 * scale))
            Image(systemName: "magnifyingglass").font(.system(size: 20 * scale, weight: .medium))
        }
        .environment(\.layoutDirection, .leftToRight).foregroundStyle(Palette.navy.opacity(0.72)).padding(.horizontal, 13 * scale).frame(height: 39 * scale)
        .background(URColor.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: 11 * scale)).overlay(RoundedRectangle(cornerRadius: 11 * scale).stroke(Palette.line))
    }
}

private struct HeroRateCard: View {
    let rate: Rate?; let isCached: Bool; let fetchedAt: Date; let scale: CGFloat
    private var isStale: Bool { rate.map { $0.staleAfter <= Date() } ?? true }
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.blue, Palette.navy], startPoint: .topLeading, endPoint: .bottomTrailing)
            decorativeLines
            VStack(spacing: 8 * scale) {
                HStack(alignment: .top, spacing: 9 * scale) {
                    Text("🇺🇸").font(.system(size: 36 * scale))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("الدولار الأمريكي  ←  الدينار العراقي").font(.system(size: 14 * scale, weight: .bold))
                        Text("USD / IQD").font(.system(size: 9 * scale, weight: .medium)).foregroundStyle(.white.opacity(0.70))
                    }
                    Spacer(minLength: 2)
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(isCached ? "بيانات محفوظة" : isStale ? "بيانات المصدر قديمة" : "من المصدر")
                            Circle().fill(isCached || isStale ? .orange : .green).frame(width: 7 * scale, height: 7 * scale)
                        }
                        Text("تحديث السعر: " + (rate?.sourceTimestamp.formatted(date: .abbreviated, time: .shortened) ?? "—"))
                        Text("آخر جلب: " + fetchedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 7.5 * scale))
                    }.font(.system(size: 9 * scale, weight: .semibold)).foregroundStyle(.white.opacity(0.78))
                }
                HStack(spacing: 0) {
                    value(title: "سعر البيع", number: rate?.sell)
                    Rectangle().fill(.white.opacity(0.22)).frame(width: 1, height: 58 * scale)
                    value(title: "سعر الشراء", number: rate?.buy)
                    Image("DollarStack")
                        .resizable().scaledToFill()
                        .frame(width: 122 * scale, height: 76 * scale)
                        .clipShape(RoundedRectangle(cornerRadius: 8 * scale))
                        .rotationEffect(.degrees(-4))
                }
            }.padding(12 * scale)
        }
        .foregroundStyle(.white).frame(height: 145 * scale).clipShape(RoundedRectangle(cornerRadius: 13 * scale))
        .overlay(RoundedRectangle(cornerRadius: 13 * scale).stroke(Palette.gold.opacity(0.45)))
    }
    private func value(title: String, number: Decimal?) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 12 * scale, weight: .semibold))
            Text(number?.formatted(.number.grouping(.automatic)) ?? "—").font(.system(size: 34 * scale, weight: .black, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7)
            Text("حسب وحدة النشرة المنشورة").font(.system(size: 8.5 * scale)).foregroundStyle(.white.opacity(0.72))
        }.frame(maxWidth: .infinity)
    }
    private var decorativeLines: some View {
        Canvas { context, size in
            var path = Path(); path.move(to: CGPoint(x: size.width * 0.62, y: size.height * 0.78))
            path.addCurve(to: CGPoint(x: size.width, y: size.height * 0.43), control1: CGPoint(x: size.width * 0.73, y: size.height * 0.41), control2: CGPoint(x: size.width * 0.88, y: size.height * 0.72))
            context.stroke(path, with: .color(Palette.gold.opacity(0.75)), lineWidth: 1)
        }
    }
}

private struct DisplayRow: Hashable {
    let id: UUID
    let name: String
    let code: String
    let flag: String
    let amount: Decimal?
    let buy: Decimal?
    let sell: Decimal?
    let sourceCode: String
    let isFee: Bool
    let logoUrl: String?
    let deliverySpeed: String?

    init(rate: Rate) {
        id = rate.id
        name = rate.routeNameArabic
        code = rate.destinationCurrency
        flag = Self.flag(for: rate.routeNameArabic)
        amount = rate.feeFixed ?? rate.sell ?? rate.buy
        buy = rate.buy
        sell = rate.sell
        sourceCode = rate.sourceCurrency
        isFee = rate.feeFixed != nil
        logoUrl = rate.logoUrl
        deliverySpeed = rate.deliverySpeed
    }

    private static func flag(for name: String) -> String {
        let flags: [(String, String)] = [("السعود", "🇸🇦"), ("قطر", "🇶🇦"), ("دبي", "🇦🇪"), ("الكويت", "🇰🇼"), ("عمان", "🇴🇲"), ("البحرين", "🇧🇭"), ("طهران", "🇮🇷"), ("مشهد", "🇮🇷"), ("قم", "🇮🇷"), ("تومان", "🇮🇷"), ("تركيا", "🇹🇷"), ("فرنسا", "🇫🇷"), ("بريطانيا", "🇬🇧"), ("كندا", "🇨🇦"), ("ألمانيا", "🇩🇪"), ("إيطاليا", "🇮🇹"), ("كرواتيا", "🇭🇷"), ("الأردن", "🇯🇴"), ("لبنان", "🇱🇧"), ("مصر", "🇪🇬"), ("الصين", "🇨🇳"), ("الحوالات", "🌐")]
        return flags.first { name.contains($0.0) }?.1 ?? "🇮🇶"
    }
}

private struct DisplaySection: Hashable {
    let title: String; let icon: String; let rows: [DisplayRow]
}

private struct RateSectionCard: View {
    let section: DisplaySection
    let collapsed: Bool
    let scale: CGFloat
    let favoriteIDs: Set<UUID>
    let onToggleFavorite: (UUID) -> Void
    let onToggle: () -> Void
    private var bestID: UUID? {
        let priced = section.rows.filter { $0.amount != nil }
        let feeRows = priced.filter(\.isFee)
        if feeRows.count == priced.count { return feeRows.min { ($0.amount ?? 0) < ($1.amount ?? 0) }?.id }
        return priced.filter { !$0.isFee }.max { ($0.amount ?? 0) < ($1.amount ?? 0) }?.id
    }
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 7 * scale) {
                    Image(systemName: collapsed ? "chevron.down" : "chevron.up").font(.system(size: 10 * scale, weight: .bold)); Spacer()
                    Text(section.title).font(.system(size: 15 * scale, weight: .bold)); Text(section.icon).font(.system(size: 18 * scale))
                }.foregroundStyle(Palette.navy).padding(.horizontal, 12 * scale).frame(height: 34 * scale)
            }.buttonStyle(.plain)
            if !collapsed {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider().padding(.leading, 45 * scale).overlay(Palette.line) }
                    HStack(spacing: 0) {
                        Button {
                            onToggleFavorite(row.id)
                        } label: {
                            Image(systemName: favoriteIDs.contains(row.id) ? "star.fill" : "star")
                                .font(.system(size: 17 * scale, weight: .medium))
                                .foregroundStyle(Palette.gold)
                                .frame(width: 30 * scale)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        NavigationLink { DestinationRouteView(row: row) } label: {
                            RateRow(row: row, scale: scale, isBest: row.id == bestID)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(URColor.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 10 * scale)).overlay(RoundedRectangle(cornerRadius: 10 * scale).stroke(Palette.line))
    }
}

// ═══════════════════════════════════════════════════
//  Destination Route View — حاسبة فاخرة
// ═══════════════════════════════════════════════════

private struct DestinationRouteView: View {
    let row: DisplayRow
    @State private var amount = ""
    @State private var showAlertSheet = false
    @State private var chartScale: CGFloat = 1

    private var history: [RateSnapshot] { RateHistoryStore.shared.history(for: row.id) }
    private var prediction: Double? { RateHistoryStore.shared.linearPrediction(for: row.id) }

    private var numericAmount: Decimal { Decimal(string: amount) ?? 0 }
    private var validAmount: Bool { numericAmount > 0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                URPageTitle(title: "تفاصيل السعر", subtitle: "مقارنة العراق مع \(row.name)", symbol: "chart.line.uptrend.xyaxis")

                HStack(spacing: 12) {
                    location(title: row.name, subtitle: "السوق المقارن", flag: row.flag)
                    Image(systemName: "arrow.left").font(.title3.weight(.black)).foregroundStyle(URColor.premiumGold)
                    location(title: "العراق", subtitle: "بلد الإرسال", flag: "🇮🇶")
                }
                .environment(\.layoutDirection, .leftToRight)

                URCard {
                    VStack(alignment: .trailing, spacing: 12) {
                        HStack {
                            Image(systemName: "function").foregroundStyle(URColor.premiumGold)
                            Text("حاسبة التحويل").font(.headline.weight(.bold)).foregroundStyle(URColor.deepNavy)
                            Spacer()
                        }
                        HStack { Text("USD").font(.headline.weight(.black)).foregroundStyle(URColor.premiumGold); TextField("0", text: $amount).keyboardType(.decimalPad).font(.title2.weight(.black)).multilineTextAlignment(.trailing) }

                        HStack(spacing: 8) {
                            quickAmount(1000)
                            quickAmount(5000)
                            quickAmount(10000)
                            quickAmount(50000)
                        }

                        Text("العمولة أدناه تُحتسب نسبيًا على أساس كل 10,000 دولار")
                            .font(.caption2)
                            .foregroundStyle(validAmount || amount.isEmpty ? Color.gray : Color.red)

                        Divider()

                        HStack {
                            Text(formattedAdjustment).font(.title3.weight(.black))
                                .foregroundStyle((row.amount ?? 0) < 0 ? Palette.red : Palette.green)
                            Spacer()
                            Text(row.isFee ? "فرق السعر / الرسوم" : "سعر الصرف")
                                .foregroundStyle(.secondary)
                        }

                        if validAmount && row.isFee {
                            Divider()
                            breakdownRow("المبلغ المُرسل", "$\(amount)")
                            breakdownRow("العمولة", formattedAdjustment, highlight: false)
                            breakdownRow("الإجمالي المدفوع", totalPaid, highlight: true)
                        }
                    }
                }

                URCard {
                    VStack(alignment: .trailing, spacing: 10) {
                        HStack {
                            if let prediction {
                                Text("توقع 24 ساعة: \(prediction, specifier: "%.2f")").font(.caption.weight(.bold)).foregroundStyle(URColor.premiumGold)
                            }
                            Spacer()
                            Text("اتجاه السعر").font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
                        }
                        if history.count >= 2 {
                            Chart(history) { point in
                                LineMark(x: .value("الوقت", point.date), y: .value("السعر", point.value))
                                    .foregroundStyle(URColor.royalBlue)
                                PointMark(x: .value("الوقت", point.date), y: .value("السعر", point.value))
                                    .foregroundStyle(URColor.premiumGold)
                            }
                            .frame(height: 190 * chartScale)
                            .chartYAxis { AxisMarks(position: .leading) }
                            .gesture(MagnifyGesture().onChanged { chartScale = min(max($0.magnification, 0.8), 2.2) })
                            Text("قرّب بإصبعين · التوقع إحصائي وليس سعراً مضموناً").font(.caption2).foregroundStyle(.secondary)
                        } else {
                            ContentUnavailableView("لا يوجد تاريخ كافٍ", systemImage: "chart.xyaxis.line", description: Text("يظهر الرسم بعد تسجيل تحديثين حقيقيين على الأقل."))
                                .frame(height: 180)
                        }
                    }
                }

                VStack(alignment: .trailing, spacing: 10) {
                    Label("البيانات المعروضة معلومات إرشادية فقط", systemImage: "info.circle.fill")
                    Label("قد يتغير السعر حسب السوق والوقت", systemImage: "clock.fill")
                    Label("التطبيق لا ينفذ أي معاملة مالية", systemImage: "checkmark.shield.fill")
                }
                .font(.subheadline).foregroundStyle(URColor.deepNavy).frame(maxWidth: .infinity, alignment: .trailing).padding(16)
                .background(URColor.premiumGold.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 10) {
                    Button {
                        showAlertSheet = true
                    } label: {
                        Label(
                            PriceAlertManager.shared.threshold(for: row.id) != nil ? "تنبيه مُفعّل" : "تنبيه سعر",
                            systemImage: PriceAlertManager.shared.threshold(for: row.id) != nil ? "bell.fill" : "bell"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(URColor.royalBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(URColor.royalBlue)
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: shareText) {
                        Label("مشاركة", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(URColor.premiumGold.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(URColor.deepNavy)
                    }
                    .buttonStyle(.plain)
                }
                .font(.subheadline.weight(.bold))

                Link(destination: URL(string: "https://urremit.com/contact")!) {
                    Label("استفسار عن السعر", systemImage: "message.fill")
                }
                .buttonStyle(URPrimaryButtonStyle()).opacity(validAmount ? 1 : 0.55).allowsHitTesting(validAmount)
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea())
        .toolbar(.visible, for: .navigationBar).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAlertSheet) {
            PriceAlertSheet(
                rateID: row.id,
                displayName: row.name,
                currency: row.code,
                currentPrice: row.amount
            )
            .presentationDetents([.medium])
        }
    }

    private func quickAmount(_ value: Double) -> some View {
        Button {
            amount = String(format: "%.0f", value)
        } label: {
            Text("\(Int(value / 1000))K")
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.navy)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    amount == String(format: "%.0f", value) ? Palette.gold.opacity(0.2) : Palette.ivory,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func breakdownRow(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(value)
                .font(highlight ? .headline.weight(.black) : .subheadline.weight(.semibold))
                .foregroundStyle(highlight ? Palette.gold : Palette.navy)
                .monospacedDigit()
            Spacer()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var totalPaid: String {
        guard let value = row.amount else { return "—" }
        let fee = row.isFee ? value * numericAmount / 10_000 : 0
        let total = numericAmount + fee
        return "$" + total.formatted(.number.precision(.fractionLength(0...2)).grouping(.automatic))
    }

    private var shareText: String {
        let priceText = row.amount?.formatted(.number.grouping(.automatic)) ?? "—"
        return """
        💱 UR — \(row.name)
        \(row.isFee ? "العمولة" : "سعر الصرف"): \(priceText)\(row.isFee ? "$ لكل 10,000$" : " \(row.code)")
        \(validAmount ? "مبلغ المقارنة: \(amount) USD" : "")
        """
    }

    private func location(title: String, subtitle: String, flag: String) -> some View {
        VStack(spacing: 6) { Text(flag).font(.system(size: 34)); Text(title).font(.subheadline.weight(.black)).lineLimit(1); Text(subtitle).font(.caption2).foregroundStyle(.secondary) }
            .foregroundStyle(URColor.deepNavy).frame(maxWidth: .infinity, minHeight: 112).background(URColor.surface.opacity(0.90), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline))
    }

    private var formattedAdjustment: String {
        guard let value = row.amount else { return "يُحدد لاحقاً" }
        let displayed = row.isFee && numericAmount > 0 ? value * numericAmount / 10_000 : value
        return (row.isFee && displayed > 0 ? "+" : "") + displayed.formatted(.number.precision(.fractionLength(0...2)).grouping(.automatic)) + (row.isFee ? "$" : "")
    }
}

// ═══════════════════════════════════════════════════
//  RateRow — يعرض الشعار + شارة السرعة
// ═══════════════════════════════════════════════════

private struct RateRow: View {
    let row: DisplayRow; let scale: CGFloat; let isBest: Bool
    var body: some View {
        HStack(spacing: 8 * scale) {
            BrandBadge(name: row.name, logoUrl: row.logoUrl, size: 34 * scale)
                .frame(width: 34 * scale)

            VStack(alignment: .leading, spacing: -1) {
                HStack(spacing: 4) {
                    Text(row.name).font(.system(size: 12.5 * scale, weight: .bold)).lineLimit(1)
                    if isBest {
                        Label("الأفضل سعرًا", systemImage: "crown.fill")
                            .font(.system(size: 7 * scale, weight: .black))
                            .foregroundStyle(Palette.gold)
                    }
                }
                HStack(spacing: 3) {
                    if row.deliverySpeed == "instant" {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7 * scale))
                            .foregroundStyle(.green)
                    } else if row.deliverySpeed == "same_day" {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 7 * scale))
                            .foregroundStyle(.orange)
                    }
                    Text(row.code).font(.system(size: 8.5 * scale, weight: .medium)).opacity(0.62)
                }
            }
            Spacer(minLength: 2)
            VStack(alignment: .trailing, spacing: -1) {
                if !row.isFee, row.buy != nil || row.sell != nil {
                    HStack(spacing: 7 * scale) {
                        rateValue("بيع", row.sell, Palette.red)
                        rateValue("شراء", row.buy, Palette.green)
                    }
                    Text("\(row.code) / \(row.sourceCode)").font(.system(size: 7.5 * scale, weight: .semibold)).foregroundStyle(Palette.navy.opacity(0.55))
                } else {
                    Text(formattedAmount).font(.system(size: 16 * scale, weight: .black)).monospacedDigit().foregroundStyle((row.amount ?? 0) < 0 ? Palette.red : Palette.green)
                    Text(row.isFee ? "لكل 10,000$" : "سعر الصرف").font(.system(size: 8.5 * scale)).foregroundStyle(Palette.navy.opacity(0.62))
                }
            }
            Image(systemName: "chevron.right").font(.system(size: 12 * scale, weight: .bold)).foregroundStyle(Palette.navy.opacity(0.78))
        }
        .environment(\.layoutDirection, .leftToRight).foregroundStyle(Palette.navy).padding(.horizontal, 10 * scale).frame(minHeight: 49 * scale)
    }

    private func rateValue(_ title: String, _ value: Decimal?, _ color: Color) -> some View {
        VStack(alignment: .trailing, spacing: -1) {
            Text(title).font(.system(size: 7 * scale, weight: .bold)).foregroundStyle(Palette.navy.opacity(0.58))
            Text(value?.formatted(.number.grouping(.automatic)) ?? "—")
                .font(.system(size: 12 * scale, weight: .black)).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.72)
        }
    }

    private var formattedAmount: String {
        guard let amount = row.amount else { return "—" }
        let prefix = row.isFee && amount > 0 ? "+" : ""
        let suffix = row.isFee ? "$" : ""
        return prefix + amount.formatted(.number.grouping(.automatic)) + suffix
    }
}

private struct RatesSkeletonView: View {
    var body: some View {
        ScrollView { VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 12).fill(.quaternary).frame(height: 154)
            RoundedRectangle(cornerRadius: 11).fill(.quaternary).frame(height: 39)
            RoundedRectangle(cornerRadius: 13).fill(.quaternary).frame(height: 145)
            ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 10).fill(.quaternary).frame(height: 100) }
        }.padding(.horizontal, 11).redacted(reason: .placeholder) }
    }
}
