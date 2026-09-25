import Foundation

enum APIEnvironment: String, Sendable { case development, staging, production }

struct APIConfiguration: Sendable {
    let baseURL: URL
    let timeout: Duration

    static var current: APIConfiguration {
        #if DEBUG
        APIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080/api/v1/mobile/")!, timeout: .seconds(15))
        #else
        APIConfiguration(baseURL: URL(string: "https://yqvcoomjunwokyxwofvt.supabase.co/functions/v1/mobile-api/")!, timeout: .seconds(15))
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
    func offices() async throws -> [Office]
    func track(reference: String) async throws -> TransferTracking
    func verifyAgent(code: String) async throws -> AgentVerification
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
        try await get("rates", as: [Rate].self)
    }

    func offices() async throws -> [Office] { try await get("offices", as: [Office].self) }

    func track(reference: String) async throws -> TransferTracking {
        try await get("transfers/\(reference)/status", as: TransferTracking.self)
    }

    func verifyAgent(code: String) async throws -> AgentVerification {
        var components = URLComponents(url: configuration.baseURL.appending(path: "agents/verify"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return try await get(components.url!, as: AgentVerification.self)
    }

    private func get<Value: Decodable & Sendable>(_ path: String, as type: Value.Type) async throws -> Value {
        try await get(configuration.baseURL.appending(path: path), as: type)
    }

    private func get<Value: Decodable & Sendable>(_ url: URL, as type: Value.Type) async throws -> Value {
        var request = URLRequest(url: url)
        request.timeoutInterval = Double(configuration.timeout.components.seconds)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw NetworkError.httpStatus(http.statusCode) }
            do { return try decoder.decode(APIEnvelope<Value>.self, from: data).data }
            catch { throw NetworkError.decoding }
        } catch let error as NetworkError { throw error }
        catch { throw NetworkError.transport }
    }
}

private struct APIEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value
}
