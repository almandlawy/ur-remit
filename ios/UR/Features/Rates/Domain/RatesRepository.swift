protocol RatesRepository: Sendable {
    func loadRates() async throws -> RatesSnapshot
}

struct RatesSnapshot: Sendable {
    let rates: [Rate]
    let isFromCache: Bool
}

