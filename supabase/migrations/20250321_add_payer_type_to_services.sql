-- =============================================================================
-- FalcoNest – Kdo platí službu (Majitel vs. Host) – apartment_services & reservation_services
-- =============================================================================
-- Na úrovni bytu (apartment_services) výchozí plátce; v rezervaci (reservation_services)
-- lze pro konkrétní pobyt přepsat (Override Tier 2 & 3).
-- =============================================================================

ALTER TABLE public.apartment_services
  ADD COLUMN IF NOT EXISTS payer_type text NOT NULL DEFAULT 'guest'
  CHECK (payer_type IN ('owner', 'guest'));

COMMENT ON COLUMN public.apartment_services.payer_type IS 'Kdo platí službu: owner (majitel - faktura) nebo guest (host - na místě)';

ALTER TABLE public.reservation_services
  ADD COLUMN IF NOT EXISTS payer_type text
  CHECK (payer_type IS NULL OR payer_type IN ('owner', 'guest'));

COMMENT ON COLUMN public.reservation_services.payer_type IS 'Kdo platí službu u této rezervace (override); NULL = použít hodnotu z apartment_services.';
