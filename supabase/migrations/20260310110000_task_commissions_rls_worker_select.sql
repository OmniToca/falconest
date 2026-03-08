-- =============================================================================
-- FalcoNest – Zaměstnanec může číst své vlastní provize (profile_id)
-- =============================================================================
-- PROČ: Worker pohled „Moje výdělky“ zobrazuje i provize získané zaměstnancem.
-- Bez této policy by zaměstnanec nemohl načíst záznamy z task_commissions.
-- =============================================================================

CREATE POLICY "task_commissions_select_worker"
  ON public.task_commissions FOR SELECT
  USING (
    tenant_id = public.my_tenant_id()
    AND profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );
