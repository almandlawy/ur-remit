import XCTest
@testable import URRemit

/// Verifies the admin API client (Supabase Auth + PostgREST direct access) maps HTTP status codes
/// and RLS-empty responses to the right `AdminAPIError` cases, without touching a real network.
final class AdminAPIClientTests: XCTestCase {
    func testSignInDecodesSessionOnSuccess() async throws {
        let body = """
        {"access_token":"stub-access","refresh_token":"stub-refresh","expires_in":3600}
        """.data(using: .utf8)!
        let client = makeClient(status: 200, body: body)

        let session = try await client.signIn(email: "admin@urremit.local", password: "x")

        XCTAssertEqual(session.accessToken, "stub-access")
        XCTAssertEqual(session.refreshToken, "stub-refresh")
        XCTAssertEqual(session.email, "admin@urremit.local")
        XCTAssertFalse(session.isExpired)
    }

    func testSignInMapsBadRequestToInvalidCredentials() async throws {
        let client = makeClient(status: 400, body: Data())
        do {
            _ = try await client.signIn(email: "admin@urremit.local", password: "wrong")
            XCTFail("expected invalidCredentials")
        } catch AdminAPIError.invalidCredentials {
            // expected
        }
    }

    func testVerifyAdminDecodesBooleanRPCResult() async throws {
        let client = makeClient(status: 200, body: Data("true".utf8))
        let isAdmin = try await client.verifyAdmin(accessToken: "t")
        XCTAssertTrue(isAdmin)
    }

    func testUpdateRateThrowsForbiddenWhenRLSBlocksTheWriteSilently() async throws {
        // PostgREST returns 200 with an empty array (not 403) when RLS blocks a row-level write.
        let client = makeClient(status: 200, body: Data("[]".utf8))
        do {
            try await client.updateRate(id: UUID(), update: AdminRateUpdate(buy: 1), accessToken: "t")
            XCTFail("expected forbidden")
        } catch AdminAPIError.forbidden {
            // expected
        }
    }

    func testUpdateRateSucceedsWhenRowIsReturned() async throws {
        let id = UUID()
        let body = "[{\"id\":\"\(id.uuidString.lowercased())\"}]".data(using: .utf8)!
        let client = makeClient(status: 200, body: body)
        try await client.updateRate(id: id, update: AdminRateUpdate(buy: 1), accessToken: "t")
    }

    func testUpdateRateSkipsRequestWhenUpdateIsEmpty() async throws {
        let client = makeClient(status: 500, body: Data())
        // An empty update must be a no-op and never hit the network (which would fail with 500).
        try await client.updateRate(id: UUID(), update: AdminRateUpdate(), accessToken: "t")
    }

    private func makeClient(status: Int, body: Data) -> URLSessionAdminAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.status = status
        StubURLProtocol.body = body
        return URLSessionAdminAPIClient(
            projectURL: URL(string: "https://stub.local")!,
            apiKey: "stub-key",
            session: URLSession(configuration: configuration)
        )
    }
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
