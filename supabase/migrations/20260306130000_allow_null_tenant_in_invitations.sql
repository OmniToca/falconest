-- =============================================================================
-- FalcoNest HQ Tým – pozvánky bez agentury
-- =============================================================================
-- PROČ: Pro přidání nového člena HQ týmu (Super-Admin, Account Manager) ukládáme
-- pozvánku do invitations s tenant_id = NULL (bez přiřazení k agentuře).
-- ADDITIVE: pouze povolíme NULL u sloupce tenant_id, nic nemazáme.
-- =============================================================================

ALTER TABLE public.invitations
  ALTER COLUMN tenant_id DROP NOT NULL;

COMMENT ON COLUMN public.invitations.tenant_id IS 'Agentura, pro kterou je pozvánka určena; NULL = pozvánka pro HQ (Super-Admin / Account Manager).';
