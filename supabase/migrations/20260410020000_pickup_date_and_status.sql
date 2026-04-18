-- =============================================================================
-- FalcoNest – Datum vyzvednutí hotovosti + stav „připraveno k vyzvednutí“
-- =============================================================================
-- PROČ Fáze 3: majitel u vault_pickup zadává pickup_date; dispečink může nastavit
-- status ready_for_pickup. Majitel (pending) smí měnit pickup_date přes novou RLS politiku.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. owner_cash_disposition_requests – pickup_date + rozšíření status CHECK
-- -----------------------------------------------------------------------------
ALTER TABLE public.owner_cash_disposition_requests
  ADD COLUMN IF NOT EXISTS pickup_date timestamptz;

COMMENT ON COLUMN public.owner_cash_disposition_requests.pickup_date IS
  'Plánované vyzvednutí hotovosti v trezoru (vault_pickup); UTC v aplikaci.';

ALTER TABLE public.owner_cash_disposition_requests
  DROP CONSTRAINT IF EXISTS owner_cash_disposition_requests_status_check;

ALTER TABLE public.owner_cash_disposition_requests
  ADD CONSTRAINT owner_cash_disposition_requests_status_check
  CHECK (
    status IN (
      'pending',
      'approved',
      'rejected',
      'completed',
      'partially_completed',
      'ready_for_pickup'
    )
  );

-- Majitel (property_owner): UPDATE vlastní žádosti jen ve stavu pending (např. pickup_date).
DROP POLICY IF EXISTS "owner_cash_disposition_requests_update_owner_pending"
  ON public.owner_cash_disposition_requests;

CREATE POLICY "owner_cash_disposition_requests_update_owner_pending"
  ON public.owner_cash_disposition_requests
  FOR UPDATE
  TO authenticated
  USING (
    owner_cash_disposition_requests.owner_profile_id = (
      SELECT p_u.id
      FROM public.profiles AS p_u
      WHERE p_u.auth_id = auth.uid()
      LIMIT 1
    )
    AND owner_cash_disposition_requests.tenant_id = public.my_tenant_id()
    AND (
      SELECT p_r.role
      FROM public.profiles AS p_r
      WHERE p_r.auth_id = auth.uid()
      LIMIT 1
    ) = 'property_owner'
    AND owner_cash_disposition_requests.status = 'pending'
  )
  WITH CHECK (
    owner_cash_disposition_requests.owner_profile_id = (
      SELECT p_w.id
      FROM public.profiles AS p_w
      WHERE p_w.auth_id = auth.uid()
      LIMIT 1
    )
    AND owner_cash_disposition_requests.tenant_id = public.my_tenant_id()
    AND owner_cash_disposition_requests.status = 'pending'
  );
