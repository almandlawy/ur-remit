# UR Global 1.2.1 (17)

## Implemented in this branch

- Persistent customer transfer draft and idempotency identifier.
- Electronic checkout no longer asks for a cash collection office.
- Only server-enabled payment methods are shown; public cash and PayPal preview paths are removed.
- Quote summary separates signed route commission, the single USD 2 payment fee, total paid, and beneficiary net.
- Supabase access-token renewal uses the refresh token and preserves a session during temporary network failure.
- Authentication callbacks are restricted to `urremit://auth/callback`.
- Account-deletion cleanup removes UR preferences, App Group rate data, cache, and pending/delivered notifications after server success.
- QR camera usage description and UserDefaults/App Group required-reason declarations.
- Widget placeholders no longer invent prices and displayed rates use thousands separators.

## Hosted backend candidate

- Saved Sites version: 162 (not deployed).
- Source commit: `c8365af415eb9973df850bee4ff243724f51e218`.
- Formula: `amount / 10000 * signed route commission + USD 2`.
- Positive, zero, and negative route commissions are preserved through quote arithmetic.
- Valid orders receive a server quote and enter `awaiting_payment`; evidence still enters `payment_review` and never confirms receipt automatically.
- FIB and ZainCash settings remain hidden until complete and enabled, and are explicitly marked manual verification.

## Verification

- iOS generic Simulator build: passed.
- iPhone 15 Simulator XCTest: 2/2 passed.
- iPad (10th generation) Simulator build: passed.
- Hosted backend build: passed.
- Focused backend tests: 15/15 passed, including 3/3 new signed-commission/payment-fee cases.
- Protected-rate check: 8/8 files unchanged.

## Release gates still open

- Sites version 162 is not deployed because the complete legacy suite has 11 failures: eight assumptions conflict with the newly requested flow and three are pre-existing/environmental (`python` alias, backup fixture, and a test-module loader). The focused changed-path suite passes.
- Live customer/admin linkage, provider verification, deletion of a dedicated test account, QR device camera, and Universal Link device routing are not yet verified against the candidate server.
- Commodity prices are not enabled: a redistribution-safe no-new-cost data source has not been approved. No mock or scraped data is shown.
- Build 17 is confirmed unused in App Store Connect but has not been archived or uploaded while the backend candidate is undeployed.
- No App Store review submission and no Apple Ads activation occurred.
