import Foundation

protocol RatesCache: Sendable {
    func read() async throws -> [Rate]
    func write(_ rates: [Rate]) async throws
    func lastWrittenAt() async throws -> Date
}

actor FileRatesCache: RatesCache {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.fileURL = fileURL ?? base.appending(path: "ur-rates-v1.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = ISO8601DateParser.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
            }
            return date
        }
    }

    func read() throws -> [Rate] {
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([Rate].self, from: data)
    }

    func write(_ rates: [Rate]) throws {
        let data = try encoder.encode(rates)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func lastWrittenAt() throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let date = attributes[.modificationDate] as? Date else {
            throw CocoaError(.fileReadUnknown)
        }
        return date
    }
}

struct DefaultRatesRepository: RatesRepository {
    let remote: any APIClient
    let cache: any RatesCache

    func loadRates() async throws -> RatesSnapshot {
        do {
            let rates = try await remote.rates()
            try await cache.write(rates)
            return RatesSnapshot(rates: rates, isFromCache: false, fetchedAt: Date())
        } catch {
            let cached = try await cache.read()
            let cachedAt = try await cache.lastWrittenAt()
            return RatesSnapshot(rates: cached, isFromCache: true, fetchedAt: cachedAt)
        }
    }
}
