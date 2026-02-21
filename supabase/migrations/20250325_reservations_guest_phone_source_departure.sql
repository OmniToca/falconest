-- =============================================================================
-- FalcoNest – Rozšíření reservations: telefon hosta, zdroj rezervace, čas odjezdu
-- Pro Task Automator (plánování úklidů a odvozů) a reporting zdrojů.
-- =============================================================================

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS guest_phone TEXT,
  ADD COLUMN IF NOT EXISTS reservation_source TEXT DEFAULT 'Other',
  ADD COLUMN IF NOT EXISTS departure_time TIMESTAMP WITH TIME ZONE;

-- Zdroj rezervace: CHECK pro konzistenci (Booking, Airbnb, Direct, Other)
ALTER TABLE public.reservations DROP CONSTRAINT IF EXISTS reservations_reservation_source_check;
ALTER TABLE public.reservations
  ADD CONSTRAINT reservations_reservation_source_check
  CHECK (reservation_source IS NULL OR reservation_source IN ('Booking', 'Airbnb', 'Direct', 'Other'));

COMMENT ON COLUMN public.reservations.guest_phone IS 'Telefon hosta (kontakt pro transfery a předání)';
COMMENT ON COLUMN public.reservations.reservation_source IS 'Zdroj rezervace: Booking, Airbnb, Direct, Other';
COMMENT ON COLUMN public.reservations.departure_time IS 'Předpokládaný čas odjezdu z apartmánu (pro plánování úklidu a transferu na letiště)';
