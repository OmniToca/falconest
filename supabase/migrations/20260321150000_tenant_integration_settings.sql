-- =============================================================================
-- FalcoNest – Tenant: integrace (API klíče, vlastní identita odesílatele)
-- =============================================================================
-- PROČ: Každá agentura může mít vlastní Resend/Twilio/TTLock účty bez nové tabulky.
-- Hodnoty držíme v JSONB – Edge funkce je čte přes service role (RLS bypass).
-- =============================================================================

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS integration_settings jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.tenants.integration_settings IS
  'Obecné nastavení integrací (JSON): např. resend_api_key, resend_from_email, Twilio, TTLock. Neukládejte tajemství do klienta – zápis jen přes zabezpečené API/UI.';
