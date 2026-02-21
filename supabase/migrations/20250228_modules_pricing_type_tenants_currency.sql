-- =============================================================================
-- FalcoNest – typ ceny u modulů (fixed / per_apartment / per_user) + měna u tenanta
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. modules: sloupec pricing_type
-- -----------------------------------------------------------------------------
ALTER TABLE public.modules
  ADD COLUMN IF NOT EXISTS pricing_type text NOT NULL DEFAULT 'fixed';

ALTER TABLE public.modules
  DROP CONSTRAINT IF EXISTS modules_pricing_type_check;

ALTER TABLE public.modules
  ADD CONSTRAINT modules_pricing_type_check
  CHECK (pricing_type IN ('fixed', 'per_apartment', 'per_user'));

COMMENT ON COLUMN public.modules.pricing_type IS 'fixed = měsíční paušál; per_apartment = cena × počet bytů; per_user = cena × počet uživatelů.';

-- Existující data: apartments = per_apartment, staff = per_user, ostatní fixed
UPDATE public.modules SET pricing_type = 'per_apartment' WHERE key = 'apartments';
UPDATE public.modules SET pricing_type = 'per_user' WHERE key = 'staff';
UPDATE public.modules SET pricing_type = 'fixed' WHERE pricing_type IS NULL OR pricing_type = '';

-- -----------------------------------------------------------------------------
-- 2. tenants: sloupec currency (pro formátování cen v Tenant Detail)
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS currency text DEFAULT 'CZK';

COMMENT ON COLUMN public.tenants.currency IS 'Měna tenanta pro zobrazení cen (CZK, EUR, USD).';
