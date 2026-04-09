-- =============================================================================
-- FalcoNest – Oddělení příjmu agentury (charged_price) od průtokové hotovosti majitele
-- =============================================================================

ALTER TABLE public.reservation_services
  ADD COLUMN IF NOT EXISTS transit_cash_to_collect numeric NULL;

COMMENT ON COLUMN public.reservation_services.transit_cash_to_collect IS
  'Hotovost za ubytování k výběru od hosta (průtok majiteli), EUR. Odděleně od charged_price (příjem agentury za službu).';

ALTER TABLE public.employee_cash_transactions
  ADD COLUMN IF NOT EXISTS transit_portion numeric NULL;

COMMENT ON COLUMN public.employee_cash_transactions.transit_portion IS
  'Část částky COLLECTED_FROM_GUEST připadající na průtokovou hotovost majitele (po alokaci agency vs. transit z metadat úkolu).';
