# Administration

The dashboard is a Next.js server-rendered application. Browser credentials are exchanged through the dashboard BFF; the resulting admin token is stored only in an `HttpOnly`, `SameSite=Strict`, secure production cookie.

The in-app admin login uses an admin username or email and password; an Authenticator app or MFA code is not required. Login is rate-limited to five requests per 15 minutes, and five invalid password attempts lock the account for 15 minutes. Sessions expire after 24 hours and are stored as keyed fingerprints only.

Rate edits require `rates.write` and create an immutable new rate version, rate-history entry, and audit event in one database transaction.

Environment:

```text
UR_BACKEND_URL=https://api.urremit.com
```

Never expose database or session hashing keys to the browser.
