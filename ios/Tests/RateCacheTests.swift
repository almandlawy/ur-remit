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

    func testAdminRateRetryPolicyRetriesTransientFailuresOnlyAndStopsAfterThreeAttempts() {
        XCTAssertTrue(AdminRateRetryPolicy.shouldRetry(.networkUnavailable, attempt: 1))
        XCTAssertTrue(AdminRateRetryPolicy.shouldRetry(.serverFailure(statusCode: 503), attempt: 2))
        XCTAssertTrue(AdminRateRetryPolicy.shouldRetry(.requestFailed, attempt: 1))
        XCTAssertFalse(AdminRateRetryPolicy.shouldRetry(.unauthorized, attempt: 1))
        XCTAssertFalse(AdminRateRetryPolicy.shouldRetry(.forbidden, attempt: 1))
        XCTAssertFalse(AdminRateRetryPolicy.shouldRetry(.invalidInput, attempt: 1))
        XCTAssertFalse(AdminRateRetryPolicy.shouldRetry(.notFound, attempt: 1))
        XCTAssertFalse(AdminRateRetryPolicy.shouldRetry(.serverFailure(statusCode: 503), attempt: 3))
        XCTAssertEqual(AdminRateRetryPolicy.delayMilliseconds(after: 1), 500)
        XCTAssertEqual(AdminRateRetryPolicy.delayMilliseconds(after: 2), 1_000)
    }

    func testAdminRateUpdateEncodesIdempotencyKeyForEdgeFunction() throws {
        let requestID = UUID()
        let body = RateUpdateBody(
            buy: "3.67",
            sell: nil,
            feeFixed: "2",
            requestID: requestID.uuidString
        )
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any]
        )

        XCTAssertEqual(json["requestId"] as? String, requestID.uuidString)
        XCTAssertNil(json["requestID"])
    }

    func testGuestFacingMobileAPIRequestsNeverAttachAnAuthorizationHeader() async throws {
        // Guests must be able to browse rates/offices/tracking without ever signing in (the app-root
        // gate that used to force `AuthView` on every launch has been removed) — this locks in that
        // the mobile API client itself never depends on a bearer token for these calls.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = URLSessionAPIClient(
            configuration: APIConfiguration(baseURL: URL(string: "https://example.invalid/api/")!, timeout: .seconds(5)),
            session: session
        )
        RecordingURLProtocol.responseData = Data(#"{"data":[]}"#.utf8)

        _ = try await client.rates()
        XCTAssertNil(RecordingURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"))

        _ = try await client.offices()
        XCTAssertNil(RecordingURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func testRateReportsStaleOnlyAfterItsOwnSourceTimestampCrossesTheServerComputedCutoffNotLocalFetchTime() {
        let sourceTimestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let rate = makeRate(
            id: UUID(),
            arabic: "بغداد إلى دبي",
            english: "Baghdad to Dubai",
            sourceCurrency: "USD",
            destinationCurrency: "AED",
            sourceTimestamp: sourceTimestamp,
            staleAfter: sourceTimestamp.addingTimeInterval(900)
        )

        XCTAssertFalse(rate.isStale(asOf: sourceTimestamp.addingTimeInterval(899)))
        XCTAssertTrue(rate.isStale(asOf: sourceTimestamp.addingTimeInterval(900)))
        // A fetch/render happening "now" (far later than the source's real timestamp) must not make
        // an old price look fresh — staleness only depends on the source's own timestamp.
        XCTAssertTrue(rate.isStale(asOf: sourceTimestamp.addingTimeInterval(60 * 60 * 24 * 2)))
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

    private func makeRate(
        id: UUID,
        arabic: String,
        english: String,
        sourceCurrency: String,
        destinationCurrency: String,
        sourceTimestamp: Date,
        staleAfter: Date
    ) -> Rate {
        Rate(
            id: id,
            routeNameArabic: arabic,
            routeNameEnglish: english,
            sourceCurrency: sourceCurrency,
            destinationCurrency: destinationCurrency,
            buy: Decimal(string: "1.5"),
            sell: nil,
            feeFixed: nil,
            feePercent: nil,
            updatedAt: sourceTimestamp,
            sourceTimestamp: sourceTimestamp,
            version: 1,
            staleAfter: staleAfter
        )
    }

    /// Guards the in-app admin rate editor's client-side format check against drifting from the
    /// backend's `decimal` Zod schema (`backend/src/admin-routes.ts`): an optional leading `-`, up to
    /// 16 integer digits, up to 8 fractional digits, no thousands separators. Negative values are
    /// accepted so admins can record discount/adjustment routes with a negative fee.
    func testAdminRateInputValidatorAcceptsBackendDecimalFormatAndRejectsMalformedInput() {
        XCTAssertTrue(AdminRateInputValidator.isValidDecimalOrAbsent(nil))
        XCTAssertTrue(AdminRateInputValidator.isValidDecimalOrAbsent("3.675"))
        XCTAssertTrue(AdminRateInputValidator.isValidDecimalOrAbsent("1500"))
        XCTAssertTrue(AdminRateInputValidator.isValidDecimalOrAbsent("0.00000001"))
        XCTAssertEqual(AdminRateInputValidator.normalizedDecimalInput("٣٫٦٧٥"), "3.675")
        XCTAssertEqual(AdminRateInputValidator.normalizedDecimalInput("۳.۶۷۵"), "3.675")
        XCTAssertEqual(AdminRateInputValidator.normalizedDecimalInput("١٥٠٠"), "1500")
        XCTAssertTrue(AdminRateInputValidator.isValidDecimalOrAbsent("  "))
        XCTAssertTrue(AdminRateInputValidator.isValidDecimalOrAbsent("-1.5"))
        XCTAssertEqual(AdminRateInputValidator.normalizedDecimalInput("-1.5"), "-1.5")
        XCTAssertEqual(AdminRateInputValidator.normalizedDecimalInput("-0.00000001"), "-0.00000001")
        XCTAssertFalse(AdminRateInputValidator.isValidDecimalOrAbsent("1-5"))
        XCTAssertFalse(AdminRateInputValidator.isValidDecimalOrAbsent("--1.5"))
        XCTAssertFalse(AdminRateInputValidator.isValidDecimalOrAbsent("-"))
        XCTAssertFalse(AdminRateInputValidator.isValidDecimalOrAbsent("1,500"))
        XCTAssertFalse(AdminRateInputValidator.isValidDecimalOrAbsent("abc"))
        XCTAssertFalse(AdminRateInputValidator.isValidDecimalOrAbsent("1.234567890"))
        XCTAssertNil(AdminRateInputValidator.normalizedDecimalInput("3٫6.75"))
        XCTAssertNil(AdminRateInputValidator.normalizedDecimalInput(""))
    }

    func testAdminLoginUnauthorizedIsReportedAsInvalidCredentialsNotExpiredSession() {
        let loginError = AdminAPIError.loginFailure(for: .unauthorized)
        let dashboardError = AdminAPIError.loginFailure(for: .requestFailed)

        XCTAssertEqual(loginError.errorDescription, "بيانات الدخول غير صحيحة أو الحساب غير متاح.")
        XCTAssertEqual(dashboardError.errorDescription, AdminAPIError.requestFailed.errorDescription)
        XCTAssertEqual(AdminAPIError.unauthorized.errorDescription, "انتهت جلسة الإدارة. سجّل الدخول مجدداً.")
    }

    func testAdminRateDraftIgnoresDecimalFormattingOnlyChanges() {
        let rate = makeRate(
            id: UUID(),
            arabic: "بغداد إلى دبي",
            english: "Baghdad to Dubai",
            sourceCurrency: "USD",
            destinationCurrency: "AED"
        )

        XCTAssertTrue(
            AdminRateDraft.changes(for: rate, buy: "1.5000", sell: "", feeFixed: "").isEmpty
        )
    }

    func testAdminRateDraftSummarizesChangedAndClearedValuesBeforeSaving() {
        let rate = makeRate(
            id: UUID(),
            arabic: "بغداد إلى دبي",
            english: "Baghdad to Dubai",
            sourceCurrency: "USD",
            destinationCurrency: "AED"
        )

        let changes = AdminRateDraft.changes(for: rate, buy: "1.75", sell: "", feeFixed: "")

        XCTAssertEqual(changes, [
            AdminRateChange(title: "شراء", previousValue: "1.5", newValue: "1.75")
        ])
        XCTAssertEqual(AdminRateDraft.summary(of: changes), "شراء: 1.5 ← 1.75")
    }

    func testAdminRateDraftRejectsRemovingEveryRateValueButKeepsPercentageFeeRatesValid() {
        let rate = makeRate(
            id: UUID(),
            arabic: "بغداد إلى دبي",
            english: "Baghdad to Dubai",
            sourceCurrency: "USD",
            destinationCurrency: "AED"
        )

        XCTAssertFalse(AdminRateDraft.hasAnyValue(for: rate, buy: "", sell: "", feeFixed: ""))

        let percentageFeeRate = Rate(
            id: rate.id,
            routeNameArabic: rate.routeNameArabic,
            routeNameEnglish: rate.routeNameEnglish,
            sourceCurrency: rate.sourceCurrency,
            destinationCurrency: rate.destinationCurrency,
            buy: nil,
            sell: nil,
            feeFixed: nil,
            feePercent: Decimal(string: "1.5"),
            updatedAt: rate.updatedAt,
            sourceTimestamp: rate.sourceTimestamp,
            version: rate.version,
            staleAfter: rate.staleAfter
        )
        XCTAssertTrue(AdminRateDraft.hasAnyValue(for: percentageFeeRate, buy: "", sell: "", feeFixed: ""))
    }

    /// Regression guard: `debugBaseURL` (mobile routes) and `adminBaseURL` (admin routes) must target
    /// the same host+port, since both are served by the single local backend process. A drift here
    /// previously left rates/tracking silently unreachable on the Simulator while admin login still
    /// appeared to work — this locks the two together and to the backend's actual default port.
    func testDebugBaseURLsShareTheSameHostAndPortAsTheAdminBaseURL() {
        let configuration = APIConfiguration.current
        let mobileComponents = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)
        let adminComponents = URLComponents(url: configuration.adminBaseURL, resolvingAgainstBaseURL: false)
        XCTAssertEqual(mobileComponents?.host, adminComponents?.host)
        XCTAssertEqual(mobileComponents?.port, adminComponents?.port)
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

/// Test-only `URLProtocol` that records the last request it intercepted and returns a canned
/// response, so tests can assert on request-building behavior (e.g. headers) without a real network
/// call. Access is serial within each test (one `await` at a time), so `nonisolated(unsafe)` storage
/// is safe here.
private final class RecordingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var responseData = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        RecordingURLProtocol.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: RecordingURLProtocol.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
