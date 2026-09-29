BEGIN;

CREATE TABLE user_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text CHECK (char_length(display_name) <= 120),
  locale text NOT NULL DEFAULT 'ar' CHECK (locale IN ('ar', 'en')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_favorite_routes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  route_id uuid NOT NULL REFERENCES rate_routes(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, route_id)
);

CREATE TABLE user_saved_tracking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label text NOT NULL CHECK (char_length(label) BETWEEN 1 AND 80),
  reference_ciphertext bytea NOT NULL,
  reference_fingerprint text NOT NULL,
  reference_suffix char(4) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, reference_fingerprint)
);

CREATE TABLE user_notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  rate_alerts boolean NOT NULL DEFAULT false,
  transfer_alerts boolean NOT NULL DEFAULT false,
  announcements boolean NOT NULL DEFAULT true,
  security_alerts boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfer_status_public ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorite_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_saved_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON user_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_favorite_routes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_saved_tracking TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_notification_preferences TO authenticated;

CREATE POLICY user_profiles_select_own ON user_profiles
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY user_profiles_insert_own ON user_profiles
  FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY user_profiles_update_own ON user_profiles
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY user_profiles_delete_own ON user_profiles
  FOR DELETE TO authenticated USING ((SELECT auth.uid()) = user_id);

CREATE POLICY favorite_routes_select_own ON user_favorite_routes
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY favorite_routes_insert_own ON user_favorite_routes
  FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY favorite_routes_delete_own ON user_favorite_routes
  FOR DELETE TO authenticated USING ((SELECT auth.uid()) = user_id);

CREATE POLICY saved_tracking_select_own ON user_saved_tracking
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY saved_tracking_insert_own ON user_saved_tracking
  FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY saved_tracking_update_own ON user_saved_tracking
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY saved_tracking_delete_own ON user_saved_tracking
  FOR DELETE TO authenticated USING ((SELECT auth.uid()) = user_id);

CREATE POLICY notification_preferences_select_own ON user_notification_preferences
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY notification_preferences_insert_own ON user_notification_preferences
  FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY notification_preferences_update_own ON user_notification_preferences
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY notification_preferences_delete_own ON user_notification_preferences
  FOR DELETE TO authenticated USING ((SELECT auth.uid()) = user_id);

COMMIT;
;
