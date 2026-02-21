-- =============================================================================
-- FalcoNest – Rozšíření tabulky reservations pro Admin modul
-- =============================================================================
-- Spusť v Supabase SQL Editoru (Dashboard → SQL Editor).
-- Přidává sloupce: guest_name, check_in, check_out, needs_transfer.
-- Pokud tabulka reservations neexistuje, vytvoř ji (závisí na existujícím schématu).
-- =============================================================================

-- Přidání sloupců – pokud tabulka má již start_date/end_date, ponecháme je pro kompatibilitu
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS guest_name TEXT,
  ADD COLUMN IF NOT EXISTS check_in TEXT,
  ADD COLUMN IF NOT EXISTS check_out TEXT,
  ADD COLUMN IF NOT EXISTS needs_transfer BOOLEAN DEFAULT false;

COMMENT ON COLUMN public.reservations.guest_name IS 'Jméno hosta';
COMMENT ON COLUMN public.reservations.check_in IS 'Termín příjezdu (ISO nebo text, např. 25.08.2026)';
COMMENT ON COLUMN public.reservations.check_out IS 'Termín odjezdu (ISO nebo text)';
COMMENT ON COLUMN public.reservations.needs_transfer IS 'Zda host požaduje transfer na letiště';
