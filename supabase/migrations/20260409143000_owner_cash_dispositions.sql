-- =============================================================================
-- FalcoNest – Tabulka owner_cash_disposition_requests (žádosti majitele o dispozici)
-- =============================================================================
-- Pouze nová tabulka + indexy + RLS. Tabulka owner_cash_transit_settlements se
-- v této migraci vůbec nemění (žádné ALTER na ni).
-- Sloupce disposition_type a status: text + CHECK (žádné CREATE TYPE / enumy).

CREATE TABLE IF NOT EXISTS public.owner_cash_disposition_requests (
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

CREATE INDEX IF NOT EXISTS idx_owner_cash_disposition_requests_tenant
  ON public.owner_cash_disposition_requests (tenant_id);

CREATE INDEX IF NOT EXISTS idx_owner_cash_disposition_requests_owner
  ON public.owner_cash_disposition_requests (owner_profile_id);

CREATE INDEX IF NOT EXISTS idx_owner_cash_disposition_requests_settlement
  ON public.owner_cash_disposition_requests (settlement_id);

CREATE INDEX IF NOT EXISTS idx_owner_cash_disposition_requests_status
  ON public.owner_cash_disposition_requests (tenant_id, status);

ALTER TABLE public.owner_cash_disposition_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_cash_disposition_requests_select_owner"
  ON public.owner_cash_disposition_requests
  FOR SELECT
  TO authenticated
  USING (
    owner_profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "owner_cash_disposition_requests_select_tenant_staff"
  ON public.owner_cash_disposition_requests
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND (
        SELECT pr.role
        FROM public.profiles AS pr
        WHERE pr.auth_id = auth.uid()
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
    AND owner_profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    AND tenant_id = public.my_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM public.owner_cash_transit_settlements AS s
      INNER JOIN public.reservations AS r ON r.id = s.reservation_id
      INNER JOIN public.apartment_owners AS ao
        ON ao.apartment_id = r.apartment_id
        AND ao.deleted_at IS NULL
        AND ao.owner_id = owner_profile_id
      WHERE s.id = settlement_id
        AND s.tenant_id = tenant_id
    )
  );

CREATE POLICY "owner_cash_disposition_requests_update_admin_manager"
  ON public.owner_cash_disposition_requests
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p
        WHERE p.auth_id = auth.uid()
          AND p.tenant_id = owner_cash_disposition_requests.tenant_id
          AND p.role IN ('admin', 'manager')
      )
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p
        WHERE p.auth_id = auth.uid()
          AND p.tenant_id = owner_cash_disposition_requests.tenant_id
          AND p.role IN ('admin', 'manager')
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
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p
        WHERE p.auth_id = auth.uid()
          AND p.tenant_id = owner_cash_disposition_requests.tenant_id
          AND p.role IN ('admin', 'manager')
      )
    )
  );
