BEGIN;

ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS username text;
CREATE UNIQUE INDEX IF NOT EXISTS admin_users_username_unique
  ON admin_users (lower(username)) WHERE username IS NOT NULL;

INSERT INTO permissions(name) VALUES ('dashboard.read'), ('rates.read'), ('rates.write')
ON CONFLICT (name) DO NOTHING;

INSERT INTO role_permissions(role_id, permission_id)
SELECT roles.id, permissions.id
FROM roles CROSS JOIN permissions
WHERE roles.name = 'PRICE_MANAGER'
  AND permissions.name IN ('dashboard.read', 'rates.read', 'rates.write')
ON CONFLICT DO NOTHING;

UPDATE admin_users
SET disabled_at = now()
WHERE lower(email) <> 'admin@urremit.local';

INSERT INTO admin_users(email, username, password_hash, role_id, mfa_required)
SELECT
  'admin@urremit.local',
  'Almandlawy',
  'scrypt$32768$8$1$Vw9R7xLKIt8mV1i4kbKOgQ$Eq1_xqtQm_CnqvcqmLZL0nb5gXjApENWGuPmUvCSxl8',
  roles.id,
  false
FROM roles WHERE roles.name = 'PRICE_MANAGER'
ON CONFLICT (email) DO UPDATE SET
  username = EXCLUDED.username,
  password_hash = EXCLUDED.password_hash,
  role_id = EXCLUDED.role_id,
  mfa_required = false,
  disabled_at = NULL;

INSERT INTO app_config(key, value, is_public) VALUES
  ('commissionBasis', '{"currency":"USD","amount":10000,"labelAr":"لكل 10,000 دولار","labelEn":"per USD 10,000"}'::jsonb, true)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, is_public = EXCLUDED.is_public, updated_at = now();

COMMIT;
