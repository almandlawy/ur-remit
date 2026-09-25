# Supabase authentication

Production project: `UR Production` (`yqvcoomjunwokyxwofvt`). The iOS app uses only the public project URL and publishable key. Administrative database credentials and the service-role key must never be embedded in the app.

## Redirect configuration

In Supabase Authentication > URL Configuration, add this exact redirect URL:

`urremit://auth/callback`

Keep the production website as the Site URL. Do not use wildcard redirects in production.

## Sign in with Apple

1. Keep the Xcode `Sign in with Apple` capability enabled for `com.urremit.mobile`.
2. In the Apple Developer portal create/configure the Services ID used by Supabase.
3. Add the Supabase callback URL shown on the Apple provider page to the Apple Services ID.
4. Enter the Apple Services ID and generated client secret in Supabase Authentication > Providers > Apple, then enable it.

The app sends an SHA-256 nonce with the native Apple request and exchanges the returned identity token with Supabase.

## Google

1. In Google Cloud create an OAuth Web client for UR.
2. Add the Supabase callback URL shown on the Google provider page as an authorized redirect URI.
3. Add `urremit.com` and the Supabase project domain as authorized domains where required.
4. Enter the Google client ID and client secret in Supabase Authentication > Providers > Google, then enable it.

The iOS callback returns to `urremit://auth/callback` and the resulting session is stored in the iOS Keychain.

## Release gate

Before TestFlight upload, verify Apple and Google using real provider credentials on a physical device. A successful Xcode build does not prove that external provider credentials are configured.
