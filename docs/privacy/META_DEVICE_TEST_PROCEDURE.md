# Meta Events Manager test on a real iPhone (safe procedure)

Purpose: confirm that opt-in activation events reach Meta, and that nothing is sent without consent, **without** changing any shipped build or production settings.

## Preconditions (owner)
- Meta Developers → UR Global: iOS platform added with bundle ID `com.urremit.mobile`. The Meta app can stay in **Development** mode; do not switch it to Live.
- `ios/Config/Meta.local.xcconfig` (gitignored, never committed): real client token, and `META_APP_EVENTS_ENABLED = YES` **only for this test build**.
- A test iPhone signed in with an Apple ID; Debug build, never uploaded to App Store Connect.

## Steps
1. Events Manager → UR Global app data source → **Test events** tab → choose "App", keep the page open.
2. Build and install the Debug build on the iPhone (Xcode or `xcodebuild` + `devicectl`).
3. **Negative test**: open the app, keep Meta measurement **off** (default) for 2 minutes, background and reopen once. Expect **no events** in Test events.
4. Open More → إعدادات الخصوصية → turn on «قياس الإعلانات عبر Meta».
5. Expect `fb_mobile_activate_app` (and on a fresh install `fb_mobile_install`) within a few minutes. Check that the event shows `advertiser_tracking_enabled = false` and no advertiser ID.
6. Background and reopen: expect another `fb_mobile_activate_app`.
7. **Opt-out test**: turn the switch off, background and reopen twice. Expect no new events.
8. Relaunch the app fully. Expect no SDK traffic at all (optionally confirm with a proxy or Xcode network instrument).

## Afterwards
- Set `META_APP_EVENTS_ENABLED = NO` in the local file.
- Delete the Debug build from the iPhone and reinstall UR Global from the App Store.
- Record the results, with screenshots of Test events, in the PR. Never screenshot the client token.

## Do not
- Do not switch the Meta app to Live, create or launch campaigns, or add funds.
- Do not upload this build to App Store Connect or TestFlight.
- Do not enable advertiser-ID collection or add an ATT prompt.
