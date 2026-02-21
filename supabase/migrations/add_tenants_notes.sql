-- Přidá sloupec notes do tabulky tenants pro interní poznámky Super Admina.
-- Spusť v Supabase SQL Editoru.

ALTER TABLE public.tenants
ADD COLUMN IF NOT EXISTS notes TEXT;

COMMENT ON COLUMN public.tenants.notes IS 'Interní poznámky Super Admina o agentuře (majitel, kontakty, poznámky).';
