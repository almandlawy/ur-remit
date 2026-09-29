import Foundation
import UserNotifications
import Observation

/// مدير التذكير اليومي بالأسعار
/// يجدول إشعاراً محلياً متكرراً بالوقت والأيام التي يحددها المستخدم
@Observable
@MainActor
final class DailyReminderManager {
    static let shared = DailyReminderManager()

    private let enabledKey = "daily_reminder_enabled"
    private let hourKey = "daily_reminder_hour"
    private let minuteKey = "daily_reminder_minute"
    private let weekdaysKey = "daily_reminder_weekdays"

    /// هل التذكير مفعّل؟
    var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            Task { await reschedule() }
        }
    }

    /// الساعة (0-23)
    var hour: Int = 9 {
        didSet {
            UserDefaults.standard.set(hour, forKey: hourKey)
            Task { await reschedule() }
        }
    }

    /// الدقيقة (0-59)
    var minute: Int = 0 {
        didSet {
            UserDefaults.standard.set(minute, forKey: minuteKey)
            Task { await reschedule() }
        }
    }

    /// الأيام المحددة (1 = الأحد، 7 = السبت — حسب Calendar)
    var weekdays: Set<Int> = Set(1...7) {
        didSet {
            UserDefaults.standard.set(Array(weekdays), forKey: weekdaysKey)
            Task { await reschedule() }
        }
    }

    private init() { load() }

    // MARK: - Persistence
    private func load() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        hour = UserDefaults.standard.object(forKey: hourKey) as? Int ?? 9
        minute = UserDefaults.standard.object(forKey: minuteKey) as? Int ?? 0
        if let days = UserDefaults.standard.array(forKey: weekdaysKey) as? [Int], !days.isEmpty {
            weekdays = Set(days)
        }
    }

    // MARK: - Public API

    /// يطلب صلاحية الإشعارات إن لم تُطلب
    func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// يجدول التذكير بناءً على الإعدادات الحالية
    func reschedule() async {
        let center = UNUserNotificationCenter.current()

        // احذف كل التذكيرات السابقة
        center.removePendingNotificationRequests(withIdentifiers: identifiers())

        guard isEnabled, !weekdays.isEmpty else { return }

        // تحقق من الصلاحية
        let authorized = await requestPermissionIfNeeded()
        guard authorized else { return }

        for weekday in weekdays {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = weekday

            let content = makeContent()
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: identifier(for: weekday),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func clearSettings() async {
        isEnabled = false
        hour = 9
        minute = 0
        weekdays = Set(1...7)

        UserDefaults.standard.removeObject(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: hourKey)
        UserDefaults.standard.removeObject(forKey: minuteKey)
        UserDefaults.standard.removeObject(forKey: weekdaysKey)
        UserDefaults.standard.removeObject(forKey: "reminder_last_reset")

        await reschedule()
    }

    /// يحدّث محتوى الإشعار بآخر سعر معروف (يُستدعى عند تحديث الأسعار)
    func refreshContent(usdIqd: Rate?) async {
        if let rate = usdIqd, let price = rate.sell ?? rate.buy {
            UserDefaults.standard.set("\(price)", forKey: "last_known_usd_iqd")
        }

        await reschedule()
    }

    /// لتصفير التنبيهات المُطلقة يومياً
    func resetFiredIfNewDay() {
        let today = Calendar.current.startOfDay(for: .now)
        let lastReset = UserDefaults.standard.object(forKey: "reminder_last_reset") as? Date ?? .distantPast
        if Calendar.current.startOfDay(for: lastReset) < today {
            UserDefaults.standard.set(Date.now, forKey: "reminder_last_reset")
        }
    }

    // MARK: - Content
    private func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "💱 أسعار UR اليومية"
        content.sound = .default

        if let priceString = UserDefaults.standard.string(forKey: "last_known_usd_iqd"),
           let price = Decimal(string: priceString) {
            content.body = "الدولار الأمريكي: \(price.formatted()) دينار عراقي — افتح التطبيق لتفاصيل أكثر."
        } else {
            content.body = "افتح التطبيق للاطّلاع على آخر أسعار العملات."
        }

        return content
    }

    // MARK: - Identifiers
    private func identifier(for weekday: Int) -> String {
        "ur_daily_reminder_\(weekday)"
    }

    private func identifiers() -> [String] {
        (1...7).map(identifier(for:))
    }

    /// نص وصفي للأيام المختارة
    var weekdaysText: String {
        if weekdays.count == 7 { return "كل يوم" }
        if weekdays.count == 5 && weekdays == Set([2, 3, 4, 5, 6]) { return "أيام الأسبوع" }
        if weekdays.count == 2 && weekdays == Set([1, 7]) { return "عطلة نهاية الأسبوع" }

        let names: [Int: String] = [
            1: "الأحد", 2: "الاثنين", 3: "الثلاثاء", 4: "الأربعاء",
            5: "الخميس", 6: "الجمعة", 7: "السبت"
        ]
        let sorted = weekdays.sorted().compactMap { names[$0] }
        return sorted.joined(separator: "، ")
    }

    /// نص الوقت
    var timeText: String {
        let date = Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: .now
        ) ?? .now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
