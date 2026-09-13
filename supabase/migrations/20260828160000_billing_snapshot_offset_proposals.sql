-- =============================================================================
-- FalcoNest – Fáze 3.1: Approval Loop – návrhy doplatku ze zálohy majitele
-- =============================================================================
-- PROČ: Po částečném zápočtu (partially_paid) může dispečer navrhnout majiteli
-- doplnění z volné hotovostní rezervy. Majitel schvaluje/zamítá přes RPC
-- respond_billing_offset_proposal – atomický zápis bez přímého UPDATE majitele.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka billing_snapshot_offset_proposals
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.billing_snapshot_offset_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  billing_snapshot_id uuid NOT NULL REFERENCES public.billing_snapshots (id) ON DELETE CASCADE,
  owner_profile_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE RESTRICT,
  settlement_id uuid NOT NULL REFERENCES public.owner_cash_transit_settlements (id) ON DELETE RESTRICT,
  proposed_amount numeric NOT NULL CHECK (proposed_amount > 0),
  applied_amount numeric CHECK (applied_amount IS NULL OR applied_amount >= 0),
  currency text NOT NULL DEFAULT 'EUR',
  status text NOT NULL DEFAULT 'pending_owner'
    CHECK (
      status IN (
        'pending_owner',
        'applied',
        'rejected_by_owner',
        'cancelled_by_admin',
        'stale'
      )
    ),
  proposed_by_profile_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE RESTRICT,
  disposition_request_id uuid REFERENCES public.owner_cash_disposition_requests (id) ON DELETE SET NULL,
  owner_responded_at timestamptz,
  owner_rejection_note text,
  admin_notes text,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

COMMENT ON TABLE public.billing_snapshot_offset_proposals IS
  'Návrh dispečera na doplatek faktury ze zálohy majitele – schválení/zamítnutí majitelem přes RPC.';

COMMENT ON COLUMN public.billing_snapshot_offset_proposals.proposed_amount IS
  'Navrhovaná částka doplatku v době vytvoření návrhu (typicky zbývající doplatek faktury).';

COMMENT ON COLUMN public.billing_snapshot_offset_proposals.applied_amount IS
  'Skutečně uplatněná částka po schválení (může být nižší než proposed_amount při změně poolu).';

COMMENT ON COLUMN public.billing_snapshot_offset_proposals.settlement_id IS
  'Zdrojový settlement z owner_cash_transit_settlements – vazba pro novou invoice_credit žádost.';

COMMENT ON COLUMN public.billing_snapshot_offset_proposals.disposition_request_id IS
  'Vytvořená schválená žádost invoice_credit po kliknutí majitele na Ano.';

-- PROČ: Na jednu fakturu smí být aktivní jen jeden návrh čekající na majitele.
CREATE UNIQUE INDEX IF NOT EXISTS idx_billing_snapshot_offset_proposals_one_pending
  ON public.billing_snapshot_offset_proposals (billing_snapshot_id)
  WHERE status = 'pending_owner';

CREATE INDEX IF NOT EXISTS idx_billing_snapshot_offset_proposals_tenant
  ON public.billing_snapshot_offset_proposals (tenant_id);

CREATE INDEX IF NOT EXISTS idx_billing_snapshot_offset_proposals_owner_status
  ON public.billing_snapshot_offset_proposals (owner_profile_id, status);

CREATE INDEX IF NOT EXISTS idx_billing_snapshot_offset_proposals_snapshot
  ON public.billing_snapshot_offset_proposals (billing_snapshot_id);

-- -----------------------------------------------------------------------------
-- 2. RLS – admin/manager INSERT + SELECT + UPDATE (zrušení); majitel SELECT only
-- -----------------------------------------------------------------------------
ALTER TABLE public.billing_snapshot_offset_proposals ENABLE ROW LEVEL SECURITY;

-- Staff tenanta + super_admin: čtení návrhů v rámci tenanta.
CREATE POLICY "billing_snapshot_offset_proposals_select_staff"
  ON public.billing_snapshot_offset_proposals
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      billing_snapshot_offset_proposals.tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p_sel
        WHERE p_sel.auth_id = auth.uid()
          AND p_sel.tenant_id = billing_snapshot_offset_proposals.tenant_id
          AND p_sel.role IN ('admin', 'manager')
      )
    )
  );

-- Majitel: SELECT jen vlastní návrhy (profile id z auth.uid()).
CREATE POLICY "billing_snapshot_offset_proposals_select_owner"
  ON public.billing_snapshot_offset_proposals
  FOR SELECT
  TO authenticated
  USING (
    billing_snapshot_offset_proposals.owner_profile_id = (
      SELECT p_own.id
      FROM public.profiles AS p_own
      WHERE p_own.auth_id = auth.uid()
      LIMIT 1
    )
  );

-- Admin/manager: vytvoření návrhu – validace stavu faktury a vazby majitele.
CREATE POLICY "billing_snapshot_offset_proposals_insert_admin_manager"
  ON public.billing_snapshot_offset_proposals
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR (
      billing_snapshot_offset_proposals.tenant_id = public.my_tenant_id()
      AND billing_snapshot_offset_proposals.proposed_by_profile_id = (
        SELECT p_ins.id
        FROM public.profiles AS p_ins
        WHERE p_ins.auth_id = auth.uid()
        LIMIT 1
      )
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p_role
        WHERE p_role.auth_id = auth.uid()
          AND p_role.tenant_id = billing_snapshot_offset_proposals.tenant_id
          AND p_role.role IN ('admin', 'manager')
      )
      AND EXISTS (
        SELECT 1
        FROM public.billing_snapshots AS bs
        WHERE bs.id = billing_snapshot_offset_proposals.billing_snapshot_id
          AND bs.tenant_id = billing_snapshot_offset_proposals.tenant_id
          AND bs.payment_status = 'partially_paid'
          AND billing_snapshot_offset_proposals.proposed_amount <= GREATEST(
            0::numeric,
            COALESCE((bs.snapshot_data->>'final_to_invoice')::numeric, 0)
              - COALESCE(bs.offset_amount, 0)
          )
          AND EXISTS (
            SELECT 1
            FROM public.clients AS c
            WHERE c.id = bs.client_id
              AND c.profile_id = billing_snapshot_offset_proposals.owner_profile_id
              AND c.deleted_at IS NULL
          )
      )
      AND EXISTS (
        SELECT 1
        FROM public.owner_cash_transit_settlements AS s
        WHERE s.id = billing_snapshot_offset_proposals.settlement_id
          AND s.tenant_id = billing_snapshot_offset_proposals.tenant_id
          AND (
            EXISTS (
              SELECT 1
              FROM public.reservations AS r
              INNER JOIN public.apartment_owners AS ao
                ON ao.apartment_id = r.apartment_id
                AND ao.deleted_at IS NULL
                AND ao.owner_id = billing_snapshot_offset_proposals.owner_profile_id
              WHERE r.id = s.reservation_id
            )
            OR EXISTS (
              SELECT 1
              FROM public.apartment_owners AS ao
              WHERE ao.apartment_id = s.apartment_id
                AND ao.deleted_at IS NULL
                AND ao.owner_id = billing_snapshot_offset_proposals.owner_profile_id
            )
          )
      )
    )
  );

-- Admin/manager: zrušení aktivního návrhu (pending_owner → cancelled_by_admin).
CREATE POLICY "billing_snapshot_offset_proposals_update_cancel_admin"
  ON public.billing_snapshot_offset_proposals
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      billing_snapshot_offset_proposals.tenant_id = public.my_tenant_id()
      AND billing_snapshot_offset_proposals.status = 'pending_owner'
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p_upd
        WHERE p_upd.auth_id = auth.uid()
          AND p_upd.tenant_id = billing_snapshot_offset_proposals.tenant_id
          AND p_upd.role IN ('admin', 'manager')
      )
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      billing_snapshot_offset_proposals.tenant_id = public.my_tenant_id()
      AND billing_snapshot_offset_proposals.status = 'cancelled_by_admin'
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p_wc
        WHERE p_wc.auth_id = auth.uid()
          AND p_wc.tenant_id = billing_snapshot_offset_proposals.tenant_id
          AND p_wc.role IN ('admin', 'manager')
      )
    )
  );

-- PROČ: Majitel NEMÁ INSERT/UPDATE/DELETE – stav mění výhradně RPC respond_billing_offset_proposal.

-- -----------------------------------------------------------------------------
-- 3. Pomocné funkce (interní – bez GRANT pro authenticated)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._billing_offset_eps()
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 0.000001::numeric;
$$;

COMMENT ON FUNCTION public._billing_offset_eps() IS
  'Numerická tolerance pro porovnání částek v zápočtových RPC (≈ 1e-6 EUR).';

-- Součet fyzického poolu majitele (Σ settlementů v měně) – stejná sémantika jako getOwnerSettlementPool.
CREATE OR REPLACE FUNCTION public._billing_offset_owner_pool_sum(
  p_tenant_id uuid,
  p_owner_profile_id uuid,
  p_currency text
)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(s.amount), 0::numeric)
  FROM public.owner_cash_transit_settlements AS s
  WHERE s.tenant_id = p_tenant_id
    AND upper(trim(COALESCE(s.currency, 'EUR'))) = upper(trim(COALESCE(p_currency, 'EUR')))
    AND (
      EXISTS (
        SELECT 1
        FROM public.reservations AS r
        INNER JOIN public.apartment_owners AS ao
          ON ao.apartment_id = r.apartment_id
          AND ao.deleted_at IS NULL
          AND ao.owner_id = p_owner_profile_id
        WHERE r.id = s.reservation_id
      )
      OR EXISTS (
        SELECT 1
        FROM public.apartment_owners AS ao
        WHERE ao.apartment_id = s.apartment_id
          AND ao.deleted_at IS NULL
          AND ao.owner_id = p_owner_profile_id
      )
    );
$$;

REVOKE ALL ON FUNCTION public._billing_offset_owner_pool_sum(uuid, uuid, text) FROM PUBLIC;

-- Výpočet plánu zápočtu – mirror OwnerCashOffsetCalculator.compute v SQL.
CREATE OR REPLACE FUNCTION public._billing_offset_compute_plan(
  p_invoice_due numeric,
  p_existing_offset numeric,
  p_owner_pool numeric,
  p_request_remaining numeric,
  OUT amount_to_apply numeric,
  OUT remaining_invoice_due numeric,
  OUT derived_payment_status text,
  OUT blocked boolean,
  OUT block_reason text
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_eps numeric := public._billing_offset_eps();
  v_due numeric := GREATEST(COALESCE(p_invoice_due, 0), 0);
  v_pool numeric := GREATEST(COALESCE(p_owner_pool, 0), 0);
  v_req_rem numeric := GREATEST(COALESCE(p_request_remaining, 0), 0);
  v_prior numeric := GREATEST(COALESCE(p_existing_offset, 0), 0);
  v_invoice_remaining numeric;
BEGIN
  amount_to_apply := 0;
  remaining_invoice_due := 0;
  derived_payment_status := 'partially_paid';
  blocked := true;
  block_reason := NULL;

  v_invoice_remaining := GREATEST(v_due - v_prior, 0);

  IF v_invoice_remaining <= v_eps THEN
    block_reason := 'already_settled';
    derived_payment_status := 'cash_offset';
    RETURN;
  END IF;

  IF v_req_rem <= v_eps THEN
    block_reason := 'no_request_remaining';
    remaining_invoice_due := v_invoice_remaining;
    RETURN;
  END IF;

  IF v_pool <= v_eps THEN
    block_reason := 'insufficient_pool';
    remaining_invoice_due := v_invoice_remaining;
    RETURN;
  END IF;

  amount_to_apply := LEAST(v_invoice_remaining, LEAST(v_req_rem, v_pool));
  remaining_invoice_due := GREATEST(v_invoice_remaining - amount_to_apply, 0);

  IF amount_to_apply <= v_eps THEN
    block_reason := 'insufficient_pool';
    amount_to_apply := 0;
    remaining_invoice_due := v_invoice_remaining;
    RETURN;
  END IF;

  blocked := false;
  IF remaining_invoice_due <= v_eps THEN
    derived_payment_status := 'cash_offset';
    remaining_invoice_due := 0;
  ELSE
    derived_payment_status := 'partially_paid';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public._billing_offset_compute_plan(numeric, numeric, numeric, numeric) FROM PUBLIC;

-- Jádro zápočtu – sdílená mutace (žádost musí existovat ve stavu approved/partially_completed).
CREATE OR REPLACE FUNCTION public.apply_billing_snapshot_offset_core(
  p_tenant_id uuid,
  p_snapshot_id uuid,
  p_request_id uuid,
  p_invoice_due numeric,
  p_currency text,
  p_created_by_profile_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_eps numeric := public._billing_offset_eps();
  v_now timestamptz := (now() AT TIME ZONE 'utc');
  v_req public.owner_cash_disposition_requests%ROWTYPE;
  v_snap public.billing_snapshots%ROWTYPE;
  v_source public.owner_cash_transit_settlements%ROWTYPE;
  v_existing_pay text;
  v_existing_offset numeric;
  v_invoice_remaining numeric;
  v_pool numeric;
  v_request_remaining numeric;
  v_plan_amount_to_apply numeric;
  v_plan_remaining_invoice_due numeric;
  v_plan_derived_payment_status text;
  v_plan_blocked boolean;
  v_plan_block_reason text;
  v_new_used numeric;
  v_new_request_status text;
  v_offset_settlement_id uuid;
  v_offset_note text;
BEGIN
  IF p_tenant_id IS NULL OR p_snapshot_id IS NULL OR p_request_id IS NULL THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: missing identifiers';
  END IF;
  IF COALESCE(p_invoice_due, 0) <= 0 THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: invoice due must be positive';
  END IF;

  SELECT *
  INTO v_req
  FROM public.owner_cash_disposition_requests
  WHERE id = p_request_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: disposition request not found';
  END IF;

  IF v_req.disposition_type <> 'invoice_credit' THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: only invoice_credit supported';
  END IF;

  IF v_req.status NOT IN ('approved', 'partially_completed') THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: request must be approved or partially_completed';
  END IF;

  SELECT *
  INTO v_snap
  FROM public.billing_snapshots
  WHERE id = p_snapshot_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: billing snapshot not found';
  END IF;

  v_existing_pay := lower(trim(COALESCE(v_snap.payment_status, '')));
  v_existing_offset := COALESCE(v_snap.offset_amount, 0);
  v_invoice_remaining := GREATEST(COALESCE(p_invoice_due, 0) - v_existing_offset, 0);

  IF v_existing_pay = 'paid' THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: snapshot already paid';
  END IF;

  IF v_existing_pay = 'cash_offset' OR v_invoice_remaining <= v_eps THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: snapshot already fully offset';
  END IF;

  v_pool := public._billing_offset_owner_pool_sum(
    p_tenant_id,
    v_req.owner_profile_id,
    COALESCE(p_currency, 'EUR')
  );
  v_request_remaining := GREATEST(v_req.amount - COALESCE(v_req.used_amount, 0), 0);

  SELECT
    amount_to_apply,
    remaining_invoice_due,
    derived_payment_status,
    blocked,
    block_reason
  INTO
    v_plan_amount_to_apply,
    v_plan_remaining_invoice_due,
    v_plan_derived_payment_status,
    v_plan_blocked,
    v_plan_block_reason
  FROM public._billing_offset_compute_plan(
    p_invoice_due,
    v_existing_offset,
    v_pool,
    v_request_remaining
  );

  IF v_plan_blocked OR COALESCE(v_plan_amount_to_apply, 0) <= v_eps THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: offset blocked (%)', COALESCE(v_plan_block_reason, 'unknown');
  END IF;

  IF v_pool < v_plan_amount_to_apply - v_eps THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: insufficient owner pool';
  END IF;

  SELECT *
  INTO v_source
  FROM public.owner_cash_transit_settlements
  WHERE id = v_req.settlement_id
    AND tenant_id = p_tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: source settlement not found';
  END IF;

  v_new_used := COALESCE(v_req.used_amount, 0) + v_plan_amount_to_apply;
  IF v_new_used > v_req.amount + v_eps THEN
    RAISE EXCEPTION 'apply_billing_snapshot_offset_core: amount exceeds request capacity';
  END IF;

  IF v_new_used >= v_req.amount - v_eps THEN
    v_new_request_status := 'completed';
  ELSE
    v_new_request_status := 'partially_completed';
  END IF;

  UPDATE public.owner_cash_disposition_requests
  SET
    used_amount = v_new_used,
    status = v_new_request_status,
    updated_at = v_now
  WHERE id = v_req.id;

  v_offset_note := format(
    'Zápočet podkladu %s proti žádosti %s',
    p_snapshot_id::text,
    p_request_id::text
  );

  INSERT INTO public.owner_cash_transit_settlements (
    tenant_id,
    reservation_id,
    apartment_id,
    task_id,
    amount,
    currency,
    settled_at,
    note,
    created_by
  )
  VALUES (
    p_tenant_id,
    v_source.reservation_id,
    v_source.apartment_id,
    v_source.task_id,
    -v_plan_amount_to_apply,
    COALESCE(NULLIF(trim(v_source.currency), ''), upper(trim(COALESCE(p_currency, 'EUR')))),
    v_now,
    v_offset_note,
    p_created_by_profile_id
  )
  RETURNING id INTO v_offset_settlement_id;

  UPDATE public.billing_snapshots
  SET
    payment_status = v_plan_derived_payment_status,
    paid_at = v_now,
    offset_amount = v_existing_offset + v_plan_amount_to_apply,
    offset_request_id = v_req.id,
    offset_applied_at = v_now
  WHERE id = v_snap.id;

  RETURN jsonb_build_object(
    'amount_applied', v_plan_amount_to_apply,
    'remaining_invoice_due', v_plan_remaining_invoice_due,
    'payment_status', v_plan_derived_payment_status,
    'offset_settlement_id', v_offset_settlement_id,
    'request_id', v_req.id,
    'request_status_after', v_new_request_status,
    'used_amount_after', v_new_used,
    'offset_amount_total', v_existing_offset + v_plan_amount_to_apply
  );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_billing_snapshot_offset_core(uuid, uuid, uuid, numeric, text, uuid) FROM PUBLIC;

-- -----------------------------------------------------------------------------
-- 4. RPC – respond_billing_offset_proposal (majitel schválí / zamítne)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_billing_offset_proposal(
  p_proposal_id uuid,
  p_action text,
  p_owner_rejection_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_eps numeric := public._billing_offset_eps();
  v_now timestamptz := (now() AT TIME ZONE 'utc');
  v_action text := lower(trim(COALESCE(p_action, '')));
  v_caller_profile_id uuid;
  v_proposal public.billing_snapshot_offset_proposals%ROWTYPE;
  v_snap public.billing_snapshots%ROWTYPE;
  v_settlement public.owner_cash_transit_settlements%ROWTYPE;
  v_invoice_due numeric;
  v_existing_offset numeric;
  v_invoice_remaining numeric;
  v_pool numeric;
  v_amount_to_apply numeric;
  v_plan_amount_to_apply numeric;
  v_plan_remaining_invoice_due numeric;
  v_plan_derived_payment_status text;
  v_plan_blocked boolean;
  v_plan_block_reason text;
  v_new_request_id uuid;
  v_offset_result jsonb;
  v_admin_notes text;
BEGIN
  IF p_proposal_id IS NULL THEN
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:missing_proposal_id';
  END IF;

  IF v_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:invalid_action';
  END IF;

  -- PROČ: SECURITY DEFINER obchází RLS – explicitně ověříme volajícího majitele.
  SELECT p.id
  INTO v_caller_profile_id
  FROM public.profiles AS p
  WHERE p.auth_id = auth.uid()
    AND p.role = 'property_owner'
  LIMIT 1;

  IF v_caller_profile_id IS NULL THEN
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:owner_access_denied';
  END IF;

  SELECT *
  INTO v_proposal
  FROM public.billing_snapshot_offset_proposals
  WHERE id = p_proposal_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:not_found';
  END IF;

  IF v_proposal.owner_profile_id IS DISTINCT FROM v_caller_profile_id THEN
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:owner_mismatch';
  END IF;

  IF v_proposal.status <> 'pending_owner' THEN
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:not_pending (status=%)', v_proposal.status;
  END IF;

  -- ── Zamítnutí ─────────────────────────────────────────────────────────────
  IF v_action = 'reject' THEN
    UPDATE public.billing_snapshot_offset_proposals
    SET
      status = 'rejected_by_owner',
      owner_responded_at = v_now,
      owner_rejection_note = NULLIF(trim(COALESCE(p_owner_rejection_note, '')), ''),
      updated_at = v_now
    WHERE id = v_proposal.id;

    INSERT INTO public.audit_logs (
      tenant_id,
      user_id,
      action_type,
      table_name,
      record_id,
      details
    )
    VALUES (
      v_proposal.tenant_id,
      auth.uid(),
      'BILLING_OFFSET_PROPOSAL_REJECTED',
      'billing_snapshot_offset_proposals',
      v_proposal.id::text,
      jsonb_build_object(
        'proposal_id', v_proposal.id,
        'billing_snapshot_id', v_proposal.billing_snapshot_id,
        'owner_profile_id', v_proposal.owner_profile_id,
        'proposed_amount', v_proposal.proposed_amount
      )
    );

    RETURN jsonb_build_object(
      'ok', true,
      'action', 'reject',
      'proposal_id', v_proposal.id,
      'status', 'rejected_by_owner'
    );
  END IF;

  -- ── Schválení – atomický zápočet ──────────────────────────────────────────
  SELECT *
  INTO v_snap
  FROM public.billing_snapshots
  WHERE id = v_proposal.billing_snapshot_id
    AND tenant_id = v_proposal.tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    UPDATE public.billing_snapshot_offset_proposals
    SET status = 'stale', updated_at = v_now
    WHERE id = v_proposal.id;
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:snapshot_missing';
  END IF;

  IF lower(trim(COALESCE(v_snap.payment_status, ''))) <> 'partially_paid' THEN
    UPDATE public.billing_snapshot_offset_proposals
    SET status = 'stale', updated_at = v_now
    WHERE id = v_proposal.id;
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:snapshot_not_partially_paid';
  END IF;

  v_invoice_due := COALESCE((v_snap.snapshot_data->>'final_to_invoice')::numeric, 0);
  v_existing_offset := COALESCE(v_snap.offset_amount, 0);
  v_invoice_remaining := GREATEST(v_invoice_due - v_existing_offset, 0);

  IF v_invoice_remaining <= v_eps THEN
    UPDATE public.billing_snapshot_offset_proposals
    SET status = 'stale', updated_at = v_now
    WHERE id = v_proposal.id;
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:invoice_already_settled';
  END IF;

  SELECT *
  INTO v_settlement
  FROM public.owner_cash_transit_settlements
  WHERE id = v_proposal.settlement_id
    AND tenant_id = v_proposal.tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:settlement_not_found';
  END IF;

  v_pool := public._billing_offset_owner_pool_sum(
    v_proposal.tenant_id,
    v_proposal.owner_profile_id,
    v_proposal.currency
  );

  -- PROČ: amount nové žádosti = min(navrhovaná částka, zbývající faktura, pool).
  v_amount_to_apply := LEAST(
    v_proposal.proposed_amount,
    v_invoice_remaining,
    v_pool
  );

  IF v_amount_to_apply <= v_eps THEN
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:insufficient_pool_at_approval';
  END IF;

  SELECT
    amount_to_apply,
    remaining_invoice_due,
    derived_payment_status,
    blocked,
    block_reason
  INTO
    v_plan_amount_to_apply,
    v_plan_remaining_invoice_due,
    v_plan_derived_payment_status,
    v_plan_blocked,
    v_plan_block_reason
  FROM public._billing_offset_compute_plan(
    v_invoice_due,
    v_existing_offset,
    v_pool,
    v_amount_to_apply
  );

  IF v_plan_blocked OR COALESCE(v_plan_amount_to_apply, 0) <= v_eps THEN
    RAISE EXCEPTION 'BILLING_OFFSET_PROPOSAL:compute_blocked (%)', COALESCE(v_plan_block_reason, 'unknown');
  END IF;

  v_admin_notes := format(
    'Schváleno majitelem (návrh doplatku %s)',
    v_proposal.id::text
  );

  INSERT INTO public.owner_cash_disposition_requests (
    tenant_id,
    settlement_id,
    owner_profile_id,
    disposition_type,
    amount,
    used_amount,
    status,
    admin_notes,
    created_at,
    updated_at
  )
  VALUES (
    v_proposal.tenant_id,
    v_proposal.settlement_id,
    v_proposal.owner_profile_id,
    'invoice_credit',
    v_plan_amount_to_apply,
    0,
    'approved',
    v_admin_notes,
    v_now,
    v_now
  )
  RETURNING id INTO v_new_request_id;

  v_offset_result := public.apply_billing_snapshot_offset_core(
    v_proposal.tenant_id,
    v_proposal.billing_snapshot_id,
    v_new_request_id,
    v_invoice_due,
    v_proposal.currency,
    v_proposal.proposed_by_profile_id
  );

  UPDATE public.billing_snapshot_offset_proposals
  SET
    status = 'applied',
    applied_amount = v_plan_amount_to_apply,
    disposition_request_id = v_new_request_id,
    owner_responded_at = v_now,
    updated_at = v_now
  WHERE id = v_proposal.id;

  INSERT INTO public.audit_logs (
    tenant_id,
    user_id,
    action_type,
    table_name,
    record_id,
    details
  )
  VALUES (
    v_proposal.tenant_id,
    auth.uid(),
    'BILLING_OFFSET_PROPOSAL_APPROVED',
    'billing_snapshot_offset_proposals',
    v_proposal.id::text,
    jsonb_build_object(
      'proposal_id', v_proposal.id,
      'billing_snapshot_id', v_proposal.billing_snapshot_id,
      'disposition_request_id', v_new_request_id,
      'proposed_amount', v_proposal.proposed_amount,
      'applied_amount', v_plan_amount_to_apply,
      'offset_result', v_offset_result
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'approve',
    'proposal_id', v_proposal.id,
    'status', 'applied',
    'applied_amount', v_plan_amount_to_apply,
    'payment_status', v_offset_result->>'payment_status',
    'remaining_invoice_due', v_offset_result->>'remaining_invoice_due',
    'disposition_request_id', v_new_request_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.respond_billing_offset_proposal(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_billing_offset_proposal(uuid, text, text) TO authenticated;

COMMENT ON FUNCTION public.respond_billing_offset_proposal(uuid, text, text) IS
  'Majitel schválí (approve) nebo zamítne (reject) návrh doplatku faktury ze zálohy. Approve = atomický zápočet v jedné transakci.';

COMMENT ON FUNCTION public.apply_billing_snapshot_offset_core(uuid, uuid, uuid, numeric, text, uuid) IS
  'Interní jádro zápočtu faktury – volá se z respond_billing_offset_proposal; není určeno pro přímé volání z klienta.';
