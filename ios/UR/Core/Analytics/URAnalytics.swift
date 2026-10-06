import Foundation
import SwiftUI
import UIKit

// Product analytics: no amounts, rates, emails, OTPs, URLs or advertising identifiers.
enum UREvent: String, Codable, Sendable, CaseIterable {
    case appFirstOpen = "app_first_open", appOpen = "app_open", sessionStart = "session_start"
    case signupStarted = "signup_started", signupCompleted = "signup_completed", loginCompleted = "login_completed", logout
    case homeViewed = "home_viewed", ratesViewed = "rates_viewed", calculatorViewed = "calculator_viewed", officesViewed = "offices_viewed"
    case calculatorUsed = "calculator_used", currencySelected = "currency_selected"
    case whatsappClicked = "whatsapp_clicked", phoneClicked = "phone_clicked", websiteClicked = "website_clicked", officeClicked = "office_clicked", mapClicked = "map_clicked"
    case appStoreClicked = "app_store_clicked", shareAppClicked = "share_app_clicked", contactAttempted = "contact_attempted"
    case languageChanged = "language_changed", errorOccurred = "error_occurred"
}

struct URAnalyticsEvent: Codable, Sendable {
    let id: UUID
    let event_name: String
    let anonymous_id: UUID
    let session_id: UUID
    let platform: String
    let app_version: String
    let build_number: String
    let device_type: String
    let os_version: String
    let locale: String
    let metadata: [String: String]
    let created_at: String
}

@MainActor
final class URAnalytics {
    static let shared = URAnalytics()
    static let appStoreURL = URL(string: "https://apps.apple.com/app/ur-global/id6815895731")!
    static let websiteURL = URL(string: "https://www.urremit.com")!
    private struct Pending { let event: URAnalyticsEvent; let bearer: String? }
    private let defaults: UserDefaults
    private let installation: UUID
    private let endpoint: URL?
    private let key: String
    private let transport: URLSession
    private var sessionID = UUID()
    private var lastBackground: Date?
    private var hasActivated = false
    private var firstOpenQueued = false
    private var bearer: String?
    private var queue: [Pending] = []
    private var sender: Task<Void, Never>?
    private var retryAttempt = 0
    private let enabled: Bool
    private var collectionEnabled: Bool

    var pendingEventNames: [String] { queue.map { $0.event.event_name } }

    init(defaults: UserDefaults = .standard, enabled: Bool = true, projectURL: URL? = nil, publishableKey: String? = nil, transport: URLSession = .shared) {
        self.transport = transport
        self.defaults = defaults
        self.collectionEnabled = defaults.object(forKey: "ur.analytics.enabled") as? Bool ?? true
        self.enabled = enabled && !ProcessInfo.processInfo.arguments.contains("-disableAnalytics") && (projectURL != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil)
        let saved = defaults.string(forKey: "ur.analytics.installation").flatMap(UUID.init(uuidString:))
        installation = saved ?? UUID()
        defaults.set(installation.uuidString, forKey: "ur.analytics.installation")
        let project = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        endpoint = (projectURL ?? URL(string: project))?.appending(path: "functions/v1/app-analytics/events")
        key = publishableKey ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String ?? ""
        if self.enabled, let data = defaults.data(forKey: "ur.analytics.outbox"), let savedEvents = try? JSONDecoder().decode([URAnalyticsEvent].self, from: data) {
            let cutoff = Date().addingTimeInterval(-86400)
            queue = savedEvents.filter { (ISO8601DateFormatter().date(from: $0.created_at) ?? .distantPast) >= cutoff }.suffix(200).map { Pending(event: $0, bearer: nil) }
        }
    }

    func setCollectionEnabled(_ value: Bool) {
        collectionEnabled = value
        defaults.set(value, forKey: "ur.analytics.enabled")
        if !value {
            sender?.cancel(); sender = nil; queue.removeAll(); firstOpenQueued = false
            defaults.removeObject(forKey: "ur.analytics.outbox")
        }
    }
    func identify(accessToken: String?) { bearer = accessToken }
    func activated() {
        guard enabled, collectionEnabled else { return }
        if !hasActivated || (lastBackground.map { Date().timeIntervalSince($0) >= 1800 } ?? false) {
            sessionID = UUID()
            track(.sessionStart)
        }
        hasActivated = true
        lastBackground = nil
        let language = Locale.current.language.languageCode?.identifier ?? "ar"
        if let previous = defaults.string(forKey: "ur.analytics.language"), previous != language {
            track(.languageChanged, metadata: ["ar","en"].contains(language) ? ["language":language] : [:])
        }
        defaults.set(language, forKey: "ur.analytics.language")
        if !defaults.bool(forKey: "ur.analytics.firstOpenSent") && !firstOpenQueued {
            firstOpenQueued = true
            track(.appFirstOpen)
        }
        track(.appOpen)
    }
    func backgrounded() { lastBackground = Date(); persist() }
    func track(_ name: UREvent, metadata: [String: String] = [:]) {
        guard enabled, collectionEnabled, endpoint != nil, !key.isEmpty else { return }
        let event = URAnalyticsEvent(id: UUID(), event_name: name.rawValue, anonymous_id: installation, session_id: sessionID, platform: "ios", app_version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1", build_number: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "12", device_type: UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone", os_version: UIDevice.current.systemVersion, locale: Locale.current.identifier, metadata: metadata, created_at: ISO8601DateFormatter().string(from: Date()))
        queue.append(Pending(event: event, bearer: bearer))
        if queue.count > 200 { queue.removeFirst(queue.count - 200) }
        persist()
        schedule()
    }
    func external(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        if scheme == "tel" { track(.phoneClicked); track(.contactAttempted, metadata: ["channel":"phone"]) }
        else if host == "wa.me" || host == "api.whatsapp.com" || scheme == "whatsapp" { track(.whatsappClicked); track(.contactAttempted, metadata: ["channel":"whatsapp"]) }
        else if host == "maps.apple.com" { track(.mapClicked) }
        else if host == "apps.apple.com" { track(.appStoreClicked) }
        else if host == "urremit.com" || host == "www.urremit.com" {
            track(.websiteClicked)
            if url.path.hasPrefix("/contact") { track(.contactAttempted, metadata: ["channel":"website"]) }
        }
    }
    private func persist() {
        // Authentication tokens stay in memory/Keychain. Only anonymous events survive termination.
        let anonymous = queue.filter { $0.bearer == nil }.map(\.event)
        if let data = try? JSONEncoder().encode(anonymous) { defaults.set(data, forKey: "ur.analytics.outbox") }
    }
    private func schedule() {
        guard collectionEnabled, sender == nil, !queue.isEmpty else { return }
        sender = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            await self?.sendNext()
        }
    }
    private func sendNext() async {
        guard let endpoint, let first = queue.first else { sender = nil; return }
        let batch = Array(queue.prefix(while: { $0.bearer == first.bearer }).prefix(20))
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = first.bearer { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        struct Batch: Encodable { let events: [URAnalyticsEvent] }
        request.httpBody = try? JSONEncoder().encode(Batch(events: batch.map(\.event)))
        do {
            let (_, response) = try await transport.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 202 {
                let ids = Set(batch.map { $0.event.id })
                queue.removeAll { ids.contains($0.event.id) }
                if batch.contains(where: { $0.event.event_name == UREvent.appFirstOpen.rawValue }) { defaults.set(true, forKey: "ur.analytics.firstOpenSent") }
                retryAttempt = 0
            } else if [400,401,413].contains(status) {
                let ids = Set(batch.map { $0.event.id }); queue.removeAll { ids.contains($0.event.id) }
                firstOpenQueued = queue.contains { $0.event.event_name == UREvent.appFirstOpen.rawValue }
            } else { retryAttempt += 1 }
        } catch { retryAttempt += 1 }
        persist()
        if retryAttempt > 0 {
            do { try await Task.sleep(for: .seconds(min(60, pow(2, Double(min(retryAttempt, 6)))))) } catch { sender = nil; return }
        }
        sender = nil
        schedule()
    }
}

private struct URAnalyticsScreen: ViewModifier {
    let event: UREvent
    @State private var visible = false
    func body(content: Content) -> some View {
        content.onAppear { if !visible { visible = true; URAnalytics.shared.track(event) } }.onDisappear { visible = false }
    }
}
extension View {
    func analyticsScreen(_ event: UREvent) -> some View { modifier(URAnalyticsScreen(event: event)) }
}

struct URShareSheet: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: ["UR Global", URAnalytics.appStoreURL], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
