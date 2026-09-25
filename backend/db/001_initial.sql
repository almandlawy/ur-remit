BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE transfer_public_status AS ENUM ('ISSUED','ASSIGNED','READY_FOR_PICKUP','COMPLETED','CANCELLED','REFUNDED','HELD');
CREATE TYPE agent_status AS ENUM ('VERIFIED','SUSPENDED','EXPIRED');

CREATE TABLE countries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  iso_code char(2) UNIQUE NOT NULL,
  name_ar text NOT NULL,
  name_en text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE cities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id uuid NOT NULL REFERENCES countries(id),
  name_ar text NOT NULL,
  name_en text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (country_id, name_en)
);

CREATE TABLE rate_routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_country_id uuid NOT NULL REFERENCES countries(id),
  origin_city_id uuid REFERENCES cities(id),
  destination_country_id uuid NOT NULL REFERENCES countries(id),
  destination_city_id uuid REFERENCES cities(id),
  source_currency char(3) NOT NULL,
  destination_currency char(3) NOT NULL,
  name_ar text NOT NULL,
  name_en text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id uuid NOT NULL REFERENCES rate_routes(id),
  buy numeric(24,8),
  sell numeric(24,8),
  fee_fixed numeric(24,8),
  fee_percent numeric(9,6),
  valid_from timestamptz NOT NULL,
  valid_until timestamptz,
  source_timestamp timestamptz NOT NULL,
  version bigint NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (buy IS NOT NULL OR sell IS NOT NULL),
  CHECK (valid_until IS NULL OR valid_until > valid_from),
  UNIQUE (route_id, version)
);

CREATE TABLE rate_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  rate_id uuid NOT NULL REFERENCES rates(id),
  old_value jsonb,
  new_value jsonb NOT NULL,
  actor_id uuid,
  request_id text NOT NULL,
  context jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE offices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_code text UNIQUE NOT NULL,
  country_id uuid NOT NULL REFERENCES countries(id),
  city_id uuid NOT NULL REFERENCES cities(id),
  name_ar text NOT NULL,
  name_en text NOT NULL,
  address_ar text NOT NULL,
  address_en text NOT NULL,
  latitude numeric(9,6),
  longitude numeric(9,6),
  phone text,
  whatsapp text,
  working_hours jsonb NOT NULL DEFAULT '{}'::jsonb,
  services jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_verified boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code_hash text UNIQUE NOT NULL,
  phone_hash text,
  trade_name text NOT NULL,
  country_id uuid NOT NULL REFERENCES countries(id),
  city_id uuid NOT NULL REFERENCES cities(id),
  status agent_status NOT NULL,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE transfer_status_public (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_hash text UNIQUE NOT NULL,
  reference_suffix char(4) NOT NULL,
  origin_label text NOT NULL,
  destination_label text NOT NULL,
  status transfer_public_status NOT NULL,
  estimated_completion timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title_ar text NOT NULL,
  title_en text NOT NULL,
  body_ar text NOT NULL,
  body_en text NOT NULL,
  kind text NOT NULL,
  published_at timestamptz,
  expires_at timestamptz,
  is_active boolean NOT NULL DEFAULT false
);

CREATE TABLE app_config (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  is_public boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE push_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  token_ciphertext bytea NOT NULL,
  token_fingerprint text UNIQUE NOT NULL,
  environment text NOT NULL CHECK (environment IN ('sandbox','production')),
  preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz
);

CREATE TABLE roles (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text UNIQUE NOT NULL);
CREATE TABLE permissions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text UNIQUE NOT NULL);
CREATE TABLE role_permissions (role_id uuid REFERENCES roles(id), permission_id uuid REFERENCES permissions(id), PRIMARY KEY(role_id, permission_id));
CREATE TABLE admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  role_id uuid NOT NULL REFERENCES roles(id),
  mfa_required boolean NOT NULL DEFAULT true,
  disabled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE audit_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id uuid REFERENCES admin_users(id),
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  before_value jsonb,
  after_value jsonb,
  request_id text NOT NULL,
  ip_context inet,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE security_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_type text NOT NULL,
  severity text NOT NULL,
  fingerprint text,
  context jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX rates_active_route_idx ON rates(route_id, is_active, valid_from DESC);
CREATE INDEX offices_location_idx ON offices(country_id, city_id) WHERE is_active;
CREATE INDEX transfer_status_updated_idx ON transfer_status_public(updated_at DESC);
CREATE INDEX audit_logs_actor_created_idx ON audit_logs(actor_id, created_at DESC);
CREATE INDEX security_events_type_created_idx ON security_events(event_type, created_at DESC);

COMMIT;
