import Foundation
import UserNotifications

actor SmartNotificationService {
    static let shared = SmartNotificationService()
    private let identifiers = ["ur.smart.09", "ur.smart.12", "ur.smart.16"]

    func scheduleDailySummaries() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        for (index, hour) in [9, 12, 16].enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "أسعار UR"
            content.body = hour == 9 ? "افتتاح أسعار اليوم متاح الآن." : hour == 12 ? "راجع تحديث منتصف اليوم قبل التحويل." : "ملخص أسعار المساء جاهز."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour), repeats: true)
            try? await center.add(UNNotificationRequest(identifier: identifiers[index], content: content, trigger: trigger))
        }
    }
}
