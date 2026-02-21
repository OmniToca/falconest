-- Přidání sloupce required_role do tenant_services pro propojení služby s profesí (Task Automator).
-- Hodnoty: any (kdokoliv), cleaner, driver, maintenance, checkin_agent.
ALTER TABLE public.tenant_services
  ADD COLUMN IF NOT EXISTS required_role text DEFAULT 'any';

COMMENT ON COLUMN public.tenant_services.required_role IS 'Požadovaná profese pro vykonání služby (any = kdokoliv; cleaner, driver, maintenance, checkin_agent). Pro Task Automator.';
