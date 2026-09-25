BEGIN;

CREATE POLICY service_role_only_countries ON countries FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_cities ON cities FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_rate_routes ON rate_routes FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_rates ON rates FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_rate_history ON rate_history FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_offices ON offices FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_agents ON agents FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_transfer_status ON transfer_status_public FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_announcements ON announcements FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_app_config ON app_config FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_push_tokens ON push_tokens FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_roles ON roles FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_permissions ON permissions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_role_permissions ON role_permissions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_admin_users ON admin_users FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_admin_sessions ON admin_sessions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_audit_logs ON audit_logs FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_only_security_events ON security_events FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE INDEX admin_sessions_admin_user_idx ON admin_sessions(admin_user_id);
CREATE INDEX admin_users_role_idx ON admin_users(role_id);
CREATE INDEX agents_city_idx ON agents(city_id);
CREATE INDEX agents_country_idx ON agents(country_id);
CREATE INDEX offices_city_idx ON offices(city_id);
CREATE INDEX rate_history_rate_idx ON rate_history(rate_id);
CREATE INDEX rate_routes_destination_city_idx ON rate_routes(destination_city_id);
CREATE INDEX rate_routes_destination_country_idx ON rate_routes(destination_country_id);
CREATE INDEX rate_routes_origin_city_idx ON rate_routes(origin_city_id);
CREATE INDEX rate_routes_origin_country_idx ON rate_routes(origin_country_id);
CREATE INDEX role_permissions_permission_idx ON role_permissions(permission_id);
CREATE INDEX user_favorite_routes_route_idx ON user_favorite_routes(route_id);

COMMIT;
