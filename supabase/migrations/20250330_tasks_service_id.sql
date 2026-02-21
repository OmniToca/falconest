-- Přidání sloupce service_id do tasks – vazba úkolu na službu z katalogu.
-- U scheduled úkolů umožňuje Ochranný štít (žádný duplicitní úkol pro apartment+service).
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS service_id uuid REFERENCES public.tenant_services(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.tasks.service_id IS 'Služba z katalogu (tenant_services). Pro scheduled úkoly: identifikace a ochranný štít.';
