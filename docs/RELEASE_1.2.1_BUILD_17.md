# UR Global 1.2.1 (17)

## Payment review update

- The customer flow now follows sender, receiver, approved destination office, amount/fee mode, payment, and confirmation.
- The server validates the active approved office against the declared destination country.
- A valid route is quoted immediately; proof submission enters payment review and never confirms funds.
- Administration can request more information, reject evidence with a visible reason, or confirm actual receipt once.
- Confirmation freezes a unique receipt number and immutable snapshot with operator, time, amount, currency, and reference.
- Deployed server: Sites version 164, commit `35d8f8831fedaa9c8183b79eb23d77fa1880b00c`. Rollback: redeploy version 163.
- Payment receipts render from the immutable approval snapshot, including the frozen receipt number, parties, office, quote, payment method, receipt reference, approving operator, and approval time.

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

## Hosted backend

- Production Sites version: 164.
- Source commit: `35d8f8831fedaa9c8183b79eb23d77fa1880b00c`.
- Formula: `amount / 10000 * signed route commission + USD 2`.
- Positive, zero, and negative route commissions are preserved through quote arithmetic.
- Valid orders receive a server quote and enter `awaiting_payment`; evidence still enters `payment_review` and never confirms receipt automatically.
- FIB and ZainCash settings remain hidden until complete and enabled, and are explicitly marked manual verification.

## Verification

- iOS generic Simulator build: passed.
- iPhone 15 Simulator XCTest: 2/2 passed.
- iPad (10th generation) Simulator XCTest: 2/2 passed.
- Hosted backend build: passed.
- Complete backend suite: 109/109 passed, including signed-commission/payment-fee, office isolation, evidence review, replay prevention, deletion, analytics, and privacy cases.
- Protected-rate check: 8/8 files unchanged.

## Release gates still open

- Live customer/admin linkage, provider verification, deletion of a dedicated test account, QR device camera, and Universal Link device routing are not yet verified against the candidate server.
- Commodity prices are not enabled: a redistribution-safe no-new-cost data source has not been approved. No mock or scraped data is shown.
- Build 17 is confirmed unused in App Store Connect and the signed Archive succeeded. Upload remains blocked because Xcode has no Apple ID recorded in its Accounts list with App Store Connect access for team `H7LT4CJA73`.
- No App Store review submission and no Apple Ads activation occurred.
