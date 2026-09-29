import Foundation

enum APIEnvironment: String, Sendable { case development, staging, production }

struct APIConfiguration: Sendable {
    let baseURL: URL
    let timeout: Duration

    static var current: APIConfiguration {
        #if DEBUG
        APIConfiguration(baseURL: debugBaseURL, timeout: .seconds(15))
        #else
        APIConfiguration(baseURL: URL(string: "https://yqvcoomjunwokyxwofvt.supabase.co/functions/v1/mobile-api/")!, timeout: .seconds(15))
        #endif
    }

    #if DEBUG
    /// The local backend's host during development: the Simulator shares the Mac's network stack, so loopback
    /// reaches it directly, while a physical device is a separate machine on the same Wi-Fi and must target the
    /// Mac's LAN IP instead (override with the UR_DEBUG_API_HOST env var in the Xcode scheme if the IP changes).
    static var debugHost: String {
        #if targetEnvironment(simulator)
        "127.0.0.1"
        #else
        ProcessInfo.processInfo.environment["UR_DEBUG_API_HOST"] ?? "192.168.1.93"
        #endif
    }

    private static var debugBaseURL: URL {
        URL(string: "http://\(debugHost):8081/api/v1/mobile/")!
    }

    /// Base URL for the admin-only endpoints (`/api/v1/admin/...`) exposed by the same local backend.
    /// These routes are never deployed behind the public Supabase Edge Function, so this in-app admin
    /// access only works while the backend is running and reachable on the local network (Debug builds only).
    static var debugAdminBaseURL: URL {
        URL(string: "http://\(debugHost):8081/api/v1/admin/")!
    }
    #endif

    /// The Supabase project URL and publishable (anon) key, used for Auth/PostgREST/Realtime calls
    /// that bypass the local backend entirely (admin sign-in, direct rate writes, rate change
    /// notifications). Both values are public by design — the publishable key only grants whatever
    /// access Postgres RLS allows for the `anon`/`authenticated` roles.
    static var supabaseProjectURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String).flatMap(URL.init(string:))
    }

    static var supabasePublishableKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
    }
}

enum NetworkError: Error, Equatable {
    case invalidResponse
    case invalidInput
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
        let normalizedReference = reference.uppercased()
        guard normalizedReference.range(of: #"^UR-[A-Z0-9]{8}$"#, options: .regularExpression) != nil else {
            throw NetworkError.invalidInput
        }
        return try await get("transfers/\(normalizedReference)/status", as: TransferTracking.self)
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
