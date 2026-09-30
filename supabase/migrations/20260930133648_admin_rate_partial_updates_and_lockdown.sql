BEGIN;

-- Replace every previously deployed signature so PostgREST has one unambiguous
-- RPC and the SECURITY DEFINER function is not left executable by public roles.
DROP FUNCTION IF EXISTS public.admin_update_rate(uuid, uuid, numeric, numeric, numeric, text);
DROP FUNCTION IF EXISTS public.admin_update_rate(uuid, uuid, numeric, numeric, numeric, text, numeric);
DROP FUNCTION IF EXISTS public.admin_update_rate(
  uuid, uuid, numeric, numeric, numeric, text, numeric,
  boolean, boolean, boolean, timestamptz, timestamptz, boolean, boolean
);
DROP FUNCTION IF EXISTS public.admin_update_rate(
  uuid, uuid, numeric, numeric, numeric, text, numeric,
  boolean, boolean, boolean, boolean, timestamptz, timestamptz, boolean, boolean
);

CREATE FUNCTION public.admin_update_rate(
  p_actor_id uuid,
  p_rate_id uuid,
  p_buy numeric,
  p_sell numeric,
  p_fee_fixed numeric,
  p_request_id text,
  p_fee_percent numeric DEFAULT NULL,
  p_buy_set boolean DEFAULT TRUE,
  p_sell_set boolean DEFAULT TRUE,
  p_fee_fixed_set boolean DEFAULT TRUE,
  p_fee_percent_set boolean DEFAULT FALSE,
  p_valid_from timestamptz DEFAULT NULL,
  p_valid_until timestamptz DEFAULT NULL,
  p_valid_until_set boolean DEFAULT FALSE,
  p_active boolean DEFAULT TRUE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_route_id uuid;
  old_rate public.rates%ROWTYPE;
  new_rate public.rates%ROWTYPE;
  previous_result jsonb;
  v_next_version bigint;
BEGIN
  SELECT new_value INTO previous_result
  FROM public.rate_history
  WHERE request_id = p_request_id
    AND actor_id = p_actor_id
    AND context->>'source' = 'admin-edge-api'
  ORDER BY id DESC
  LIMIT 1;
  IF FOUND THEN RETURN previous_result; END IF;

  SELECT route_id INTO v_route_id FROM public.rates WHERE id = p_rate_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  PERFORM 1 FROM public.rates WHERE route_id = v_route_id FOR UPDATE;

  -- Prefer the active version; if a route was intentionally deactivated,
  -- allow the latest version to be edited or reactivated.
  SELECT * INTO old_rate FROM public.rates
  WHERE route_id = v_route_id
  ORDER BY is_active DESC, version DESC
  LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;

  SELECT new_value INTO previous_result
  FROM public.rate_history
  WHERE request_id = p_request_id
    AND actor_id = p_actor_id
    AND context->>'source' = 'admin-edge-api'
  ORDER BY id DESC
  LIMIT 1;
  IF FOUND THEN RETURN previous_result; END IF;

  SELECT COALESCE(MAX(version), 0) + 1
  INTO v_next_version
  FROM public.rates
  WHERE route_id = v_route_id;

  PERFORM set_config('app.admin_update_rate_request_id', p_request_id, true);
  UPDATE public.rates SET is_active = false WHERE route_id = v_route_id AND is_active = true;

  INSERT INTO public.rates(
    route_id, buy, sell, fee_fixed, fee_percent, valid_from, valid_until,
    source_timestamp, version, is_active
  )
  VALUES(
    v_route_id,
    CASE WHEN p_buy_set THEN p_buy ELSE old_rate.buy END,
    CASE WHEN p_sell_set THEN p_sell ELSE old_rate.sell END,
    CASE WHEN p_fee_fixed_set THEN p_fee_fixed ELSE old_rate.fee_fixed END,
    CASE WHEN p_fee_percent_set THEN p_fee_percent ELSE old_rate.fee_percent END,
    COALESCE(p_valid_from, now()),
    CASE WHEN p_valid_until_set THEN p_valid_until ELSE old_rate.valid_until END,
    now(), v_next_version, p_active
  )
  RETURNING * INTO new_rate;

  INSERT INTO public.rate_history(rate_id, old_value, new_value, actor_id, request_id, context)
  VALUES(
    new_rate.id, to_jsonb(old_rate), to_jsonb(new_rate), p_actor_id,
    p_request_id, '{"source":"admin-edge-api"}'::jsonb
  );
  INSERT INTO public.audit_logs(actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  VALUES(
    p_actor_id, 'UPDATE', 'rate', new_rate.id::text,
    to_jsonb(old_rate), to_jsonb(new_rate), p_request_id
  );

  RETURN to_jsonb(new_rate);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_rate(
  uuid, uuid, numeric, numeric, numeric, text, numeric,
  boolean, boolean, boolean, boolean, timestamptz, timestamptz, boolean, boolean
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_rate(
  uuid, uuid, numeric, numeric, numeric, text, numeric,
  boolean, boolean, boolean, boolean, timestamptz, timestamptz, boolean, boolean
) TO service_role;

COMMIT;