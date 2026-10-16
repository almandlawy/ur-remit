# App Store Connect privacy disclosures: proposed changes

**Status: for owner review. Nothing changed in App Store Connect.** Covers only the analytics and Meta measurement added or corrected by PR #21. Keep your existing declarations for account, contact, remittance and financial data.

## What the Meta SDK can collect vs. what it collects here

Meta's bundled `FBSDKCoreKit/PrivacyInfo.xcprivacy` (18.1.1) declares the **maximum** the SDK can collect:

| SDK manifest entry | In UR Global's configuration |
|---|---|
| Device ID: linked, tracking, third-party advertising / app functionality / analytics | **IDFA is never read**: `isAdvertiserIDCollectionEnabled = false` makes `advertiserID` return nil, and no ATT prompt exists. The SDK still sends its own random `anon_id`. |
| Other data types: not linked, analytics | **Yes**: `extinfo` device data (model, OS, language, time zone, carrier, screen, CPU cores, app version). |
| Crash data: not linked, app functionality | **Possible**: the SDK reports its own crashes to Meta. |
| `NSPrivacyTracking = true`, domain `ep1.facebook.com` | iOS blocks this domain unless the user grants ATT. With no ATT prompt, it is never contacted. |
| User ID / user data (`app_user_id`, `ud`) | **Not sent**: the app never sets `AppEvents.userID` or user data (`ud` is `{}`). |

All of this applies only when the build has a token, `META_APP_EVENTS_ENABLED = YES`, **and** the user opts in.

## Proposed App Privacy answers (additions)

| Data type (Apple category) | Collected by | Purposes | Linked to user? | Used for tracking? |
|---|---|---|---|---|
| **Identifiers → Device ID** | UR (installation ID) and Meta (`anon_id`) | Analytics; Third-Party Advertising (Meta) | UR: Yes when signed in. Meta: No | **No** |
| **Usage Data → Product Interaction** (app opens, installs) | UR and Meta | Analytics; Third-Party Advertising (Meta) | UR: Yes when signed in. Meta: No | **No** |
| **Diagnostics → Crash Data** | Meta SDK | App Functionality | No | No |
| **Diagnostics → Other Diagnostic Data** (device model, OS, carrier, screen) | Meta SDK | Analytics; Third-Party Advertising | No | No |

"Used for tracking = No" holds only while there is no IDFA and no ATT. If you later add ATT and IDFA collection, change Device ID to tracking = Yes, add `NSUserTrackingUsageDescription`, and show the prompt before enabling.

Apple counts optional collection as collection, so these answers apply even though Meta measurement is opt-in.

## App privacy manifest (`ios/Resources/PrivacyInfo.xcprivacy`)
No change needed for Meta: Xcode merges the SDK's own manifest into the app's privacy report. Optional for accuracy: declare the first-party installation ID (Device ID, analytics, linked) and product interaction in the app manifest, because `URNativeTelemetry` is UR's own collection.

## Before the next submission
1. Update App Privacy answers as above.
2. Generate the Xcode privacy report (Archive → Generate Privacy Report) and check that it matches.
3. Publish the revised privacy policy first; the App Store privacy URL points to it.
