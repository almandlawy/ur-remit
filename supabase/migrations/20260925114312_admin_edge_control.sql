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

UPDATE admin_users SET disabled_at = now()
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

CREATE OR REPLACE FUNCTION public.admin_authenticate(p_token_hash text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE actor jsonb;
BEGIN
  UPDATE admin_sessions s SET last_seen_at = now()
  FROM admin_users u, roles r
  WHERE s.admin_user_id = u.id AND r.id = u.role_id
    AND s.token_hash = p_token_hash AND s.revoked_at IS NULL
    AND s.expires_at > now() AND u.disabled_at IS NULL
  RETURNING jsonb_build_object(
    'id', u.id,
    'role', r.name,
    'permissions', COALESCE((
      SELECT jsonb_agg(p.name ORDER BY p.name)
      FROM role_permissions rp JOIN permissions p ON p.id = rp.permission_id
      WHERE rp.role_id = r.id
    ), '[]'::jsonb)
  ) INTO actor;
  RETURN actor;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'activeRoutes', (SELECT count(*) FROM rate_routes WHERE is_active),
    'activeOffices', (SELECT count(*) FROM offices WHERE is_active AND is_verified),
    'verifiedAgents', (SELECT count(*) FROM agents WHERE status = 'VERIFIED'),
    'pushSubscribers', (SELECT count(*) FROM push_tokens WHERE revoked_at IS NULL),
    'lastRateUpdate', (SELECT max(source_timestamp) FROM rates WHERE is_active)
  );
$$;

CREATE OR REPLACE FUNCTION public.admin_update_rate(
  p_actor_id uuid,
  p_rate_id uuid,
  p_buy numeric,
  p_sell numeric,
  p_fee_fixed numeric,
  p_request_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE old_rate rates%ROWTYPE; new_rate rates%ROWTYPE;
BEGIN
  SELECT * INTO old_rate FROM rates WHERE id = p_rate_id FOR UPDATE;
  IF NOT FOUND THEN RETURN NULL; END IF;

  UPDATE rates SET is_active = false WHERE id = p_rate_id;
  INSERT INTO rates(route_id, buy, sell, fee_fixed, fee_percent, valid_from, valid_until, source_timestamp, version, is_active)
  VALUES(old_rate.route_id, p_buy, p_sell, p_fee_fixed, old_rate.fee_percent, now(), old_rate.valid_until, now(), old_rate.version + 1, true)
  RETURNING * INTO new_rate;

  INSERT INTO rate_history(rate_id, old_value, new_value, actor_id, request_id, context)
  VALUES(new_rate.id, to_jsonb(old_rate), to_jsonb(new_rate), p_actor_id, p_request_id, '{"source":"admin-edge-api"}'::jsonb);
  INSERT INTO audit_logs(actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  VALUES(p_actor_id, 'UPDATE', 'rate', new_rate.id::text, to_jsonb(old_rate), to_jsonb(new_rate), p_request_id);
  RETURN to_jsonb(new_rate);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_authenticate(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_dashboard_metrics() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_update_rate(uuid, uuid, numeric, numeric, numeric, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_authenticate(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_metrics() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_rate(uuid, uuid, numeric, numeric, numeric, text) TO service_role;

COMMIT;
