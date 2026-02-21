-- =============================================================================
-- FalcoNest – odstranění rekurze v RLS (is_super_admin bez čtení z profiles)
-- =============================================================================
-- Chyba: "infinite recursion detected in policy for relation profiles"
-- Příčina: is_super_admin() četl z tabulky profiles, zatímco RLS na profiles
-- volá is_super_admin() → zacyklení (i při SECURITY DEFINER to Postgres detekuje).
--
-- Řešení: Funkce is_super_admin() nesmí číst z profiles. Zavedeme tabulku
-- app_super_admins (pouze id uživatelů s rolí super_admin). Funkce čte jen z ní.
-- Synchronizace: trigger na profiles při změně role.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka app_super_admins – pouze ID uživatelů, kteří jsou super_admin
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_super_admins (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
);

COMMENT ON TABLE public.app_super_admins IS 'Seznam uživatelů s rolí super_admin. Slouží pro RLS funkci is_super_admin() bez čtení z profiles (zamezení rekurze).';

-- Naplnění PŘED zapnutím RLS (migrace běží s oprávněními, které mohou číst profiles).
INSERT INTO public.app_super_admins (id)
SELECT id FROM public.profiles WHERE role = 'super_admin'
ON CONFLICT (id) DO NOTHING;

-- Nová definice is_super_admin() HNED – čte jen app_super_admins (ne profiles).
-- Musí být před policy, které ji volají.
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.app_super_admins WHERE id = auth.uid());
$$;

COMMENT ON FUNCTION public.is_super_admin() IS 'Vrací true, pokud je aktuální uživatel v app_super_admins. Nepoužívá profiles → žádná rekurze v RLS.';

-- RLS: uživatel smí číst/vkládat/mazat jen řádek se svým id (trigger sync to potřebuje).
ALTER TABLE public.app_super_admins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_super_admins_select_own"
  ON public.app_super_admins FOR SELECT
  USING (id = auth.uid());

-- Trigger sync běží v kontextu toho, kdo mění profiles (i jiný uživatel – např. super_admin).
CREATE POLICY "app_super_admins_insert_own_or_super"
  ON public.app_super_admins FOR INSERT
  WITH CHECK (id = auth.uid() OR public.is_super_admin());

CREATE POLICY "app_super_admins_delete_own_or_super"
  ON public.app_super_admins FOR DELETE
  USING (id = auth.uid() OR public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 3. Trigger: při změně role v profiles držet app_super_admins v syncu
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_app_super_admins()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.role = 'super_admin' THEN
    INSERT INTO public.app_super_admins (id) VALUES (NEW.id)
    ON CONFLICT (id) DO NOTHING;
  ELSIF (TG_OP = 'UPDATE' AND OLD.role = 'super_admin' AND (NEW.role IS NULL OR NEW.role <> 'super_admin')) THEN
    DELETE FROM public.app_super_admins WHERE id = OLD.id;
  ELSIF TG_OP = 'DELETE' AND OLD.role = 'super_admin' THEN
    DELETE FROM public.app_super_admins WHERE id = OLD.id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS sync_app_super_admins_trigger ON public.profiles;
CREATE TRIGGER sync_app_super_admins_trigger
  AFTER INSERT OR UPDATE OF role OR DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_app_super_admins();
