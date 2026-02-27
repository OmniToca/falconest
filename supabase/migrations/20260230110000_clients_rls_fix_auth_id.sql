-- =============================================================================
-- FalcoNest – Oprava RLS pro tabulku clients (auth_id místo id)
-- =============================================================================
-- PROBLÉM: Politiky clients_select/insert/update/delete používaly
--   tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
-- Tabulka profiles má id = UUID profilu, auth_id = auth.users(id). auth.uid() vrací
-- auth users id, nikoliv profile id. Výraz tedy nikdy nenašel řádek → RLS vždy blokoval INSERT.
--
-- ŘEŠENÍ: Použít public.my_tenant_id() – standardní funkci, která správně bere
-- tenant_id z profiles WHERE auth_id = auth.uid(). Konzistence s ostatními tabulkami
-- (apartments, reservations, tasks, finance_*, zones, …).
-- =============================================================================

-- DROP a CREATE všech čtyř politik s opravenou podmínkou
DROP POLICY IF EXISTS "clients_select" ON public.clients;
CREATE POLICY "clients_select"
  ON public.clients FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

DROP POLICY IF EXISTS "clients_insert" ON public.clients;
CREATE POLICY "clients_insert"
  ON public.clients FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

DROP POLICY IF EXISTS "clients_update" ON public.clients;
CREATE POLICY "clients_update"
  ON public.clients FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

DROP POLICY IF EXISTS "clients_delete" ON public.clients;
CREATE POLICY "clients_delete"
  ON public.clients FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );
