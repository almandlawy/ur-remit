# Administration

The dashboard is a Next.js server-rendered application. Browser credentials are exchanged through the dashboard BFF; the resulting admin token is stored only in an `HttpOnly`, `SameSite=Strict`, secure production cookie.

Admin login requires email, a scrypt password, and a six-digit TOTP. Five failed attempts lock the user for 15 minutes. Sessions expire after 30 minutes and are stored as keyed fingerprints only.

Rate edits require `rates.write` and create an immutable new rate version, rate-history entry, and audit event in one database transaction.

Environment:

```text
UR_BACKEND_URL=https://api.urremit.com
```

Never expose database, session hashing, or MFA encryption keys to the browser.

