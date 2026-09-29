//import Foundation
import UserNotifications
import Observation

@Observable
@MainActor
final class PriceAlertManager {
    static let shared = PriceAlertManager()

    private let alertsKey = "price_alerts"
    private let firedKey = "price_alerts_fired"

    private(set) var alerts: [UUID: Decimal] = [:]
    private(set) var firedToday: Set<UUID> = []
    private(set) var isAuthorized = false

    private init() { load() }

    // MARK: - Permission
    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    // MARK: - CRUD
    func setAlert(for id: UUID, threshold: Decimal) {
        alerts[id] = threshold
        firedToday.remove(id)
        save()
    }

    func removeAlert(for id: UUID) {
        alerts.removeValue(forKey: id)
        firedToday.remove(id)
        save()
    }

    func removeAllAlerts() async {
        alerts.removeAll()
        firedToday.removeAll()
        UserDefaults.standard.removeObject(forKey: alertsKey)
        UserDefaults.standard.removeObject(forKey: firedKey)
        UserDefaults.standard.removeObject(forKey: "alerts_last_reset")

        let center = UNUserNotificationCenter.current()
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("price_alert_") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func threshold(for id: UUID) -> Decimal? { alerts[id] }

    // MARK: - Fire
    func fire(rate: Rate, current: Decimal, threshold: Decimal) async {
        guard !firedToday.contains(rate.id) else { return }
        firedToday.insert(rate.id)
        saveFired()

        let content = UNMutableNotificationContent()
        content.title = "🔔 تنبيه سعر"
        content.body = "\(rate.routeNameArabic) وصل إلى \(current.formatted()) (الهدف: \(threshold.formatted()))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "price_alert_\(rate.id.uuidString)_fired_\(Date.now.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func resetFiredIfNewDay() {
        let today = Calendar.current.startOfDay(for: .now)
        let lastReset = UserDefaults.standard.object(forKey: "alerts_last_reset") as? Date ?? .distantPast
        if Calendar.current.startOfDay(for: lastReset) < today {
            firedToday.removeAll()
            saveFired()
            UserDefaults.standard.set(Date.now, forKey: "alerts_last_reset")
        }
    }

    // MARK: - Persistence
    private func load() {
        if let raw = UserDefaults.standard.dictionary(forKey: alertsKey) as? [String: String] {
            alerts = raw.reduce(into: [:]) { result, pair in
                if let uuid = UUID(uuidString: pair.key), let value = Decimal(string: pair.value) {
                    result[uuid] = value
                }
            }
        }
        if let raw = UserDefaults.standard.array(forKey: firedKey) as? [String] {
            firedToday = Set(raw.compactMap(UUID.init(uuidString:)))
        }
    }

    private func save() {
        let raw = alerts.reduce(into: [String: String]()) { result, pair in
            result[pair.key.uuidString] = "\(pair.value)"
        }
        UserDefaults.standard.set(raw, forKey: alertsKey)
    }

    private func saveFired() {
        UserDefaults.standard.set(firedToday.map(\.uuidString), forKey: firedKey)
    }
}//  PriceAlertManager.swift
//  URRemit
//
//  Created by RIFAD on 27/09/2026.
//

import Foundation
