-- =============================================================================
-- FalcoNest – clean slate RLS pro tabulky tenants, apartments, reservations, tasks
-- =============================================================================
-- Dynamicky smaže VŠECHNY policy na těchto tabulkách (včetně starých/duplicit),
-- pak vytvoří jen správné. Neměň profiles ani is_super_admin().
-- Spusť v Supabase SQL Editoru.
-- =============================================================================

DO $$
DECLARE
  r record;
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['tenants', 'apartments', 'reservations', 'tasks']
  LOOP
    FOR r IN
      SELECT policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = t
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, t);
    END LOOP;
  END LOOP;
END
$$;

-- -----------------------------------------------------------------------------
-- TENANTS – super_admin vše; běžný uživatel jen řádek svého tenanta (tenants.id = profile.tenant_id)
-- -----------------------------------------------------------------------------
CREATE POLICY "tenants_select"
  ON public.tenants FOR SELECT
  USING (
    public.is_super_admin()
    OR id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "tenants_insert_super"
  ON public.tenants FOR INSERT
  WITH CHECK (public.is_super_admin());

CREATE POLICY "tenants_update_super"
  ON public.tenants FOR UPDATE
  USING (public.is_super_admin());

CREATE POLICY "tenants_delete_super"
  ON public.tenants FOR DELETE
  USING (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- APARTMENTS – vlastní tenant_id NEBO super_admin
-- -----------------------------------------------------------------------------
CREATE POLICY "apartments_select"
  ON public.apartments FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "apartments_insert"
  ON public.apartments FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "apartments_update"
  ON public.apartments FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "apartments_delete"
  ON public.apartments FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

-- -----------------------------------------------------------------------------
-- RESERVATIONS – nemají tenant_id; vazba přes apartment_id → apartments.tenant_id
-- -----------------------------------------------------------------------------
CREATE POLICY "reservations_select"
  ON public.reservations FOR SELECT
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id
        AND a.tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY "reservations_insert"
  ON public.reservations FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id
        AND a.tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY "reservations_update"
  ON public.reservations FOR UPDATE
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id
        AND a.tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY "reservations_delete"
  ON public.reservations FOR DELETE
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id
        AND a.tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
    )
  );

-- -----------------------------------------------------------------------------
-- TASKS – mají tenant_id
-- -----------------------------------------------------------------------------
CREATE POLICY "tasks_select"
  ON public.tasks FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "tasks_insert"
  ON public.tasks FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "tasks_update"
  ON public.tasks FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "tasks_delete"
  ON public.tasks FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );
