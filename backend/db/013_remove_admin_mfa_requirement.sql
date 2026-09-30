BEGIN;

-- Preserve disabled_at: removing MFA must not silently reactivate intentionally disabled admins.
UPDATE admin_sessions
SET revoked_at = now()
WHERE revoked_at IS NULL;

ALTER TABLE admin_users
  DROP CONSTRAINT IF EXISTS admin_users_requires_mfa,
  DROP CONSTRAINT IF EXISTS admin_users_mfa_required_secret;

UPDATE admin_users
SET mfa_required = false
WHERE mfa_required;

ALTER TABLE admin_sessions
  ALTER COLUMN mfa_verified_at DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.admin_authenticate(p_token_hash text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  actor jsonb;
BEGIN
  UPDATE admin_sessions s
  SET last_seen_at = now()
  FROM admin_users u, roles r
  WHERE s.admin_user_id = u.id
    AND r.id = u.role_id
    AND s.token_hash = p_token_hash
    AND s.revoked_at IS NULL
    AND s.expires_at > now()
    AND u.disabled_at IS NULL
  RETURNING jsonb_build_object(
    'id', u.id,
    'role', r.name,
    'permissions', COALESCE((
      SELECT jsonb_agg(p.name ORDER BY p.name)
      FROM role_permissions rp
      JOIN permissions p ON p.id = rp.permission_id
      WHERE rp.role_id = r.id
    ), '[]'::jsonb)
  ) INTO actor;
  RETURN actor;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_authenticate(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_authenticate(text) TO service_role;

COMMIT;
