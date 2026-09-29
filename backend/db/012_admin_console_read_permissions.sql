BEGIN;

UPDATE admin_sessions s
SET revoked_at = now()
FROM admin_users u
WHERE s.admin_user_id = u.id
  AND s.revoked_at IS NULL
  AND (NOT u.mfa_required OR u.mfa_secret_ciphertext IS NULL);

UPDATE admin_users
SET disabled_at = COALESCE(disabled_at, now())
WHERE NOT mfa_required OR mfa_secret_ciphertext IS NULL;

ALTER TABLE admin_users
  DROP CONSTRAINT IF EXISTS admin_users_requires_mfa,
  ADD CONSTRAINT admin_users_requires_mfa
    CHECK (disabled_at IS NOT NULL OR (mfa_required AND mfa_secret_ciphertext IS NOT NULL));

DROP POLICY IF EXISTS public_read_rates ON rates;
DROP POLICY IF EXISTS public_read_active_rates ON rates;
CREATE POLICY public_read_active_rates ON rates
  FOR SELECT TO anon USING (is_active = true);

DROP POLICY IF EXISTS public_read_offices ON offices;
DROP POLICY IF EXISTS public_read_active_offices ON offices;
CREATE POLICY public_read_active_offices ON offices
  FOR SELECT TO anon USING (is_active = true);

GRANT SELECT ON rates, offices TO anon;

INSERT INTO permissions(name) VALUES ('admins.read')
ON CONFLICT (name) DO NOTHING;

INSERT INTO role_permissions(role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'SUPER_ADMIN'
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO role_permissions(role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE p.name IN ('audit.read', 'agents.read')
  AND r.name = 'COMPLIANCE_OFFICER'
ON CONFLICT (role_id, permission_id) DO NOTHING;

COMMIT;
