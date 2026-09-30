BEGIN;

-- Root cause of the recurring "تعذّر الاتصال بخدمة الإدارة" / rate-save failures:
-- admin_update_rate() looked up the OLD row by the exact id the client sent
-- (`WHERE id = p_rate_id`) and computed `old_rate.version + 1`. Every save
-- retires the old row (is_active = false) and inserts a brand new row with a
-- new id. If a client had not refreshed its local rate id after a prior save
-- (its own or a concurrent admin's) and tried to save again using the now
-- stale id, this recomputed the SAME version number as the row that
-- superseded it, and the insert failed with:
--   duplicate key value violates unique constraint "rates_route_id_version_key"
-- PostgREST surfaces that as a generic 400, which the edge function turns
-- into "database_400" -> 503 for the caller, and both the iOS app and the
-- admin web panel show a network-sounding "service unreachable" message even
-- though the real cause was a stale row id, not connectivity.
--
-- Fix: resolve the route from whatever id the client sent, lock every row for
-- that route (serializing concurrent/racing updates), and always operate on
-- the row that is *currently* active for the route using MAX(version) + 1 -
-- never trusting a possibly-superseded client-provided row id for the
-- version calculation. Idempotency replay is also relaxed to match on
-- request_id + actor only (not the stale row id) so retries succeed too.
-- Dropped and recreated (rather than CREATE OR REPLACE) because adding
-- `p_fee_percent` changes the function's signature; existing callers that
-- omit it keep working thanks to the DEFAULT NULL, which preserves the
-- previous "fee_percent never changes through this RPC" behavior.
DROP FUNCTION IF EXISTS public.admin_update_rate(uuid, uuid, numeric, numeric, numeric, text);

CREATE OR REPLACE FUNCTION public.admin_update_rate(
  p_actor_id uuid,
  p_rate_id uuid,
  p_buy numeric,
  p_sell numeric,
  p_fee_fixed numeric,
  p_request_id text,
  p_fee_percent numeric DEFAULT NULL
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
  v_next_version integer;
BEGIN
  SELECT new_value INTO previous_result
  FROM public.rate_history
  WHERE request_id = p_request_id
    AND actor_id = p_actor_id
    AND context->>'source' = 'admin-edge-api'
  ORDER BY id DESC
  LIMIT 1;
  IF FOUND THEN RETURN previous_result; END IF;

  -- Resolve the route from whatever row id the client sent - it may
  -- reference a version that has since been superseded.
  SELECT route_id INTO v_route_id FROM public.rates WHERE id = p_rate_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  -- Lock every row for this route so concurrent edits/retries serialize
  -- instead of racing on the same `version` value.
  PERFORM 1 FROM public.rates WHERE route_id = v_route_id FOR UPDATE;

  -- Always operate on the row that is *currently* active for the route,
  -- not the (possibly stale) row id the client sent.
  SELECT * INTO old_rate FROM public.rates
  WHERE route_id = v_route_id AND is_active = true
  ORDER BY version DESC LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;

  -- Re-check idempotency after acquiring the lock in case a concurrent
  -- request with the same id just completed while we were waiting.
  SELECT new_value INTO previous_result
  FROM public.rate_history
  WHERE request_id = p_request_id
    AND actor_id = p_actor_id
    AND context->>'source' = 'admin-edge-api'
  ORDER BY id DESC
  LIMIT 1;
  IF FOUND THEN RETURN previous_result; END IF;

  SELECT COALESCE(MAX(version), 0) + 1 INTO v_next_version FROM public.rates WHERE route_id = v_route_id;

  PERFORM set_config('app.admin_update_rate_request_id', p_request_id, true);
  UPDATE public.rates SET is_active = false WHERE route_id = v_route_id AND is_active = true;
  INSERT INTO public.rates(
    route_id, buy, sell, fee_fixed, fee_percent, valid_from, valid_until,
    source_timestamp, version, is_active
  )
  VALUES(
    v_route_id, p_buy, p_sell, p_fee_fixed, COALESCE(p_fee_percent, old_rate.fee_percent),
    now(), old_rate.valid_until, now(), v_next_version, true
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

COMMIT;
