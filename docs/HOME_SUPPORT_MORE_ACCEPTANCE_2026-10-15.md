# UR Global — Home, Support and More acceptance checkpoint

Date: 2026-10-15  
App version/build: 1.2.1 (18)  
Server source commit: `7cc0b6d`

## Implemented

- Home is now the default tab and works as a customer follow-up center.
- USD/IQD buy and sell use grouped digits, an explicit per-100 USD unit, source timestamp, and cached/stale badges.
- Rate loading and open-order loading are isolated, refresh on foreground, and support pull-to-refresh and retry.
- New transfer and transfer history are primary actions; open orders show a short identifier, state and next action without copying profile data into the Home state.
- Support uses the existing authenticated customer session and the server ticket store rather than WhatsApp autofill.
- Transfer/payment tickets require one of the authenticated customer's own orders. The server verifies ownership.
- Ticket creation/reply/reopen are idempotent, account scoped and audited. Staff replies move the ticket to `waiting_customer`; customer replies/reopen move it to `in_progress`; staff can close it.
- More is grouped into Account, Tools, and Help/Information. Placeholder leaderboard and generic share templates were removed from the customer path.
- Fixed splash wait reduced from five seconds to 1.1 seconds (0.25 seconds with Reduce Motion).

## Verification completed

- Protected rates check: 8 protected files unchanged.
- Server production build: passed.
- Server tests: 112/112 passed, including 3 new support ownership/idempotency/isolation tests.
- iPhone 15 Simulator build: passed.
- iPhone 15 Simulator XCTest: 2/2 passed.
- iPad 10th generation Simulator XCTest: 2/2 passed.
- Visual inspection: Home, Support visitor state and More captured on iPhone and iPad under `output/ui-qa/home-support-more/`.

## Not yet claimed

- The new server migration and support API are not deployed at this checkpoint.
- Authenticated ticket create/reply/close acceptance with two dedicated test accounts is pending credentials/deployment; local tests do not prove production behavior.
- Support attachment upload is not exposed in the iOS ticket composer yet.
- App Store Connect was checked live: Build 17 is already uploaded and `Ready to Submit`, so this source was advanced to Build 18. Archive/TestFlight upload remains a separate verification step; App Store review was not started.
