-- =============================================================================
-- FalcoNest – PostGIS / GIST: VACUUM ANALYZE pro mapové tabulky (pg_cron)
-- =============================================================================
-- PROČ: Geometrické a GIN indexy potřebují pravidelný VACUUM ANALYZE kvůli statistikám
-- plánovače a výkonu mapy.
--
-- OMEZENÍ POSTGRESQL: Příkaz VACUUM nelze spustit uvnitř PL/pgSQL funkce ani procedury,
-- protože běží v transakčním bloku. Požadovanou logiku „maintenance_vacuum_geo“ proto
-- realizují tři samostatné cron joby (jeden příkaz = jedno spojení bez vnořené transakce
-- kolem VACUUM). Časy jsou v neděli těsně po sobě (04:00–04:02 UTC).
-- =============================================================================

-- Volitelná prázdná „kotva“ pro dokumentaci a ruční kontrolu v katalogu (nepoužívá VACUUM).
CREATE OR REPLACE FUNCTION public.maintenance_vacuum_geo()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN
    'Skutečné VACUUM ANALYZE běží přes pg_cron joby maintenance-vacuum-geo-{apartments,tasks,clients} '
    || '(neděle ~04:00 UTC). PostgreSQL neumožňuje VACUUM uvnitř uložené procedury.';
END;
$$;

COMMENT ON FUNCTION public.maintenance_vacuum_geo() IS
  'Dokumentační kotva: VACUUM ANALYZE pro apartments/tasks/clients je v cron jobech (viz migrace).';

REVOKE ALL ON FUNCTION public.maintenance_vacuum_geo() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.maintenance_vacuum_geo() TO postgres;

-- -----------------------------------------------------------------------------
-- Tři joby – každý jeden příkaz VACUUM ANALYZE
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'maintenance-vacuum-geo-apartments') THEN
    PERFORM cron.unschedule('maintenance-vacuum-geo-apartments');
  END IF;
  PERFORM cron.schedule(
    'maintenance-vacuum-geo-apartments',
    '0 4 * * 0',
    'VACUUM ANALYZE public.apartments'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – maintenance-vacuum-geo-apartments nezaregistrován.';
  WHEN OTHERS THEN
    RAISE NOTICE 'maintenance-vacuum-geo-apartments: %', SQLERRM;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'maintenance-vacuum-geo-tasks') THEN
    PERFORM cron.unschedule('maintenance-vacuum-geo-tasks');
  END IF;
  PERFORM cron.schedule(
    'maintenance-vacuum-geo-tasks',
    '1 4 * * 0',
    'VACUUM ANALYZE public.tasks'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – maintenance-vacuum-geo-tasks nezaregistrován.';
  WHEN OTHERS THEN
    RAISE NOTICE 'maintenance-vacuum-geo-tasks: %', SQLERRM;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'maintenance-vacuum-geo-clients') THEN
    PERFORM cron.unschedule('maintenance-vacuum-geo-clients');
  END IF;
  PERFORM cron.schedule(
    'maintenance-vacuum-geo-clients',
    '2 4 * * 0',
    'VACUUM ANALYZE public.clients'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – maintenance-vacuum-geo-clients nezaregistrován.';
  WHEN OTHERS THEN
    RAISE NOTICE 'maintenance-vacuum-geo-clients: %', SQLERRM;
END $$;
