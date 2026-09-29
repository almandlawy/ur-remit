BEGIN;

UPDATE admin_sessions s
SET revoked_at = now()
FROM admin_users u
WHERE s.admin_user_id = u.id
  AND s.revoked_at IS NULL
  AND (NOT u.mfa_required OR s.mfa_verified_at IS NULL);

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
    AND s.mfa_verified_at IS NOT NULL
    AND u.mfa_required
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
