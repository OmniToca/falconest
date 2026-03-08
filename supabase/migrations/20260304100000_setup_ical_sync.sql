-- =============================================================================
-- FalcoNest – Příprava struktury pro iCal Sync (Idempotence a zdroje)
-- =============================================================================
-- 1. reservations.external_uid – unikátní identifikátor z iCal (VEVENT UID) pro
--    idempotenci při opakovaném syncu. NULL u ručně/Excel vytvořených rezervací.
-- 2. apartment_ical_sources – tabulka pro uložení iCal URL odkazů (Airbnb,
--    Booking). Jeden apartmán může mít více zdrojů (UNIQUE apartment_id + source_label).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Sloupec external_uid v reservations
-- -----------------------------------------------------------------------------
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS external_uid text;

COMMENT ON COLUMN public.reservations.external_uid IS 'Unikátní ID z iCal (VEVENT UID) pro idempotenci syncu. NULL u ručně/Excel importů.';

-- Parciální unikátní index – pouze řádky s external_uid. Ručně vytvořené rezervace
-- (NULL) projdou; iCal rezervace se nesmí duplikovat v rámci tenanta.
CREATE UNIQUE INDEX IF NOT EXISTS idx_reservations_external_uid
  ON public.reservations (tenant_id, external_uid)
  WHERE external_uid IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 2. Tabulka apartment_ical_sources
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.apartment_ical_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  apartment_id uuid NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
  ical_url text NOT NULL,
  source_label text NOT NULL,
  last_synced_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  UNIQUE (apartment_id, source_label)
);

COMMENT ON TABLE public.apartment_ical_sources IS 'iCal URL odkazy pro automatický sync rezervací (Airbnb, Booking, Smoobu). Jeden apartmán může mít více zdrojů.';
COMMENT ON COLUMN public.apartment_ical_sources.ical_url IS 'URL .ics souboru z Airbnb, Booking.com nebo jiného channelu.';
COMMENT ON COLUMN public.apartment_ical_sources.source_label IS 'Lidský název zdroje – např. Airbnb, Booking.';
COMMENT ON COLUMN public.apartment_ical_sources.last_synced_at IS 'Kdy byl naposledy proveden sync z tohoto zdroje.';

CREATE INDEX IF NOT EXISTS idx_apartment_ical_sources_tenant_id
  ON public.apartment_ical_sources(tenant_id);
CREATE INDEX IF NOT EXISTS idx_apartment_ical_sources_apartment_id
  ON public.apartment_ical_sources(apartment_id);

-- -----------------------------------------------------------------------------
-- 3. RLS politiky na apartment_ical_sources
-- -----------------------------------------------------------------------------
ALTER TABLE public.apartment_ical_sources ENABLE ROW LEVEL SECURITY;

-- SELECT: Super Admin nebo admin svého tenantu
CREATE POLICY "apartment_ical_sources_select"
  ON public.apartment_ical_sources FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

-- INSERT: Super Admin nebo admin svého tenantu
CREATE POLICY "apartment_ical_sources_insert"
  ON public.apartment_ical_sources FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

-- UPDATE: Super Admin nebo admin svého tenantu
CREATE POLICY "apartment_ical_sources_update"
  ON public.apartment_ical_sources FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

-- DELETE: Super Admin nebo admin svého tenantu
CREATE POLICY "apartment_ical_sources_delete"
  ON public.apartment_ical_sources FOR DELETE
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );
