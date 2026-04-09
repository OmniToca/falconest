-- =============================================================================
-- FalcoNest – Klientská zóna: JSONB metadata u rezervací a firemních výdajů
-- -----------------------------------------------------------------------------
-- PROČ: Majitel ukládá schválení výdajů (owner_approved) a značku blokace pobytu
--       (is_owner_stay) bez nových tabulek. ADDITIVE pouze sloupce.
-- =============================================================================

ALTER TABLE public.employee_cash_transactions
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.employee_cash_transactions.metadata IS
  'Rozšíření záznamu (např. owner_approved, owner_approved_at u COMPANY_EXPENSE).';

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.reservations.metadata IS
  'Volitelná rozšíření (např. is_owner_stay pro blokaci termínu majitelem).';
