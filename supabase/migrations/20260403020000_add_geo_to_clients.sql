-- Geolokace klientů (CRM) – stejný model jako u apartmánů a úkolů (WGS 84, SRID 4326).
-- PROČ: Externí klienti a agentury často potřebují bod na mapě pro transfery / navigaci bez vázání na konkrétní byt.

ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS geo_location extensions.geometry(Point, 4326);

CREATE INDEX IF NOT EXISTS idx_clients_geo ON public.clients USING GIST (geo_location);

COMMENT ON COLUMN public.clients.geo_location IS
  'Volitelný bod WGS 84 (EPSG:4326) – PostgREST vrací jako GeoJSON.';
