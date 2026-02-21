-- FalcoNest – umožnění UPDATE last_sign_in_at pro přihlášené uživatele (Tenant Health).
-- RLS: uživatel smí aktualizovat pouze vlastní řádek. Grant: oprávnění na sloupec last_sign_in_at.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- UPDATE policy: uživatel může měnit vlastní profil (id = auth.uid()); super_admin může měnit libovolný.
DROP POLICY IF EXISTS "profiles_update_own_or_super" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id OR public.is_super_admin())
  WITH CHECK (auth.uid() = id OR public.is_super_admin());

-- Oprávnění pro roli authenticated (Supabase přihlášení) – update sloupce last_sign_in_at.
GRANT UPDATE (last_sign_in_at) ON public.profiles TO authenticated;

COMMENT ON COLUMN public.profiles.last_sign_in_at IS 'Poslední přihlášení – nastavuje aplikace po úspěšném sign-in. Pro Super Admin dashboard (Tenant Health).';
