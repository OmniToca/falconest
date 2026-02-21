-- Přidání sloupce duration_minutes do tenant_services – časová náročnost / rezerva v minutách.
-- U úklidu slouží jako vata (přičítá se k standardCleaningDuration bytu), u ostatních jako fixní doba.
ALTER TABLE public.tenant_services
  ADD COLUMN IF NOT EXISTS duration_minutes integer DEFAULT 60;

COMMENT ON COLUMN public.tenant_services.duration_minutes IS 'Časová náročnost / rezerva v minutách. U úklidu: vata nad standardCleaningDuration. U transfer/extra: fixní doba. Pro Task Automator.';
