-- =============================================================================
-- FalcoNest – Oblasti (Zóny) a Žebříček preferencí zaměstnanců
-- =============================================================================
-- Fáze 3.1: Každý tenant má vlastní Oblasti (např. La Mata, Guardamar).
-- Každý apartmán patří do jedné oblasti. Zaměstnanec si může Oblasti očíslovat
-- podle preferencí (1 = nejraději, 2 = dojedu) – pro inteligentní přidělování úkolů.
-- Spusť v Supabase SQL Editoru.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka zones
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.zones IS 'Oblasti/zóny agentury – La Mata, Guardamar atd. Multi-tenant izolace přes tenant_id.';
COMMENT ON COLUMN public.zones.name IS 'Název oblasti (např. La Mata).';

CREATE INDEX IF NOT EXISTS zones_tenant_id_idx ON public.zones(tenant_id);

-- -----------------------------------------------------------------------------
-- 2. RLS na zones
-- -----------------------------------------------------------------------------
ALTER TABLE public.zones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "zones_select"
  ON public.zones FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "zones_insert"
  ON public.zones FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "zones_update"
  ON public.zones FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "zones_delete"
  ON public.zones FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- -----------------------------------------------------------------------------
-- 3. Sloupec zone_id v apartments
-- -----------------------------------------------------------------------------
ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS zone_id uuid REFERENCES public.zones(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.apartments.zone_id IS 'FK na zones – oblast, do které apartmán patří. Nullable (staré záznamy).';

CREATE INDEX IF NOT EXISTS apartments_zone_id_idx ON public.apartments(zone_id);

-- -----------------------------------------------------------------------------
-- 4. Sloupec zone_preferences v profiles
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS zone_preferences jsonb DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.profiles.zone_preferences IS 'Žebříček preferencí oblastí: {"zone_id_uuid": 1, "zone_id_2": 2}. 1 = nejraději, 2 = dojedu. Prázdný objekt = bez preferencí.';
