# UR Global 1.2.1 (17)

## Payment review update

- The customer flow now follows sender, receiver, approved destination office, amount/fee mode, payment, and confirmation.
- The server validates the active approved office against the declared destination country.
- A valid route is quoted immediately; proof submission enters payment review and never confirms funds.
- Administration can request more information, reject evidence with a visible reason, or confirm actual receipt once.
- Confirmation freezes a unique receipt number and immutable snapshot with operator, time, amount, currency, and reference.
- Deployed server: Sites version 166, commit `13a91b646184ec9715daf09d6d784bde1cf4f556`. Rollback: redeploy version 165.
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

- Production Sites version: 166.
- Source commit: `13a91b646184ec9715daf09d6d784bde1cf4f556`.
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

## Final acceptance checkpoint — 15 October 2026

- Candidate app source: commit `67973d449eec9abc18b63e970cf33e8f97ec67f4`, Version 1.2.1, Build 17.
- App Store Connect showed Build 16 only under Version 1.2.1; Build 17 was unused at the time of the check.
- A fresh signed Build 17 archive from the candidate commit succeeded. Upload stopped before transmission because Xcode could not find an App Store Connect upload account for team `H7LT4CJA73`.
- Hosted backend production build and complete test suite passed 109/109.
- iPhone 15 Simulator XCTest passed 2/2. The iPad (10th generation) runner did not materialize and the run was interrupted after 180 seconds; it is not counted as a pass.
- The production AASA returned HTTP 200 with `H7LT4CJA73.com.urremit.mobile` and the approved app, tracking, receipt, payment-verification, and transfer paths.
- Device launches with transfer-history and tracking payload URLs succeeded. A real Safari Universal Link tap still requires manual confirmation on the unlocked device.
- The live Iraq to United Arab Emirates 5,000 USD quote returned a signed route commission of 72.50 USD, one 2 USD payment fee, a 5,074.50 USD total, and 18,362.50 AED beneficiary net. The quote was explicitly marked stale by the server and must not be paid without a refreshed valid quote.
- At the published IQD buy rate of 165,000 IQD per 100 USD, the expected SuperQi deposit for 5,074.50 USD is 8,372,925 IQD. The server unit and buy side are covered by the passing production-source tests; a fresh authenticated live order remains required for end-to-end confirmation.
- No real payment, transfer issuance, wallet debit, balance adjustment, App Store review submission, or Apple Ads activation occurred.

## Release gates still open

- Live customer/admin linkage, correction/re-submission, approval and receipt extraction remain blocked because no dedicated test administrator session is available. The public administration page redirects to login; no real owner credentials were used or changed.
- Visual inspection of a receipt PDF, immutable-snapshot mutation check, deletion of a dedicated Apple test account with Apple revocation, and QR camera permission/scan remain pending because they require the dedicated live accounts and physical-device interaction.
- Commodity prices are not enabled: a redistribution-safe no-new-cost data source has not been approved. No mock or scraped data is shown.
- Xcode Cloud is configured and its latest visible run succeeded, but the candidate branch is not present in its manual-start list because it has not been pushed to the connected repository. No Git remote was changed.
- Build 17 is confirmed unused in App Store Connect and the fresh signed Archive succeeded. Upload remains blocked because the Xcode distribution service reports no App Store Connect upload account for team `H7LT4CJA73`.
- No App Store review submission and no Apple Ads activation occurred.
