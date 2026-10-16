import SwiftUI
import Charts

// ═══════════════════════════════════════════════════════════════
//  UR Enhancements — ميزات إضافية
//  RateHistoryStore + ShareRateCard + NewsletterGenerator + BestBadge
// ═══════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────
// 1) RateHistoryStore — يحفظ تاريخ الأسعار
// ───────────────────────────────────────────────

struct RateSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let rateID: UUID
    let routeName: String
    let value: Double
    let date: Date
    let isFee: Bool

    init(rateID: UUID, routeName: String, value: Double, date: Date = Date(), isFee: Bool) {
        self.id = UUID()
        self.rateID = rateID
        self.routeName = routeName
        self.value = value
        self.date = date
        self.isFee = isFee
    }
}

@Observable
@MainActor
final class RateHistoryStore {
    static let shared = RateHistoryStore()

    private let storageKey = "ur.rate.history.v2"
    private let maxDays = 90
    private let minIntervalSeconds: TimeInterval = 3600

    private(set) var snapshots: [UUID: [RateSnapshot]] = [:]

    private init() { load() }

    func record(rates: [Rate]) {
        let now = Date()
        var changed = false

        for rate in rates {
            guard let value = extractValue(rate) else { continue }
            let isFee = rate.feeFixed != nil
            var history = snapshots[rate.id] ?? []

            if let last = history.last, now.timeIntervalSince(last.date) < minIntervalSeconds {
                if abs(last.value - value) > 0.001 {
                    history[history.count - 1] = RateSnapshot(
                        rateID: rate.id,
                        routeName: rate.routeNameArabic,
                        value: value,
                        date: last.date,
                        isFee: isFee
                    )
                    snapshots[rate.id] = history
                    changed = true
                }
                continue
            }

            history.append(RateSnapshot(
                rateID: rate.id,
                routeName: rate.routeNameArabic,
                value: value,
                date: now,
                isFee: isFee
            ))
            let cutoff = now.addingTimeInterval(-Double(maxDays) * 86400)
            history = history.filter { $0.date >= cutoff }
            snapshots[rate.id] = history
            changed = true
        }

        if changed { save() }
    }

    func history(for rateID: UUID) -> [RateSnapshot] {
        (snapshots[rateID] ?? []).sorted { $0.date < $1.date }
    }

    func range(for rateID: UUID, days: Int = 30) -> (min: Double, max: Double, avg: Double)? {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let values = (snapshots[rateID] ?? [])
            .filter { $0.date >= cutoff }
            .map(\.value)
        guard !values.isEmpty else { return nil }
        return (
            values.min() ?? 0,
            values.max() ?? 0,
            values.reduce(0, +) / Double(values.count)
        )
    }

    func trend(for rateID: UUID, days: Int = 7) -> Double? {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let history = (snapshots[rateID] ?? []).filter { $0.date >= cutoff }
        guard history.count >= 2,
              let first = history.first?.value,
              let last = history.last?.value,
              first != 0 else { return nil }
        return ((last - first) / abs(first)) * 100.0
    }

    /// Least-squares projection based only on recorded observations.
    /// Returns nil rather than inventing a trend when history is insufficient.
    func linearPrediction(for rateID: UUID, hoursAhead: Double = 24) -> Double? {
        let points = history(for: rateID)
        guard points.count >= 3, let origin = points.first?.date else { return nil }
        let xs = points.map { $0.date.timeIntervalSince(origin) / 3600 }
        let ys = points.map(\.value)
        let count = Double(points.count)
        let meanX = xs.reduce(0, +) / count
        let meanY = ys.reduce(0, +) / count
        let numerator = zip(xs, ys).reduce(0.0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let denominator = xs.reduce(0.0) { $0 + pow($1 - meanX, 2) }
        guard denominator > 0 else { return nil }
        let slope = numerator / denominator
        let intercept = meanY - slope * meanX
        return intercept + slope * ((xs.last ?? 0) + hoursAhead)
    }

    private func extractValue(_ rate: Rate) -> Double? {
        let value = rate.feeFixed ?? rate.sell ?? rate.buy
        guard let value else { return nil }
        return NSDecimalNumber(decimal: value).doubleValue
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([UUID: [RateSnapshot]].self, from: data) else { return }
        snapshots = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// ───────────────────────────────────────────────
// 2) ShareRateCard — بطاقة فاخرة للمشاركة
// ───────────────────────────────────────────────

struct ShareRateCard: View {
    let name: String
    let flag: String
    let code: String
    let amount: Decimal?
    let isFee: Bool
    let trend: Double?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.012, green: 0.08, blue: 0.21),
                    Color(red: 0.015, green: 0.18, blue: 0.31)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UR").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("GLOBAL REMITTANCES").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Color(red: 0.67, green: 0.49, blue: 0.16))
                    }
                    Spacer()
                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.65))
                }
                .padding(.horizontal, 32)
                .padding(.top, 36)

                VStack(spacing: 12) {
                    Text(flag).font(.system(size: 64))
                    Text(name).font(.title2.weight(.black)).foregroundStyle(.white)
                    Text(code).font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.white.opacity(0.55))

                    if let amount {
                        Text(formattedAmount(amount))
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color(red: 0.67, green: 0.49, blue: 0.16))
                            .padding(.top, 8)
                        Text(isFee ? "لكل 10,000$" : "سعر الصرف")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    if let trend {
                        HStack(spacing: 6) {
                            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text("\(abs(trend), specifier: "%.2f")%")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(trend >= 0 ? Color.green : Color.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            (trend >= 0 ? Color.green : Color.red).opacity(0.15),
                            in: Capsule()
                        )
                    }
                }
                .padding(.vertical, 30)

                Spacer()

                VStack(spacing: 6) {
                    Divider().overlay(Color(red: 0.67, green: 0.49, blue: 0.16).opacity(0.4)).padding(.horizontal, 32)
                    Text("حمّل التطبيق الآن").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.9))
                    Text("urremit.com").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(Color(red: 0.67, green: 0.49, blue: 0.16))
                }
                .padding(.bottom, 30)
            }
        }
        .frame(width: 500, height: 660)
    }

    private func formattedAmount(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value).doubleValue
        let prefix = isFee && number > 0 ? "+" : ""
        let suffix = isFee ? "$" : ""
        return prefix + String(format: "%.2f", number) + suffix
    }
}

// ───────────────────────────────────────────────
// 3) ShareSheet — Wrapper
// ───────────────────────────────────────────────

struct URImageShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// ───────────────────────────────────────────────
// 4) NewsletterGenerator — مُنشئ النشرة
// ───────────────────────────────────────────────

@Observable
@MainActor
final class URNewsletterGenerator {
    private(set) var generatedText: String = ""

    func generate(from rates: [Rate]) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "EEEE yyyy-MM-dd"
        let today = formatter.string(from: Date())

        var text = "📢 نشرة أسعار الحوالات اليومية\n"
        text += "🏢 شركة أُور للحوالات العالمية\n"
        text += "📅 \(today)\n\n"

        text += "━━━━━━━━━━━━━━━━━━\n"
        text += "💵 أسعار صرف الدولار\n"
        text += "━━━━━━━━━━━━━━━━━━\n"
        if let main = rates.first(where: { $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD" }) {
            text += "🟢 شراء: \(formatNumber(main.buy)) دينار\n"
            text += "🔴 بيع:  \(formatNumber(main.sell)) دينار\n"
        }
        text += "\n"

        if let rmb = rates.first(where: {
            $0.routeNameArabic.contains("الصين") || $0.routeNameArabic.contains("يوان")
        }), let buy = rmb.buy {
            text += "🇨🇳 يوان صيني (رنمينبي): \(formatNumber(buy))\n\n"
        }

        let groups: [(String, [String])] = [
            ("🏛 داخل العراق", ["بغداد","أربيل","السليمانية","البصرة","دهوك","الموصل","زاخو","كركوك","كربلاء","النجف","الديوانية","الحلة"]),
            ("🏙 دول الخليج", ["السعودية","قطر","دبي","الكويت","سلطنة عمان","البحرين"]),
            ("🕌 إيران وتركيا", ["طهران","مشهد","قم","تومان","تركيا"]),
            ("🏛 أوروبا وكندا", ["فرنسا","بريطانيا","كندا","ألمانيا","إيطاليا","كرواتيا"]),
            ("🌍 الدول العربية", ["الأردن","لبنان","مصر"]),
            ("💸 التحويلات العالمية", ["ويسترن","Western","موني","Money","ويو","Wio","المشرق","Mashreq"]),
            ("🏦 بنوك الإمارات", ["بنك دبي","أبو ظبي","ADIB"]),
            ("🇮🇳 الهند", ["الهند"]),
            ("🌐 أسعار دولية", ["الحوالات","الصين"])
        ]

        let mainRateID = rates.first(where: { $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD" })?.id
        var used = Set<UUID>()

        for (title, keywords) in groups {
            let matched = rates.filter { rate in
                guard !used.contains(rate.id), rate.id != mainRateID else { return false }
                return keywords.contains(where: { rate.routeNameArabic.contains($0) })
            }.sorted { ($0.updatedAt) < ($1.updatedAt) }

            guard !matched.isEmpty else { continue }

            text += "━━━━━━━━━━━━━━━━━━\n"
            text += "\(title)\n"
            text += "━━━━━━━━━━━━━━━━━━\n"

            for rate in matched {
                used.insert(rate.id)
                let amount = rate.feeFixed ?? rate.sell ?? rate.buy
                guard let value = amount else { continue }
                let sign = value >= 0 ? "+" : ""
                let suffix = rate.feeFixed != nil ? "$" : ""
                text += "📍 \(rate.routeNameArabic): \(sign)\(formatNumber(value))\(suffix)\n"
            }
            text += "\n"
        }

        text += """
        ━━━━━━━━━━━━━━━━━━
        📞 تواصل معنا
        ━━━━━━━━━━━━━━━━━━
        🇮🇶 بغداد: +964 770 458 3730
        🇬🇧 لندن: +44 7915 387858
        💬 واتساب: +971 55 175 4032

        ✨ أموالك تصل أبعد في كل مكان ✨
        """

        generatedText = text
    }

    private func formatNumber(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Double(truncating: value as NSNumber))) ?? "\(value)"
    }
}

// ───────────────────────────────────────────────
// 5) NewsletterSheet — عرض النشرة
// ───────────────────────────────────────────────

struct URNewsletterSheet: View {
    let rates: [Rate]
    @State private var text = ""
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .background(Color(red: 0.993, green: 0.985, blue: 0.963))
            .navigationTitle("النشرة الجاهزة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = text
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            Label(copied ? "✓ تم النسخ" : "📋 نسخ",
                                  systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.subheadline.weight(.bold))
                        }
                        .tint(Color(red: 0.67, green: 0.49, blue: 0.16))

                        Spacer()

                        Button {
                            shareText(text)
                        } label: {
                            Label("📱 مشاركة", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.bold))
                        }
                        .tint(Color(red: 0.012, green: 0.08, blue: 0.21))
                    }
                    .padding(.horizontal)
                }
            }
            .onAppear {
                let gen = URNewsletterGenerator()
                gen.generate(from: rates)
                text = gen.generatedText
            }
        }
    }

    private func shareText(_ value: String) {
        let av = UIActivityViewController(activityItems: [value], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = root.view
            root.present(av, animated: true)
        }
    }
}
