-- =============================================================================
-- FalcoNest – časové pásmo agentury (IANA) pro šablony a automatizace
-- =============================================================================

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'Europe/Madrid';

COMMENT ON COLUMN public.tenants.timezone IS
  'IANA časová zóna agentury (např. Europe/Prague). Šablony zpráv a Edge enqueue ji použijí pro datum/čas; výchozí Europe/Madrid.';

-- Bezpečný zápis jen timezone (admin/manager vlastního tenanta; super_admin s explicitním tenant_id).
CREATE OR REPLACE FUNCTION public.set_tenant_timezone(p_timezone text, p_tenant_id uuid DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tz text;
  v_tid uuid;
  v_role text;
BEGIN
  v_tz := COALESCE(NULLIF(trim(p_timezone), ''), 'Europe/Madrid');

  IF public.is_super_admin() AND p_tenant_id IS NOT NULL THEN
    UPDATE public.tenants
    SET timezone = v_tz
    WHERE id = p_tenant_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'tenant not found';
    END IF;
    RETURN;
  END IF;

  SELECT p.tenant_id, p.role INTO v_tid, v_role
  FROM public.profiles p
  WHERE p.auth_id = auth.uid()
  LIMIT 1;

  IF v_tid IS NULL THEN
    RAISE EXCEPTION 'no tenant';
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('admin', 'manager') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_tenant_id IS NOT NULL AND p_tenant_id <> v_tid THEN
    RAISE EXCEPTION 'tenant mismatch';
  END IF;

  UPDATE public.tenants
  SET timezone = v_tz
  WHERE id = v_tid;
END;
$$;

REVOKE ALL ON FUNCTION public.set_tenant_timezone(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_tenant_timezone(text, uuid) TO authenticated;
