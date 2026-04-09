-- =============================================================================
-- FalcoNest – Globální tarif jednotkových cen zpráv (EUR) pro automatizace a billing
-- -----------------------------------------------------------------------------
-- PROČ: Ceny dříve byly natvrdo v Edge (`automation-dispatch`) a ve Flutteru; tato
-- tabulka umožní měnit sazby bez deploye. Historie přes `valid_from` (append-only).
-- Skutečně účtované částky zůstávají v `tenant_message_log.unit_price`.
--
-- RLS: `authenticated` smí jen SELECT (Flutter admin / Super-Admin přehledy).
-- Zápis nemá politiku pro běžného přihlášeného uživatele → zamítnuto.
-- `service_role` (Edge Functions, migrace) RLS obchází → INSERT/UPDATE/DELETE možné.
-- Až bude Super-Admin UI, přidejte politiku INSERT s `is_super_admin()`.
-- =============================================================================

CREATE TABLE public.platform_messaging_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel text NOT NULL
    CHECK (channel IN ('sms', 'whatsapp', 'email')),
  price_eur numeric(12, 6) NOT NULL CHECK (price_eur >= 0),
  valid_from timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT platform_messaging_rates_channel_valid_from_uniq UNIQUE (channel, valid_from)
);

CREATE INDEX idx_platform_messaging_rates_channel_valid_from
  ON public.platform_messaging_rates (channel, valid_from DESC);

COMMENT ON TABLE public.platform_messaging_rates IS
  'Globální jednotkové ceny zpráv (EUR); aktuální řádek = nejnovější valid_from <= now() per kanál.';

ALTER TABLE public.platform_messaging_rates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS platform_messaging_rates_select_authenticated
  ON public.platform_messaging_rates;
CREATE POLICY platform_messaging_rates_select_authenticated
  ON public.platform_messaging_rates
  FOR SELECT
  TO authenticated
  USING (true);

-- PROČ: Žádná politika INSERT/UPDATE/DELETE pro `authenticated` → zamítnuto pod RLS.
-- Service role obchází RLS → Edge a budoucí údržba přes SQL.

GRANT SELECT ON public.platform_messaging_rates TO authenticated;
GRANT ALL ON public.platform_messaging_rates TO service_role;

-- Výchozí tarif (stejné hodnoty jako dříve v kódu).
INSERT INTO public.platform_messaging_rates (channel, price_eur, valid_from)
VALUES
  ('sms', 0.05, now()),
  ('whatsapp', 0.08, now()),
  ('email', 0.02, now());
