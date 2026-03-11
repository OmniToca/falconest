-- =============================================================================
-- FalcoNest – Hlavní plátce u spoluvlastnictví (Primary billing owner)
-- =============================================================================
-- U apartmánů s více majiteli (apartment_owners má více řádků pro stejný
-- apartment_id) musí fakturace (paušál i úkoly) jít vždy jen jednomu klientovi.
-- Sloupec is_primary_billing označuje, který majitel je hlavní plátce za daný byt.
-- =============================================================================

ALTER TABLE public.apartment_owners
  ADD COLUMN IF NOT EXISTS is_primary_billing BOOLEAN DEFAULT false;

COMMENT ON COLUMN public.apartment_owners.is_primary_billing IS 'U spoluvlastnictví: true = tento majitel je hlavní plátce (fakturace paušálu a úkolů). Pouze jeden záznam na apartment_id by měl mít true.';
