-- =============================================================================
-- Hotfix: get_calendar_feed_data + PostGIS ve schématu extensions
-- =============================================================================
-- PROČ: Na clusterech s PostGIS v `extensions` a `SET search_path = public` u RPC
-- nekvalifikované ST_X/ST_Y při běhu selžou → supabase.rpc chyba → Edge export_calendar 500.
-- Tato migrace je idempotentní (CREATE OR REPLACE) a doplní nasazení, kde starší varianta
-- 20260403140000 ještě používala ST_Y/ST_X bez prefixu.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_calendar_feed_data(p_token_hash text)
RETURNS TABLE (
  id uuid,
  title text,
  scheduled_start timestamp with time zone,
  due_date text,
  location_text text,
  guest_name text,
  apartment_name text,
  task_description text,
  assignee_display_name text,
  geo_latitude double precision,
  geo_longitude double precision
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
  v_apartment_id uuid;
BEGIN
  IF p_token_hash IS NULL OR btrim(p_token_hash) = '' THEN
    RETURN;
  END IF;

  SELECT t.tenant_id, t.apartment_id
  INTO v_tenant_id, v_apartment_id
  FROM public.tenant_calendar_feed_tokens AS t
  WHERE t.token_hash = btrim(p_token_hash)
    AND t.revoked_at IS NULL
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    tk.id,
    tk.title,
    tk.scheduled_start,
    tk.due_date,
    NULLIF(
      trim(
        COALESCE(
          NULLIF(trim(apt.address), ''),
          NULLIF(trim(tk.custom_location), '')
        )
      ),
      ''
    ) AS location_text,
    NULLIF(trim(res.guest_name), '') AS guest_name,
    NULLIF(trim(apt.name), '') AS apartment_name,
    NULLIF(trim(tk.description), '') AS task_description,
    NULLIF(
      trim(
        COALESCE(
          NULLIF(trim(p.name), ''),
          concat_ws(
            ' ',
            NULLIF(trim(p.first_name), ''),
            NULLIF(trim(p.last_name), '')
          )
        )
      ),
      ''
    ) AS assignee_display_name,
    (CASE
      WHEN tk.geo_location IS NOT NULL THEN extensions.ST_Y(tk.geo_location)
      WHEN apt.geo_location IS NOT NULL THEN extensions.ST_Y(apt.geo_location)
      ELSE NULL
    END)::double precision AS geo_latitude,
    (CASE
      WHEN tk.geo_location IS NOT NULL THEN extensions.ST_X(tk.geo_location)
      WHEN apt.geo_location IS NOT NULL THEN extensions.ST_X(apt.geo_location)
      ELSE NULL
    END)::double precision AS geo_longitude
  FROM public.tasks AS tk
  LEFT JOIN public.apartments AS apt
    ON apt.id = tk.apartment_id
    AND apt.deleted_at IS NULL
  LEFT JOIN public.reservations AS res
    ON res.id = tk.reservation_id
    AND res.deleted_at IS NULL
  LEFT JOIN public.profiles AS p
    ON p.id = tk.assigned_to
    AND p.deleted_at IS NULL
  WHERE tk.tenant_id = v_tenant_id
    AND tk.deleted_at IS NULL
    AND tk.invoiced_at IS NULL
    AND (v_apartment_id IS NULL OR tk.apartment_id = v_apartment_id);

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.get_calendar_feed_data(text) IS
  'ICS export: úkoly tenanta + volitelné WGS 84 (úkol nebo byt) pro GEO v .ics.';

ALTER FUNCTION public.get_calendar_feed_data(text) SET search_path = public;

REVOKE ALL ON FUNCTION public.get_calendar_feed_data(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_calendar_feed_data(text) TO service_role;
