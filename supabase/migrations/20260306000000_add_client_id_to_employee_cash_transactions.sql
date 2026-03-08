-- =============================================================================
-- FalcoNest – Přidání client_id do employee_cash_transactions
-- =============================================================================
-- PROČ: Transakce (příjem/výdaj) musí mít možnost vazby na konkrétního klienta,
-- když se platba netýká apartmánu (např. externí klient Pepa zaplatí za transfer).
-- apartment_id a task_id zůstávají beze změny – Additive Development.
-- =============================================================================

ALTER TABLE public.employee_cash_transactions
  ADD COLUMN IF NOT EXISTS client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.employee_cash_transactions.client_id IS 'Vazba na klienta – pro platby nesouvisející s apartmánem (např. externí transfer).';

CREATE INDEX IF NOT EXISTS idx_employee_cash_transactions_client_id
  ON public.employee_cash_transactions(client_id)
  WHERE client_id IS NOT NULL;
