BEGIN;

ALTER TABLE admin_users
  ADD COLUMN mfa_secret_ciphertext bytea,
  ADD COLUMN failed_login_count integer NOT NULL DEFAULT 0,
  ADD COLUMN locked_until timestamptz,
  ADD COLUMN last_login_at timestamptz;

ALTER TABLE admin_users ADD CONSTRAINT admin_users_mfa_required_secret
  CHECK (NOT mfa_required OR mfa_secret_ciphertext IS NOT NULL);

COMMIT;

