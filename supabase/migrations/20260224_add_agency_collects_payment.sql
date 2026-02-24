-- =============================================================================
-- FEATURE: Volba výběru platby od hosta (Majitel vs Agentura)
-- Klientský portál (Owner Portal) – majitel při vytváření rezervace určí,
-- kdo od hostů vybere peníze: false = platbu řeší majitel, true = agentura.
-- =============================================================================

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS agency_collects_payment BOOLEAN DEFAULT false;

COMMENT ON COLUMN public.reservations.agency_collects_payment IS 'Kdo vybírá platbu od hosta: false = majitel (nebo již má), true = prosím agenturu o vybrání na místě';

NOTIFY pgrst, 'reload schema';
