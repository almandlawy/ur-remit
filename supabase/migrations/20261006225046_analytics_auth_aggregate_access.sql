-- Server aggregation needs only registration timestamps and confirmation state.
-- Do not grant table-wide auth.users access or access to email/password/token columns.
grant select(created_at,email_confirmed_at,phone_confirmed_at,is_anonymous,deleted_at)
 on auth.users to service_role;
