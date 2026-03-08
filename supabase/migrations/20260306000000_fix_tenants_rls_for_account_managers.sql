-- =============================================================================
-- P0 bezpečnostní oprava z auditu Super-Admin modulu (SUPER_ADMIN_MODULE_CODE_REVIEW_AND_AUDIT.md).
-- =============================================================================
-- PROBLÉM: Politika tenants_select povolovala pouze is_super_admin() NEBO id = my_tenant_id().
-- U account_managera je my_tenant_id() = NULL (HQ, ne přiřazen k jednomu tenantu), takže
-- nemohl číst žádného tenanta → prázdný HQ dashboard a nefunkční rollout pro Account Managery.
--
-- ŘEŠENÍ: Rozšířit tenants_select tak, aby account_manager viděl jen tenanty, u kterých
-- je Lovec (acquired_by) nebo Farmář (managed_by) = jeho profile_id. ADDITIVE: přístup
-- super_admin a běžných uživatelů (id = my_tenant_id()) zůstává beze změny.
-- =============================================================================

DROP POLICY IF EXISTS "tenants_select" ON public.tenants;

CREATE POLICY "tenants_select" ON public.tenants FOR SELECT
  USING (
    public.is_super_admin()
    OR id = public.my_tenant_id()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'account_manager'
      AND (
        acquired_by = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
        OR managed_by = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      )
    )
  );

COMMENT ON POLICY "tenants_select" ON public.tenants IS
  'SELECT: super_admin vše; běžný uživatel jen svůj tenant (my_tenant_id); account_manager jen tenanty, kde je Lovec nebo Farmář (P0 audit fix).';
