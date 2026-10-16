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
