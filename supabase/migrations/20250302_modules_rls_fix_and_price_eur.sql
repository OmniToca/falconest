-- =============================================================================
-- FalcoNest – oprava RLS na public.modules (42501) + jistota sloupce price_eur
-- =============================================================================
-- Problém: Při vytváření/úpravě modulu dochází k RLS violation – chybí nebo
-- nesedí politiky pro Super Admin (INSERT/UPDATE/DELETE).
-- Řešení: Sjednotit politiky – SELECT pro všechny, ALL pro is_super_admin().
-- Zároveň zajistit, že sloupec ceny je vždy price_eur (rename monthly_price pokud existuje).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. RLS na modules – zapnuto (pro jistotu)
-- -----------------------------------------------------------------------------
ALTER TABLE public.modules ENABLE ROW LEVEL SECURITY;

-- Odstranit všechny možné staré názvy politik (z různých migrací nebo ručních úprav)
DROP POLICY IF EXISTS "Enable read access for all users" ON public.modules;
DROP POLICY IF EXISTS "Super Admin Write" ON public.modules;
DROP POLICY IF EXISTS "Super Admin Full Access" ON public.modules;
DROP POLICY IF EXISTS "modules_select_all" ON public.modules;
DROP POLICY IF EXISTS "modules_insert_super" ON public.modules;
DROP POLICY IF EXISTS "modules_update_super" ON public.modules;
DROP POLICY IF EXISTS "modules_delete_super" ON public.modules;

-- Čtení: všichni (přihlášení i anonym) mohou vidět katalog modulů
CREATE POLICY "Enable read access for all users"
  ON public.modules FOR SELECT
  USING (true);

-- Zápis: pouze Super Admin smí INSERT, UPDATE, DELETE
CREATE POLICY "Super Admin Full Access"
  ON public.modules FOR ALL
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 2. Sloupec ceny – musí být price_eur (Flutter posílá jen price_eur)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'modules' AND column_name = 'monthly_price'
  ) THEN
    ALTER TABLE public.modules RENAME COLUMN monthly_price TO price_eur;
  END IF;
END $$;

-- Pokud by náhodou zůstal sloupec 'price', přejmenovat na price_eur (nebo už byl v 20250301)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'modules' AND column_name = 'price'
  ) THEN
    ALTER TABLE public.modules RENAME COLUMN price TO price_eur;
  END IF;
END $$;

ALTER TABLE public.modules ADD COLUMN IF NOT EXISTS price_eur NUMERIC DEFAULT 0;
