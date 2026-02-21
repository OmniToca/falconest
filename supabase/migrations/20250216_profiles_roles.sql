-- Volitelný sloupec roles v profiles – text[] pro přímé uložení týmových rolí.
-- Pokud preferuješ user_roles tabulku, tuto migraci nepoužívej.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS roles TEXT[] DEFAULT '{}';

COMMENT ON COLUMN public.profiles.roles IS 'Týmové role – admin, cleaner, driver, maintenance. Alternativa k tabulce user_roles.';
