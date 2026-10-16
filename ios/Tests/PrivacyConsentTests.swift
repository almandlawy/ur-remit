import XCTest
@testable import URRemit

@MainActor
final class PrivacyConsentTests: XCTestCase {
    private let keys = [URPrivacyPreferences.usageAnalyticsKey, URPrivacyPreferences.metaMeasurementKey]

    override func setUp() async throws { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }
    override func tearDown() async throws { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }

    func testDefaultsKeepUsageAnalyticsOnAndMetaMeasurementOff() {
        XCTAssertTrue(URPrivacyPreferences.usageAnalyticsEnabled)
        XCTAssertFalse(URPrivacyPreferences.metaMeasurementConsent)
    }

    func testUsageAnalyticsOptOutIsRespected() {
        UserDefaults.standard.set(false, forKey: URPrivacyPreferences.usageAnalyticsKey)
        XCTAssertFalse(URPrivacyPreferences.usageAnalyticsEnabled)
    }

    func testMetaUnavailableWithoutConfiguredTokenAndBuildFlag() {
        // Test builds carry no real client token and META_APP_EVENTS_ENABLED = NO.
        XCTAssertFalse(URMetaMeasurement.isAvailableInBuild)
    }

    func testConsentIsStoredEvenWhenMetaUnavailable() {
        URMetaMeasurement.setConsent(true)
        XCTAssertTrue(URPrivacyPreferences.metaMeasurementConsent)
        URMetaMeasurement.setConsent(false)
        XCTAssertFalse(URPrivacyPreferences.metaMeasurementConsent)
    }
}
