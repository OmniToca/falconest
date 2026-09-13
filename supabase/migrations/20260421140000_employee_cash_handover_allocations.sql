-- =============================================================================
-- FalcoNest – FIFO bulk handover: auditní alokace převzaté hotovosti
-- =============================================================================
-- PROČ:
-- - Částečné/hromadné převzetí hotovosti (např. 1400 z 1500) musí být účetně
--   rozděleno FIFO na konkrétní původní výběry od hosta.
-- - Transit část pro majitele se pak nesmí připsat "prvnímu záznamu", ale přesně
--   podle alokací na source transakce (reservation_id/task_id/apartment_id).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.employee_cash_handover_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  wallet_id uuid NOT NULL REFERENCES public.employee_cash_wallets (id) ON DELETE CASCADE,
  worker_profile_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE RESTRICT,
  handed_transaction_id uuid NOT NULL REFERENCES public.employee_cash_transactions (id) ON DELETE CASCADE,
  source_transaction_id uuid NOT NULL REFERENCES public.employee_cash_transactions (id) ON DELETE RESTRICT,
  task_id uuid NULL REFERENCES public.tasks (id) ON DELETE SET NULL,
  reservation_id uuid NULL REFERENCES public.reservations (id) ON DELETE SET NULL,
  apartment_id uuid NULL REFERENCES public.apartments (id) ON DELETE SET NULL,
  allocated_amount numeric NOT NULL CHECK (allocated_amount > 0),
  allocated_transit_amount numeric NOT NULL DEFAULT 0 CHECK (allocated_transit_amount >= 0),
  currency text NOT NULL DEFAULT 'EUR',
  created_by uuid NOT NULL REFERENCES public.profiles (id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT employee_cash_handover_allocations_transit_lte_allocated
    CHECK (allocated_transit_amount <= allocated_amount),
  CONSTRAINT employee_cash_handover_allocations_unique_handed_source
    UNIQUE (handed_transaction_id, source_transaction_id)
);

COMMENT ON TABLE public.employee_cash_handover_allocations IS
  'Auditní rozpad hromadného převzetí hotovosti (FIFO): kolik z HANDED připadlo na které původní COLLECTED transakce.';

COMMENT ON COLUMN public.employee_cash_handover_allocations.allocated_amount IS
  'Částka převzatá z konkrétní source transakce v rámci jednoho HANDED bulk kroku.';

COMMENT ON COLUMN public.employee_cash_handover_allocations.allocated_transit_amount IS
  'Podíl allocated_amount, který představuje transit hotovost majitele (pro owner_cash_transit_settlements).';

CREATE INDEX IF NOT EXISTS idx_employee_cash_handover_allocations_tenant
  ON public.employee_cash_handover_allocations (tenant_id);

CREATE INDEX IF NOT EXISTS idx_employee_cash_handover_allocations_wallet_created
  ON public.employee_cash_handover_allocations (wallet_id, created_at);

CREATE INDEX IF NOT EXISTS idx_employee_cash_handover_allocations_handed
  ON public.employee_cash_handover_allocations (handed_transaction_id);

CREATE INDEX IF NOT EXISTS idx_employee_cash_handover_allocations_source
  ON public.employee_cash_handover_allocations (source_transaction_id);

ALTER TABLE public.employee_cash_handover_allocations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "employee_cash_handover_allocations_select_tenant_staff"
  ON public.employee_cash_handover_allocations
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.auth_id = auth.uid()
          AND p.tenant_id = employee_cash_handover_allocations.tenant_id
          AND p.role IN ('admin', 'manager')
      )
    )
  );

CREATE POLICY "employee_cash_handover_allocations_insert_tenant_staff"
  ON public.employee_cash_handover_allocations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.auth_id = auth.uid()
          AND p.tenant_id = employee_cash_handover_allocations.tenant_id
          AND p.role IN ('admin', 'manager')
      )
    )
  );

CREATE OR REPLACE FUNCTION public.process_worker_cash_handover_fifo(
  p_tenant_id uuid,
  p_worker_profile_id uuid,
  p_admin_profile_id uuid,
  p_total_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id uuid;
  v_wallet_balance numeric;
  v_wallet_balance_after numeric;
  v_handed_tx_id uuid;
  v_remaining numeric;
  v_take numeric;
  v_take_transit numeric;
  v_alloc_count integer := 0;
  v_alloc_total numeric := 0;
  v_alloc_transit_total numeric := 0;
  v_has_allocations boolean := false;
  v_last_handed_at timestamptz;
  v_now timestamptz := now();
  v_is_admin boolean := false;
  rec record;
BEGIN
  IF p_tenant_id IS NULL OR p_worker_profile_id IS NULL OR p_admin_profile_id IS NULL THEN
    RAISE EXCEPTION 'process_worker_cash_handover_fifo: missing required identifiers';
  END IF;
  IF p_total_amount IS NULL OR p_total_amount <= 0 THEN
    RAISE EXCEPTION 'process_worker_cash_handover_fifo: total amount must be positive';
  END IF;

  -- PROČ: SECURITY DEFINER obchází RLS, proto explicitně validujeme, že caller je
  -- autentizovaný admin/manager (nebo super_admin) v rámci požadovaného tenanta.
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = p_admin_profile_id
      AND p.auth_id = auth.uid()
      AND (
        public.is_super_admin()
        OR (p.tenant_id = p_tenant_id AND p.role IN ('admin', 'manager'))
      )
  ) INTO v_is_admin;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'process_worker_cash_handover_fifo: admin access denied';
  END IF;

  SELECT w.id, COALESCE(w.balance, 0)
  INTO v_wallet_id, v_wallet_balance
  FROM public.employee_cash_wallets w
  WHERE w.tenant_id = p_tenant_id
    AND w.profile_id = p_worker_profile_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'process_worker_cash_handover_fifo: wallet not found for worker %', p_worker_profile_id;
  END IF;
  IF p_total_amount > v_wallet_balance THEN
    RAISE EXCEPTION 'process_worker_cash_handover_fifo: amount % exceeds wallet balance %', p_total_amount, v_wallet_balance;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.employee_cash_handover_allocations a
    WHERE a.tenant_id = p_tenant_id
      AND a.wallet_id = v_wallet_id
    LIMIT 1
  ) INTO v_has_allocations;

  IF NOT v_has_allocations THEN
    SELECT MAX(t.created_at)
    INTO v_last_handed_at
    FROM public.employee_cash_transactions t
    WHERE t.tenant_id = p_tenant_id
      AND t.wallet_id = v_wallet_id
      AND t.transaction_type = 'HANDED_TO_AGENCY';
  END IF;

  INSERT INTO public.employee_cash_transactions (
    tenant_id,
    wallet_id,
    amount,
    transaction_type,
    created_by,
    metadata
  ) VALUES (
    p_tenant_id,
    v_wallet_id,
    -p_total_amount,
    'HANDED_TO_AGENCY',
    p_admin_profile_id,
    jsonb_build_object(
      'handover_mode', 'fifo_bulk',
      'worker_profile_id', p_worker_profile_id::text,
      'requested_amount', p_total_amount,
      'created_at', v_now
    )
  )
  RETURNING id INTO v_handed_tx_id;

  v_remaining := p_total_amount;

  FOR rec IN
    WITH collected AS (
      SELECT
        tx.id AS source_transaction_id,
        tx.created_at,
        tx.task_id,
        tx.reservation_id,
        tx.amount AS collected_amount,
        COALESCE(
          tx.transit_portion,
          CASE
            WHEN COALESCE((t.metadata->>'transit_amount_to_collect')::numeric, 0) > 0 THEN
              LEAST(
                GREATEST(
                  tx.amount - COALESCE((t.metadata->>'amount_to_collect')::numeric, 0),
                  0
                ),
                COALESCE((t.metadata->>'transit_amount_to_collect')::numeric, 0)
              )
            ELSE 0
          END
        ) AS transit_amount,
        t.apartment_id
      FROM public.employee_cash_transactions tx
      LEFT JOIN public.tasks t
        ON t.id = tx.task_id
      WHERE tx.tenant_id = p_tenant_id
        AND tx.wallet_id = v_wallet_id
        AND tx.transaction_type = 'COLLECTED_FROM_GUEST'
        AND tx.amount > 0
        AND (
          v_has_allocations
          OR v_last_handed_at IS NULL
          OR tx.created_at > v_last_handed_at
        )
    ),
    allocated AS (
      SELECT
        a.source_transaction_id,
        COALESCE(SUM(a.allocated_amount), 0) AS allocated_amount,
        COALESCE(SUM(a.allocated_transit_amount), 0) AS allocated_transit_amount
      FROM public.employee_cash_handover_allocations a
      WHERE a.tenant_id = p_tenant_id
        AND a.wallet_id = v_wallet_id
      GROUP BY a.source_transaction_id
    )
    SELECT
      c.source_transaction_id,
      c.created_at,
      c.task_id,
      c.reservation_id,
      c.apartment_id,
      GREATEST(c.collected_amount - COALESCE(al.allocated_amount, 0), 0) AS pending_amount,
      GREATEST(c.transit_amount - COALESCE(al.allocated_transit_amount, 0), 0) AS pending_transit_amount
    FROM collected c
    LEFT JOIN allocated al
      ON al.source_transaction_id = c.source_transaction_id
    WHERE GREATEST(c.collected_amount - COALESCE(al.allocated_amount, 0), 0) > 0
    ORDER BY c.created_at ASC, c.source_transaction_id ASC
  LOOP
    EXIT WHEN v_remaining <= 0;

    v_take := LEAST(v_remaining, rec.pending_amount);
    IF v_take <= 0 THEN
      CONTINUE;
    END IF;

    v_take_transit := LEAST(v_take, rec.pending_transit_amount);
    IF v_take_transit < 0 THEN
      v_take_transit := 0;
    END IF;

    INSERT INTO public.employee_cash_handover_allocations (
      tenant_id,
      wallet_id,
      worker_profile_id,
      handed_transaction_id,
      source_transaction_id,
      task_id,
      reservation_id,
      apartment_id,
      allocated_amount,
      allocated_transit_amount,
      currency,
      created_by
    ) VALUES (
      p_tenant_id,
      v_wallet_id,
      p_worker_profile_id,
      v_handed_tx_id,
      rec.source_transaction_id,
      rec.task_id,
      rec.reservation_id,
      rec.apartment_id,
      v_take,
      v_take_transit,
      'EUR',
      p_admin_profile_id
    );

    IF v_take_transit > 0 THEN
      INSERT INTO public.owner_cash_transit_settlements (
        tenant_id,
        reservation_id,
        apartment_id,
        task_id,
        amount,
        currency,
        created_by,
        note
      ) VALUES (
        p_tenant_id,
        rec.reservation_id,
        rec.apartment_id,
        rec.task_id,
        v_take_transit,
        'EUR',
        p_admin_profile_id,
        format(
          'fifo_bulk_handover: tx %s, source %s',
          v_handed_tx_id::text,
          rec.source_transaction_id::text
        )
      );
    END IF;

    v_alloc_count := v_alloc_count + 1;
    v_alloc_total := v_alloc_total + v_take;
    v_alloc_transit_total := v_alloc_transit_total + v_take_transit;
    v_remaining := v_remaining - v_take;
  END LOOP;

  IF v_remaining > 0.000001 THEN
    RAISE EXCEPTION 'process_worker_cash_handover_fifo: insufficient pending collected cash (remaining %)', v_remaining;
  END IF;

  v_wallet_balance_after := v_wallet_balance - p_total_amount;
  UPDATE public.employee_cash_wallets
  SET balance = v_wallet_balance_after,
      updated_at = v_now
  WHERE id = v_wallet_id;

  RETURN jsonb_build_object(
    'handed_transaction_id', v_handed_tx_id,
    'wallet_id', v_wallet_id,
    'wallet_balance_before', v_wallet_balance,
    'wallet_balance_after', v_wallet_balance_after,
    'received_total', p_total_amount,
    'allocations_count', v_alloc_count,
    'allocated_total', v_alloc_total,
    'allocated_transit_total', v_alloc_transit_total
  );
END;
$$;

COMMENT ON FUNCTION public.process_worker_cash_handover_fifo(uuid, uuid, uuid, numeric) IS
  'FIFO bulk handover: rozdělí převzatou hotovost na source COLLECTED transakce, uloží auditní alokace a vytvoří owner settlementy pro transit část.';

REVOKE ALL ON FUNCTION public.process_worker_cash_handover_fifo(uuid, uuid, uuid, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.process_worker_cash_handover_fifo(uuid, uuid, uuid, numeric) TO authenticated;
