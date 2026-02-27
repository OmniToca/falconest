-- =============================================================================
-- FalcoNest – Propagace requires_photo do apartment_services a reservation_services
-- =============================================================================
-- PROČ: Plná propagace podle Override Pattern (Katalog -> Byt -> Rezervace).
-- tenant_services již má requires_photo. Tento sloupec umožňuje:
-- - apartment_services: override na úrovni bytu (NULL = použít z katalogu)
-- - reservation_services: snapshot pro konkrétní rezervaci (NULL = dopočítat z bytu/katalogu)
-- =============================================================================

-- Úroveň 2: apartment_services – override pro tento byt
ALTER TABLE public.apartment_services
ADD COLUMN IF NOT EXISTS requires_photo boolean;

COMMENT ON COLUMN public.apartment_services.requires_photo IS 'Override: vyžadovat fotodokumentaci pro tuto službu u tohoto bytu. NULL = použít z tenant_services.';

-- Úroveň 3: reservation_services – snapshot pro tuto rezervaci
ALTER TABLE public.reservation_services
ADD COLUMN IF NOT EXISTS requires_photo boolean;

COMMENT ON COLUMN public.reservation_services.requires_photo IS 'Snapshot: vyžadovat fotodokumentaci pro tuto službu u této rezervace. NULL = dopočítat z apartment_services/tenant_services.';
