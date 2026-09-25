import Foundation

protocol RatesCache: Sendable {
    func read() async throws -> [Rate]
    func write(_ rates: [Rate]) async throws
}

actor FileRatesCache: RatesCache {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.fileURL = fileURL ?? base.appending(path: "ur-rates-v1.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func read() throws -> [Rate] {
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([Rate].self, from: data)
    }

    func write(_ rates: [Rate]) throws {
        let data = try encoder.encode(rates)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}

struct DefaultRatesRepository: RatesRepository {
    let remote: any APIClient
    let cache: any RatesCache

    func loadRates() async throws -> RatesSnapshot {
        do {
            let rates = try await remote.rates()
            try await cache.write(rates)
            return RatesSnapshot(rates: rates, isFromCache: false)
        } catch {
            let cached = try await cache.read()
            return RatesSnapshot(rates: cached, isFromCache: true)
        }
    }
}

