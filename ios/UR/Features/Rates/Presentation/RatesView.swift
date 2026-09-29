import SwiftUI

struct RatesView: View {
    @StateObject private var model: RatesViewModel
    @Environment(FavoritesStore.self) private var favorites
    @State private var query = ""
    @State private var collapsedSections: Set<String> = []
    @State private var showOnlyFavorites = false

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
                SearchBar(query: $query, scale: scale)
                favoriteFilterChip(scale: scale)
                HStack(spacing: 6) {
                    Image(systemName: "banknote.fill")
                    Text("العمولة محسوبة لكل 10,000$")
                }
                .font(.system(size: 10 * scale, weight: .bold))
                .foregroundStyle(Palette.gold)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 4)
                HeroRateCard(rate: snapshot.rates.first { $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD" }, isCached: snapshot.isFromCache, scale: scale)
                ForEach(filteredSections(snapshot.rates), id: \.title) { section in
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
            }
            .padding(.horizontal, 11 * scale).padding(.top, 2).padding(.bottom, 8)
        }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private func favoriteFilterChip(scale: CGFloat) -> some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showOnlyFavorites.toggle()
                }
            } label: {
                Label("المفضلة", systemImage: showOnlyFavorites ? "star.fill" : "star")
                    .font(.system(size: 11 * scale, weight: .bold))
                    .padding(.horizontal, 12 * scale)
                    .frame(height: 30 * scale)
                    .background(showOnlyFavorites ? Palette.gold : .white, in: Capsule())
                    .foregroundStyle(showOnlyFavorites ? .white : Palette.navy)
                    .overlay(Capsule().stroke(Palette.line))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func filteredSections(_ rates: [Rate]) -> [DisplaySection] {
        var sections = makeSections(rates)

        if showOnlyFavorites {
            sections = sections.compactMap { section in
                let rows = section.rows.filter { favorites.favoriteIDs.contains($0.id) }
                return rows.isEmpty ? nil : DisplaySection(title: section.title, icon: section.icon, rows: rows)
            }
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return sections }
        return sections.compactMap { section in
            let rows = section.rows.filter {
                $0.name.localizedCaseInsensitiveContains(trimmedQuery) ||
                $0.code.localizedCaseInsensitiveContains(trimmedQuery)
            }
            return rows.isEmpty ? nil : DisplaySection(title: section.title, icon: section.icon, rows: rows)
        }
    }

    private func makeSections(_ rates: [Rate]) -> [DisplaySection] {
        let visible = rates.filter { !($0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD") }
        let definitions: [(String, String, [String])] = [
            ("العراق — المدن الرئيسية", "🇮🇶", ["بغداد", "أربيل", "السليمانية", "البصرة"]),
            ("بقية مدن العراق", "🗺️", ["دهوك", "الموصل", "زاخو", "كركوك", "تكريت", "كربلاء", "النجف", "الناصرية", "العمارة", "الكوت", "الحلة", "الديوانية"]),
            ("الخليج", "🏙️", ["السعودية", "قطر", "دبي", "الكويت", "سلطنة عمان", "البحرين"]),
            ("إيران وتركيا", "🕌", ["طهران", "مشهد", "قم", "تومان", "تركيا"]),
            ("أوروبا وكندا", "🏛️", ["فرنسا", "بريطانيا", "كندا", "ألمانيا", "إيطاليا", "كرواتيا"]),
            ("الدول العربية", "🌍", ["الأردن", "لبنان", "مصر"]),
            ("أسعار دولية", "🌐", ["الحوالات البنكية", "الصين"])
        ]
        var used = Set<UUID>()
        var sections: [DisplaySection] = definitions.compactMap { title, icon, names in
            let matched = names.compactMap { name in visible.first { !used.contains($0.id) && $0.routeNameArabic.contains(name) } }.map { rate -> DisplayRow in
                used.insert(rate.id); return DisplayRow(rate: rate)
            }
            return matched.isEmpty ? nil : DisplaySection(title: title, icon: icon, rows: matched)
        }
        let remaining = visible.filter { !used.contains($0.id) }.map(DisplayRow.init(rate:))
        if !remaining.isEmpty { sections.append(.init(title: "أسعار أخرى", icon: "✨", rows: remaining)) }
        return sections
    }
}

private enum Palette {
    static let navy = Color(red: 0.012, green: 0.08, blue: 0.21)
    static let blue = Color(red: 0.015, green: 0.18, blue: 0.31)
    static let gold = Color(red: 0.67, green: 0.49, blue: 0.16)
    static let ivory = Color(red: 0.993, green: 0.985, blue: 0.963)
    static let line = Color(red: 0.80, green: 0.77, blue: 0.68).opacity(0.48)
    static let green = Color(red: 0.00, green: 0.50, blue: 0.27)
    static let red = Color(red: 0.78, green: 0.08, blue: 0.15)
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
                .background(.white.opacity(0.90), in: Capsule()).overlay(Capsule().stroke(Palette.line))
            }
            .environment(\.layoutDirection, .leftToRight).offset(x: 4 * scale, y: 7 * scale)
            VStack(alignment: .trailing, spacing: -1) {
                HStack(spacing: 5 * scale) {
                    Text("UR").font(.system(size: 34 * scale, weight: .black, design: .rounded))
                    Rectangle().fill(Palette.gold).frame(width: 1, height: 27 * scale)
                    Text("أور").font(.system(size: 27 * scale, weight: .black))
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
            .frame(width: 38 * scale, height: 38 * scale).background(.white.opacity(0.90), in: Circle()).overlay(Circle().stroke(Palette.line))
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
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 11 * scale)).overlay(RoundedRectangle(cornerRadius: 11 * scale).stroke(Palette.line))
    }
}

private struct HeroRateCard: View {
    let rate: Rate?; let isCached: Bool; let scale: CGFloat
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
                        HStack(spacing: 5) { Text(isCached ? "بيانات محفوظة" : "محدث الآن"); Circle().fill(isCached ? .orange : .green).frame(width: 7 * scale, height: 7 * scale) }
                        Text("24 سبتمبر 2026   10:30 ص").font(.system(size: 7.5 * scale))
                    }.font(.system(size: 9 * scale, weight: .semibold)).foregroundStyle(.white.opacity(0.78))
                }
                HStack(spacing: 0) {
                    value(title: "سعر البيع", number: rate?.sell ?? 1573)
                    Rectangle().fill(.white.opacity(0.22)).frame(width: 1, height: 58 * scale)
                    value(title: "سعر الشراء", number: rate?.buy ?? 1568)
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
    private func value(title: String, number: Decimal) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 12 * scale, weight: .semibold))
            Text(number.formatted(.number.grouping(.automatic))).font(.system(size: 34 * scale, weight: .black, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7)
            Text("دينار لكل دولار").font(.system(size: 9 * scale)).foregroundStyle(.white.opacity(0.72))
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
    let isFee: Bool

    init(rate: Rate) {
        id = rate.id
        name = rate.routeNameArabic
        code = rate.destinationCurrency
        flag = Self.flag(for: rate.routeNameArabic)
        amount = rate.feeFixed ?? rate.sell ?? rate.buy
        isFee = rate.feeFixed != nil
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
                            RateRow(row: row, scale: scale)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 10 * scale)).overlay(RoundedRectangle(cornerRadius: 10 * scale).stroke(Palette.line))
    }
}

private struct DestinationRouteView: View {
    let row: DisplayRow
    @State private var amount = ""
    @State private var showAlertSheet = false

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
                        Text("مبلغ المقارنة").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        HStack { Text("USD").font(.headline.weight(.black)).foregroundStyle(URColor.premiumGold); TextField("0", text: $amount).keyboardType(.decimalPad).font(.title2.weight(.black)).multilineTextAlignment(.trailing) }
                        Text("العمولة أدناه تُحتسب نسبيًا على أساس كل 10,000 دولار").font(.caption2).foregroundStyle(validAmount || amount.isEmpty ? Color.gray : Color.red)
                        Divider()
                        HStack { Text(formattedAdjustment).font(.title3.weight(.black)).foregroundStyle((row.amount ?? 0) < 0 ? Palette.red : Palette.green); Spacer(); Text(row.isFee ? "فرق السعر / الرسوم" : "سعر الصرف").foregroundStyle(.secondary) }
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
            .foregroundStyle(URColor.deepNavy).frame(maxWidth: .infinity, minHeight: 112).background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline))
    }

    private var formattedAdjustment: String {
        guard let value = row.amount else { return "يُحدد لاحقاً" }
        let displayed = row.isFee && numericAmount > 0 ? value * numericAmount / 10_000 : value
        return (row.isFee && displayed > 0 ? "+" : "") + displayed.formatted(.number.precision(.fractionLength(0...2)).grouping(.automatic)) + (row.isFee ? "$" : "")
    }
}

private struct RateRow: View {
    let row: DisplayRow; let scale: CGFloat
    var body: some View {
        HStack(spacing: 8 * scale) {
            Text(row.flag).font(.system(size: 25 * scale)).frame(width: 34 * scale)
            VStack(alignment: .leading, spacing: -1) {
                Text(row.name).font(.system(size: 12.5 * scale, weight: .bold)).lineLimit(1)
                Text(row.code).font(.system(size: 8.5 * scale, weight: .medium)).opacity(0.62)
            }
            Spacer(minLength: 2)
            VStack(alignment: .trailing, spacing: -1) {
                Text(formattedAmount).font(.system(size: 16 * scale, weight: .black)).monospacedDigit().foregroundStyle((row.amount ?? 0) < 0 ? Palette.red : Palette.green)
                Text(row.isFee ? "لكل 10,000$" : "سعر الصرف").font(.system(size: 8.5 * scale)).foregroundStyle(Palette.navy.opacity(0.62))
            }
            Image(systemName: "chevron.right").font(.system(size: 12 * scale, weight: .bold)).foregroundStyle(Palette.navy.opacity(0.78))
        }
        .environment(\.layoutDirection, .leftToRight).foregroundStyle(Palette.navy).padding(.horizontal, 10 * scale).frame(height: 39 * scale)
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
