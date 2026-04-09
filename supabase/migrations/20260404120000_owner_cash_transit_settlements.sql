-- =============================================================================
-- FalcoNest – Vyúčtování průtokové hotovosti majiteli (transit → settled)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.owner_cash_transit_settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES public.reservations (id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'EUR',
  settled_at timestamptz NOT NULL DEFAULT now(),
  note text,
  created_by uuid NOT NULL REFERENCES public.profiles (id) ON DELETE RESTRICT
);

COMMENT ON TABLE public.owner_cash_transit_settlements IS
  'Záznam vyúčtování hotovosti od hosta vůči majiteli (průtoková hotovost – není tržba agentury).';

CREATE INDEX IF NOT EXISTS idx_owner_cash_transit_settlements_tenant
  ON public.owner_cash_transit_settlements (tenant_id);

CREATE INDEX IF NOT EXISTS idx_owner_cash_transit_settlements_reservation
  ON public.owner_cash_transit_settlements (reservation_id);

ALTER TABLE public.owner_cash_transit_settlements ENABLE ROW LEVEL SECURITY;

-- Zaměstnanci agentury (kromě property_owner): plný SELECT v rámci tenanta.
CREATE POLICY "owner_cash_transit_settlements_select_tenant_staff"
  ON public.owner_cash_transit_settlements
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND (
        SELECT p.role
        FROM public.profiles p
        WHERE p.auth_id = auth.uid()
        LIMIT 1
      ) IS DISTINCT FROM 'property_owner'
    )
  );

-- Majitel: jen záznamy pro rezervace na svých bytech.
CREATE POLICY "owner_cash_transit_settlements_select_property_owner"
  ON public.owner_cash_transit_settlements
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.auth_id = auth.uid()
        AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1
      FROM public.reservations r
      INNER JOIN public.apartment_owners ao
        ON ao.apartment_id = r.apartment_id
        AND ao.deleted_at IS NULL
        AND ao.owner_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      WHERE r.id = owner_cash_transit_settlements.reservation_id
    )
  );

-- INSERT: admin / manager tenanta nebo super_admin.
CREATE POLICY "owner_cash_transit_settlements_insert_admin_manager"
  ON public.owner_cash_transit_settlements
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
          AND p.tenant_id = owner_cash_transit_settlements.tenant_id
          AND p.role IN ('admin', 'manager')
      )
    )
  );

-- UPDATE / DELETE: stejně jako INSERT (účetní opravy jen management).
CREATE POLICY "owner_cash_transit_settlements_update_admin_manager"
  ON public.owner_cash_transit_settlements
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.auth_id = auth.uid()
          AND p.tenant_id = owner_cash_transit_settlements.tenant_id
          AND p.role IN ('admin', 'manager')
      )
    )
  );

CREATE POLICY "owner_cash_transit_settlements_delete_admin_manager"
  ON public.owner_cash_transit_settlements
  FOR DELETE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.auth_id = auth.uid()
          AND p.tenant_id = owner_cash_transit_settlements.tenant_id
          AND p.role IN ('admin', 'manager')
      )
    )
  );
