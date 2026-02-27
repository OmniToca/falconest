-- =============================================================================
-- FalcoNest – Sloupec flight_number do reservation_services
-- =============================================================================
-- Číslo letu (např. FR1495) pro transfery – sledování letu, FlightRadar24.
-- Dříve ukládáno do custom_note s prefixem [FLIGHT:XXX]; nyní samostatný sloupec.
-- =============================================================================

ALTER TABLE public.reservation_services
  ADD COLUMN IF NOT EXISTS flight_number text;

COMMENT ON COLUMN public.reservation_services.flight_number IS 'Číslo letu pro transfery (např. FR1495). Pro sledování na FlightRadar24.';
