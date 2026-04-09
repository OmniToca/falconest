-- =============================================================================
-- FalcoNest – ICS export: obohacení o adresu, hosta, byt, popis, pracovníka
-- =============================================================================
-- PROČ: Veřejný kalendářový feed slouží Smart Home (Home Assistant), navigaci (Tesla)
-- a další automatizace – potřebují LOCATION (fyzická adresa) a DESCRIPTION (kontext).
-- Interní poznámky rezervace (internal_note) záměrně neexportujeme – citlivé údaje.
-- ADDITIVE: rozšíření výstupu funkce – PostgreSQL neumožní OR REPLACE při změně
-- struktury RETURNS TABLE, proto DROP a znovu CREATE + obnovení GRANT.
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_calendar_feed_data(text);

CREATE FUNCTION public.get_calendar_feed_data(p_token_hash text)
RETURNS TABLE (
  id uuid,
  title text,
  scheduled_start timestamp with time zone,
  due_date text,
  location_text text,
  guest_name text,
  apartment_name text,
  task_description text,
  assignee_display_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  IF p_token_hash IS NULL OR btrim(p_token_hash) = '' THEN
    RETURN;
  END IF;

  SELECT t.tenant_id
  INTO v_tenant_id
  FROM public.tenant_calendar_feed_tokens AS t
  WHERE t.token_hash = btrim(p_token_hash)
    AND t.revoked_at IS NULL
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RETURN;
  END IF;

  -- PROČ: LEFT JOIN – údržba vozu / úkol bez bytu musí projít; NULL ve sloupcích doplní Edge.
  -- deleted_at u všech dimenzí vylučuje soft-smazané záznamy z JOIN výsledku.
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
    ) AS assignee_display_name
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
    AND tk.invoiced_at IS NULL;

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.get_calendar_feed_data(text) IS
  'ICS export: úkoly + location_text (adresa/custom_location), guest, byt, popis, přiřazený pracovník (assigned_to→profiles); bez internal_note.';

ALTER FUNCTION public.get_calendar_feed_data(text) SET search_path = public;

REVOKE ALL ON FUNCTION public.get_calendar_feed_data(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_calendar_feed_data(text) TO service_role;
