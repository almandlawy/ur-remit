import Foundation
import UserNotifications

@MainActor
final class DeleteAccountService {
    static let shared = DeleteAccountService()

    enum DeleteError: LocalizedError {
        case remoteDeletionRequired

        var errorDescription: String? {
            "حذف الحساب غير متاح حتى يُضاف مسار الحذف إلى الخادم."
        }
    }

    private init() {}

    func deleteAccount(remoteDelete: (() async throws -> Void)? = nil) async throws {
        guard let remoteDelete else {
            throw DeleteError.remoteDeletionRequired
        }

        try await remoteDelete()
        try await clearAllLocalData()
    }

    private func clearAllLocalData() async throws {
        FavoritesStore.shared.removeAll()

        await clearPriceAlerts()
        await clearDailyReminder()
        try clearRatesCache()

        await URAuthService.live.signOut()

        [
            "favorite_rate_ids",
            "price_alerts",
            "price_alerts_fired",
            "alerts_last_reset",
            "daily_reminder_enabled",
            "daily_reminder_hour",
            "daily_reminder_minute",
            "daily_reminder_weekdays",
            "reminder_last_reset",
            "last_known_usd_iqd"
        ].forEach(UserDefaults.standard.removeObject(forKey:))
    }

    private func clearPriceAlerts() async {
        let center = UNUserNotificationCenter.current()
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("price_alert_") }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)

        await PriceAlertManager.shared.removeAllAlerts()
    }

    private func clearDailyReminder() async {
        await DailyReminderManager.shared.clearSettings()
    }

    private func clearRatesCache() throws {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let cacheURL = cacheDirectory.appending(path: "ur-rates-v1.json")
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        try FileManager.default.removeItem(at: cacheURL)
    }
}
