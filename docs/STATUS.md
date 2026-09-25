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

In progress. See `ARCHITECTURE.md` and `API.md`.

