-- =============================================================================
-- FalcoNest – RPC register_agency pro organickou registraci
-- =============================================================================
-- Volá se při registraci nového uživatele bez pozvánky (Varianta B).
-- Vytvoří tenanta a profil s auth_id=current_user (Ghost Profile Strategy).
-- SECURITY DEFINER – obchází RLS (uživatel nemá profil ani tenant před voláním).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.register_agency(
  p_agency_name text,
  p_manager_name text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
  v_user_id uuid;
  v_user_email text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Nejste přihlášeni';
  END IF;

  -- Získej email z auth.users (SECURITY DEFINER vidí auth schema)
  SELECT email INTO v_user_email FROM auth.users WHERE id = v_user_id;

  -- Vytvoř tenanta
  INSERT INTO public.tenants (name)
  VALUES (COALESCE(NULLIF(TRIM(p_agency_name), ''), 'Nová agentura'))
  RETURNING id INTO v_tenant_id;

  -- Vytvoř profil (auth_id místo id – Ghost Profile Strategy)
  INSERT INTO public.profiles (
    auth_id,
    tenant_id,
    email,
    first_name,
    last_name,
    name,
    status,
    role
  )
  VALUES (
    v_user_id,
    v_tenant_id,
    v_user_email,
    COALESCE(NULLIF(TRIM(p_manager_name), ''), 'Admin'),
    '',
    COALESCE(NULLIF(TRIM(p_manager_name), ''), 'Admin'),
    'active',
    'admin'
  );

  RETURN v_tenant_id;
END;
$$;

COMMENT ON FUNCTION public.register_agency(text, text) IS 'Organická registrace: vytvoří tenanta a profil s auth_id=current_user. Volá se z onboarding_screen.';
