-- =============================================================================
-- FalcoNest – 3-úrovňový model dynamických služeb (Katalog → Byt → Rezervace)
-- =============================================================================
-- 1) Rozšíření reservations: guest_adults, guest_children, arrival_time
-- 2) Nová tabulka tenant_services (katalog agentury)
-- 3) Nová tabulka apartment_services (ceník a pravidla bytu)
-- 4) Nová tabulka reservation_services (služby vybrané k pobytu)
-- Override Pattern: cena a popis se na každé úrovni mohou přepsat (viz database_schema.md).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) RESERVATIONS – nové sloupce
-- -----------------------------------------------------------------------------
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS guest_adults integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS guest_children integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS arrival_time timestamptz;

COMMENT ON COLUMN public.reservations.guest_adults IS 'Počet dospělých hostů';
COMMENT ON COLUMN public.reservations.guest_children IS 'Počet dětí';
COMMENT ON COLUMN public.reservations.arrival_time IS 'Předpokládaný čas příjezdu (volitelné)';

-- -----------------------------------------------------------------------------
-- 2) TENANT_SERVICES – katalog služeb agentury (úroveň 1)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenant_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  service_type text NOT NULL CHECK (service_type IN ('cleaning', 'transfer', 'maintenance', 'extra')),
  default_price numeric,
  is_active boolean NOT NULL DEFAULT true,
  deleted_at timestamptz
);

COMMENT ON TABLE public.tenant_services IS 'Katalog služeb tenanta (výchozí cena a popis – Override Pattern úroveň 1)';
COMMENT ON COLUMN public.tenant_services.description IS 'Co služba standardně obsahuje';
COMMENT ON COLUMN public.tenant_services.default_price IS 'Výchozí cena; na úrovni bytu/rezervace lze přepsat';
COMMENT ON COLUMN public.tenant_services.deleted_at IS 'Soft delete: NOT NULL = služba skrytá z katalogu';

CREATE INDEX IF NOT EXISTS idx_tenant_services_tenant_id ON public.tenant_services(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_services_deleted_at ON public.tenant_services(deleted_at);

ALTER TABLE public.tenant_services ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_services_select"
  ON public.tenant_services FOR SELECT
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "tenant_services_insert"
  ON public.tenant_services FOR INSERT
  WITH CHECK (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "tenant_services_update"
  ON public.tenant_services FOR UPDATE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "tenant_services_delete"
  ON public.tenant_services FOR DELETE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

-- -----------------------------------------------------------------------------
-- 3) APARTMENT_SERVICES – ceník a pravidla bytu (úroveň 2)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.apartment_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  apartment_id uuid NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
  service_id uuid NOT NULL REFERENCES public.tenant_services(id) ON DELETE CASCADE,
  custom_price numeric,
  custom_description text,
  trigger_type text NOT NULL CHECK (trigger_type IN ('manual', 'after_checkout', 'scheduled')),
  schedule_interval text
);

COMMENT ON TABLE public.apartment_services IS 'Služby nabízené u bytu – přepis ceny/popisu pro tento byt (Override Pattern úroveň 2)';
COMMENT ON COLUMN public.apartment_services.custom_price IS 'Přepis ceny pro tento byt; NULL = použít default_price z tenant_services';
COMMENT ON COLUMN public.apartment_services.custom_description IS 'Přepis obsahu pro tento byt; NULL = použít description z tenant_services';
COMMENT ON COLUMN public.apartment_services.schedule_interval IS 'Např. weekly, biannually – u trigger_type = scheduled';

CREATE INDEX IF NOT EXISTS idx_apartment_services_tenant_id ON public.apartment_services(tenant_id);
CREATE INDEX IF NOT EXISTS idx_apartment_services_apartment_id ON public.apartment_services(apartment_id);
CREATE INDEX IF NOT EXISTS idx_apartment_services_service_id ON public.apartment_services(service_id);

ALTER TABLE public.apartment_services ENABLE ROW LEVEL SECURITY;

CREATE POLICY "apartment_services_select"
  ON public.apartment_services FOR SELECT
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "apartment_services_insert"
  ON public.apartment_services FOR INSERT
  WITH CHECK (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "apartment_services_update"
  ON public.apartment_services FOR UPDATE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "apartment_services_delete"
  ON public.apartment_services FOR DELETE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

-- -----------------------------------------------------------------------------
-- 4) RESERVATION_SERVICES – služby vybrané k pobytu (úroveň 3)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reservation_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES public.reservations(id) ON DELETE CASCADE,
  apartment_service_id uuid NOT NULL REFERENCES public.apartment_services(id) ON DELETE CASCADE,
  custom_note text,
  charged_price numeric
);

COMMENT ON TABLE public.reservation_services IS 'Služby přiřazené k rezervaci – poznámka klienta a účtovaná cena (Override Pattern úroveň 3)';
COMMENT ON COLUMN public.reservation_services.custom_note IS 'Specifická poznámka klienta k této službě (např. dětská sedačka u transferu) – neukládat do reservations';
COMMENT ON COLUMN public.reservation_services.charged_price IS 'Skutečně účtovaná cena za tuto službu u této rezervace; NULL = dopočítat z bytu/katalogu';

CREATE INDEX IF NOT EXISTS idx_reservation_services_tenant_id ON public.reservation_services(tenant_id);
CREATE INDEX IF NOT EXISTS idx_reservation_services_reservation_id ON public.reservation_services(reservation_id);
CREATE INDEX IF NOT EXISTS idx_reservation_services_apartment_service_id ON public.reservation_services(apartment_service_id);

ALTER TABLE public.reservation_services ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reservation_services_select"
  ON public.reservation_services FOR SELECT
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "reservation_services_insert"
  ON public.reservation_services FOR INSERT
  WITH CHECK (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "reservation_services_update"
  ON public.reservation_services FOR UPDATE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "reservation_services_delete"
  ON public.reservation_services FOR DELETE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());
