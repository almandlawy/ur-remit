BEGIN;

ALTER TABLE admin_sessions
  ALTER COLUMN mfa_verified_at DROP NOT NULL;

COMMIT;
