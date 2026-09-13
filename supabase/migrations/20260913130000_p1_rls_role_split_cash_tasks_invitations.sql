-- =============================================================================
-- P1 bezpečnost: role-split RLS (cash, tasks UPDATE, invitations) + wallet RPC
-- =============================================================================
-- PROČ (audit): Same-tenant IDOR – jakýkoli člen tenanta mohl UPDATE cash/tasks/
-- invitations. Worker má měnit jen své úkoly; cash UPDATE jen admin/manager;
-- pozvánky jen admin/manager; deduct_wallet_credits jen admin/manager/super_admin.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) deduct_wallet_credits – vyžadovat admin/manager (nebo super_admin)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.deduct_wallet_credits(
  p_tenant_id uuid,
  p_deduct_amount integer,
  p_transaction_type text,
  p_reference_id text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_balance integer;
  v_caller_tenant_id uuid;
BEGIN
  v_caller_tenant_id := (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1);

  IF public.is_super_admin() THEN
    NULL; -- HQ smí
  ELSIF public.is_tenant_admin_or_manager()
        AND v_caller_tenant_id IS NOT NULL
        AND v_caller_tenant_id IS NOT DISTINCT FROM p_tenant_id THEN
    NULL; -- admin/manager vlastního tenanta
  ELSE
    RETURN FALSE;
  END IF;

  IF p_deduct_amount <= 0 THEN
    RAISE EXCEPTION 'deduct_wallet_credits: p_deduct_amount musí být kladné, bylo %', p_deduct_amount;
  END IF;

  SELECT balance INTO v_current_balance
  FROM public.tenant_wallets
  WHERE tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  IF v_current_balance < p_deduct_amount THEN
    RETURN FALSE;
  END IF;

  UPDATE public.tenant_wallets
  SET
    balance = balance - p_deduct_amount,
    updated_at = now()
  WHERE tenant_id = p_tenant_id;

  INSERT INTO public.wallet_transactions (tenant_id, amount, transaction_type, reference_id)
  VALUES (p_tenant_id, -p_deduct_amount, p_transaction_type, p_reference_id);

  RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION public.deduct_wallet_credits(uuid, integer, text, text) IS
  'P1: strhne kredity; volání jen super_admin nebo admin/manager vlastního tenanta.';

-- -----------------------------------------------------------------------------
-- 2) invitations – mutace jen admin/manager (+ super_admin)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "invitations_insert" ON public.invitations;
CREATE POLICY "invitations_insert"
  ON public.invitations FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      public.is_tenant_admin_or_manager()
      AND tenant_id = public.my_tenant_id()
    )
  );

DROP POLICY IF EXISTS "invitations_update" ON public.invitations;
CREATE POLICY "invitations_update"
  ON public.invitations FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      public.is_tenant_admin_or_manager()
      AND tenant_id IS NOT NULL
      AND tenant_id = public.my_tenant_id()
    )
  );

DROP POLICY IF EXISTS "invitations_delete" ON public.invitations;
CREATE POLICY "invitations_delete"
  ON public.invitations FOR DELETE
  USING (
    public.is_super_admin()
    OR (
      public.is_tenant_admin_or_manager()
      AND tenant_id IS NOT NULL
      AND tenant_id = public.my_tenant_id()
    )
    -- PROČ: acceptInvitation maže pozvánku po propojení ghost profilu – nový uživatel
    -- ještě není admin; smí smazat jen řádek, kde profile_id = jeho profiles.id.
    OR (
      profile_id IS NOT NULL
      AND profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    )
  );

-- -----------------------------------------------------------------------------
-- 3) employee_cash_* – wallet UPDATE/INSERT: admin/manager NEBO vlastní peněženka
--    (worker při COLLECTED_FROM_GUEST navyšuje balance a případně INSERT wallet).
--    transactions UPDATE: jen admin/manager (shortfall resolution, opravy).
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "employee_cash_wallets_update" ON public.employee_cash_wallets;
CREATE POLICY "employee_cash_wallets_update"
  ON public.employee_cash_wallets FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND (
        public.is_tenant_admin_or_manager()
        OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      )
    )
  );

DROP POLICY IF EXISTS "employee_cash_transactions_update" ON public.employee_cash_transactions;
CREATE POLICY "employee_cash_transactions_update"
  ON public.employee_cash_transactions FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      public.is_tenant_admin_or_manager()
      AND tenant_id = public.my_tenant_id()
    )
  );

-- INSERT wallets: admin/manager nebo worker zakládá jen svou peněženku
DROP POLICY IF EXISTS "employee_cash_wallets_insert" ON public.employee_cash_wallets;
CREATE POLICY "employee_cash_wallets_insert"
  ON public.employee_cash_wallets FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND (
        public.is_tenant_admin_or_manager()
        OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      )
    )
  );

-- INSERT transactions: zůstává v rámci tenanta (provozní nutnost výběru v terénu).

-- -----------------------------------------------------------------------------
-- 4) tasks UPDATE – admin/manager celý tenant; worker jen přiřazené úkoly
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
CREATE POLICY "tasks_update"
  ON public.tasks FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND (
        public.is_tenant_admin_or_manager()
        OR public.is_worker_assigned_to_task(id)
      )
    )
  );

COMMENT ON POLICY "tasks_update" ON public.tasks IS
  'P1: UPDATE úkolů – admin/manager tenanta nebo worker přiřazený k úkolu (is_worker_assigned_to_task).';
