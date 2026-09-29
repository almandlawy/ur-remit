BEGIN;

UPDATE public.admin_sessions s
SET revoked_at = now()
FROM public.admin_users u
WHERE s.admin_user_id = u.id
  AND s.revoked_at IS NULL
  AND (NOT u.mfa_required OR u.mfa_secret_ciphertext IS NULL);

UPDATE public.admin_users
SET disabled_at = COALESCE(disabled_at, now())
WHERE NOT mfa_required OR mfa_secret_ciphertext IS NULL;

ALTER TABLE public.admin_users
  DROP CONSTRAINT IF EXISTS admin_users_requires_mfa,
  ADD CONSTRAINT admin_users_requires_mfa
    CHECK (disabled_at IS NOT NULL OR (mfa_required AND mfa_secret_ciphertext IS NOT NULL));

DROP POLICY IF EXISTS public_read_rates ON public.rates;
DROP POLICY IF EXISTS public_read_active_rates ON public.rates;
CREATE POLICY public_read_active_rates ON public.rates
  FOR SELECT TO anon USING (is_active = true);

DROP POLICY IF EXISTS public_read_offices ON public.offices;
DROP POLICY IF EXISTS public_read_active_offices ON public.offices;
CREATE POLICY public_read_active_offices ON public.offices
  FOR SELECT TO anon USING (is_active = true);

GRANT SELECT ON public.rates, public.offices TO anon;

INSERT INTO public.permissions(name) VALUES ('admins.read')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.role_permissions(role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.name = 'SUPER_ADMIN'
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO public.role_permissions(role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.name IN ('audit.read', 'agents.read')
  AND r.name = 'COMPLIANCE_OFFICER'
ON CONFLICT (role_id, permission_id) DO NOTHING;

COMMIT;
