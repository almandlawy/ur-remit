import SwiftUI
import WidgetKit

private struct URWidgetRoute: Codable, Hashable {
    let name: String
    let value: String
    let code: String
}

private struct URRateEntry: TimelineEntry {
    let date: Date
    let sourceDate: Date?
    let buy: String?
    let sell: String?
    let routes: [URWidgetRoute]
    let highlightedRoute: Int
}

private struct URRateProvider: TimelineProvider {
    func placeholder(in context: Context) -> URRateEntry {
        .init(date: .now, sourceDate: nil, buy: nil, sell: nil, routes: sampleRoutes, highlightedRoute: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (URRateEntry) -> Void) {
        completion(load(at: .now, index: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<URRateEntry>) -> Void) {
        let now = Date.now
        let loaded = load(at: now, index: 0)
        let count = max(loaded.routes.count, 1)
        let entries = (0..<count).map { index in load(at: now.addingTimeInterval(Double(index) * 15 * 60), index: index) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(Double(count) * 15 * 60))))
    }

    private func load(at date: Date, index: Int) -> URRateEntry {
        let defaults = UserDefaults(suiteName: "group.com.urremit.shared")
        let routes: [URWidgetRoute]
        if let data = defaults?.data(forKey: "widget_featured_routes"),
           let decoded = try? JSONDecoder().decode([URWidgetRoute].self, from: data), !decoded.isEmpty {
            routes = decoded
        } else { routes = sampleRoutes }
        return .init(
            date: date,
            sourceDate: defaults?.object(forKey: "usd_iqd_source_timestamp") as? Date,
            buy: defaults?.string(forKey: "usd_iqd_buy"),
            sell: defaults?.string(forKey: "usd_iqd_sell"),
            routes: routes,
            highlightedRoute: index % max(routes.count, 1)
        )
    }

    private var sampleRoutes: [URWidgetRoute] {
        [
            .init(name: "دبي", value: "—", code: "AED"),
            .init(name: "عُمان", value: "—", code: "OMR"),
            .init(name: "تركيا", value: "—", code: "TRY"),
            .init(name: "الصين", value: "—", code: "CNY")
        ]
    }
}

private struct URRateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: URRateEntry
    private let navy = Color(red: 0.015, green: 0.10, blue: 0.30)
    private let blue = Color(red: 0.02, green: 0.28, blue: 0.80)
    private let gold = Color(red: 0.94, green: 0.68, blue: 0.18)

    var body: some View {
        VStack(spacing: family == .systemSmall ? 7 : 9) {
            header
            HStack(spacing: 8) {
                rateValue("شراء", entry.buy)
                Rectangle().fill(.white.opacity(0.18)).frame(width: 1)
                rateValue("بيع", entry.sell)
            }
            if family == .systemMedium { routeRail } else { compactRoute }
        }
        .padding(family == .systemSmall ? 12 : 14)
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("أسعار أور: شراء \(entry.buy ?? "غير متاح")، بيع \(entry.sell ?? "غير متاح")")
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(colors: [navy, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(gold.opacity(0.18)).frame(width: 180, height: 180).offset(x: 125, y: -75)
                Circle().stroke(gold.opacity(0.22), lineWidth: 1).frame(width: 150, height: 150).offset(x: -120, y: 90)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("URAppIcon")
                .resizable()
                .scaledToFill()
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.46)))
            VStack(alignment: .leading, spacing: 0) {
                Text("UR GLOBAL").font(.system(size: 11, weight: .black, design: .rounded)).tracking(0.5)
                Text("USD / IQD").font(.system(size: 9, weight: .bold)).foregroundStyle(gold)
            }
            Spacer()
            if family == .systemMedium {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("آخر مصدر").font(.system(size: 8, weight: .semibold)).opacity(0.7)
                    if let sourceDate = entry.sourceDate {
                        Text(sourceDate, style: .time).font(.system(size: 10, weight: .bold)).monospacedDigit()
                    } else {
                        Text("غير متاح").font(.system(size: 9, weight: .bold))
                    }
                }
            }
        }
    }

    private func rateValue(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.72))
            Text(formatted(value)).font(.system(size: family == .systemSmall ? 19 : 24, weight: .black, design: .rounded))
                .minimumScaleFactor(0.65).lineLimit(1).monospacedDigit().contentTransition(.numericText())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(_ value: String?) -> String {
        guard let value, let number = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else { return "—" }
        let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.numberStyle = .decimal; formatter.maximumFractionDigits = 4
        return formatter.string(from: number as NSDecimalNumber) ?? "—"
    }

    private var compactRoute: some View {
        let route = entry.routes.isEmpty ? URWidgetRoute(name: "الأسعار", value: "—", code: "") : entry.routes[entry.highlightedRoute % entry.routes.count]
        return HStack(spacing: 5) {
            Circle().fill(gold).frame(width: 5, height: 5)
            Text(route.name).font(.system(size: 9, weight: .black)).lineLimit(1)
            Spacer()
            Text(route.value).font(.system(size: 10, weight: .black)).monospacedDigit()
            Text(route.code).font(.system(size: 7, weight: .bold)).foregroundStyle(gold)
        }
        .padding(.horizontal, 8).frame(height: 25)
        .background(.white.opacity(0.10), in: Capsule())
    }

    private var routeRail: some View {
        let visibleRoutes: [URWidgetRoute] = {
            guard entry.routes.count > 4 else { return entry.routes }
            return (0..<4).map { entry.routes[(entry.highlightedRoute + $0) % entry.routes.count] }
        }()
        return HStack(spacing: 6) {
            ForEach(Array(visibleRoutes.enumerated()), id: \.offset) { index, route in
                VStack(spacing: 1) {
                    Text(route.name).font(.system(size: 8, weight: .bold)).lineLimit(1)
                    Text(route.value).font(.system(size: 11, weight: .black)).monospacedDigit().lineLimit(1)
                    Text(route.code).font(.system(size: 6.5, weight: .bold)).foregroundStyle(gold).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 37)
                .background(index == 0 ? gold.opacity(0.19) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(index == 0 ? gold.opacity(0.6) : .clear))
            }
        }
    }
}

struct URRateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "URUSD-IQD", provider: URRateProvider()) { URRateWidgetView(entry: $0) }
            .configurationDisplayName("لوحة أسعار أور")
            .description("الدولار وأسعار دبي وعُمان وتركيا والصين والتحويلات")
            .supportedFamilies([.systemSmall, .systemMedium])
            .contentMarginsDisabled()
    }
}

@main struct URWidgetBundle: WidgetBundle {
    var body: some Widget { URRateWidget() }
}
