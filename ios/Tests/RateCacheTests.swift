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

    func testFreshRemoteRatesAreReturnedWhenCacheWriteFails() async throws {
        let freshRate = makeRate(
            id: UUID(),
            arabic: "بغداد إلى دبي",
            english: "Baghdad to Dubai",
            sourceCurrency: "USD",
            destinationCurrency: "AED"
        )
        let oldRate = makeRate(
            id: UUID(),
            arabic: "بغداد إلى لندن",
            english: "Baghdad to London",
            sourceCurrency: "USD",
            destinationCurrency: "GBP"
        )
        let repository = DefaultRatesRepository(
            remote: StubRatesAPIClient(result: .success([freshRate])),
            cache: StubRatesCache(cachedRates: [oldRate], failWrites: true)
        )

        let snapshot = try await repository.loadRates()

        XCTAssertEqual(snapshot.rates, [freshRate])
        XCTAssertFalse(snapshot.isFromCache)
        XCTAssertTrue(snapshot.cacheWriteFailed)
    }

    func testRemoteRateFailureUsesCachedRates() async throws {
        let cachedRate = makeRate(
            id: UUID(),
            arabic: "بغداد إلى دبي",
            english: "Baghdad to Dubai",
            sourceCurrency: "USD",
            destinationCurrency: "AED"
        )
        let repository = DefaultRatesRepository(
            remote: StubRatesAPIClient(result: .failure(.unavailable)),
            cache: StubRatesCache(cachedRates: [cachedRate], failWrites: false)
        )

        let snapshot = try await repository.loadRates()

        XCTAssertEqual(snapshot.rates, [cachedRate])
        XCTAssertTrue(snapshot.isFromCache)
        XCTAssertFalse(snapshot.cacheWriteFailed)
    }

    func testOAuthCallbackParsesAuthorizationCodeFromQuery() throws {
        let url = try XCTUnwrap(URL(string: "urremit://auth/callback?code=one-time-code"))

        let callback = try XCTUnwrap(SupabaseOAuthCallback.parse(url))

        XCTAssertEqual(callback.code, "one-time-code")
        XCTAssertNil(callback.accessToken)
        XCTAssertFalse(callback.hasError)
    }

    func testOAuthCallbackParsesLegacyTokensFromFragmentWithoutCrashingOnDuplicates() throws {
        let url = try XCTUnwrap(URL(string: "urremit://auth/callback#access_token=access&access_token=duplicate&refresh_token=refresh"))

        let callback = try XCTUnwrap(SupabaseOAuthCallback.parse(url))

        XCTAssertEqual(callback.accessToken, "access")
        XCTAssertEqual(callback.refreshToken, "refresh")
    }

    func testOAuthCallbackRejectsUnexpectedRoutesAndIdentifiesProviderErrors() throws {
        let unrelatedURL = try XCTUnwrap(URL(string: "urremit://elsewhere/callback?code=ignored"))
        let errorURL = try XCTUnwrap(URL(string: "urremit://auth/callback?error=access_denied&error_description=Cancelled"))

        XCTAssertNil(SupabaseOAuthCallback.parse(unrelatedURL))
        XCTAssertEqual(SupabaseOAuthCallback.parse(errorURL)?.hasError, true)
    }

    func testTransferTrackingRejectsMalformedReferencesBeforeNetworking() async {
        let client = URLSessionAPIClient(configuration: APIConfiguration(
            baseURL: URL(string: "https://example.invalid/api/")!,
            timeout: .seconds(5)
        ))

        do {
            _ = try await client.track(reference: "../admin")
            XCTFail("Malformed tracking references must be rejected.")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .invalidInput)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testRatesViewModelKeepsLoadedRatesWhenRefreshFails() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rate = Rate(
            id: UUID(), routeNameArabic: "بغداد إلى دبي", routeNameEnglish: "Baghdad to Dubai",
            sourceCurrency: "USD", destinationCurrency: "AED", buy: Decimal(string: "3.675"), sell: nil,
            feeFixed: nil, feePercent: nil,
            updatedAt: now, sourceTimestamp: now, version: 1, staleAfter: now.addingTimeInterval(900)
        )
        let repository = SequencedRatesRepository([
            .success(RatesSnapshot(rates: [rate], isFromCache: false)),
            .failure(RepositoryTestError.unavailable)
        ])
        let model = RatesViewModel(repository: repository)

        await model.load()
        await model.load()

        guard case .failed(let snapshot) = model.state else {
            XCTFail("Expected the refresh to fail while retaining the previous snapshot.")
            return
        }
        XCTAssertEqual(snapshot?.rates, [rate])
    }

    func testRateListFilterSearchesLocalizedNamesAndCurrenciesAndPrioritizesFavorites() {
        let favoriteID = UUID()
        let favorite = makeRate(
            id: favoriteID,
            arabic: "بغداد إلى دبي",
            english: "Baghdad to Dubai",
            sourceCurrency: "USD",
            destinationCurrency: "AED"
        )
        let anotherRate = makeRate(
            id: UUID(),
            arabic: "أربيل إلى إسطنبول",
            english: "Erbil to Istanbul",
            sourceCurrency: "USD",
            destinationCurrency: "TRY"
        )
        let usdRate = makeRate(
            id: UUID(),
            arabic: "بغداد إلى لندن",
            english: "Baghdad to London",
            sourceCurrency: "GBP",
            destinationCurrency: "USD"
        )

        let englishRates = RateListFilter.matchingRates(
            [anotherRate, favorite, usdRate],
            searchText: "usd",
            favoriteIDs: [favoriteID],
            favoritesOnly: false,
            locale: Locale(identifier: "en")
        )
        let arabicRates = RateListFilter.matchingRates(
            [anotherRate, favorite, usdRate],
            searchText: "لندن",
            favoriteIDs: [],
            favoritesOnly: false,
            locale: Locale(identifier: "ar")
        )
        let favorites = RateListFilter.matchingRates(
            [anotherRate, favorite, usdRate],
            searchText: "",
            favoriteIDs: [favoriteID],
            favoritesOnly: true,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(englishRates.map(\.id), [favorite.id, usdRate.id, anotherRate.id])
        XCTAssertEqual(arabicRates.map(\.id), [usdRate.id])
        XCTAssertEqual(favorites.map(\.id), [favorite.id])
    }

    func testTransferAmountRequiresPositiveDecimalInTheSelectedLocaleWithoutAnArbitraryCap() {
        XCTAssertEqual(
            TransferAmount.positiveDecimal(from: "12.50", locale: Locale(identifier: "en_US")),
            Decimal(string: "12.50")
        )
        XCTAssertEqual(
            TransferAmount.positiveDecimal(from: "12,50", locale: Locale(identifier: "de_DE")),
            Decimal(string: "12.50")
        )
        XCTAssertNotNil(
            TransferAmount.positiveDecimal(from: "1000000000", locale: Locale(identifier: "en_US"))
        )
        XCTAssertNil(TransferAmount.positiveDecimal(from: "0", locale: Locale(identifier: "en_US")))
        XCTAssertNil(TransferAmount.positiveDecimal(from: "-1", locale: Locale(identifier: "en_US")))
        XCTAssertNil(TransferAmount.positiveDecimal(from: "not-an-amount", locale: Locale(identifier: "en_US")))
    }

    private func makeRate(
        id: UUID,
        arabic: String,
        english: String,
        sourceCurrency: String,
        destinationCurrency: String
    ) -> Rate {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        return Rate(
            id: id,
            routeNameArabic: arabic,
            routeNameEnglish: english,
            sourceCurrency: sourceCurrency,
            destinationCurrency: destinationCurrency,
            buy: Decimal(string: "1.5"),
            sell: nil,
            feeFixed: nil,
            feePercent: nil,
            updatedAt: now,
            sourceTimestamp: now,
            version: 1,
            staleAfter: now.addingTimeInterval(900)
        )
    }
}

private enum RepositoryTestError: Error, Sendable { case unavailable }

private actor StubRatesAPIClient: APIClient {
    private let result: Result<[Rate], RepositoryTestError>

    init(result: Result<[Rate], RepositoryTestError>) {
        self.result = result
    }

    func rates() async throws -> [Rate] { try result.get() }
    func offices() async throws -> [Office] { throw RepositoryTestError.unavailable }
    func track(reference: String) async throws -> TransferTracking { throw RepositoryTestError.unavailable }
    func verifyAgent(code: String) async throws -> AgentVerification { throw RepositoryTestError.unavailable }
}

private actor StubRatesCache: RatesCache {
    private let cachedRates: [Rate]
    private let failWrites: Bool

    init(cachedRates: [Rate], failWrites: Bool) {
        self.cachedRates = cachedRates
        self.failWrites = failWrites
    }

    func read() throws -> [Rate] { cachedRates }

    func write(_ rates: [Rate]) throws {
        if failWrites { throw RepositoryTestError.unavailable }
    }
}

private actor SequencedRatesRepository: RatesRepository {
    private var responses: [Result<RatesSnapshot, RepositoryTestError>]

    init(_ responses: [Result<RatesSnapshot, RepositoryTestError>]) {
        self.responses = responses
    }

    func loadRates() async throws -> RatesSnapshot {
        guard !responses.isEmpty else { throw RepositoryTestError.unavailable }
        return try responses.removeFirst().get()
    }
}
