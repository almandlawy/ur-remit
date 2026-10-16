# UR Global — Meta iOS App Events integration audit

Date: 2026-10-17
Status: **Audit only — no SDK code changes, no app build, no advertising activation.**

## Verified in this repository (main at time of branch creation)

- iOS target: `ios/URRemit.xcodeproj` and `ios/project.yml`.
- Bundle identifier: `com.urremit.mobile`.
- SwiftUI app entry: `ios/UR/App/URRemitApp.swift` has an existing `@main` app. Preserve its authentication, splash, and alerts lifecycle.
- `ios/Resources/Info.plist` has no `FacebookAppID`, `FacebookClientToken`, or Meta app-event settings.
- The project file has no Facebook SDK package-product dependency.
- This checkout's project.yml says marketing version 1.0.0 and build 10, so **verify that it is the current iOS source before editing**. It may lag the App Store version.
- No live-device event verification or Xcode build was possible from this audit.

## Meta context (from the owner's Meta console)

- Meta App ID: `2280513229394946`
- Apple App Store ID: `6815895731`
- Meta app's iOS Bundle ID was blank; App Events reported no events.
- Ads draft: account `2613637262442341`; iOS 14+ app selection blocked by incomplete conversion data.
- Do not bypass event requirements by acknowledging missing events, and do not publish the ad.

## Next implementation steps — only after source/version verification

1. Compare this branch to the current Mac/Xcode release source. If outdated, migrate this audit to the current source; do not overwrite release code.
2. Add Meta's current supported iOS Core SDK through Swift Package Manager to the **current** Xcode target. Pin a compatible version and check the upstream release notes.
3. Configure Meta App ID and the app's client token in the app target's Info.plist (do not commit secrets). Merge SDK initialization into the existing SwiftUI lifecycle without replacing its `@main` entry or scene code.
4. Determine an explicit privacy posture with the owner: event logging, IDFA collection, ATT prompt, Apple privacy labels, privacy policy, and data deletion instructions. Do not enable tracking or IDFA collection by default.
5. Run on a physical iPhone, inspect Meta Events Manager Test Events and diagnostics, and confirm actual app-activation events. Event delivery may not be immediate.
6. Build, run tests, verify auth/rates/notifications, and only then propose an App Store submission for approval.
7. Independently update Meta Developers iOS Bundle ID to `com.urremit.mobile` and complete its privacy disclosures. Confirm the ad account has app permissions.

## Explicitly out of scope

- Changing production prices, backend, credentials, privacy permissions without approval.
- Publishing a Meta app, launching ads, funding campaigns, or submitting to App Store.
- Assuming that the app's existing release has the same source as this repository.
