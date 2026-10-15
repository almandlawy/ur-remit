#!/bin/sh
set -eu

cd "${CI_PRIMARY_REPOSITORY_PATH:?CI_PRIMARY_REPOSITORY_PATH is required}"

python3 scripts/check-protected-rates.py

# The generated project is committed so Xcode Cloud does not need Homebrew or
# a network install. Fail if release identity drifts between the source of truth
# and the checked-in project.
expected_build="$(awk '/CURRENT_PROJECT_VERSION:/ { print $2; exit }' ios/project.yml)"
test -n "$expected_build"
expected_count="$(grep -c "CURRENT_PROJECT_VERSION = ${expected_build};" ios/URRemit.xcodeproj/project.pbxproj)"
actual_count="$(grep -c 'CURRENT_PROJECT_VERSION = ' ios/URRemit.xcodeproj/project.pbxproj)"
test "$expected_count" -eq "$actual_count"
grep -q 'MARKETING_VERSION = 1.2.1;' ios/URRemit.xcodeproj/project.pbxproj
grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.urremit.mobile;' ios/URRemit.xcodeproj/project.pbxproj
