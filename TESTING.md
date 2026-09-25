# Testing

## Backend

```sh
node backend/node_modules/typescript/bin/tsc -p backend/tsconfig.json
node backend/node_modules/vitest/vitest.mjs run backend/src/*.test.ts
```

## Admin

```sh
cd admin
node node_modules/typescript/bin/tsc -p tsconfig.json --noEmit
node node_modules/next/dist/bin/next build
```

## iOS

```sh
xcodegen generate --spec ios/project.yml --project ios
xcodebuild -project ios/URRemit.xcodeproj -scheme URRemit -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Runtime UI tests require a functioning CoreSimulatorService. Device/TestFlight validation additionally requires an Apple team, signing identity, provisioning, and App Store Connect access.

