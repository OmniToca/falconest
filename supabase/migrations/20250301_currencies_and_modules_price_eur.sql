-- =============================================================================
-- FalcoNest – Multi-Currency: tabulka kurzů (currencies) + moduly v EUR (price_eur)
-- =============================================================================
-- Základní měna: EUR. Ceny modulů jsou v EUR; tenant vidí přepočet dle tenants.currency
-- a kurzu z public.currencies (rate vůči EUR, EUR = 1.0).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka currencies (kurzovní lístek)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.currencies (
    code TEXT PRIMARY KEY,
    symbol TEXT NOT NULL,
    rate NUMERIC NOT NULL,
    name TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.currencies IS 'Kurzovní lístek: kurzy vůči EUR (EUR = 1.0). Pro zobrazení cen tenanta v jeho měně.';
COMMENT ON COLUMN public.currencies.rate IS 'Kurz vůči EUR. Např. CZK 25 = 1 EUR = 25 CZK.';

-- -----------------------------------------------------------------------------
-- 2. Výchozí kurzy
-- -----------------------------------------------------------------------------
INSERT INTO public.currencies (code, symbol, rate, name) VALUES
('EUR', '€', 1.00, 'Euro'),
('CZK', 'Kč', 25.00, 'Česká koruna'),
('USD', '$', 1.10, 'US Dollar')
ON CONFLICT (code) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 3. RLS: všichni čtou; zapisovat smí jen Super Admin
-- -----------------------------------------------------------------------------
ALTER TABLE public.currencies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "currencies_select_all" ON public.currencies;
CREATE POLICY "currencies_select_all"
    ON public.currencies FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "currencies_super_admin_all" ON public.currencies;
CREATE POLICY "currencies_super_admin_all"
    ON public.currencies FOR ALL
    USING (public.is_super_admin())
    WITH CHECK (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 4. Moduly: sjednocení na EUR (price_eur)
-- Aktuální schéma má sloupec [price]; přejmenujeme na price_eur.
-- Sloupec [currency] v modules nikdy nebyl v migracích – pro jistotu DROP IF EXISTS.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'modules' AND column_name = 'monthly_price'
    ) THEN
        ALTER TABLE public.modules RENAME COLUMN monthly_price TO price_eur;
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'modules' AND column_name = 'price'
    ) THEN
        ALTER TABLE public.modules RENAME COLUMN price TO price_eur;
    END IF;
END $$;

-- Zajistit sloupec price_eur existuje (např. pokud tabulka měla jiný název sloupce).
ALTER TABLE public.modules ADD COLUMN IF NOT EXISTS price_eur NUMERIC DEFAULT 0;

ALTER TABLE public.modules DROP COLUMN IF EXISTS currency;

COMMENT ON COLUMN public.modules.price_eur IS 'Měsíční cena modulu v EUR (základní měna). Pro zobrazení se přepočítá dle tenants.currency a public.currencies.';

-- -----------------------------------------------------------------------------
-- 5. Profily: preferovaná měna uživatele (pro zobrazení cen v Nastavení / katalogu)
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS preferred_currency TEXT DEFAULT 'CZK';

COMMENT ON COLUMN public.profiles.preferred_currency IS 'Preferovaná měna pro zobrazení cen (CZK, EUR, USD). Super Admin vidí ceny modulů v této měně.';
