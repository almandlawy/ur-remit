# UR Global — comprehensive repair verification

Date: 2026-10-15

## Release identity

- App Store ID: `6815895731`
- Bundle ID: `com.urremit.mobile`
- Marketing version: `1.2`
- Local project build: `14`
- Latest archive verified on this Mac: version `1.2`, build `13`, archived and uploaded on 2026-10-13.
- Build 14 availability in App Store Connect is not verified because the App Store Connect session requires an owner login. No archive or upload was started.

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

## Verification evidence

- Protected-rate integrity: 8/8 files matched the reviewed manifest.
- Backend: 28/28 tests passed; TypeScript lint passed.
- Admin web: TypeScript lint and production Next.js build passed.
- Edge functions: Deno 2.5.4 type checks passed for `mobile-api`, `admin-password-auth`, and `delete-account`.
- iPhone Simulator: unit tests passed 2/2; result bundle: `outputs/comprehensive-unit-tests-after-rates.xcresult`.
- iPad Simulator: compilation succeeds, but test runner startup hangs while waiting for workers on both iOS 26 and iOS 17 simulators. The interrupted result is not counted as a pass: `outputs/comprehensive-ipad-ios17-final.xcresult`.
- Live public API checks returned valid rates, routes, offices, and payment configuration. Public privacy, terms, contact, offices, pricing, and app links returned successfully. Universal Links AASA still returns 404.
- Unauthenticated live admin login/dashboard requests were rejected. No authorized disposable admin credentials were available, so dashboard loading and session restoration against production remain unverified.
- No disposable customer account was available; therefore transfer creation/admin arrival and destructive final account deletion were not executed against production.

## Required owner gates

1. Provide disposable authorized admin and customer test accounts through a secure channel to complete the live authenticated and destructive tests.
2. Sign in to App Store Connect so build-number availability can be checked before creating build 14's archive.
3. After that verification, create/sign the archive and upload to TestFlight, then wait for Apple's processing. No App Store review submission is authorized.

## Advertising guardrail

No campaign was created or started. A future Iraq search campaign must have an explicit 50 USD lifetime stop condition, fixed end date, conservative daily cap and bid ceiling, and monitoring that pauses delivery before aggregate spend reaches 50 USD. The full configuration must be approved before any spend.
