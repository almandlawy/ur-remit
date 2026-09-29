import XCTest
@testable import URRemit

final class RateCacheTests: XCTestCase {
    func testISO8601ParserAcceptsProductionFractionalTimestamps() {
        XCTAssertNotNil(ISO8601DateParser.date(from: "2026-09-25T02:08:08.843891+00:00"))
        XCTAssertNotNil(ISO8601DateParser.date(from: "2026-09-23T21:15:00.000Z"))
        XCTAssertNotNil(ISO8601DateParser.date(from: "2026-09-23T21:15:00Z"))
    }

    func testFileCacheRoundTripPreservesDecimalAndFreshness() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = FileRatesCache(fileURL: url)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rate = Rate(
            id: UUID(), routeNameArabic: "بغداد إلى دبي", routeNameEnglish: "Baghdad to Dubai",
            sourceCurrency: "USD", destinationCurrency: "AED", buy: Decimal(string: "3.675"), sell: nil,
            feeFixed: nil, feePercent: nil,
            updatedAt: now, sourceTimestamp: now, version: 7, staleAfter: now.addingTimeInterval(900)
        )
        try await cache.write([rate])
        let restored = try await cache.read()
        XCTAssertEqual(restored, [rate])
    }
}
