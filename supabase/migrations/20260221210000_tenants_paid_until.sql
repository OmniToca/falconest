-- =============================================================================
-- FalcoNest – paid_until pro Kill Switch (Globální stopka po 5. dni v měsíci)
-- =============================================================================

-- Sloupec paid_until: datum do kdy je předplatné zaplaceno. NULL = neomezeno / neplatí.
-- Používá se pro hard-lock aplikace, pokud faktura není zaplacena do 5. dne v měsíci.
ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS paid_until timestamptz;

COMMENT ON COLUMN public.tenants.paid_until IS 'Zaplaceno do – Kill Switch: přístup blokován pokud today > paid_until (a platba nebyla do 5. dne). NULL = bez omezení.';
