import Foundation

/// A Supabase Auth session for the signed-in admin, persisted in the Keychain so the hidden admin
/// screen doesn't require a full email/password login every launch. Mirrors the token shape returned
/// by `POST /auth/v1/token` (grant_type=password / refresh_token).
struct AdminSupabaseSession: Codable, Sendable {
    let email: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    /// A short buffer before the real expiry so a refresh is attempted slightly early rather than
    /// racing a request that's already in flight when the token expires.
    var isExpired: Bool { expiresAt <= Date().addingTimeInterval(30) }
}

/// Fields the admin can edit for a single rate route, written directly to Supabase's `rates` table
/// via PostgREST. Only non-nil fields are sent, matching PostgREST's partial-update (`PATCH`) semantics.
struct AdminRateUpdate: Sendable {
    var buy: Decimal? = nil
    var sell: Decimal? = nil
    var feeFixed: Decimal? = nil
    var feePercent: Decimal? = nil

    var isEmpty: Bool { buy == nil && sell == nil && feeFixed == nil && feePercent == nil }
}

enum AdminAPIError: Error, Equatable {
    case invalidCredentials
    case notAnAdmin
    case sessionExpired
    case forbidden
    case notFound
    case invalidInput
    case transport
    case missingConfiguration
}
