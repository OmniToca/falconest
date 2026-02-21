-- =============================================================================
-- FalcoNest – Soft Delete pro zones, apartment_owners, tenants
-- =============================================================================
-- Audit Log vyžaduje zachování historie – místo tvrdého DELETE se používá
-- UPDATE deleted_at = now(). Při čtení se filtrují záznamy s deleted_at IS NULL.
-- Spusť v Supabase SQL Editoru.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. zones – měkké mazání oblastí
-- -----------------------------------------------------------------------------
ALTER TABLE public.zones
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

COMMENT ON COLUMN public.zones.deleted_at IS 'Soft delete: NOT NULL = oblast skrytá z katalogu. Místo DELETE se volá UPDATE deleted_at = now().';

-- -----------------------------------------------------------------------------
-- 2. apartment_owners – měkké mazání propojení majitel–byt
-- -----------------------------------------------------------------------------
ALTER TABLE public.apartment_owners
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

COMMENT ON COLUMN public.apartment_owners.deleted_at IS 'Soft delete: NOT NULL = propojení skryto. Místo DELETE se volá UPDATE deleted_at = now().';

-- -----------------------------------------------------------------------------
-- 3. tenants – měkké mazání agentur
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

COMMENT ON COLUMN public.tenants.deleted_at IS 'Soft delete: NOT NULL = agentura skryta. Místo DELETE se volá UPDATE deleted_at = now().';
