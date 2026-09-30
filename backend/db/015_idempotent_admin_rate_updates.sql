CREATE INDEX IF NOT EXISTS rate_history_admin_request_lookup_idx
  ON public.rate_history (request_id, actor_id, id DESC)
  WHERE context->>'source' = 'admin-edge-api';

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
SET search_path = ''
AS $$
DECLARE
  old_rate public.rates%ROWTYPE;
  new_rate public.rates%ROWTYPE;
  previous_result jsonb;
BEGIN
  SELECT new_value INTO previous_result
  FROM public.rate_history
  WHERE request_id = p_request_id
    AND actor_id = p_actor_id
    AND old_value->>'id' = p_rate_id::text
    AND context->>'source' = 'admin-edge-api'
  ORDER BY id DESC
  LIMIT 1;
  IF FOUND THEN RETURN previous_result; END IF;

  SELECT * INTO old_rate FROM public.rates WHERE id = p_rate_id FOR UPDATE;
  IF NOT FOUND THEN RETURN NULL; END IF;

  -- A retry may have waited for the first request's rate-row lock.
  SELECT new_value INTO previous_result
  FROM public.rate_history
  WHERE request_id = p_request_id
    AND actor_id = p_actor_id
    AND old_value->>'id' = p_rate_id::text
    AND context->>'source' = 'admin-edge-api'
  ORDER BY id DESC
  LIMIT 1;
  IF FOUND THEN RETURN previous_result; END IF;

  PERFORM set_config('app.admin_update_rate_request_id', p_request_id, true);
  UPDATE public.rates SET is_active = false WHERE id = p_rate_id;
  INSERT INTO public.rates(
    route_id, buy, sell, fee_fixed, fee_percent, valid_from, valid_until,
    source_timestamp, version, is_active
  )
  VALUES(
    old_rate.route_id, p_buy, p_sell, p_fee_fixed, old_rate.fee_percent,
    now(), old_rate.valid_until, now(), old_rate.version + 1, true
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
