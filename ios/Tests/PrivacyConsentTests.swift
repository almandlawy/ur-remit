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

    func testOptOutDeletesSDKAnonymousIDFile() throws {
        let library = try XCTUnwrap(FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first)
        let file = library.appendingPathComponent(URMetaMeasurement.anonymousIDFileName)
        try Data(#"{"anon_id":"XZtest"}"#.utf8).write(to: file)
        URMetaMeasurement.setConsent(false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testAnonymousIDFileNameMatchesPinnedSDK() throws {
        // Fails if a Meta SDK update renames the file, so the reset can be revisited.
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/spm/checkouts/facebook-ios-sdk/FBSDKCoreKit_Basics/FBSDKCoreKit_Basics/FBSDKBasicUtility.m")
        guard let text = try? String(contentsOf: source, encoding: .utf8) else {
            throw XCTSkip("SDK checkout not available at \(source.path)")
        }
        XCTAssertTrue(text.contains("@\"\(URMetaMeasurement.anonymousIDFileName)\""))
    }

    func testConsentIsStoredEvenWhenMetaUnavailable() {
        URMetaMeasurement.setConsent(true)
        XCTAssertTrue(URPrivacyPreferences.metaMeasurementConsent)
        URMetaMeasurement.setConsent(false)
        XCTAssertFalse(URPrivacyPreferences.metaMeasurementConsent)
    }
}
