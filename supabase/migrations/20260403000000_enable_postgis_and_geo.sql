-- Enterprise: PostGIS + geosloupce pro apartmány a úkoly.
-- PROČ: Nativní prostorové dotazy (vzdálenost, bbox, mapové výřezy) bez změny aplikační logiky v tomto kroku.
-- Rozšíření v schématu extensions je běžný vzor Supabase (izolace od public).

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- Bod WGS 84 (EPSG:4326); NULL dokud aplikace nezačne souřadnice plnit.
ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS geo_location extensions.geometry(Point, 4326);

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS geo_location extensions.geometry(Point, 4326);

COMMENT ON COLUMN public.apartments.geo_location IS
  'Poloha bytu (WGS 84). Prostorové indexy GIST pro geofiltry.';

COMMENT ON COLUMN public.tasks.geo_location IS
  'Poloha úkolu / místa výkonu (WGS 84). Volitelné; GIST pro geovýběr.';

CREATE INDEX IF NOT EXISTS idx_apartments_geo
  ON public.apartments
  USING GIST (geo_location);

CREATE INDEX IF NOT EXISTS idx_tasks_geo
  ON public.tasks
  USING GIST (geo_location);
