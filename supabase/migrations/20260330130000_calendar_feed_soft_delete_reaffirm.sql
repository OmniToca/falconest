-- =============================================================================
-- FalcoNest – ICS feed: explicitní vyloučení soft-smazaných úkolů (re-affirm)
-- =============================================================================
-- PROČ: Běží až PO 20260330120000 (get_calendar_feed_data). CEO hlásil smazané úkoly
-- ve feedu – původní migrace už měla tk.deleted_at IS NULL; tato migrace znovu nasadí
-- funkci se stejnou logikou a rozšíří COMMENT pro audit / nasazení, kde starší verze
-- chyběla. ADDITIVE: pouze CREATE OR REPLACE funkce.
-- =============================================================================

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

  -- PROČ: Soft delete – řádek se smazaným úkolem nesmí opustit DB do ICS (stejně jako UI).
  -- invoiced_at: archivované úkoly také neexportujeme.
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
  'ICS export: úkoly tenanta podle token_hash; vyloučí soft-smazané (deleted_at IS NULL) a archiv (invoiced_at IS NULL).';

ALTER FUNCTION public.get_calendar_feed_data(text) SET search_path = public;
