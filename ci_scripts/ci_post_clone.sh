#!/bin/sh
set -eu

cd "${CI_PRIMARY_REPOSITORY_PATH:?CI_PRIMARY_REPOSITORY_PATH is required}"

python3 scripts/check-protected-rates.py

# The generated project is committed so Xcode Cloud does not need Homebrew or
# a network install. Fail if release identity drifts between the source of truth
# and the checked-in project.
grep -q 'CURRENT_PROJECT_VERSION = 15;' ios/URRemit.xcodeproj/project.pbxproj
grep -q 'MARKETING_VERSION = 1.2;' ios/URRemit.xcodeproj/project.pbxproj
grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.urremit.mobile;' ios/URRemit.xcodeproj/project.pbxproj
