-- =============================================================================
-- FalcoNest – preference jazyka v profilu + popis modulů
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. profiles: preference jazyka (cs, en, es)
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS language_code text DEFAULT 'cs';

COMMENT ON COLUMN public.profiles.language_code IS 'Preferovaný jazyk uživatele: cs, en, es. Používá se v Nastavení a pro EasyLocalization.';

-- -----------------------------------------------------------------------------
-- 2. modules: sloupec description (volitelný popis modulu)
-- -----------------------------------------------------------------------------
ALTER TABLE public.modules
  ADD COLUMN IF NOT EXISTS description text;

COMMENT ON COLUMN public.modules.description IS 'Volitelný popis modulu pro katalog (Super Admin).';

-- Ověření sloupců: key, name, monthly_price/price, pricing_type, order_index už máme z předchozích migrací.
