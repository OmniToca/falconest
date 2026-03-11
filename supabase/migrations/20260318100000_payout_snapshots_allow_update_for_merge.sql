-- =============================================================================
-- FalcoNest – Povolení UPDATE na payout_snapshots pro sloučení při doplacení
-- =============================================================================
-- PROČ: Při opakovaném „Vyplatit“ pro téhož příjemce ve stejném měsíci musíme
-- sloučit položky a částku do existujícího řádku (merge). Bez UPDATE policy by
-- upsert v aplikaci na update selhal.
-- =============================================================================

CREATE POLICY "payout_snapshots_update_admin_merge"
  ON public.payout_snapshots FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

COMMENT ON POLICY "payout_snapshots_update_admin_merge" ON public.payout_snapshots IS
  'UPDATE: Admin tenantu může měnit řádek (sloučení při doplacení ve stejném měsíci).';
