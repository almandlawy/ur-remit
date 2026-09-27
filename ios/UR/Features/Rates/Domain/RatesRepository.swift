protocol RatesRepository: Sendable {
    func loadRates() async throws -> RatesSnapshot
}

struct RatesSnapshot: Sendable {
    let rates: [Rate]
    let isFromCache: Bool
    let cacheWriteFailed: Bool

    init(rates: [Rate], isFromCache: Bool, cacheWriteFailed: Bool = false) {
        self.rates = rates
        self.isFromCache = isFromCache
        self.cacheWriteFailed = cacheWriteFailed
    }
}
