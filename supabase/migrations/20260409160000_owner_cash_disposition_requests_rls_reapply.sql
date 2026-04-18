-- =============================================================================
-- FalcoNest – REAPPLY owner_cash_disposition_requests (RLS bez ambiguous sloupců)
-- =============================================================================
-- Pro databáze, kde migrace 20260409143000 už proběhla se starým SQL (Supabase ji
-- znovu nespustí po změně souboru). Obsah je shodný s opravenou 20260409143000.
-- Na čistém resetu: 143000 vytvoří tabulku, tato migrace ji znovu DROP+CREATE (stejný stav).
-- Žádné změny u owner_cash_transit_settlements.

DROP TABLE IF EXISTS public.owner_cash_disposition_requests CASCADE;

CREATE TABLE public.owner_cash_disposition_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  settlement_id uuid NOT NULL REFERENCES public.owner_cash_transit_settlements (id) ON DELETE CASCADE,
  owner_profile_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE RESTRICT,
  disposition_type text NOT NULL
    CHECK (disposition_type IN ('bank_transfer', 'invoice_credit', 'vault_pickup')),
  amount numeric NOT NULL CHECK (amount > 0),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
  admin_notes text,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

COMMENT ON TABLE public.owner_cash_disposition_requests IS
  'Žádost majitele o způsob vyřízení uznané průtokové hotovosti (odděleno od řádku settlement).';

COMMENT ON COLUMN public.owner_cash_disposition_requests.settlement_id IS
  'FK na owner_cash_transit_settlements.id – uznaná částka, součty a audit.';

CREATE INDEX idx_owner_cash_disposition_requests_tenant
  ON public.owner_cash_disposition_requests (tenant_id);

CREATE INDEX idx_owner_cash_disposition_requests_owner
  ON public.owner_cash_disposition_requests (owner_profile_id);

CREATE INDEX idx_owner_cash_disposition_requests_settlement
  ON public.owner_cash_disposition_requests (settlement_id);

CREATE INDEX idx_owner_cash_disposition_requests_status
  ON public.owner_cash_disposition_requests (tenant_id, status);

ALTER TABLE public.owner_cash_disposition_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_cash_disposition_requests_select_owner"
  ON public.owner_cash_disposition_requests
  FOR SELECT
  TO authenticated
  USING (
    owner_cash_disposition_requests.owner_profile_id = (
      SELECT p_sel.id
      FROM public.profiles AS p_sel
      WHERE p_sel.auth_id = auth.uid()
      LIMIT 1
    )
  );

CREATE POLICY "owner_cash_disposition_requests_select_tenant_staff"
  ON public.owner_cash_disposition_requests
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      owner_cash_disposition_requests.tenant_id = public.my_tenant_id()
      AND (
        SELECT p_staff.role
        FROM public.profiles AS p_staff
        WHERE p_staff.auth_id = auth.uid()
        LIMIT 1
      ) IS DISTINCT FROM 'property_owner'
    )
  );

CREATE POLICY "owner_cash_disposition_requests_insert_owner"
  ON public.owner_cash_disposition_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles AS p0
      WHERE p0.auth_id = auth.uid()
        AND p0.role = 'property_owner'
    )
    AND owner_cash_disposition_requests.owner_profile_id = (
      SELECT p1.id
      FROM public.profiles AS p1
      WHERE p1.auth_id = auth.uid()
      LIMIT 1
    )
    AND owner_cash_disposition_requests.tenant_id = public.my_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM public.owner_cash_transit_settlements AS s
      INNER JOIN public.reservations AS r ON r.id = s.reservation_id
      INNER JOIN public.apartment_owners AS ao
        ON ao.apartment_id = r.apartment_id
        AND ao.deleted_at IS NULL
        AND ao.owner_id = owner_cash_disposition_requests.owner_profile_id
      WHERE s.id = owner_cash_disposition_requests.settlement_id
        AND s.tenant_id = owner_cash_disposition_requests.tenant_id
    )
  );

CREATE POLICY "owner_cash_disposition_requests_update_admin_manager"
  ON public.owner_cash_disposition_requests
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      owner_cash_disposition_requests.tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p2
        WHERE p2.auth_id = auth.uid()
          AND p2.tenant_id = owner_cash_disposition_requests.tenant_id
          AND p2.role IN ('admin', 'manager')
      )
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      owner_cash_disposition_requests.tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p3
        WHERE p3.auth_id = auth.uid()
          AND p3.tenant_id = owner_cash_disposition_requests.tenant_id
          AND p3.role IN ('admin', 'manager')
      )
    )
  );

CREATE POLICY "owner_cash_disposition_requests_delete_admin_manager"
  ON public.owner_cash_disposition_requests
  FOR DELETE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      owner_cash_disposition_requests.tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p4
        WHERE p4.auth_id = auth.uid()
          AND p4.tenant_id = owner_cash_disposition_requests.tenant_id
          AND p4.role IN ('admin', 'manager')
      )
    )
  );
