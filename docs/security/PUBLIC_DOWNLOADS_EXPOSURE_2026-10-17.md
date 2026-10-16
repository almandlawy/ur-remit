# Publicly downloadable iOS source and setup scripts on urremit.com

**Status: finding only. Nothing changed or deleted.** Checked 2026-10-17.

## What is exposed
All files below return HTTP 200 from `https://www.urremit.com/downloads/…` and are byte-identical (SHA-256) to `hosted-site-source/public/downloads/…`:

| Path | Size | Type |
|---|---|---|
| `native-ios/MoreView.swift` | 132 KB | iOS source: account, sign-in, owner session, telemetry |
| `native-ios/NativeFlow.swift` | 113 KB | iOS source: native flows |
| `native-ios/README-AR.txt` | 11 KB | Instructions |
| `UR-Native-iOS-20261008.zip` | 277 KB | Source archive (11 files) |
| `UR-Mac-Native.sh`, `UR-Mac-Resume.sh`, `UR-Mac-Upgrade.sh` | 276 / 8 / 23 KB | Mac setup scripts |

## Risk
- **No credentials found.** Secret patterns matched only empty `password = ""` resets. Archive file names include no keys, certificates, profiles or `.env` files.
- They do disclose internal API routes, auth and owner-session flows, and app logic. That makes targeted probing easier.
- The Mac scripts are executable installers served from the production domain. If they were ever altered, users who ran them could be harmed.

## Recommendation (needs owner approval)
1. Remove `public/downloads/native-ios/`, the zip and the three `.sh` files from the site source and redeploy.
2. If any are still needed, serve them from a private location (for example a private GitHub release), not the public site.
3. Review `app/` routes and tests that reference these files (`tests/native-installer-assets.test.mjs`) before removal.
