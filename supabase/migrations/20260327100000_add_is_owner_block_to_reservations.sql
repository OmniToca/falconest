-- =============================================================================
-- FalcoNest – Rozlišení osobní blokace majitele v tabulce reservations
-- -----------------------------------------------------------------------------
-- PROČ: Stejný řádek rezervace slouží pro platícího hosta i pro „zablokovaný“ termín
-- majitele; bez příznaku by statistiky, fakturace a automatické e-maily kolem hosta
-- špatně interpretovaly záznam.
-- =============================================================================

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS is_owner_block boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.reservations.is_owner_block IS
  'true = majitel si zablokoval termín pro vlastní pobyt/využití (Klientský portál); false = běžná rezervace hosta.';
