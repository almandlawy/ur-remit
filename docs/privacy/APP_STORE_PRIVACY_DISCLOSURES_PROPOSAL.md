# App Store Connect privacy disclosures: proposed changes

**Status: for owner review. Nothing changed in App Store Connect.** Revised 2026-10-16 against SDK 18.1.1 source and the owner's decisions: strictly opt-in, no IDFA, no ATT prompt, no SDK before consent. Covers analytics and Meta measurement only. Keep your existing declarations for account, contact, remittance and financial data.

## What the Meta SDK can collect vs. what it collects here

The SDK's `FBSDKCoreKit/PrivacyInfo.xcprivacy` declares its **maximum**. In UR Global's configuration, and only after the user opts in:

| SDK manifest entry | Actual behaviour | Evidence (SDK 18.1.1) |
|---|---|---|
| Device ID: linked, tracking | **IDFA never read**: `advertiserID` returns nil when `isAdvertiserIDCollectionEnabled == false`. An SDK-generated random `anon_id` **is** sent. | `FBSDKAppEventsUtility.m` (advertiserID, activityParametersDictionaryForEvent) |
| Other Data Types: analytics, not linked | **Sent**: `extinfo` (bundle, app version, OS version, device model, language, time zone, carrier, screen size/density, CPU cores) | `FBSDKAppEventsDeviceInfo.m` |
| Crash Data: app functionality, not linked | **Possible**: the SDK reports its own crashes after initialization | SDK crash observer |
| `NSPrivacyTracking = true`, domain `ep1.facebook.com` | iOS blocks tracking domains without ATT permission; no ATT prompt exists | Apple privacy manifest rules |
| User ID / user data | **Not sent**: no `userID`, `ud` = `{}` | `URPrivacyConsent.swift` |

Verified at runtime on the simulator (dummy token, events enabled): **no connection to Meta without consent**; a `facebook.com` connection appears within 20 seconds with consent.

## Proposed App Privacy answers (additions)

| Apple data type | Collected by | Purposes | Linked to user? | Tracking? |
|---|---|---|---|---|
| Identifiers → **Device ID** | UR (installation UUID); Meta (`anon_id`, opt-in) | Analytics; Third-Party Advertising | No | See decision below |
| Usage Data → **Product Interaction** (installs, app opens) | UR; Meta (opt-in) | Analytics; Third-Party Advertising | No | See decision below |
| Other Data → **Other Data Types** (device characteristics) | Meta (opt-in) | Analytics; Third-Party Advertising | No | See decision below |
| Diagnostics → **Crash Data** | Meta SDK (opt-in) | App Functionality | No | No |

Changes from the first draft: UR events are **not linked** (the server stores no account ID); device characteristics moved to **Other Data Types**, to match the SDK manifest and Xcode's privacy report. Apple counts optional collection as collection.

IP address: Meta receives it on connection. Apple asks you to declare **Coarse Location** only if IP is used to infer location. Meta's terms allow location inference for ads, so consider declaring Coarse Location (Third-Party Advertising, not linked) to be safe.

## Essential decision: does Meta measurement count as "tracking" under Apple's definition?

Apple defines tracking as linking data from your app with other companies' data **for targeted advertising or advertising measurement**, or sharing it with data brokers. Attributing an install to a Meta ad means Meta combines your app's event with its own record of who saw the ad. That is advertising measurement across companies.

- Meta's position: without ATT, the SDK sends `advertiser_tracking_enabled=false`, and Meta says it then processes events under restricted, non-tracking rules (Aggregated Event Measurement).
- Apple's rule: an app is responsible for its SDKs. If a partner uses the data for tracking, ATT permission is required.

| Option | Labels | Consequence |
|---|---|---|
| **1. Opt-in Meta events, declared "not used for tracking"** (current build) | Tables above with Tracking = No | Compatible with the owner's no-ATT decision. Relies on Meta's non-tracking representation for `advertiser_tracking_enabled=false` events. **Residual risk**: App Review could treat it as tracking under guideline 5.1.2, which would require ATT or removing the SDK. |
| 2. Declare "used for tracking" | Tracking = Yes | Requires an ATT prompt before sending, which **conflicts with the owner's decision**. Not available as currently decided. |
| 3. SKAdNetwork only (no Meta SDK events) | No Meta rows | Lowest risk: iOS sends aggregated install postbacks itself, using the Meta SKAdNetwork IDs already in Info.plist. Weaker optimisation; check in Ads Manager whether app-install campaigns run without SDK events. |

Option 1 fits the owner's decisions and is what the code implements, with a known residual review risk. Option 3 is the fallback if App Review objects.

## App privacy manifest (`ios/Resources/PrivacyInfo.xcprivacy`)
Xcode merges the SDK manifest automatically. For accuracy, consider declaring UR's own installation ID (Device ID, Analytics, not linked) and Product Interaction in the app manifest. Not changed in this PR.

## Before submission
1. Owner chooses the tracking option above.
2. Update App Privacy answers in App Store Connect.
3. Archive → Generate Privacy Report; check that it matches.
4. Publish the revised privacy policy first.
