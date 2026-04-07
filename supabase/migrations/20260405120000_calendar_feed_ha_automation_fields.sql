-- =============================================================================
-- FalcoNest – iCal export: pole pro Home Assistant automatizace (ceny, typ úkolu)
-- =============================================================================
-- PROČ: Zákazník potřebuje v DESCRIPTION strukturované klíče (Type, AgencyPrice,
-- TransitPrice) parsované v HA; data bereme z tasks.metadata a typ z tenant_services
-- / tasks.task_type / title. JOIN na tenant_services je nutný pro service_type a název.
-- PostgreSQL nepovolí změnit RETURNS TABLE u existující funkce přes CREATE OR REPLACE
-- (chyba 42P13) – proto nejprve DROP FUNCTION se stejnou signaturou, pak CREATE.
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_calendar_feed_data(text);

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
  geo_longitude double precision,
  feed_task_type text,
  feed_agency_price numeric,
  feed_transit_price numeric
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
    END)::double precision AS geo_longitude,
    -- Typ pro HA: kód služby z katalogu, jinak task_type, jinak zjednodušený title, jinak other
    COALESCE(
      NULLIF(trim(ts.service_type), ''),
      NULLIF(trim(tk.task_type), ''),
      NULLIF(
        left(
          regexp_replace(trim(COALESCE(tk.title, '')), '[\r\n]+', ' ', 'g'),
          200
        ),
        ''
      ),
      'other'
    ) AS feed_task_type,
    -- Částky z metadata JSONB – bezpečný cast jen pro jednoduché desetinné zápisy (jako v aplikaci)
    (
      CASE
        WHEN (tk.metadata->>'amount_to_collect') ~ '^-?[0-9]+(\.[0-9]+)?$'
        THEN (tk.metadata->>'amount_to_collect')::numeric
        ELSE NULL
      END
    ) AS feed_agency_price,
    (
      CASE
        WHEN (tk.metadata->>'transit_amount_to_collect') ~ '^-?[0-9]+(\.[0-9]+)?$'
        THEN (tk.metadata->>'transit_amount_to_collect')::numeric
        ELSE NULL
      END
    ) AS feed_transit_price
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
  LEFT JOIN public.tenant_services AS ts
    ON ts.id = tk.service_id
    AND ts.tenant_id = tk.tenant_id
    AND ts.deleted_at IS NULL
  WHERE tk.tenant_id = v_tenant_id
    AND tk.deleted_at IS NULL
    AND tk.invoiced_at IS NULL
    AND (v_apartment_id IS NULL OR tk.apartment_id = v_apartment_id);

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.get_calendar_feed_data(text) IS
  'ICS export: úkoly tenanta + GEO + feed_task_type + ceny z metadata (amount_to_collect, transit_amount_to_collect) pro HA.';

ALTER FUNCTION public.get_calendar_feed_data(text) SET search_path = public;

REVOKE ALL ON FUNCTION public.get_calendar_feed_data(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_calendar_feed_data(text) TO service_role;
