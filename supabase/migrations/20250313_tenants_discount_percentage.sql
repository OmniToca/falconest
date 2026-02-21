-- FalcoNest – sleva tenanta (0–100 %) pro výpočet MRR.
-- Sloupec discount_percentage se aplikuje na součet aktivních modulů (mimo trial).

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS discount_percentage integer NOT NULL DEFAULT 0
  CHECK (discount_percentage >= 0 AND discount_percentage <= 100);

COMMENT ON COLUMN public.tenants.discount_percentage IS 'Sleva v procentech (0–100) aplikovaná na MRR z placených modulů.';
