-- =============================================================================
-- FalcoNest – Sloupec agency_id v tabulce clients
-- =============================================================================
-- PROČ: Externí klient (client_type = 'external') může být doporučen konkrétní
-- agenturou (client_type = 'agency'). Self-reference na clients.id umožňuje
-- evidovat, která agentura nám klienta přivedla – pro reporty a provize.
--
-- ON DELETE SET NULL: Při smazání agentury zůstane externí klient v CRM,
-- pouze se ztratí informace o doporučující agentuře.
-- =============================================================================

ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS agency_id uuid REFERENCES public.clients(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.clients.agency_id IS 'FK na clients – agentura, která nám tohoto externího klienta doporučila. Pouze pro client_type = external.';

CREATE INDEX IF NOT EXISTS idx_clients_agency_id ON public.clients(agency_id) WHERE agency_id IS NOT NULL;
