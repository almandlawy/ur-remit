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
xcodebuild test -project ios/URRemit.xcodeproj -scheme URRemit \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Runtime UI tests require a functioning CoreSimulatorService. Device/TestFlight validation additionally requires an Apple team, signing identity, provisioning, and App Store Connect access.

### iOS manual smoke checks

- With VoiceOver on, verify each bottom-navigation tab announces its localized name and selected state.
- Increase Dynamic Type and confirm bottom-navigation labels and rate cards remain readable.
- Search rates by localized route name and either currency; save a favorite, filter to favorites, and relaunch to confirm favorites persist.
- With rates loaded, enable airplane mode and refresh. Confirm cached rates remain visible with an offline notice.
- Enter zero, a negative value, malformed text, and a positive amount using the device locale in the calculator. Only positive, parseable amounts should produce an estimate.
- Enter a reference that does not match the existing `UR-XXXXXXXX` tracking format and confirm the app blocks the lookup before sending a request.
- If the cache directory is unavailable or unwritable during local testing, confirm a successful online rate response remains visible and the app explains that offline saving failed.
