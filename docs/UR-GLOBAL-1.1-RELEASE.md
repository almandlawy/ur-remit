# UR Global 1.1 release preparation

Version: **1.1**. Build: **12**, according to the requested fallback because build 11 was previously used. Bundle identifier remains `com.urremit.mobile`. App Store Connect currently requires a fresh sign-in; recheck uniqueness for version 1.1 before any future upload. No Apple upload or review action is authorized by this work.

## Architecture and deployed services

- iOS → `app-analytics/events` → validated allowlisted payloads → private Supabase `analytics_events`.
- Publishable client key is validated by Supabase. Auth IDs are resolved server-side from real Supabase sessions; no client-supplied user IDs are accepted.
- Existing mobile admin session → `app-analytics/access` or `/summary` → existing `admin_authenticate` RPC + SUPER_ADMIN or explicit `analytics.read` permission.
- Existing urremit.com SUPER_ADMIN session → server-only proxy → dedicated read-only analytics bridge. The random bridge key exists only in the site's encrypted runtime settings. Supabase stores its hash. No service-role key is distributed to the website or app.
- Server aggregation has column-level access only to Auth registration/confirmation state, not emails, password hashes or tokens. No new SECURITY DEFINER function was introduced.
- Direct analytics table and RPC access is revoked from `anon` and `authenticated`. RLS is enabled. There are no general client read policies.
- Event IDs deduplicate retries. First opens are unique per installation; session starts unique per session; signup completion unique per verified user.
- Raw events retained for 90 days. Daily cron runs `analytics_prune()` at 02:17 UTC. Short-lived salted abuse buckets expire after two days. No raw IP address is stored in analytics tables; standard infrastructure logs are governed separately by Supabase's configured log retention.

## Event semantics

Supported events: `app_first_open`, `app_open`, `session_start`, `signup_started`, `signup_completed`, `login_completed`, `logout`, `home_viewed`, `rates_viewed`, `calculator_viewed`, `offices_viewed`, `calculator_used`, `currency_selected`, `whatsapp_clicked`, `phone_clicked`, `website_clicked`, `office_clicked`, `map_clicked`, `app_store_clicked`, `share_app_clicked`, `contact_attempted`, `language_changed`, `error_occurred`.

- First Open means the first **observed** launch after this analytics system is introduced, per random installation ID. Existing users upgrading to 1.1 can generate their first observed event. It is not an App Store download or an exact person count.
- App Open: foreground activation. Session Start: cold launch or resume after at least 30 minutes in background. Merely re-rendering SwiftUI does not create either event.
- Calculator Used is debounced after valid input, and also follows a user-selected currency with valid input. Amounts/results/exchange rates are never included.
- Currency Selected occurs on a user changing a populated picker, not initial API loading.
- Signup Started refers to starting the Apple/Google authentication flow, which may lead to a new or existing account. Signup Completed requires a newly created verified account; Login Completed covers successful interactive authentication. Session restoration is not counted as a new login.
- Language Changed detects a real device/app locale change on the next activation. This does not introduce English translations into the existing Arabic-only UI.
- Contact Attempted records WhatsApp, telephone or the website contact page. It is not proof of a completed conversation. Opening privacy/terms is a Website Click, not a Contact Attempt.
- Offices Viewed counts page views. Office Clicked counts user interaction with an office card. Channels are tracked before iOS opens the URL, without waiting for the network.
- Error Occurred includes a fixed safe code only, never raw error strings or response bodies.
- There is no new Crash SDK: aggregate error codes do not constitute automatic crash collection.

Anonymous events use a bounded 200-event outbox with up to 24 hours of retention and exponential retry. Authenticated event tokens remain in memory/Keychain and are excluded from the persisted outbox; authenticated events can be lost if the app terminates offline. Analytics is best effort and never blocks user actions. Users can disable collection in More. Anonymous ingestion is rate-limited but, like any public client telemetry, is not proof against a modified client; official download numbers must come from Apple.

## Registered users

Supabase Auth is the real source. At verification time: total **5**, today **1**, last 7 days **3**, last 30 days **5**, confirmed **5**, unconfirmed **0**, excluding anonymous/deleted accounts. These project-wide accounts may include users created outside iOS. Confirmed Auth accounts and the new `signup_completed` events are displayed separately.

Time windows use Asia/Baghdad calendar days, inclusive of today: 7 days is today plus the preceding six days. All means retained event history, not fabricated pre-1.1 activity. Funnel counts sessions in order: app open → rate view → calculator use → contact attempt. The daily chart always shows the last 30 days.

## App Store Downloads architecture — credentials still required

Current status: **Not connected**, value **null**, never a fabricated zero.

Required inputs: Team API **Issuer ID**, **Key ID**, and the corresponding Apple private **AuthKey_….p8** stored in a server secret manager, never in iOS, GitHub source, or browser-visible settings. Use a dedicated **Sales and Reports** key for reading reports. The initial ONGOING analytics report request may require an Admin-enabled key or an authorized administrator to enable report generation once. App ID is `6815895731`.

Planned server worker: sign short-lived ES256 JWT → enumerate the app's analytics report request → select the standard **App Store Downloads** report → retrieve daily instances/segments → verify source and aggregate all segments once → distinguish `First-time Download` from `Redownload`, manual/auto updates and restores → idempotently replace corrected day totals in `app_store_download_reports`. Do not mix detailed/standard or daily/weekly/monthly data. Apple reports can arrive late; show freshness/completeness and reprocess corrected daily instances. This architecture is prepared; the live Apple connection is not enabled without credentials.

Primary sources:
- https://developer.apple.com/documentation/appstoreconnectapi/downloading-analytics-reports
- https://developer.apple.com/documentation/analytics-reports/app-download

## App Privacy changes required before any submission

Declare additional collection for **Analytics**, **linked to the user/device** (installation IDs and optional authenticated user IDs), **not used for tracking**:

| Category | Data type | Reason |
|---|---|---|
| Identifiers | Device ID | Random per-installation ID, not IDFA or fingerprint |
| Identifiers | User ID | Verified Supabase user ID for signed-in events |
| Usage Data | Product Interaction | Opens, screens, calculator interaction, contact clicks |
| Diagnostics | Other Diagnostic Data | Fixed safe error codes |

No advertising purposes, IDFA, third-party data matching, advertising SDK, or ATT prompt is added. The privacy manifest now declares these analytics types and the required UserDefaults reason CA92.1. Existing sign-in email/contact disclosures should also be checked against the application's current privacy answers. The manifest does not update App Store Connect answers automatically. The site's policy includes the app's collection, optional account linking, opt-out and 90-day retention. Admin/customer pages are excluded from existing public-site advertising telemetry.

Primary source: https://developer.apple.com/app-store/app-privacy-details/

## Build and verification

Passed locally: backend TypeScript, 28 backend tests; admin TypeScript and production build; four event contract/security tests; website build and 12 website tests; deployed ingress authentication checks; database RLS and privilege checks; ordered funnel test within a transaction that was rolled back (no synthetic events retained); protected rates hashes.

Website's broad standalone `tsc --noEmit` has pre-existing errors (missing Cloudflare/Expo declarations, unrelated nullable values and ES target issues). Its production build succeeds. New admin panel compiles in both projects. This is not a claim that the existing website's entire standalone TypeScript check passes.

**iOS Build, simulator tests, launch, manual Apple/Google login/signup/logout, calculator interactions, external app opening, Share Sheet, device RTL/light/dark/layout tests and Archive have not run.** This Linux environment has no Xcode, and GitHub CI run #45 could not start: account locked due to a billing issue. No xcarchive exists yet. An unsigned archive CI step and simulator tests are configured, but configuration is not execution.

After resolving GitHub billing, rerun CI, or on a Mac with Xcode and xcodegen run:

```bash
bash scripts/build-ios-1-1.sh
```

This script tests and creates an **unsigned** archive only. A distribution-signed archive still requires the authorized Apple Development Team, signing certificate/private key and provisioning profile on a Mac. Do not call the existing upload export options. Do not upload, add for review, or submit without the user's later approval.

## What's New — proposed only

تحسينات على تجربة الاستخدام والحاسبة، إضافة تحسينات في التواصل والوصول إلى خدمات UR، وتحسينات في الأداء والاستقرار.

This text has not been sent to Apple. Calculator work in this change instruments existing behavior; its price calculation remains unchanged.

## Rates protection

RatesView.swift, Rate.swift, every existing rates repository/cache file, APIClient.swift, the Supabase mobile-api function and backend public-routes.ts are byte-for-byte unchanged. `scripts/check-protected-rates.py` verifies eight protected files. The existing price-alert startup work remains intact. Dates, “محدث الآن”, sourceTimestamp, updatedAt and buy/sell behavior have not been edited. No git reset, restore or stash was used.

## Website publication and remaining verification

Published existing urremit.com site version **110**, preserving its public audience and custom domain. Added home app section with official icon, actual screenshot and App Store link, framework-generated `apple-itunes-app` metadata, `/admin/app-analytics`, a SUPER_ADMIN-only server proxy and the privacy policy. Supabase bridge summary is tested separately over HTTPS. Full signed-in browser verification of the website dashboard is still pending: the execution network gets HTTP 403 / Cloudflare error 1010 for the custom domain, and this environment does not provide the required Sites control-browser preview skill. Framework metadata rendering code confirms the banner format and source tests confirm one declaration; a live-page banner render has not been independently read here.

The canonical App Store URL remains correct and all buttons use app ID 6815895731. Apple public retrieval failed in this execution environment, so worldwide App Store availability is not certified by this work. The earlier country-availability issue needs a separate App Store Connect availability check after sign-in; no territory setting was changed.

## Migrations applied

1. `20261006223007_app_product_analytics.sql` — private events, quotas, downloads table, role permission and summary.
2. `20261006223511_analytics_site_bridge.sql` — read-only website bridge and completion deduplication.
3. `20261006224010_analytics_retention_scheduler.sql` — daily 90-day retention job.
4. `20261006224626_analytics_summary_performance.sql` — linear aggregation for chart/funnel, shared summary.
5. `20261006225046_analytics_auth_aggregate_access.sql` — narrow server-only Auth state access; no emails/passwords/tokens.

All are applied in the existing production Supabase project. No website D1/rates migrations were added.

## Modified/new repository files

- `.github/workflows/ci.yml`
- `admin/app/analytics/page.tsx`
- `admin/app/api/app-analytics/route.ts`
- `admin/app/layout.tsx`
- `admin/components/analytics/AppAnalyticsPanel.tsx`
- `admin/components/analytics/analytics.css`
- `admin/components/layout/AdminShell.tsx`
- `docs/UR-GLOBAL-1.1-RELEASE.md`
- `ios/Resources/PrivacyInfo.xcprivacy`
- `ios/Tests/URAnalyticsTests.swift`
- `ios/UR/App/RootView.swift`
- `ios/UR/App/URRemitApp.swift`
- `ios/UR/Core/Analytics/URAnalytics.swift`
- `ios/UR/Core/Auth/URAuthService.swift`
- `ios/UR/Features/Admin/AdminAnalyticsView.swift`
- `ios/UR/Features/Admin/AdminModule.swift`
- `ios/UR/Features/Calculator/CalculatorView.swift`
- `ios/UR/Features/Home/HomeView.swift`
- `ios/UR/Features/More/MoreView.swift`
- `ios/project.yml`
- `pnpm-workspace.yaml`
- `scripts/analytics-contract.test.ts`
- `scripts/build-ios-1-1.sh`
- `scripts/check-protected-rates.py`
- `scripts/protected-rates-hashes.json`
- `supabase/config.toml`
- `supabase/functions/app-analytics/contract.ts`
- `supabase/functions/app-analytics/index.ts`
- `supabase/migrations/20261006223007_app_product_analytics.sql`
- `supabase/migrations/20261006223511_analytics_site_bridge.sql`
- `supabase/migrations/20261006224010_analytics_retention_scheduler.sql`
- `supabase/migrations/20261006224626_analytics_summary_performance.sql`
- `supabase/migrations/20261006225046_analytics_auth_aggregate_access.sql`

Security advisor review: the new analytics tables intentionally have RLS and no client policies (informational lint). Existing unrelated warnings remain for set_updated_at search_path, admin_recent_activity/is_admin_user SECURITY DEFINER access and disabled leaked-password protection. They were not changed, especially the existing timestamp trigger. No new analytics security warning was reported.

Build tool alignment: pnpm is pinned to 11.25.0 (the version used for successful local checks), with only esbuild explicitly allowed to run its build script. The dependency lockfile is unchanged.
