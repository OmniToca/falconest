-- =============================================================================
-- FalcoNest – Firemní výdaje (Company Expenses) v Zaměstnanecké pokladně
-- =============================================================================
-- Přidání sloupců note a receipt_image_url do employee_cash_transactions.
-- Rozšíření transaction_type o hodnotu COMPANY_EXPENSE.
-- =============================================================================

-- Přidání sloupců pro firemní výdaje
ALTER TABLE public.employee_cash_transactions
  ADD COLUMN IF NOT EXISTS note text,
  ADD COLUMN IF NOT EXISTS receipt_image_url text;

COMMENT ON COLUMN public.employee_cash_transactions.note IS 'Poznámka k firemnímu výdaji (např. „Materiál na úklid“).';
COMMENT ON COLUMN public.employee_cash_transactions.receipt_image_url IS 'URL fotky účtenky v Supabase Storage.';

-- Rozšíření CHECK constraintu o COMPANY_EXPENSE
-- Nejprve odstraníme starý constraint (PostgreSQL neumí ALTER CHECK).
ALTER TABLE public.employee_cash_transactions
  DROP CONSTRAINT IF EXISTS employee_cash_transactions_transaction_type_check;

ALTER TABLE public.employee_cash_transactions
  ADD CONSTRAINT employee_cash_transactions_transaction_type_check
  CHECK (transaction_type IN ('COLLECTED_FROM_GUEST', 'HANDED_TO_AGENCY', 'COMPANY_EXPENSE'));
