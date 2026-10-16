# UR Global — comprehensive repair verification

Date: 2026-10-15

## Release identity

- App Store ID: `6815895731`
- Bundle ID: `com.urremit.mobile`
- Marketing version: `1.2`
- Local project build: `15`
- Latest archive created on this Mac: version `1.2`, build `15`, path `outputs/URGlobal-1.2-build15.xcarchive`.
- App Store Connect was verified on 2026-10-15: builds 10, 13, and 14 already exist for version 1.2, so build 15 is the next upload candidate.

## Implemented

- Admin login now validates fields, supports password autofill and keyboard progression, maps credentials, lock, expiry, permission, network, timeout, and service failures to distinct Arabic messages, and keeps account recovery on the approved contact route.
- Removed sensitive authentication diagnostics and an MFA test-code bypass from the protected mobile API; restored dashboard and rate-write permission enforcement.
- Transfer submission uses the request UUID as its idempotency key, disables repeat submission while in flight/after success, reloads the saved order, and presents its state to the customer.
- Account deletion now uses authenticated `DELETE`; the server derives the target user only from the caller token and deletes it with the server-side service role. Local session/data cleanup remains after confirmed server success only.
- Rate UI separates the source-price timestamp from the last successful fetch timestamp, labels cached/stale data, and derives cache time from the cache file rather than the device's current display time.
- Protected rate values and API field mapping were not changed. Protected-file hashes were deliberately refreshed only for the reviewed implementation changes.
- Payment availability remains server-controlled. Live read-only configuration showed bank, cash, SuperQi, USDT-TRC20, and USDT-ERC20 enabled; PayPal, ZainCash, FIB, cards, and Apple Pay disabled. No payment method was activated.
- Removed the duplicate More-screen navigation that labelled the rates information page as a security center, and removed the obsolete comparison wording. Iraq-last ordering remains intact.
- Xcode Cloud validation scripts were added without invoking a paid CI service. They verify protected files, version, build, and bundle identity.
- pnpm permits the install script only for `esbuild`; the workspace protection was not disabled globally.
- Universal Links now use the production domains `urremit.com` and `www.urremit.com`; the published AASA identifies `H7LT4CJA73.com.urremit.mobile` and limits handling to the approved app, tracking, receipt, payment-verification, and transfer paths.

## Verification evidence

- Protected-rate integrity: 8/8 files matched the reviewed manifest.
- Backend: 28/28 tests passed; TypeScript lint passed.
- Admin web: TypeScript lint and production Next.js build passed.
- Edge functions: Deno 2.5.4 type checks passed for `mobile-api`, `admin-password-auth`, and `delete-account`.
- iPhone Simulator: unit tests passed 2/2; result bundle: `outputs/comprehensive-unit-tests-after-rates.xcresult`.
- iPad Simulator (iOS 17.2, single runner): unit tests passed 2/2; result bundle: `outputs/ipad-single-runner-20261015.xcresult`.
- Live public API checks returned valid rates, routes, offices, and payment configuration. The AASA endpoints on the apex and `www` production domains now return HTTP 200 with `application/json` and the exact application identifier.
- The deployed `mobile-api`, `admin-password-auth`, and `delete-account` sources have the same SHA-256 hashes as this checkout; no function deployment was required.
- A disposable SUPER_ADMIN was created with generated credentials that were never printed. Production login, dashboard loading, and token reuse all passed, then the admin session and account were removed.
- A disposable customer registered and logged in, submitted one cash quote-review request twice with the same idempotency key, saw status `review`, and the live administration datastore contained exactly one matching request (`a3a5e85b-cfdf-42d7-b0be-46fe1659bc4a`). No transfer or payment was executed.
- Final account deletion passed for that disposable customer and a later login attempt was rejected. Two earlier diagnostic disposable registrations may remain and require owner-side removal because their generated credentials were not retained.
- Signed Archive build 15 succeeded. Export/upload is blocked before transmission because Xcode has no Apple Account with App Store Connect access for team `H7LT4CJA73`; browser login alone does not satisfy Xcode signing/export.

## Required owner gates

1. In Xcode, open Settings > Accounts and sign in with an Apple ID that has App Store Connect access for team `H7LT4CJA73`. Then re-run build 15 export/upload and wait for TestFlight processing. No App Store review submission is authorized.

## Advertising guardrail

No campaign was created or started. The prepared Iraq search campaign is limited to 5 USD/day for exactly 10 account-timezone days with a mandatory end date, which caps advertising spend at 50 USD. Tax treatment must be verified in the Apple Ads billing account before creation; if tax is added above media spend, the pre-tax cap must be reduced so the all-in charge remains within 50 USD.
