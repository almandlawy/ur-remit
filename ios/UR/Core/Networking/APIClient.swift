import Foundation

enum APIEnvironment: String, Sendable { case development, staging, production }

struct APIConfiguration: Sendable {
    let baseURL: URL
    let timeout: Duration

    static var current: APIConfiguration {
        #if DEBUG
        APIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080/api/v1/mobile/")!, timeout: .seconds(15))
        #else
        APIConfiguration(baseURL: URL(string: "https://api.urremit.com/api/v1/mobile/")!, timeout: .seconds(15))
        #endif
    }
}

enum NetworkError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case decoding
    case transport
}

protocol APIClient: Sendable {
    func rates() async throws -> [Rate]
}

actor URLSessionAPIClient: APIClient {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder

    init(configuration: APIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func rates() async throws -> [Rate] {
        let url = configuration.baseURL.appending(path: "rates")
        var request = URLRequest(url: url)
        request.timeoutInterval = Double(configuration.timeout.components.seconds)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw NetworkError.httpStatus(http.statusCode) }
            do { return try decoder.decode(APIEnvelope<[Rate]>.self, from: data).data }
            catch { throw NetworkError.decoding }
        } catch let error as NetworkError { throw error }
        catch { throw NetworkError.transport }
    }
}

private struct APIEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value
}

