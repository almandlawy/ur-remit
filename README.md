# UR | Global Remittances

Production monorepo for the UR informational iPhone app, public mobile API, and administration console.

The iOS v1 product is **information and tracking only**. It does not initiate, process, hold, receive, or transfer funds and does not collect payment credentials.

## Repository

- `ios/` — native SwiftUI iOS 17+ application (Clean Architecture + MVVM)
- `backend/` — versioned TypeScript REST API and PostgreSQL schema
- `admin/` — administration dashboard (introduced after the public API contract)
- `docs/` — architecture, security, API, deployment, testing, and release evidence

## Local prerequisites

- Xcode 26.3 or a compatible stable release
- Node.js 24+
- pnpm 10+
- PostgreSQL 16+

## Bootstrap

```sh
pnpm install
pnpm --filter @ur/backend test
pnpm --filter @ur/backend build
cd ios && xcodegen generate
xcodebuild -project URRemit.xcodeproj -scheme URRemit -sdk iphonesimulator build
```

Copy `backend/.env.example` to `backend/.env` and supply non-production local values. Never commit credentials.

Current delivery status and verified commands are recorded in [`docs/STATUS.md`](docs/STATUS.md).

