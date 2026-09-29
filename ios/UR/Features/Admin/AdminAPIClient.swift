import Foundation

/// Talks directly to Supabase Auth + PostgREST so the in-app admin screen works everywhere the main
/// app works — including the App Store build — instead of depending on a local Fastify backend that
/// is never reachable once the phone leaves the developer's Wi-Fi. Admin authorization itself is
/// enforced server-side by Postgres RLS (see the `is_admin_user()` policy on `public.rates`): signing
/// in only proves the email/password is correct, `verifyAdmin` confirms the signed-in account is
/// actually listed as an admin.
protocol AdminAPIClient: Sendable {
    func signIn(email: String, password: String) async throws -> AdminSupabaseSession
    func refresh(refreshToken: String, email: String) async throws -> AdminSupabaseSession
    func verifyAdmin(accessToken: String) async throws -> Bool
    func requestPasswordReset(email: String) async throws
    func updateRate(id: UUID, update: AdminRateUpdate, accessToken: String) async throws
}

actor URLSessionAdminAPIClient: AdminAPIClient {
    private let projectURL: URL
    private let apiKey: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Fails to initialize when the app is missing its Supabase configuration (should never happen in
    /// a real build; the same keys back the whole app's networking) so callers can show a clear error
    /// instead of crashing.
    init?(session: URLSession = .shared) {
        guard let projectURL = APIConfiguration.supabaseProjectURL, let apiKey = APIConfiguration.supabasePublishableKey else { return nil }
        self.init(projectURL: projectURL, apiKey: apiKey, session: session)
    }

    /// Direct initializer used by tests to point at a stub server instead of the real Supabase project.
    init(projectURL: URL, apiKey: String, session: URLSession = .shared) {
        self.projectURL = projectURL
        self.apiKey = apiKey
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
    }

    func signIn(email: String, password: String) async throws -> AdminSupabaseSession {
        var request = authRequest(path: "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "password")])
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["email": email, "password": password])
        let token = try await send(request, as: TokenResponse.self)
        return token.session(email: email)
    }

    func refresh(refreshToken: String, email: String) async throws -> AdminSupabaseSession {
        var request = authRequest(path: "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "refresh_token")])
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["refresh_token": refreshToken])
        let token = try await send(request, as: TokenResponse.self)
        return token.session(email: email)
    }

    func verifyAdmin(accessToken: String) async throws -> Bool {
        var request = authRequest(path: "rest/v1/rpc/is_admin_user")
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        return try await send(request, as: Bool.self)
    }

    /// Emails the account a Supabase-hosted "set your password" link. Used because the admin's
    /// Supabase Auth account may not have a password set yet (e.g. it was created via Google sign-in),
    /// and this app must never invent or store a password on the user's behalf.
    func requestPasswordReset(email: String) async throws {
        var request = authRequest(path: "auth/v1/recover")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["email": email])
        _ = try await sendRaw(request)
    }

    func updateRate(id: UUID, update: AdminRateUpdate, accessToken: String) async throws {
        guard !update.isEmpty else { return }
        var request = authRequest(path: "rest/v1/rates", query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())")])
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(RateUpdateBody(update))
        let rows = try await send(request, as: [RateRow].self)
        // RLS silently returns an empty array (HTTP 200) instead of 403 when the write is blocked, so
        // an empty result here means either "not an admin" or "route no longer exists".
        guard !rows.isEmpty else { throw AdminAPIError.forbidden }
    }

    private func authRequest(path: String, query: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(url: projectURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        return request
    }

    private func send<Value: Decodable & Sendable>(_ request: URLRequest, as type: Value.Type) async throws -> Value {
        let data = try await sendRaw(request)
        do { return try decoder.decode(Value.self, from: data) }
        catch { throw AdminAPIError.transport }
    }

    @discardableResult
    private func sendRaw(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch { throw AdminAPIError.transport }
        guard let http = response as? HTTPURLResponse else { throw AdminAPIError.transport }
        switch http.statusCode {
        case 200..<300: return data
        case 400: throw AdminAPIError.invalidCredentials
        case 401, 403: throw AdminAPIError.forbidden
        case 404: throw AdminAPIError.notFound
        case 422: throw AdminAPIError.invalidInput
        default: throw AdminAPIError.transport
        }
    }
}

private struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in" }

    func session(email: String) -> AdminSupabaseSession {
        AdminSupabaseSession(
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}

private struct RateUpdateBody: Encodable {
    let buy: Decimal?
    let sell: Decimal?
    let feeFixed: Decimal?
    let feePercent: Decimal?

    enum CodingKeys: String, CodingKey { case buy, sell, feeFixed = "fee_fixed", feePercent = "fee_percent" }

    init(_ update: AdminRateUpdate) {
        buy = update.buy; sell = update.sell; feeFixed = update.feeFixed; feePercent = update.feePercent
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(buy, forKey: .buy)
        try container.encodeIfPresent(sell, forKey: .sell)
        try container.encodeIfPresent(feeFixed, forKey: .feeFixed)
        try container.encodeIfPresent(feePercent, forKey: .feePercent)
    }
}

/// Only the primary key is needed: a non-empty response is proof the RLS-gated write succeeded.
private struct RateRow: Decodable, Sendable { let id: UUID }
