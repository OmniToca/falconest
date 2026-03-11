-- =============================================================================
-- FalcoNest – Měsíční paušál za správu apartmánu (Retainer fee)
-- =============================================================================
-- Přidává do tabulky apartments sloupec monthly_management_fee (numeric, default 0.00).
-- Použití: fixní měsíční poplatek za správu bytu (např. pro fakturaci majitelům).
-- =============================================================================

ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS monthly_management_fee NUMERIC DEFAULT 0.00;

COMMENT ON COLUMN public.apartments.monthly_management_fee IS 'Měsíční paušál za správu apartmánu v EUR (0 = neúčtuje se)';
