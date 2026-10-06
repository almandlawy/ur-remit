#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo 'Xcode on macOS is required.' >&2; exit 1; }
command -v xcodegen >/dev/null || { echo 'Install xcodegen using Homebrew first.' >&2; exit 1; }
python3 scripts/check-protected-rates.py
xcodegen generate --spec ios/project.yml --project ios
mkdir -p artifacts
ur_simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; print(next(d["udid"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if "iPhone" in d["name"]))')"
xcodebuild -project ios/URRemit.xcodeproj -scheme URRemit -destination "platform=iOS Simulator,id=${ur_simulator_id}" CODE_SIGNING_ALLOWED=NO -resultBundlePath "artifacts/URGlobal-tests-$(date +%Y%m%d-%H%M%S).xcresult" test
xcodebuild -project ios/URRemit.xcodeproj -scheme URRemit -destination 'generic/platform=iOS' -archivePath "artifacts/URGlobal-1.1-build12-$(date +%Y%m%d-%H%M%S).xcarchive" CODE_SIGNING_ALLOWED=NO archive
# Archive only. No export, Transporter, upload, Add for Review, or Submit for Review.
