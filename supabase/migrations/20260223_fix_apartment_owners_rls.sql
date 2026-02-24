-- =============================================================================
-- BUGFIX: Povolení plného přístupu do tabulky apartment_owners pro adminy,
-- aby mohli propojovat majitele s byty.
-- =============================================================================
-- Chyba: new row violates row-level security policy for table "apartment_owners"
-- Příčina: Stávající politika používala p.id = auth.uid(), což po migraci
-- Ghost Profile Strategy (profiles.auth_id) nefunguje. Admin/manager je
-- identifikován přes profiles.auth_id = auth.uid().
--
-- Tento skript: obnoví politiku pro admin, manager a super_admin (FOR ALL).
-- =============================================================================

DROP POLICY IF EXISTS "apartment_owners_admin_manager_all" ON public.apartment_owners;

CREATE POLICY "apartment_owners_admin_manager_all"
  ON public.apartment_owners
  FOR ALL
  TO authenticated
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  );
