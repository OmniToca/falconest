-- =============================================================================
-- FalcoNest – Povinná služba (apartment_services.is_mandatory)
-- =============================================================================
-- Služba označená jako povinná nelze v rezervaci odškrtnout (checkbox je zamčený).
-- =============================================================================

ALTER TABLE public.apartment_services
  ADD COLUMN IF NOT EXISTS is_mandatory boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.apartment_services.is_mandatory IS 'Pokud je true, nelze tuto službu v rezervaci odškrtnout (je povinná).';
