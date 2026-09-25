# Delivery status

## Phase 1 — current platform audit

**DONE — 2026-09-24**

### Evidence

- `https://www.urremit.com/` is live behind Cloudflare and publishes Arabic/English product content.
- The live site publishes an informational rate bulletin, office/contact content, transfer tracking, agent verification, and broader account/operations journeys.
- `GET https://www.urremit.com/api/v1/health` returned HTTP 404 during the audit.
- `GET https://www.urremit.com/api/v1/rates` returned HTTP 404 during the audit.
- Security headers observed include HSTS, CSP, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, and a restrictive Permissions Policy.
- The new delivery directory was empty and was not a Git repository.
- Xcode 26.3, Swift 6.2.4, XcodeGen, and a bundled Node.js/pnpm runtime are available locally.

### Decision

Do not scrape the website or pretend existing pages are a mobile API. Introduce a separately deployed, versioned `/api/v1/mobile` surface and an authenticated `/api/v1/admin` surface. Existing operational data must be migrated or integrated through an approved server-side adapter.

### Blockers discovered

- No source repository or current backend source was supplied.
- No database, DNS, hosting, APNs, Apple Developer, or App Store Connect credentials are available in this workspace.
- The requested production API endpoints are not currently published at the audited origin.

## Phase 2 — architecture

**DONE — 2026-09-24**

- System boundaries, environment isolation, public/admin API separation, Clean Architecture mobile layers, security posture, and canonical API contract are documented in `ARCHITECTURE.md`, `API.md`, and `SECURITY.md`.
- Native iOS project generated with bundle identifier `com.urremit.mobile`, iOS 17 deployment target, Arabic-first localization, English localization, dependency injection, async network client, repository boundary, and protected offline rate cache.
- PostgreSQL initial migration defines rates, routes, countries, cities, offices, agents, public transfer status, announcements, remote config, push tokens, RBAC, audit logs, and security events.

### Verification

- iOS unsigned Simulator-target compile: **passed** (`BUILD SUCCEEDED`).
- Backend unit/API tests: **2 passed**.
- Backend strict TypeScript build: **passed**.
- Simulator runtime/UI execution: not yet verified because CoreSimulatorService is unavailable to this sandboxed task.

## Phase 3 — database and API

**IN PROGRESS**

The first migration, safe configuration parser, security middleware, versioned health endpoint, remote app-config endpoint, stable 404 envelope, redacted logs, and API tests exist. Database-backed rates/offices/agents/tracking endpoints and deployment are not yet complete.

### 2026-09-24 implementation increment

- Added a pooled PostgreSQL data store with bounded connection settings and TLS verification in production.
- Added database-backed rates, rate detail/history, countries, cities, routes, verified offices, public app config, and published notices.
- Added privacy-minimized agent verification and transfer tracking. Lookups use keyed HMAC blind indexes so raw agent codes, phones, and references are not stored as searchable plaintext.
- Added strict input validation, endpoint-specific throttles, generic tracking misses, and database-aware degraded health responses.
- No seed rates, offices, agents, or transfers were introduced.

Verification: strict TypeScript build passed; public API test suite passed 9/9. A live PostgreSQL integration test remains pending because no database service or production credentials are present in this workspace.

## Phase 4 — administration

**IN PROGRESS**

### 2026-09-24 admin API foundation

- Added a separate `/api/v1/admin` route boundary.
- Added short-lived server-side admin session records; only keyed token fingerprints are stored, and sessions must record completed MFA.
- Added permission enforcement for dashboard reads and rate writes.
- Added database dashboard metrics.
- Rate changes run in one PostgreSQL transaction: lock current rate, preserve it, insert a new immutable version, append rate history, and append an audit event.
- Monetary values are accepted as validated decimal strings, never JavaScript floating-point numbers.

Verification: admin and public API suites pass 14/14. Admin login/MFA issuance and the responsive web dashboard remain to be implemented before this phase can be marked complete.
