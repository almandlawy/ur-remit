BEGIN;

CREATE TABLE admin_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id uuid NOT NULL REFERENCES admin_users(id),
  token_hash text UNIQUE NOT NULL,
  mfa_verified_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  ip_fingerprint text,
  user_agent_fingerprint text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at)
);

CREATE INDEX admin_sessions_active_token_idx ON admin_sessions(token_hash, expires_at)
  WHERE revoked_at IS NULL;

INSERT INTO permissions(name) VALUES
  ('dashboard.read'), ('rates.read'), ('rates.write'), ('offices.read'), ('offices.write'),
  ('agents.read'), ('agents.write'), ('notifications.send'), ('config.write'), ('audit.read')
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles(name) VALUES
  ('SUPER_ADMIN'), ('COUNTRY_MANAGER'), ('COMPLIANCE_OFFICER'), ('SUPPORT_EMPLOYEE'),
  ('CONTENT_MANAGER'), ('PRICE_MANAGER'), ('VIEWER')
ON CONFLICT (name) DO NOTHING;

COMMIT;

