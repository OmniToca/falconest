-- =============================================================================
-- FalcoNest – Task Automator: nové spouštěče a intervaly (apartment_services)
-- =============================================================================
-- Rušíme 'manual', zavádíme: on_demand, before_checkin, after_checkout,
-- both_ways, scheduled. Intervaly: 1_week, 2_weeks, 1_month, 2_months, 3_months, 6_months.
-- =============================================================================

-- Staré hodnoty trigger_type na on_demand (náhrada za manual)
UPDATE public.apartment_services
  SET trigger_type = 'on_demand'
  WHERE trigger_type = 'manual';

-- Převod starých intervalů na nové klíče (pro scheduled)
UPDATE public.apartment_services
  SET schedule_interval = CASE schedule_interval
    WHEN 'weekly' THEN '1_week'
    WHEN 'biweekly' THEN '2_weeks'
    WHEN 'monthly' THEN '1_month'
    WHEN 'biannually' THEN '6_months'
    ELSE COALESCE(schedule_interval, '1_week')
  END
  WHERE trigger_type = 'scheduled' AND schedule_interval IS NOT NULL;

UPDATE public.apartment_services
  SET schedule_interval = '1_week'
  WHERE trigger_type = 'scheduled' AND (schedule_interval IS NULL OR schedule_interval = '');

-- Nový CHECK pro trigger_type
ALTER TABLE public.apartment_services
  DROP CONSTRAINT IF EXISTS apartment_services_trigger_type_check;

ALTER TABLE public.apartment_services
  ADD CONSTRAINT apartment_services_trigger_type_check
  CHECK (trigger_type IN ('on_demand', 'before_checkin', 'after_checkout', 'both_ways', 'scheduled'));

-- CHECK pro schedule_interval (povolené hodnoty + null, když trigger_type != scheduled)
ALTER TABLE public.apartment_services
  DROP CONSTRAINT IF EXISTS apartment_services_schedule_interval_check;

ALTER TABLE public.apartment_services
  ADD CONSTRAINT apartment_services_schedule_interval_check
  CHECK (schedule_interval IS NULL OR schedule_interval IN ('1_week', '2_weeks', '1_month', '2_months', '3_months', '6_months'));

COMMENT ON COLUMN public.apartment_services.trigger_type IS 'Spouštěč: on_demand (během pobytu), before_checkin (příjezd), after_checkout (odjezd), both_ways (obousměrný transfer), scheduled (pravidelně)';
COMMENT ON COLUMN public.apartment_services.schedule_interval IS 'Interval u trigger_type=scheduled: 1_week, 2_weeks, 1_month, 2_months, 3_months, 6_months';
