-- =============================================================================
-- FalcoNest – Rozšíření tabulky apartments o životní cyklus bytu
-- =============================================================================
-- Spusť v Supabase SQL Editoru (Dashboard → SQL Editor).
-- Přidává sloupce: status, check_in_time, check_out_time, standard_cleaning_duration, owner_notes.
-- Tabulka se v kódu nazývá "apartments" (někdy flats).
-- =============================================================================

ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Uklizeno',
  ADD COLUMN IF NOT EXISTS check_in_time TEXT DEFAULT '15:00',
  ADD COLUMN IF NOT EXISTS check_out_time TEXT DEFAULT '10:00',
  ADD COLUMN IF NOT EXISTS standard_cleaning_duration INTEGER DEFAULT 120,
  ADD COLUMN IF NOT EXISTS owner_notes TEXT;

-- Možné hodnoty status: Uklizeno, K úklidu, Obsazeno hosty, Probíhá úklid, Rekonstrukce
COMMENT ON COLUMN public.apartments.status IS 'Stav bytu: Uklizeno, K úklidu, Obsazeno hosty, Probíhá úklid, Rekonstrukce';
COMMENT ON COLUMN public.apartments.check_in_time IS 'Standardní čas příjezdu, např. 15:00';
COMMENT ON COLUMN public.apartments.check_out_time IS 'Standardní čas odjezdu, např. 10:00';
COMMENT ON COLUMN public.apartments.standard_cleaning_duration IS 'Standardní doba úklidu v minutách';
COMMENT ON COLUMN public.apartments.owner_notes IS 'Preference a instrukce majitele pro přípravu bytu';
