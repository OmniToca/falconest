-- FalcoNest – RLS INSERT/UPDATE/DELETE pro reservations (konzistence s my_tenant_id())
-- Stará policy reservations_insert z 20250224 používala profiles.id = auth.uid(), což je špatně
-- (profiles mají auth_id, ne id). INSERT tedy vždy selhával.
-- Nová policy: povolit INSERT jen když tenant_id vloženého řádku = public.my_tenant_id().

DROP POLICY IF EXISTS "reservations_insert" ON public.reservations;
CREATE POLICY "reservations_insert"
  ON public.reservations FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (tenant_id IS NOT NULL AND tenant_id = public.my_tenant_id())
  );

DROP POLICY IF EXISTS "reservations_update" ON public.reservations;
CREATE POLICY "reservations_update"
  ON public.reservations FOR UPDATE
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id AND a.tenant_id = public.my_tenant_id()
    )
  );

DROP POLICY IF EXISTS "reservations_delete" ON public.reservations;
CREATE POLICY "reservations_delete"
  ON public.reservations FOR DELETE
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id AND a.tenant_id = public.my_tenant_id()
    )
  );

COMMENT ON POLICY "reservations_insert" ON public.reservations IS 'INSERT: super_admin nebo tenant_id řádku = my_tenant_id().';
COMMENT ON POLICY "reservations_update" ON public.reservations IS 'UPDATE: super_admin nebo byt rezervace patří do tenantu uživatele.';
COMMENT ON POLICY "reservations_delete" ON public.reservations IS 'DELETE: super_admin nebo byt rezervace patří do tenantu uživatele.';
