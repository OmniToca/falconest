-- =============================================================================
-- FalcoNest – Read-only ICS export: tokeny tenanta + SECURITY DEFINER čtecí funkce
-- =============================================================================
-- PROČ: Home Assistant a podobné systémy potřebují HTTP GET bez přihlášení uživatele.
-- Tajný token se ověří v DB; funkce běží jako DEFINER a vrátí jen úkoly daného tenanta,
-- aniž by se obcházela RLS tabulky tasks přes anon klíč v klientovi.
-- ADDITIVE: nová tabulka + nová funkce, žádné mazání existujících objektů.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Tabulka tenant_calendar_feed_tokens
-- -----------------------------------------------------------------------------
-- PROČ: V DB držíme jen hash tokenu (Edge/backend uloží hash po zobrazení surového
-- tokenu adminovi jednou). tenant_id váže záznam nepřehlédnutelně k jedné agentuře.

CREATE TABLE IF NOT EXISTS public.tenant_calendar_feed_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  token_hash text NOT NULL,
  label text,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

COMMENT ON TABLE public.tenant_calendar_feed_tokens IS
  'Tajné čtecí tokeny pro export kalendáře (např. ICS) mimo standardní přihlášení; v DB jen hash.';

COMMENT ON COLUMN public.tenant_calendar_feed_tokens.token_hash IS
  'Hash surového tokenu (např. SHA-256); surový token se do DB neukládá.';

COMMENT ON COLUMN public.tenant_calendar_feed_tokens.revoked_at IS
  'NULL = aktivní feed; NOT NULL = odkaz okamžitě neplatný (soft revoke).';

COMMENT ON COLUMN public.tenant_calendar_feed_tokens.label IS
  'Lidský popis (např. Home Assistant – kancelář).';

-- PROČ: Rychlé ověření tokenu při každém volání get_calendar_feed_data + jednoznačnost hashe.
CREATE UNIQUE INDEX IF NOT EXISTS idx_tenant_calendar_feed_tokens_token_hash
  ON public.tenant_calendar_feed_tokens (token_hash);

-- PROČ: Admin UI – seznam tokenů daného tenanta bez full scan.
CREATE INDEX IF NOT EXISTS idx_tenant_calendar_feed_tokens_tenant_id
  ON public.tenant_calendar_feed_tokens (tenant_id);

-- -----------------------------------------------------------------------------
-- 2) RLS – tokeny vidí a spravují jen admin/manager svého tenanta (+ Super Admin)
-- -----------------------------------------------------------------------------
-- PROČ: Stejný vzor jako u task_checklists; worker ani owner nesmí číst hash jiného kanálu.

ALTER TABLE public.tenant_calendar_feed_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_calendar_feed_tokens_select ON public.tenant_calendar_feed_tokens;
CREATE POLICY tenant_calendar_feed_tokens_select
  ON public.tenant_calendar_feed_tokens
  FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

DROP POLICY IF EXISTS tenant_calendar_feed_tokens_insert ON public.tenant_calendar_feed_tokens;
CREATE POLICY tenant_calendar_feed_tokens_insert
  ON public.tenant_calendar_feed_tokens
  FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

DROP POLICY IF EXISTS tenant_calendar_feed_tokens_update ON public.tenant_calendar_feed_tokens;
CREATE POLICY tenant_calendar_feed_tokens_update
  ON public.tenant_calendar_feed_tokens
  FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

-- PROČ: Tvrdé DELETE nepožadujeme – zneplatnění přes revoked_at. Politiku DELETE záměrně nepřidáváme.

-- -----------------------------------------------------------------------------
-- 3) Oprávnění k tabulce (RLS dál filtruje řádky pro authenticated)
-- -----------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE ON public.tenant_calendar_feed_tokens TO authenticated;

-- -----------------------------------------------------------------------------
-- 4) Funkce get_calendar_feed_data – čtení úkolů podle platného hashe tokenu
-- -----------------------------------------------------------------------------
-- PROČ SECURITY DEFINER: Volající je backend (service_role); funkce ověří hash, vezme tenant_id
-- z naší tabulky a teprve pak čte tasks. Žádný tenant_id z URL – nemůže dojít k přeskoku mezi tenanty.
-- Neplatný/revokovaný token => žádné řádky (bez výjimky – jednoduché volání z Edge).

CREATE OR REPLACE FUNCTION public.get_calendar_feed_data(p_token_hash text)
RETURNS TABLE (
  id uuid,
  title text,
  scheduled_start timestamp with time zone,
  due_date text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  -- PROČ: Prázdný vstup nikdy nespojíme s platným tokenem – okamžitě končíme bez dat.
  IF p_token_hash IS NULL OR btrim(p_token_hash) = '' THEN
    RETURN;
  END IF;

  -- PROČ: Jediný zdroj tenant_id pro následný SELECT; revoked_at IS NULL je nutná podmínka platnosti.
  SELECT t.tenant_id
  INTO v_tenant_id
  FROM public.tenant_calendar_feed_tokens AS t
  WHERE t.token_hash = btrim(p_token_hash)
    AND t.revoked_at IS NULL
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RETURN;
  END IF;

  -- PROČ: Kalendář v appce skrývá smazané a vyfakturované (archiv) – stejná sémantika i pro export.
  RETURN QUERY
  SELECT
    tk.id,
    tk.title,
    tk.scheduled_start,
    tk.due_date
  FROM public.tasks AS tk
  WHERE tk.tenant_id = v_tenant_id
    AND tk.deleted_at IS NULL
    AND tk.invoiced_at IS NULL;

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.get_calendar_feed_data(text) IS
  'Vrátí úkoly tenanta pro ICS export podle platného token_hash; DEFINER; neplatný token => 0 řádků.';

-- PROČ: Mitigace search_path útoků; konzistence s migrací fix_security_advisor.
ALTER FUNCTION public.get_calendar_feed_data(text) SET search_path = public;

-- PROČ: Veřejný internet tento endpoint nevolá přímo – jen Edge se service key. Anon tedy nemá EXECUTE.
REVOKE ALL ON FUNCTION public.get_calendar_feed_data(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_calendar_feed_data(text) TO service_role;
