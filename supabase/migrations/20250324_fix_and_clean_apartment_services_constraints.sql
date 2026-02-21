-- =============================================================================
-- FalcoNest – Sanitizace dat a oprava CHECK constraints (apartment_services)
-- Řeší chybu 23514: staré hodnoty (weekly, monthly, …) v schedule_interval
-- blokují nasazení nového CHECK. Pořadí: DROP → vyčistit data → ADD.
-- =============================================================================

-- A) Smazat stávající constraints pro trigger_type i schedule_interval
ALTER TABLE public.apartment_services DROP CONSTRAINT IF EXISTS apartment_services_trigger_type_check;
ALTER TABLE public.apartment_services DROP CONSTRAINT IF EXISTS apartment_services_schedule_interval_check;

-- B) Sanitizovat trigger_type: přepsat 'manual' na 'on_demand'
UPDATE public.apartment_services
  SET trigger_type = 'on_demand'
  WHERE trigger_type = 'manual';

-- C) Sanitizovat schedule_interval: hodnoty mimo nový seznam nastavit na NULL
--    (staré hodnoty např. 'weekly', 'monthly', 'biweekly', 'biannually' už nejsou povolené)
UPDATE public.apartment_services
  SET schedule_interval = NULL
  WHERE schedule_interval IS NOT NULL
    AND schedule_interval NOT IN ('1_week', '2_weeks', '1_month', '2_months', '3_months', '6_months');

-- D) Nasadit nové CHECK constraints
ALTER TABLE public.apartment_services
  ADD CONSTRAINT apartment_services_trigger_type_check
  CHECK (trigger_type IN ('on_demand', 'before_checkin', 'after_checkout', 'both_ways', 'scheduled'));

ALTER TABLE public.apartment_services
  ADD CONSTRAINT apartment_services_schedule_interval_check
  CHECK (schedule_interval IS NULL OR schedule_interval IN ('1_week', '2_weeks', '1_month', '2_months', '3_months', '6_months'));
