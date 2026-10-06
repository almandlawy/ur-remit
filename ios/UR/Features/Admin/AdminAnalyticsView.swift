import SwiftUI
import Charts

struct URAnalyticsSummary: Decodable, Sendable {
    struct Registered: Decodable, Sendable { let total, today, last7, last30, confirmed, incomplete: Int }
    struct Active: Decodable, Sendable { let today, last7, last30, selected: Int }
    struct Day: Decodable, Sendable, Identifiable { let day: String; let opens, active, contacts: Int; var id: String { day } }
    struct Funnel: Decodable, Sendable { let opened, rates, calculated, contacted: Int }
    struct Downloads: Decodable, Sendable { let status: String; let first_time_downloads: Int? }
    struct Page: Decodable, Sendable { let event_name: String; let views: Int }
    let registered: Registered
    let active: Active
    let events: [String: Int]
    let daily: [Day]
    let funnel: Funnel
    let downloads: Downloads
    let top_pages: [Page]
    let retention_days: Int
}

@MainActor
enum URAdminAnalyticsAPI {
    static func canAccess(token: String) async -> Bool {
        guard let url = endpoint(path: "access") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
    static func summary(token: String, days: Int) async throws -> URAnalyticsSummary {
        guard let url = endpoint(path: "summary")?.appending(queryItems: [.init(name: "days", value: String(days))]) else { throw Failure.configuration }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw status == 403 ? Failure.forbidden : status == 401 ? Failure.unauthorized : Failure.unavailable }
        struct Envelope: Decodable { let data: URAnalyticsSummary }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }
    private static func endpoint(path: String) -> URL? {
        guard let base = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String, let url = URL(string: base), url.scheme == "https" else { return nil }
        return url.appending(path: "functions/v1/app-analytics/\(path)")
    }
    enum Failure: LocalizedError {
        case configuration, forbidden, unauthorized, unavailable
        var errorDescription: String? {
            switch self {
            case .configuration: "خدمة المراقبة غير مهيأة."
            case .forbidden: "لا تملك صلاحية مراقبة التطبيق."
            case .unauthorized: "انتهت جلسة الإدارة. سجّل الدخول مجدداً."
            case .unavailable: "تعذر تحميل المراقبة. حاول مجدداً."
            }
        }
    }
}

struct AdminAnalyticsView: View {
    let token: String
    @State private var days = 1
    @State private var summary: URAnalyticsSummary?
    @State private var errorMessage: String?
    @State private var loading = false
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("UR Global Analytics").font(.title2.bold()).foregroundStyle(URColor.premiumGold)
                Picker("الفترة", selection: $days) {
                    Text("اليوم").tag(1); Text("7 أيام").tag(7); Text("30 يوم").tag(30); Text("90 يوم").tag(90); Text("الكل").tag(0)
                }.pickerStyle(.segmented)
                if loading { ProgressView("جاري التحديث…") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                if let s = summary {
                    LazyVGrid(columns: columns, spacing: 12) {
                        card("App Store Downloads", value: s.downloads.status == "connected" ? s.downloads.first_time_downloads.map(String.init) ?? "—" : "غير مربوط")
                        card("First Opens · أول فتح", value: number(s.events["app_first_open"] ?? 0))
                        card("Active Users · النشطون", value: number(s.active.selected))
                        card("Registered Users · المسجلون", value: number(s.registered.total))
                        card("Contact Attempts · التواصل", value: number(s.events["contact_attempted"] ?? 0))
                        card("مرات الفتح", value: number(s.events["app_open"] ?? 0))
                    }
                    Text("أول فتح ليس عدد تنزيلات App Store. النشطون تثبيتات فريدة. إجمالي المسجلين من Supabase Auth وقد يشمل حسابات من خارج التطبيق.").font(.caption).foregroundStyle(.secondary)
                    GroupBox("النشاط اليومي · آخر 30 يوم") {
                        Chart(Array(s.daily.enumerated()), id: \.element.id) { item in
                            BarMark(x: .value("اليوم", item.offset), y: .value("الفتح", item.element.opens)).foregroundStyle(URColor.premiumGold)
                            LineMark(x: .value("اليوم", item.offset), y: .value("النشطون", item.element.active), series: .value("نوع", "النشطون")).foregroundStyle(.blue)
                            LineMark(x: .value("اليوم", item.offset), y: .value("التواصل", item.element.contacts), series: .value("نوع", "التواصل")).foregroundStyle(.green)
                        }.frame(height: 190).environment(\.layoutDirection, .leftToRight)
                        Text("ذهبي: الفتح · أزرق: النشطون · أخضر: التواصل").font(.caption2)
                    }
                    GroupBox("مسار التحويل إلى التواصل") {
                        let values = [s.funnel.opened, s.funnel.rates, s.funnel.calculated, s.funnel.contacted]
                        let labels = ["فتح التطبيق", "مشاهدة الأسعار", "استخدام الحاسبة", "محاولة التواصل"]
                        VStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { index in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(labels[index]).font(.subheadline.bold())
                                        if index > 0 { Text("\(percentage(values[index], of: values[index - 1]))% من الخطوة السابقة").font(.caption).foregroundStyle(.secondary) }
                                        Text("\(percentage(values[index], of: values[0]))% من الفتح").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer(); Text(number(values[index])).font(.title3.bold())
                                }
                            }
                        }
                        Text("جلسات مرتبة زمنياً، وليست معاملات مالية.").font(.caption2).foregroundStyle(.secondary)
                    }
                    GroupBox("التفاصيل") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            card("تسجيلات اليوم", value: number(s.registered.today)); card("تسجيلات 7 أيام", value: number(s.registered.last7)); card("تسجيلات 30 يوم", value: number(s.registered.last30)); card("حسابات غير مؤكدة", value: number(s.registered.incomplete))
                            card("نشطون اليوم", value: number(s.active.today)); card("نشطون 7 أيام", value: number(s.active.last7)); card("نشطون 30 يوم", value: number(s.active.last30))
                            ForEach([("الحاسبة","calculator_used"),("الأسعار","rates_viewed"),("WhatsApp","whatsapp_clicked"),("الهاتف","phone_clicked"),("الموقع","website_clicked"),("زيارة المكاتب","offices_viewed"),("اختيار مكتب","office_clicked"),("الخرائط","map_clicked"),("تسجيل مكتمل داخل التطبيق","signup_completed")], id: \.1) { item in card(item.0, value: number(s.events[item.1] ?? 0)) }
                        }
                    }
                    GroupBox("أكثر الصفحات استخداماً") {
                        VStack(spacing: 12) {
                            if s.top_pages.isEmpty { Text("لا توجد مشاهدات مسجلة بعد.").font(.caption) }
                            ForEach(s.top_pages, id: \.event_name) { page in HStack { Text(pageTitle(page.event_name)); Spacer(); Text(number(page.views)) } }
                        }.frame(maxWidth: .infinity)
                    }
                    Text("توقيت بغداد. الاحتفاظ بالأحداث \(s.retention_days) يوماً. يبدأ التسجيل عند تشغيل الإصدار المحدّث.").font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .environment(\.layoutDirection, .rightToLeft)
        .navigationTitle("مراقبة التطبيق")
        .task(id: days) { await reload() }
        .refreshable { await reload() }
    }
    private func reload() async {
        loading = true; errorMessage = nil
        defer { loading = false }
        do { let value = try await URAdminAnalyticsAPI.summary(token: token, days: days); try Task.checkCancellation(); summary = value }
        catch is CancellationError {} catch { summary = nil; errorMessage = error.localizedDescription }
    }
    private func card(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 9) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title3.bold()).minimumScaleFactor(0.7).lineLimit(1) }
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading).padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
    private func number(_ value: Int) -> String { value.formatted(.number.locale(Locale(identifier: "ar_IQ"))) }
    private func percentage(_ value: Int, of total: Int) -> String { total > 0 ? String(format: "%.1f", Double(value) / Double(total) * 100) : "0" }
    private func pageTitle(_ name: String) -> String { ["home_viewed":"الرئيسية","rates_viewed":"الأسعار","calculator_viewed":"الحاسبة","offices_viewed":"المكاتب"][name] ?? name }
}
