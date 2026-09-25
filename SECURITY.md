# Security baseline

- TLS is mandatory at ingress; HSTS is enabled on production origins.
- Secrets live in the deployment secret manager and CI protected variables.
- Public and admin APIs are separate route trees with separate authorization policies.
- Admin requires phishing-resistant MFA where supported, short sessions, reauthentication for high-risk changes, RBAC, and append-only audits.
- Logs redact tokens, phone numbers, full transfer references, and personal data.
- Tracking and agent verification use layered IP/device/risk rate limits and generic not-found responses.
- Office QR links are signed, expiring, audience-bound tokens; signing keys never ship in the app.
- App Attest assertions can protect high-abuse endpoints after staged rollout and metrics validation.
- Certificate pinning is not enabled for v1 unless operational key rotation and backup pins are proven.

## Threat model priorities

Reference enumeration, admin credential attacks, API scraping, QR spoofing, injection, replay, push-token misuse, and sensitive logging are explicit abuse cases. Security events must be retained independently from application logs.

