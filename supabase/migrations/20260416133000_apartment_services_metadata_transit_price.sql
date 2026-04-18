-- =============================================================================
-- FalcoNest – apartment_services.metadata (transit_price pro průtokové peníze)
-- =============================================================================
-- PROČ: Sjednocení plánování nájmů a služeb do jednoho engine. Služba bytu může
-- nést vedle ceny práce i průtokovou částku (např. nájem), která se při generování
-- úkolu propíše do tasks.metadata.transit_amount_to_collect.
-- =============================================================================

ALTER TABLE public.apartment_services
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.apartment_services.metadata IS
  'Volitelná JSON konfigurace služby na úrovni bytu. Pro long-term rent flow klíč metadata.transit_price (částka průtokové hotovosti v EUR).';

