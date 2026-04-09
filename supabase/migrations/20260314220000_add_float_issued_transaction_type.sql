-- =============================================================================
-- FalcoNest – Vklad základu (Float / kasírtaška) v Zaměstnanecké pokladně
-- =============================================================================
-- Rozšíření transaction_type o hodnotu FLOAT_ISSUED – admin vloží zaměstnanci
-- hotovost na začátek směny (základ na vracení, nákupy).
-- =============================================================================

ALTER TABLE public.employee_cash_transactions
  DROP CONSTRAINT IF EXISTS employee_cash_transactions_transaction_type_check;

ALTER TABLE public.employee_cash_transactions
  ADD CONSTRAINT employee_cash_transactions_transaction_type_check
  CHECK (transaction_type IN (
    'COLLECTED_FROM_GUEST',
    'HANDED_TO_AGENCY',
    'COMPANY_EXPENSE',
    'FLOAT_ISSUED'
  ));

COMMENT ON COLUMN public.employee_cash_transactions.transaction_type IS
  'COLLECTED_FROM_GUEST = výběr od hosta; HANDED_TO_AGENCY = odevzdání agentuře; COMPANY_EXPENSE = firemní výdaj; FLOAT_ISSUED = vklad základu od agentury.';
