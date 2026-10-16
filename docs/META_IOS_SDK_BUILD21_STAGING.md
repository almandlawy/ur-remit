# Meta SDK integration — staging checklist (UR Global 1.2.1 build 21)

This branch is **NOT build-ready** and **does not send Meta events**. It intentionally keeps automatic app-event logging and advertiser-ID collection off until privacy review and owner approval.

## Changes staged
- Added Meta iOS SDK 18.1.1 `FacebookCore` dependency in `ios/project.yml` (XcodeGen source).
- Added Meta App ID and disabled event logging / advertiser ID collection in `ios/Resources/Info.plist`.
- Added a SwiftUI AppDelegate adaptor in `URRemitApp.swift`, with initialization guarded on the presence of a locally supplied Facebook client token.

## Before building on the Mac
1. Verify this is the actual release source and preserve the existing uncommitted calculator safety fix.
2. Obtain the Meta **Client Token** directly from Meta Developers. Do not commit it or send it in chat. Supply it through a secure local build configuration to the built app's `FacebookClientToken` Info.plist key.
3. Regenerate or update `ios/URRemit.xcodeproj/project.pbxproj` with XcodeGen on the Mac. The checked-in Xcode project **has not been regenerated** in this branch, and a build may fail until the package dependency is added to the actual Xcode target.
4. Verify the chosen SDK version and `ApplicationDelegate` API compile with the installed Xcode version.
5. Review Apple App Privacy, privacy policy, consent flows and Meta data processing. Do not flip either Info.plist boolean or request ATT before this review.
6. Once authorized, enable only the minimal event logging needed for campaign measurement. Test on a physical iPhone and inspect Events Manager Test Events and diagnostics. An SDK installed without events is not sufficient.
7. Run tests, verify login, rates, widgets and notifications, and seek explicit approval before App Store submission.
8. In Meta Developers, fill the missing iOS Bundle ID `com.urremit.mobile`, privacy policy, and data-deletion instructions; do not publish the Meta app or the ad without approval.

No live campaign, payment, Apple release, or production backend has been changed.

## Mac integration status (2026-10-16)
- SDK pinned to 18.1.1 (stable, 2026-08-27). 19.0.0 was released 2026-10-16 and raises the minimum to iOS 15; revisit after it settles.
- Client token plumbing: `ios/Config/Meta.xcconfig` (tracked, empty) includes the gitignored `ios/Config/Meta.local.xcconfig`. Info.plist reads `$(FACEBOOK_CLIENT_TOKEN)` and `$(META_APP_EVENTS_ENABLED)`.
- The app delegate sets `Settings.shared.isAutoLogAppEventsEnabled` from `META_APP_EVENTS_ENABLED` on every launch and always disables advertiser-ID collection. SDK 18.x can let Events Manager override the Info.plist default.
- Added Meta SKAdNetwork IDs (`v9wttpbfk9`, `n38lu8286q`) for app-install attribution.
- Xcode project regenerated with XcodeGen 2.46.0. Before the Meta changes, regenerating the shipped `project.yml` produced the same targets, files and versions as the shipped project.
- Simulator build and unit tests (4/4) pass on Xcode 26.3; signed device build passes.
- The SDK's own privacy manifest declares `NSPrivacyTracking = true` (domain `ep1.facebook.com`), Device ID (linked, tracking, third-party advertising), plus other data (analytics) and crash data. Update App Store Connect privacy labels and decide on ATT before release.
- Placeholder token (`paste_client_token_here`) is rejected at launch, so the SDK stays off until a real token is configured locally. A local pre-commit hook (not versioned) blocks committing `Meta.local.xcconfig`.
- Smoke-tested without a token: simulator and iPhone (iOS 26.6.2) launch and stay running, no Meta SDK activity.

## Privacy blockers before enabling app events
- The live policy at https://urremit.com/privacy says the app does not use the advertising ID and does **not share app events with advertising platforms**. It must be updated to disclose Meta SDK app-event sharing before `META_APP_EVENTS_ENABLED` is set to YES in any shipped build.
- The policy says usage-data sharing can be turned off from the app's More section. This iOS source has no such switch. Add one and gate Meta logging on it, or correct the policy.
- App Store Connect privacy labels must add the data types in the Meta SDK manifest (Device ID; other usage data for analytics/advertising; crash data).
- ATT: the minimum setup keeps advertiser-ID collection off and shows no ATT prompt. Measurement then relies on SKAdNetwork and Meta AEM. Add ATT only if the owner approves IDFA-based measurement.
- Meta Developers: add iOS bundle ID `com.urremit.mobile`, privacy policy URL and data-deletion instructions.

## Consent control (2026-10-16)
- More → إعدادات الخصوصية: "share usage data with UR" (on by default, gates `URNativeTelemetry`) and "Meta ad measurement" (opt-in, shown only when the build has a token and `META_APP_EVENTS_ENABLED = YES`).
- The Meta SDK is initialized only after opt-in, so there is no Meta network traffic without consent. Opting out disables auto-logging and clears SDK user data.
- Policy draft: `docs/privacy/PRIVACY_POLICY_REVISION_DRAFT_2026-10-16.md`. App Store labels: `docs/privacy/APP_STORE_PRIVACY_DISCLOSURES_PROPOSAL.md`.
