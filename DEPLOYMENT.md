# Deployment

Production requires separate PostgreSQL databases and secrets for development, staging, and production. Apply migrations in numeric order and deploy the API before the admin dashboard or iOS release.

Required backend secrets:

- `DATABASE_URL`
- `LOOKUP_HASH_KEY`
- `ADMIN_SESSION_HASH_KEY`
- `ADMIN_MFA_ENCRYPTION_KEY` (base64-encoded 32 bytes)

The production API origin is `https://api.urremit.com`; staging is `https://api-staging.urremit.com`. TLS termination, HSTS, DDoS/WAF controls, database backups, metrics, alerts, and secret rotation are infrastructure requirements.

TestFlight upload requires an Apple Distribution identity, provisioning for `com.urremit.mobile`, and App Store Connect API credentials with the minimum required role. None are committed to this repository.

