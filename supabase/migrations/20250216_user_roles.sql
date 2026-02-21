-- Multi-role podpora: jeden uživatel může mít více rolí (Admin, Uklízeč, Řidič, Údržbář).
-- Tabulka user_roles + sloupec roles v invitations.

-- 1. Tabulka user_roles – přiřazení rolí k profilům (profile_id, role)
CREATE TABLE IF NOT EXISTS public.user_roles (
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  PRIMARY KEY (profile_id, role),
  CONSTRAINT user_roles_role_check CHECK (role IN ('admin', 'cleaner', 'driver', 'maintenance'))
);

COMMENT ON TABLE public.user_roles IS 'Týmové role uživatelů – Admin, Uklízeč, Řidič, Údržbář. Jeden profil může mít více rolí.';

-- RLS – uživatel vidí pouze role v rámci svého tenanta
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Uživatel smí číst role pro profily ve svém tenantovi, super_admin vidí vše.
CREATE POLICY "user_roles_select" ON public.user_roles FOR SELECT
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'super_admin'
  OR EXISTS (
    SELECT 1 FROM public.profiles p, public.profiles me
    WHERE me.id = auth.uid() AND p.id = user_roles.profile_id
    AND p.tenant_id = me.tenant_id AND me.tenant_id IS NOT NULL
  )
);

-- Admin tenantu smí vkládat/měnit role pro profily ve svém tenantovi
CREATE POLICY "user_roles_insert" ON public.user_roles FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.profiles me ON me.id = auth.uid()
    WHERE p.id = user_roles.profile_id
    AND p.tenant_id = me.tenant_id
    AND me.role IN ('admin', 'manager')
  )
);

CREATE POLICY "user_roles_delete" ON public.user_roles FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.profiles me ON me.id = auth.uid()
    WHERE p.id = user_roles.profile_id
    AND p.tenant_id = me.tenant_id
    AND me.role IN ('admin', 'manager')
  )
);

-- 2. Sloupec roles v invitations (JSONB pole: ["admin","cleaner",...])
ALTER TABLE public.invitations
ADD COLUMN IF NOT EXISTS roles JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.invitations.roles IS 'Seznam týmových rolí přiřazených při registraci – admin, cleaner, driver, maintenance.';

-- 3. Backfill: z existujících profiles doplň user_roles (mapování role -> týmové role)
-- admin -> admin, worker -> cleaner (Uklízeč jako výchozí)
INSERT INTO public.user_roles (profile_id, role)
SELECT id, CASE
  WHEN role = 'admin' OR role = 'manager' THEN 'admin'
  WHEN role = 'worker' THEN 'cleaner'
  ELSE 'admin'
END
FROM public.profiles
WHERE tenant_id IS NOT NULL
  AND role IN ('admin', 'manager', 'worker')
  AND NOT EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.profile_id = profiles.id);
