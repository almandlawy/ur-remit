# UR Admin

Arabic, RTL administration console for the UR Remit operations API.

## Architecture

```text
Browser (Arabic RTL; session cookie is httpOnly)
  ├─ Server Components render protected admin screens
  └─ Same-origin Next.js route handlers validate Origin/CSRF
       └─ Fastify admin API (private UR_BACKEND_URL)
            └─ PostgreSQL through the existing pg-backed AdminStore
```

The existing Fastify service is the security boundary. It checks the
session-token fingerprint against `admin_sessions`, enforces MFA and
role-permission checks, validates every write with Zod, and writes audited
changes in PostgreSQL transactions. The database `service_role` key is not
used by this console and must never be added to a browser bundle. The
Supabase `service_role` role remains server-only; Supabase public policies
allow anonymous reads of active rates and offices only.

The login route forwards username, password, and a six-digit TOTP to Fastify.
The returned random session token is set only in a `Secure` (in production),
`SameSite=Strict`, `httpOnly` cookie. PostgreSQL stores only its keyed
SHA-256 fingerprint and a 24-hour expiry. Logout revokes the session in the
database. Password changes require the current password and MFA, revoke all
sessions for the account, and require a fresh login. Login is rate-limited by
Fastify to five attempts per 15 minutes.

Writes to rates use the existing versioned-rate transaction and rate history.
Office create/update/deactivate operations store audit snapshots atomically;
deactivation is a soft delete. Admin and audit pages are read-only. Office
management is guarded by `offices.read` / `offices.write`, rates by
`rates.read` / `rates.write`, admin accounts by `admins.read`, and audit data
by `audit.read`.

## Requirements

- Node.js 24 or newer
- pnpm 10 (`corepack enable` if needed)
- PostgreSQL/Supabase schema and admin migrations applied
- The UR Fastify service configured with `DATABASE_URL`,
  `ADMIN_SESSION_HASH_KEY`, and `ADMIN_MFA_ENCRYPTION_KEY`

## Local setup

Start the Fastify backend from the repository root:

```sh
cp backend/.env.example backend/.env
# Set development-only PostgreSQL and random key values in backend/.env.
corepack pnpm --dir backend dev
```

Configure and start the admin app in a second terminal:

```sh
cp admin/.env.local.example admin/.env.local
corepack pnpm --dir admin dev
```

Open `http://localhost:3000`. Set `UR_BACKEND_URL` to the internal Fastify
origin reachable from the Next.js server. Do not use a `NEXT_PUBLIC_` prefix.
In local HTTP development the session cookie is not marked `Secure`; use HTTPS
for any non-local deployment.

## First administrator

Apply the SQL migrations before bootstrapping an account. Generate a strong
password outside shell history and export it only in the short-lived command
environment. `ADMIN_MFA_ENCRYPTION_KEY` must be the same base64-encoded
32-byte key configured on the backend.

```sh
cd backend
read -s -p "Initial admin password: " ADMIN_INITIAL_PASSWORD
export ADMIN_INITIAL_PASSWORD
echo
node --env-file=.env scripts/seed-admin.mjs \
  --email admin@example.invalid \
  --username ur-admin \
  --role SUPER_ADMIN
unset ADMIN_INITIAL_PASSWORD
```

Set `ADMIN_INITIAL_PASSWORD` in the environment of that command. The script
prints a newly generated TOTP seed and provisioning URI once; enroll the seed
in an authenticator and store it securely. The database stores only an
AES-256-GCM ciphertext. To rotate an existing bootstrap account, explicitly
pass `--reset-existing`; doing so replaces its password and MFA seed and
revokes its existing sessions. The script never prints a password.

## Configuration

`admin/.env.local`:

```dotenv
UR_BACKEND_URL=http://127.0.0.1:8080
```

Backend secrets belong only in `backend/.env` locally or the backend hosting
provider's secret store:

```dotenv
DATABASE_URL=postgresql://...
ADMIN_SESSION_HASH_KEY=<independent-random-secret-at-least-32-characters>
ADMIN_MFA_ENCRYPTION_KEY=<base64-encoded-random-32-byte-key>
```

Never commit real credentials, database URLs, MFA seeds, or production keys.
No service-role key or secret is required by the browser or Next.js app.

## Routes

- `/login` — username, password, and TOTP login
- `/dashboard` — operations metrics and current active rates
- `/rates` and `/rates/[id]/edit` — rate list, history versions, and updates
- `/offices`, `/offices/new`, `/offices/[id]/edit` — office management
- `/agents` — read-only agents
- `/admins` — read-only administrator accounts
- `/audit` — read-only audit log
- `/settings` — MFA-protected password change

Next.js proxies browser mutations through same-origin handlers. The handlers
validate the `Origin` header, whitelist API paths, and read the session only
from the `httpOnly` cookie. Fastify separately validates permissions and
CSRF is not delegated to client JavaScript.

## Validation

```sh
corepack pnpm --dir backend lint
corepack pnpm --dir backend test
corepack pnpm --dir admin lint
corepack pnpm --dir admin build
```

Backend Vitest tests cover successful/failed login, rate updates, and office
creation validation and permissions.

## Supabase and production deployment

1. Review `supabase/migrations/20260928000000_admin_console_read_permissions.sql`.
   It enables public reads for active rates/offices, grants read-only admin
   permissions by role, revokes sessions lacking MFA, and disables accounts
   without an encrypted MFA seed. Apply it first to a non-production branch,
   verify an MFA-enrolled `SUPER_ADMIN` can sign in, then apply it to production.
2. Set backend secrets on the private Fastify host and deploy `backend/`.
   Configure `TRUST_PROXY=true` only behind a trusted proxy. Keep
   `ADMIN_SESSION_HASH_KEY` independent from the MFA encryption key.
3. Set `UR_BACKEND_URL` as a server-only environment variable for the Next.js
   deployment. Vercel or Netlify can host the Next.js application; ensure
   server route handlers can reach Fastify over HTTPS/private networking.
4. Configure TLS and the production host allow-list at the reverse proxy.
   The app rejects cross-origin mutations and sends restrictive security
   headers. Avoid wildcard CORS for admin endpoints.
5. Create or rotate the first admin with `backend/scripts/seed-admin.mjs`,
   enroll its TOTP seed, and verify login, logout, permissions, and audit
   records before opening access to operators.
6. Never expose a PostgreSQL connection string, Supabase `service_role` key,
   session hash key, MFA encryption key, or TOTP seed to the browser.

## Netlify + Railway deployment

Use the existing Fastify backend for admin APIs. The `mobile-api` Supabase
Edge Function is the mobile API and currently does not expose the full admin
route set; a healthy `/health` response does not mean admin routes exist there.
The admin app calls Fastify server-to-server, so browser CORS configuration is
not needed and should not be opened up for the dashboard.

### Deploy the backend to Railway

1. Push the repository to the Git provider connected to Railway. In Railway,
   create a project, choose **Deploy from GitHub repo**, and select this
   repository. Set the service root directory to `/` (repository root) so the
   root `railway.json`, workspace files, and `backend/Dockerfile` are used.
   Railway reads `railway.json` and builds `backend/Dockerfile`.
2. Add the backend secrets in Railway service **Variables**. `DATABASE_URL`
   must be the Supabase **Session pooler** connection string for this project
   (the pooler supports IPv4 hosts); keep the database password private.
   Add these variables from the protected local `backend/.env` or generate
   fresh, independent keys:

   ```text
   NODE_ENV=production
   DATABASE_URL=<Supabase Session pooler PostgreSQL URI>
   LOOKUP_HASH_KEY=<random secret of at least 32 characters>
   ADMIN_SESSION_HASH_KEY=<a separate random secret of at least 32 characters>
   ADMIN_MFA_ENCRYPTION_KEY=<base64 encoding of exactly 32 random bytes>
   TRUST_PROXY=true
   ```

   Railway supplies `PORT`; do not set a fixed production port. The backend
   binds to `0.0.0.0` in production by default. Set `TRUST_PROXY=true` only
   when Railway is the public ingress and forwards sanitized proxy headers;
   this lets request-based rate limits use the client address.
3. Deploy the service and wait for the configured `/api/v1/health`
   health-check to pass. In Railway service settings, generate a public HTTPS
   domain. The URL will be specific to your Railway service, for example
   `https://your-service.up.railway.app`; do not assume the example URL is
   your assigned domain.
4. From a terminal, set `BACKEND_URL` to the generated domain and check the
   public API and protected admin endpoint:

   ```sh
   export BACKEND_URL='https://your-assigned-domain.up.railway.app'
   curl --fail --show-error "$BACKEND_URL/api/v1/health"
   curl --include "$BACKEND_URL/api/v1/admin/me"
   ```

   Expect health HTTP 200 with `"database":"ok"` and an unauthenticated admin
   request HTTP 401. Do not send real admin passwords in test requests.

### Connect Netlify to Railway

1. Open the Netlify site `ur-global-admin`, then **Site configuration →
   Environment variables**. Add `UR_BACKEND_URL` with the exact public HTTPS
   Railway origin, with no `/api/...` suffix or trailing path.
2. Scope the variable to the Netlify deploy contexts that need the production
   API. Do not use `NEXT_PUBLIC_UR_BACKEND_URL`; the value is used only in
   server-side route handlers and Server Components.
3. Netlify sets `NODE_ENV=production` for a production Next.js deployment;
   leave that managed value alone. Trigger a new production deploy so the
   serverless functions receive `UR_BACKEND_URL`.
4. Visit `https://ur-global-admin.netlify.app/login` and sign in with the
   enabled admin username, password, and current TOTP code. The cookie is
   `httpOnly`, `Secure` in production, and `SameSite=Strict`. Dashboard and
   mutation requests go through same-origin Next.js API routes; each write
   still passes the Fastify session, permission, validation, rate-limit, and
   audit checks.

### Verify the deployment

```sh
curl --fail --show-error "$BACKEND_URL/api/v1/health"
curl --include "$BACKEND_URL/api/v1/admin/me"
```

From the browser, verify login, dashboard, rates, offices, agents, admins,
audit, settings, logout, and that a user without the corresponding permission
receives an access-denied response. Confirm that a successful rate or office
write appears in the audit page. Never put database credentials or backend
keys in Netlify variables prefixed with `NEXT_PUBLIC_`.

## Troubleshooting

- **Login always fails:** confirm the backend has the same MFA encryption
  key used when the seed was enrolled, the TOTP device clock is synchronized,
  and the account is enabled with MFA required.
- **Dashboard returns 403:** apply the role-permission migration and assign
  only the minimum required permissions to that role.
- **API unavailable:** check the server-only `UR_BACKEND_URL`, backend health,
  and network access from the Next.js server.
- **Login returns to the login page:** check Netlify `UR_BACKEND_URL` is the
  Railway HTTPS origin (not `127.0.0.1`, a Supabase project URL, or the
  `/functions/v1/mobile-api` URL); then redeploy Netlify. Check Railway logs
  and verify the `/api/v1/health` endpoint from outside Railway.
- **Backend responds with HTTP 404 for admin paths:** use Fastify's
  `/api/v1/admin/...` route prefix. Do not point the console at
  `mobile-api/admin/...`; that deployed Edge Function does not implement the
  admin console endpoints.
- **Railway deployment cannot connect to PostgreSQL:** use Supabase's Session
  pooler host/URI rather than a direct IPv6-only database endpoint; verify the
  database password and pooler connection mode in Supabase.
- **Railway never passes health check:** confirm it builds from the repository
  root with `backend/Dockerfile`, has all required environment variables, and
  that `/api/v1/health` reports the database dependency as `ok`.
- **MFA lockout:** do not disable MFA. An authorized operator should rotate
  the account with `seed-admin.mjs --reset-existing`, securely enroll the new
  seed, and invalidate old sessions.
- **RLS query failures:** public anon access is intentionally limited to
  active rate and office rows. Admin queries must stay in the trusted backend.
