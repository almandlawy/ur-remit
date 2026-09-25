# Architecture

## System boundaries

```text
iOS app ──TLS──> Public Mobile API ──> PostgreSQL / cache / APNs worker
                              |
Admin web ──MFA──> Admin API ─┴─> immutable audit events
```

The iOS v1 boundary is informational. It has no payment, wallet, funding, balance, or money-movement command.

## Mobile

SwiftUI on iOS 17+, Swift concurrency, repository/use-case boundaries, explicit dependency injection, Decimal money calculations, and file-backed actors for non-secret cached public data. Sensitive local values use Keychain.

Views never know URLs and never invoke `URLSession` directly. Environment configuration chooses development, staging, or production base URLs.

## Backend

TypeScript, Fastify, PostgreSQL, schema validation at every boundary, structured redacted logs, rate limiting, and separate public/admin route trees. Rates and configuration are server-authoritative. Timestamps are UTC.

Public tracking responses expose only reference, origin, destination, public status, last update, and estimated completion. Enumeration controls use normalized references, generic misses, layered rate limits, and security event recording.

## Admin

Responsive web client using short-lived server sessions, MFA, least-privilege RBAC, CSRF protection, and append-only audit history. The browser never receives database credentials or service secrets.

## Environments

Development, staging, and production use separate databases, secrets, APNs credentials, origins, and audit stores. Production data must never be copied to preview fixtures.

