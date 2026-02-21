-- =============================================================================
-- FalcoNest – profiles RLS: admin tenantu může spravovat členy týmu
-- =============================================================================
-- Oprava: profiles_update a profiles_delete umožňují pouze super_admin.
-- Admin tenantu musí moci: editovat členy, odstraňovat členy (pending=delete, active=tenant_id null).
-- =============================================================================

-- UPDATE: vlastní řádek NEBO super_admin NEBO admin může aktualizovat profily ve svém tenantu
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;
CREATE POLICY "profiles_update"
  ON public.profiles FOR UPDATE
  USING (
    auth_id = auth.uid()
    OR public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  )
  WITH CHECK (
    auth_id = auth.uid()
    OR public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- DELETE: super_admin NEBO admin může mazat pending profily ve svém tenantu
DROP POLICY IF EXISTS "profiles_delete" ON public.profiles;
CREATE POLICY "profiles_delete"
  ON public.profiles FOR DELETE
  USING (
    public.is_super_admin()
    OR (tenant_id = public.my_tenant_id() AND status = 'pending')
  );

-- Obnovení FK na staff_absences (propojení s profiles – ghost strategy)
ALTER TABLE public.staff_absences DROP CONSTRAINT IF EXISTS staff_absences_profile_id_fkey;
ALTER TABLE public.staff_absences ADD CONSTRAINT staff_absences_profile_id_fkey
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
