-- =============================================================================
-- FalcoNest – Majitelský portál: uložená veřejná iCal URL + RPC pro čtení
-- -----------------------------------------------------------------------------
-- PROČ: V tabulce zůstává jen hash tajného tokenu; funkční odkaz pro mobil (export_token)
--       nelze z hashe rekonstruovat. Při vytvoření tokenu v adminu uložíme kopii URL
--       do owner_visible_calendar_url (jen pro zobrazení majiteli). Majitel čte hodnotu
--       přes SECURITY DEFINER RPC – nevidí token_hash ani jiné řádky jiných bytů.
-- ADDITIVE: nový sloupec + nová funkce + nová RLS politika SELECT pro property_owner.
-- =============================================================================

ALTER TABLE public.tenant_calendar_feed_tokens
  ADD COLUMN IF NOT EXISTS owner_visible_calendar_url text;

COMMENT ON COLUMN public.tenant_calendar_feed_tokens.owner_visible_calendar_url IS
  'Volitelná kopie veřejného ICS odkazu (s export_token) pro zobrazení majiteli bytu; plní se při generování tokenu v adminu.';

-- -----------------------------------------------------------------------------
-- RPC: majitel (property_owner) dostane jen text URL pro svůj byt (ne hash)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_owner_calendar_feed_url_for_apartment(p_apartment_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id uuid;
  v_tenant_id uuid;
  v_role text;
BEGIN
  SELECT id, tenant_id, role
  INTO v_profile_id, v_tenant_id, v_role
  FROM public.profiles
  WHERE auth_id = auth.uid()
  LIMIT 1;

  IF v_profile_id IS NULL OR v_role IS DISTINCT FROM 'property_owner' THEN
    RETURN NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.apartment_owners ao
    WHERE ao.owner_id = v_profile_id
      AND ao.apartment_id = p_apartment_id
      AND ao.deleted_at IS NULL
  ) THEN
    RETURN NULL;
  END IF;

  RETURN (
    SELECT t.owner_visible_calendar_url
    FROM public.tenant_calendar_feed_tokens t
    WHERE t.tenant_id = v_tenant_id
      AND t.apartment_id = p_apartment_id
      AND t.revoked_at IS NULL
      AND t.owner_visible_calendar_url IS NOT NULL
      AND TRIM(t.owner_visible_calendar_url) <> ''
    ORDER BY t.created_at DESC
    LIMIT 1
  );
END;
$$;

COMMENT ON FUNCTION public.get_owner_calendar_feed_url_for_apartment(uuid) IS
  'Vrátí uložený iCal odkaz pro majitele daného bytu (pouze pokud existuje aktivní token s vyplněnou URL).';

GRANT EXECUTE ON FUNCTION public.get_owner_calendar_feed_url_for_apartment(uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- RLS: majitel smí číst jen řádky tokenů vázaných na své byty (volitelné – pro budoucí UI)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS tenant_calendar_feed_tokens_select_property_owner ON public.tenant_calendar_feed_tokens;

CREATE POLICY tenant_calendar_feed_tokens_select_property_owner
  ON public.tenant_calendar_feed_tokens
  FOR SELECT
  USING (
    tenant_id = public.my_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.auth_id = auth.uid()
        AND p.role = 'property_owner'
    )
    AND apartment_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.apartment_owners ao
      INNER JOIN public.profiles p ON p.id = ao.owner_id
      WHERE p.auth_id = auth.uid()
        AND ao.apartment_id = tenant_calendar_feed_tokens.apartment_id
        AND ao.deleted_at IS NULL
    )
  );

COMMENT ON POLICY tenant_calendar_feed_tokens_select_property_owner ON public.tenant_calendar_feed_tokens IS
  'SELECT: property_owner vidí tokenové řádky jen pro apartmány z apartment_owners (např. doplnění admin UI).';
