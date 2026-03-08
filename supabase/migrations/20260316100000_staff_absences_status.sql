-- =============================================================================
-- FalcoNest – Schvalovací workflow pro absence (Approval Workflow)
-- =============================================================================
-- Sloupec status: pending (žádost z mobilu), approved (schváleno / z adminu),
-- rejected (zamítnuto). Existující záznamy bez status = považujeme za approved
-- (zpětná kompatibilita).
-- =============================================================================

ALTER TABLE public.staff_absences
  ADD COLUMN IF NOT EXISTS status text;

COMMENT ON COLUMN public.staff_absences.status IS
  'pending = čeká na schválení, approved = schváleno (nebo zadané adminem), rejected = zamítnuto. NULL = legacy, považováno za approved.';
