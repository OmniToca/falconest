-- =============================================================================
-- FalcoNest – Oprava CHECK constraints pro apartment_services
-- Správné pořadí: NEJPRVE DROP constraint, TEPRVE POTÉ UPDATE dat, NAKONEC ADD.
-- (UPDATE by jinak narazil na starý CHECK, který blokuje hodnotu 'on_demand'.)
-- =============================================================================

-- 1. NEJPRVE smazat starou závoru pro spouštěč
ALTER TABLE public.apartment_services DROP CONSTRAINT IF EXISTS apartment_services_trigger_type_check;

-- 2. TEPRVE POTÉ přepsat data
UPDATE public.apartment_services SET trigger_type = 'on_demand' WHERE trigger_type = 'manual';

-- 3. NAKONEC přidat novou závoru
ALTER TABLE public.apartment_services ADD CONSTRAINT apartment_services_trigger_type_check CHECK (trigger_type IN ('on_demand', 'before_checkin', 'after_checkout', 'both_ways', 'scheduled'));

-- 4. To samé pro intervaly – nejprve smazat
ALTER TABLE public.apartment_services DROP CONSTRAINT IF EXISTS apartment_services_schedule_interval_check;

-- 5. A přidat novou (s povolením NULL)
ALTER TABLE public.apartment_services ADD CONSTRAINT apartment_services_schedule_interval_check CHECK (schedule_interval IN ('1_week', '2_weeks', '1_month', '2_months', '3_months', '6_months') OR schedule_interval IS NULL);
