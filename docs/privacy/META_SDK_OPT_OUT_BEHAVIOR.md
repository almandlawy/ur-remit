# Meta SDK behaviour around consent (SDK 18.1.1, UR Global)

Verified in SDK source (`.build/spm/checkouts/facebook-ios-sdk`) and by a simulator network check.

## Before consent
- The SDK has no load-time hooks (`+load` or constructors), so linking it does nothing by itself.
- `URMetaMeasurement` does not touch the SDK unless the build has a token, `META_APP_EVENTS_ENABLED = YES`, **and** the user opted in.
- Simulator check (dummy token, events enabled, consent off, 20 s): **0 connections to Meta hosts** and no SDK state created. Control with consent on: a connection to `*.facebook.com` appeared.

## At opt-in
- Clears any persisted event queue, enables auto-logging, initializes the SDK, sets flushing to automatic, and logs `activateApp`.
- The SDK then fetches server configuration and gatekeepers and sends install and activate events.

## At opt-out (same session)
| What | Effect |
|---|---|
| Auto-logging (`activateApp` on foreground) | Stops immediately (`isAutoLogAppEventsEnabled = false`) |
| Queued, unsent events | Not flushed automatically (`flushBehavior = .explicitOnly`); on-disk queue deleted (`clearPersistedAppEventsStates`) |
| Stored user data | Cleared (`clearUserData`, `userID = nil`); the app never sets any |
| **SDK lifecycle observers** | **Remain until the app process ends.** The SDK cannot be un-initialized |
| **Server configuration / gatekeeper fetches** | **May still occur** until relaunch, for example on foreground. These carry the app ID, SDK version and IP, but no app events |
| SKAdNetwork reporter | The SDK's own SKAN conversion-value updates may continue until relaunch |
| `anon_id` | **Reset**: the app deletes `Library/com-facebook-sdk-PersistedAnonymousID.json` on every opt-out; the SDK re-reads that file on each use, so a re-opt-in gets a new ID. A unit test checks the filename against the pinned SDK source |

## After relaunch
- With consent off, the SDK is not initialized: no Meta traffic.

## Limitations to state honestly
1. Opting out takes full effect at the next launch. Until then, configuration-only traffic is possible.
2. Data already sent to Meta stays with Meta under Meta's terms; UR cannot delete it from Meta's systems.
3. The `anon_id` reset relies on the SDK's internal filename (not public API); `testAnonymousIDFileNameMatchesPinnedSDK` fails if an SDK update changes it.
4. Apple's SKAdNetwork / AdAttributionKit postbacks are sent by iOS, not the SDK, so they don't depend on the in-app switch.
