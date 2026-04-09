-- =============================================================================
-- FalcoNest – Údržba DB: mazání starých logů a dávkové čištění soft-delete (pg_cron)
-- =============================================================================
-- PROČ: Zabránit nekonečnému růstu tabulek (tenant_message_log, audit_logs) a
-- po roce odstranit měkké mazání u úkolů a rezervací fyzickým DELETE.
-- Časové okno: neděle 03:00 UTC (pg_cron standardně UTC).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Funkce: maintenance_data_cleanup
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.maintenance_data_cleanup()
RETURNS TABLE (
  deleted_message_log bigint,
  deleted_audit bigint,
  deleted_tasks bigint,
  deleted_reservations bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ml bigint := 0;
  v_al bigint := 0;
  v_t bigint := 0;
  v_r bigint := 0;
BEGIN
  -- 1) Log zpráv starší než 6 měsíců
  DELETE FROM public.tenant_message_log
  WHERE created_at < (now() AT TIME ZONE 'utc') - interval '6 months';
  GET DIAGNOSTICS v_ml = ROW_COUNT;

  -- 2) Auditní záznamy starší než 6 měsíců
  DELETE FROM public.audit_logs
  WHERE created_at < (now() AT TIME ZONE 'utc') - interval '6 months';
  GET DIAGNOSTICS v_al = ROW_COUNT;

  -- 3a) Nejprve staré soft-smazané úkoly (FK na rezervace zůstane konzistentní)
  DELETE FROM public.tasks
  WHERE deleted_at IS NOT NULL
    AND deleted_at < (now() AT TIME ZONE 'utc') - interval '1 year';
  GET DIAGNOSTICS v_t = ROW_COUNT;

  -- 3b) Poté staré soft-smazané rezervace (ON DELETE CASCADE smaže navázané řádky)
  DELETE FROM public.reservations
  WHERE deleted_at IS NOT NULL
    AND deleted_at < (now() AT TIME ZONE 'utc') - interval '1 year';
  GET DIAGNOSTICS v_r = ROW_COUNT;

  RETURN QUERY SELECT v_ml, v_al, v_t, v_r;
END;
$$;

COMMENT ON FUNCTION public.maintenance_data_cleanup() IS
  'Týdenní údržba: mazání starých logů (6 měs.) a soft-delete záznamů starších 1 roku (tasks, reservations).';

REVOKE ALL ON FUNCTION public.maintenance_data_cleanup() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.maintenance_data_cleanup() TO postgres;

-- -----------------------------------------------------------------------------
-- pg_cron: neděle 03:00 UTC
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'maintenance-data-cleanup-weekly') THEN
    PERFORM cron.unschedule('maintenance-data-cleanup-weekly');
  END IF;
  PERFORM cron.schedule(
    'maintenance-data-cleanup-weekly',
    '0 3 * * 0',
    'SELECT * FROM public.maintenance_data_cleanup();'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – job maintenance-data-cleanup-weekly nezaregistrován (Integrations → Cron).';
  WHEN OTHERS THEN
    RAISE NOTICE 'maintenance-data-cleanup cron: %', SQLERRM;
END $$;
