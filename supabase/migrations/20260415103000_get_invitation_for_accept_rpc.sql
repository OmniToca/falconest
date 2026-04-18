-- =============================================================================
-- FalcoNest – Načtení pozvánky podle tokenu pro nepřihlášené uživatele (/invite)
-- =============================================================================
-- PROČ: RLS na invitations (migrace 20260319100000) povoluje SELECT jen
-- super_admin nebo řádky s tenant_id = my_tenant_id(). Anon nemá tenant,
-- proto přímý PostgREST dotaz z InviteRepository vrací 0 řádků → UI hlásí
-- „Neplatná pozvánka“. Stejně tak přihlášený uživatel jiného tenanta token nevidí.
--
-- Řešení: RPC SECURITY DEFINER vrátí nejvýše JEDEN řádek, pokud token (UUID)
-- odpovídá invitations.id nebo invitations.profile_id. Žádný full-table scan pro
-- anon – bez známého UUID nelze nic vyčíst.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_invitation_for_accept(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token uuid;
  v_row jsonb;
BEGIN
  IF p_token IS NULL OR length(trim(p_token)) = 0 THEN
    RETURN NULL;
  END IF;

  BEGIN
    v_token := trim(p_token)::uuid;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  SELECT to_jsonb(i.*)
    INTO v_row
    FROM public.invitations i
   WHERE i.id = v_token
      OR i.profile_id = v_token
   LIMIT 1;

  RETURN v_row;
END;
$$;

COMMENT ON FUNCTION public.get_invitation_for_accept(text) IS
  'Vrací jeden záznam invitations jako JSON podle UUID tokenu (id nebo profile_id). Pro obrazovku /invite a anon klienta; RLS tabulky jinak SELECT blokuje.';

REVOKE ALL ON FUNCTION public.get_invitation_for_accept(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_invitation_for_accept(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
