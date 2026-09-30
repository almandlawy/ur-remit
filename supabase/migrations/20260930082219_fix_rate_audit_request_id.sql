BEGIN;

CREATE OR REPLACE FUNCTION public.log_rate_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- The admin RPC writes its own audit row with the request ID; avoid a duplicate trigger row.
  IF NULLIF(current_setting('app.admin_update_rate_request_id', true), '') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.audit_logs (
    actor_id, action, entity_type, entity_id, before_value, after_value, request_id
  )
  VALUES (
    auth.uid(), 'UPDATE', 'rate', NEW.id::text, to_jsonb(OLD), to_jsonb(NEW), gen_random_uuid()::text
  );
  RETURN NEW;
END;
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
DECLARE
  old_rate rates%ROWTYPE;
  new_rate rates%ROWTYPE;
BEGIN
  SELECT * INTO old_rate FROM rates WHERE id = p_rate_id FOR UPDATE;
  IF NOT FOUND THEN RETURN NULL; END IF;

  PERFORM set_config('app.admin_update_rate_request_id', p_request_id, true);
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

COMMIT;
