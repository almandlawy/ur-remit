# App Store privacy disclosures and Apple tracking classification

**Status: recommendation for owner review. Nothing changed in App Store Connect.** Revised 2026-10-17. Owner decisions: Meta strictly opt-in, IDFA off, no ATT until classification is resolved, campaigns paused or draft.

## 1. What Apple says (official pages, checked 2026-10-17)
- **Tracking** = "linking user or device data collected from your app with user or device data collected from other companies' apps, websites, or offline properties for targeted advertising or **advertising measurement** purposes", or sharing with data brokers. ([User Privacy and Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/))
- An SDK that combines your app's data with other companies' data for targeting or measurement counts as tracking "even if you don't use the SDK for these purposes". Developers are responsible for all code in their app.
- Covered identifiers include any ID used to join data for ad measurement, not only the IDFA: "session ID, fingerprint IDs, and device graph identifiers".
- Tracking requires ATT permission. Without it, the IDFA is zeros, but **that does not make other measurement non-tracking**.
- Optional collection must still be disclosed when it is used for Third-Party Advertising. Disclosures cover third-party SDKs. ([App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/))
- Apple's privacy-preserving attribution path is **AdAttributionKit / SKAdNetwork**.

## 2. What Meta says
- SDK 17+ on iOS 17+ reads Apple's ATT status itself. For events without tracking permission, Meta says "we may restrict our use of that event". ([Advertiser Tracking Enabled](https://developers.facebook.com/docs/app-events/guides/advertising-tracking-enabled))
- Meta's developer pages do **not** state that such events are excluded from tracking as Apple defines it. Aggregated Event Measurement is described mainly in third-party sources, which disagree on current details.

## 3. What UR Global's build would send (verified in SDK 18.1.1 source and at runtime)
Only after opt-in, and only in a build with a token and `META_APP_EVENTS_ENABLED = YES`:
- Install and activate events, the SDK's persistent random `anon_id`, device data (`extinfo`: model, OS, language, time zone, carrier, screen, CPU cores, app version), and the IP address on connection.
- No IDFA (`advertiserID` returns nil), no user ID, no user data.
- Runtime check (simulator, dummy token): no connection to Meta before consent; a `facebook.com` connection after consent.

## 4. Conclusion
Sending Meta app events so Meta can attribute installs to its ads is **advertising measurement that links your app's events with Meta's own data**. Under Apple's wording that is tracking. Using `anon_id` and IP instead of the IDFA doesn't change this, because Apple names "device graph identifiers" and fingerprinting explicitly. **Disabling IDFA is not enough to answer "not used for tracking".**

With the owner's no-ATT decision, enabling Meta app events in a release build would therefore require either:
- declaring Tracking = Yes, which then requires ATT (conflicts with the decision), or
- declaring Tracking = No, which is **not supportable** from Apple's wording and Meta's documentation (review and compliance risk).

## 5. Recommended path
| Option | What ships | App Store answers | Fits owner decisions? |
|---|---|---|---|
| **A. Recommended now: SKAdNetwork / AdAttributionKit only** | Meta SDK present but **Meta events disabled in release builds** (`META_APP_EVENTS_ENABLED = NO`, the default), SKAdNetwork IDs kept | No Meta rows. UR rows only (table below) | Yes |
| B. Later: ATT plus opt-in | Meta events only when ATT is **authorized** and the in-app switch is on | Add Meta rows with **Tracking = Yes**, plus `NSUserTrackingUsageDescription` | Needs the owner to approve ATT |
| C. Remove the Meta SDK | Smallest surface | No Meta rows | Yes, but loses the option of B |

Check in Ads Manager whether UR's app-install campaign can optimise on SKAdNetwork alone; that decides how urgent option B is.

## 6. App Privacy answers

**Always (UR first-party, `URNativeTelemetry`)**

| Apple data type | Purpose | Linked | Tracking |
|---|---|---|---|
| Identifiers → Device ID (random installation UUID) | Analytics | No: the server stores no account ID | No |
| Usage Data → Product Interaction (first open, app open) | Analytics | No | No |

**Only if Meta events ship (option B)**

| Apple data type | Purpose | Linked | Tracking |
|---|---|---|---|
| Identifiers → Device ID (`anon_id`) | Third-Party Advertising, Analytics | Treat as **Yes**: Meta may link to its user data | **Yes** |
| Usage Data → Product Interaction (install, activate) | Third-Party Advertising, Analytics | Yes | **Yes** |
| Other Data → Other Data Types (device characteristics) | Third-Party Advertising, Analytics | Yes | **Yes** |
| Location → Coarse Location (from IP) | Third-Party Advertising | Yes | **Yes** |
| Diagnostics → Crash Data (SDK crashes) | App Functionality | No | No |

"Linked = Yes" for the Meta rows is the conservative choice. Apple's "not linked" criteria require that the recipient doesn't tie the data to other datasets that identify the user, which UR cannot guarantee for Meta.

## 7. Before any submission
1. Owner chooses option A, B or C.
2. Fill App Privacy from the matching table.
3. Archive → Generate Privacy Report and compare. The Meta SDK manifest still appears in the report even with events disabled; answer from actual behaviour (option A: no Meta collection).
