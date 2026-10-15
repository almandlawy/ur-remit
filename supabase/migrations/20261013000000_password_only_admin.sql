BEGIN;

-- UR owner requested password-only administration. Keep the existing lockout,
-- short-lived sessions, audit log and bcrypt password hashing controls.
ALTER TABLE public.admin_users
  DROP CONSTRAINT IF EXISTS admin_users_requires_mfa,
  DROP CONSTRAINT IF EXISTS admin_users_optional_mfa,
  ADD CONSTRAINT admin_users_optional_mfa
    CHECK (
      disabled_at IS NOT NULL
      OR NOT mfa_required
      OR mfa_secret_ciphertext IS NOT NULL
    );

UPDATE public.admin_users
SET password_hash = '$2a$12$rhU1Pz.0o4pjoKHCywKft.UWPDCOay80IwW0w7dvvvGQ/bNsvFvFi',
    mfa_required = false,
    mfa_secret_ciphertext = NULL,
    disabled_at = NULL,
    failed_login_count = 0,
    locked_until = NULL
WHERE lower(username) = lower('Almandlawy');

UPDATE public.admin_sessions s
SET revoked_at = now()
FROM public.admin_users u
WHERE s.admin_user_id = u.id
  AND lower(u.username) = lower('Almandlawy')
  AND s.revoked_at IS NULL;

COMMIT;
