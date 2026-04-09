-- =============================================================================
-- Hotfix: sloupec apartment_id u tenant_calendar_feed_tokens (iCal export)
-- =============================================================================
-- PROČ: Na produkci zjevně neproběhla starší migrace s tímto sloupcem; Flutter insert
-- posílá apartment_id při „omezit na byt“. Bez sloupce PostgREST/Postgres insert selže.
-- Idempotentní ADD COLUMN IF NOT EXISTS – bezpečné opakované nasazení.
-- =============================================================================

ALTER TABLE public.tenant_calendar_feed_tokens
  ADD COLUMN IF NOT EXISTS apartment_id uuid REFERENCES public.apartments (id) ON DELETE SET NULL;

COMMENT ON COLUMN public.tenant_calendar_feed_tokens.apartment_id IS
  'NULL = export všech úkolů tenanta; NOT NULL = jen úkoly vázané na tento apartmán.';

CREATE INDEX IF NOT EXISTS idx_tenant_calendar_feed_tokens_apartment_id
  ON public.tenant_calendar_feed_tokens (apartment_id)
  WHERE apartment_id IS NOT NULL;
