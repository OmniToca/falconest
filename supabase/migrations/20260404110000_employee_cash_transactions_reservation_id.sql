-- =============================================================================
-- FalcoNest – Průtoková hotovost: vazba transakce na rezervaci + čtení pro majitele
-- =============================================================================
-- PROČ: COLLECTED_FROM_GUEST / HANDED_TO_AGENCY lze provázat s ubytováním pro
-- majitelský přehled. Majitel (property_owner) smí číst jen řádky vztahující se
-- k rezervacím na jeho bytech (doplňuje stávající tenant-wide SELECT).
-- =============================================================================

ALTER TABLE public.employee_cash_transactions
  ADD COLUMN IF NOT EXISTS reservation_id uuid REFERENCES public.reservations (id) ON DELETE SET NULL;

COMMENT ON COLUMN public.employee_cash_transactions.reservation_id IS
  'Volitelná vazba na rezervaci (ubytování). Doplňuje task_id; pro majitelské reporty a HANDED_TO_AGENCY s vazbou na pobyt.';

CREATE INDEX IF NOT EXISTS idx_employee_cash_transactions_reservation_id
  ON public.employee_cash_transactions (reservation_id)
  WHERE reservation_id IS NOT NULL;

-- Majitel bytu: SELECT jen transakce, které patří k rezervaci na jeho apartmánu.
CREATE POLICY "employee_cash_transactions_property_owner_select"
  ON public.employee_cash_transactions
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
      (
        employee_cash_transactions.reservation_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.reservations r
          INNER JOIN public.apartment_owners ao
            ON ao.apartment_id = r.apartment_id
            AND ao.deleted_at IS NULL
            AND ao.owner_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
          WHERE r.id = employee_cash_transactions.reservation_id
        )
      )
      OR (
        employee_cash_transactions.task_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.tasks t
          INNER JOIN public.reservations r ON r.id = t.reservation_id
          INNER JOIN public.apartment_owners ao
            ON ao.apartment_id = r.apartment_id
            AND ao.deleted_at IS NULL
            AND ao.owner_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
          WHERE t.id = employee_cash_transactions.task_id
        )
      )
    )
  );

COMMENT ON POLICY "employee_cash_transactions_property_owner_select" ON public.employee_cash_transactions IS
  'Majitel vidí hotovostní transakce jen u rezervací na svých bytech (reservation_id nebo task → rezervace).';
