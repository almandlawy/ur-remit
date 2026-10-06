import XCTest
@testable import URRemit

final class AnalyticsFailingProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}

@MainActor
final class URAnalyticsTests: XCTestCase {
    func testInstallationPersistsAndSessionsDoNotRepeatOnRerender() {
        let suite = "ur.analytics.tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = URAnalytics(defaults: defaults, enabled: false)
        let installation = defaults.string(forKey: "ur.analytics.installation")
        XCTAssertNotNil(installation.flatMap(UUID.init(uuidString:)))
        _ = URAnalytics(defaults: defaults, enabled: false)
        XCTAssertEqual(defaults.string(forKey: "ur.analytics.installation"), installation)
        XCTAssertTrue(first.pendingEventNames.isEmpty)
    }
    func testOfflineEventsRemainQueuedWithoutLeakingAuthenticationTokens() async throws {
        let suite = "ur.analytics.tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AnalyticsFailingProtocol.self]
        let transport = URLSession(configuration: configuration)
        let analytics = URAnalytics(defaults: defaults, projectURL: URL(string: "https://analytics.example"), publishableKey: "public-test-key", transport: transport)
        analytics.activated()
        analytics.activated()
        XCTAssertEqual(analytics.pendingEventNames.filter { $0 == "app_first_open" }.count, 1)
        XCTAssertEqual(analytics.pendingEventNames.filter { $0 == "session_start" }.count, 1)
        analytics.identify(accessToken: "sensitive-test-token")
        analytics.track(.loginCompleted)
        let saved = defaults.data(forKey: "ur.analytics.outbox")!
        XCTAssertFalse(String(decoding: saved, as: UTF8.self).contains("sensitive-test-token"))
        XCTAssertFalse(String(decoding: saved, as: UTF8.self).contains("login_completed"))
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertTrue(analytics.pendingEventNames.contains("app_first_open"))
        XCTAssertFalse(defaults.bool(forKey: "ur.analytics.firstOpenSent"))
    }
    func testExternalContactsAndDownloadsStayDistinct() {
        let suite = "ur.analytics.tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AnalyticsFailingProtocol.self]
        let analytics = URAnalytics(defaults: defaults, projectURL: URL(string: "https://analytics.example"), publishableKey: "public-test-key", transport: URLSession(configuration: configuration))
        analytics.external(URL(string: "https://wa.me/12345")!)
        analytics.external(URL(string: "tel:12345")!)
        analytics.external(URAnalytics.appStoreURL)
        analytics.external(URL(string: "https://www.urremit.com/privacy")!)
        XCTAssertEqual(analytics.pendingEventNames.filter { $0 == "contact_attempted" }.count, 2)
        XCTAssertEqual(analytics.pendingEventNames.filter { $0 == "app_store_clicked" }.count, 1)
        XCTAssertFalse(analytics.pendingEventNames.contains("app_first_open"))
        let persisted = String(decoding: defaults.data(forKey: "ur.analytics.outbox")!, as: UTF8.self)
        XCTAssertFalse(persisted.contains("12345"))
    }
}
