-- FalcoNest: Fáze C pro dlouhodobý nájem bez reservation_id
-- PROČ: Úkoly typu rent_collection mohou mít reservation_id = NULL, ale i tak musí po
-- "Převzít hotovost" vzniknout settlement pro majitele (vazba přes task_id/apartment_id).

ALTER TABLE public.owner_cash_transit_settlements
  ALTER COLUMN reservation_id DROP NOT NULL;

ALTER TABLE public.owner_cash_transit_settlements
  ADD COLUMN IF NOT EXISTS apartment_id uuid REFERENCES public.apartments (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS task_id uuid REFERENCES public.tasks (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_owner_cash_transit_settlements_apartment
  ON public.owner_cash_transit_settlements (apartment_id);

CREATE INDEX IF NOT EXISTS idx_owner_cash_transit_settlements_task
  ON public.owner_cash_transit_settlements (task_id);

DROP POLICY IF EXISTS "owner_cash_transit_settlements_select_property_owner"
  ON public.owner_cash_transit_settlements;

-- Majitel vidí settlementy jak přes pobyt (reservation_id), tak i přes přímé apartment_id
-- pro long-term nájem, kde reservation_id není dostupné.
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
    AND (
      EXISTS (
        SELECT 1
        FROM public.reservations r
        INNER JOIN public.apartment_owners ao
          ON ao.apartment_id = r.apartment_id
          AND ao.deleted_at IS NULL
          AND ao.owner_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
        WHERE r.id = owner_cash_transit_settlements.reservation_id
      )
      OR EXISTS (
        SELECT 1
        FROM public.apartment_owners ao
        WHERE ao.apartment_id = owner_cash_transit_settlements.apartment_id
          AND ao.deleted_at IS NULL
          AND ao.owner_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      )
    )
  );
