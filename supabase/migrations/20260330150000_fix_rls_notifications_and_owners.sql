-- =============================================================================
-- FalcoNest – RLS pro notifications + explicitní ENABLE pro apartment_owners
-- =============================================================================
-- PROČ: Tabulka notifications měla v repozitáři chybějící ENABLE ROW LEVEL SECURITY
-- a politiky – riziko úniku dat mezi tenanty při přímém SELECT z klienta.
-- apartment_owners mělo politiky, ale explicitní ENABLE v migrační historii chybělo;
-- tento příkaz zajistí aktivaci RLS bez mazání stávajících politik.
--
-- Poznámka k rekurzi: Politiky používají poddotazy na profiles přes auth_id = auth.uid().
-- Funkce public.is_super_admin() čte pouze app_super_admins (viz migrace 20250220) –
-- nečte profiles, takže nedochází k cyklení profiles ↔ notifications.
-- Trigger notify_admins_on_owner_issue() je SECURITY DEFINER a INSERT obchází RLS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. NOTIFICATIONS – Row Level Security
-- -----------------------------------------------------------------------------

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Odstranění případných starších politik se stejnými jmény (idempotentní re-deploy).
DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;

-- SELECT: Super Admin vidí vše. Jinak jen vlastní řádky (profile_id + tenant_id odpovídá profilu).
CREATE POLICY "notifications_select"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      tenant_id = (
        SELECT p.tenant_id
        FROM public.profiles p
        WHERE p.auth_id = auth.uid()
          AND p.deleted_at IS NULL
        LIMIT 1
      )
      AND profile_id = (
        SELECT p2.id
        FROM public.profiles p2
        WHERE p2.auth_id = auth.uid()
          AND p2.deleted_at IS NULL
        LIMIT 1
      )
    )
  );

-- INSERT: Super Admin bez omezení. Jinak tenant_id = můj tenant, příjemce musí být profil
-- ve stejném tenantovi a platí jedna z podmínek:
-- (a) notifikace pro mě samého,
-- (b) jsem admin/manažer (mohu adresovat kohokoli v agentuře),
-- (c) jsem jiná role (např. worker) a příjemce je admin/manažer – stejný scénář jako
--     AbsenceNotificationService a CashWalletRepository (zvoneček pro dispečink).
CREATE POLICY "notifications_insert"
  ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id IS NOT NULL
      AND tenant_id = (
        SELECT me.tenant_id
        FROM public.profiles me
        WHERE me.auth_id = auth.uid()
          AND me.deleted_at IS NULL
        LIMIT 1
      )
      AND EXISTS (
        SELECT 1
        FROM public.profiles recv
        WHERE recv.id = profile_id
          AND recv.tenant_id = tenant_id
          AND recv.deleted_at IS NULL
      )
      AND (
        profile_id = (
          SELECT me2.id
          FROM public.profiles me2
          WHERE me2.auth_id = auth.uid()
            AND me2.deleted_at IS NULL
          LIMIT 1
        )
        OR EXISTS (
          SELECT 1
          FROM public.profiles me3
          WHERE me3.auth_id = auth.uid()
            AND me3.deleted_at IS NULL
            AND me3.role IN ('admin', 'manager')
            AND me3.tenant_id = tenant_id
        )
        OR EXISTS (
          SELECT 1
          FROM public.profiles recv_am
          WHERE recv_am.id = profile_id
            AND recv_am.tenant_id = tenant_id
            AND recv_am.deleted_at IS NULL
            AND recv_am.role IN ('admin', 'manager')
        )
      )
    )
  );

-- UPDATE: Označení přečtení – pouze vlastní řádky (stejný tenant + profile_id) nebo Super Admin.
CREATE POLICY "notifications_update"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      tenant_id = (
        SELECT p.tenant_id
        FROM public.profiles p
        WHERE p.auth_id = auth.uid()
          AND p.deleted_at IS NULL
        LIMIT 1
      )
      AND profile_id = (
        SELECT p2.id
        FROM public.profiles p2
        WHERE p2.auth_id = auth.uid()
          AND p2.deleted_at IS NULL
        LIMIT 1
      )
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = (
        SELECT p.tenant_id
        FROM public.profiles p
        WHERE p.auth_id = auth.uid()
          AND p.deleted_at IS NULL
        LIMIT 1
      )
      AND profile_id = (
        SELECT p2.id
        FROM public.profiles p2
        WHERE p2.auth_id = auth.uid()
          AND p2.deleted_at IS NULL
        LIMIT 1
      )
    )
  );

-- DELETE: Vlastní notifikace nebo Super Admin (aplikace DELETE typicky nepoužívá).
CREATE POLICY "notifications_delete"
  ON public.notifications
  FOR DELETE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      tenant_id = (
        SELECT p.tenant_id
        FROM public.profiles p
        WHERE p.auth_id = auth.uid()
          AND p.deleted_at IS NULL
        LIMIT 1
      )
      AND profile_id = (
        SELECT p2.id
        FROM public.profiles p2
        WHERE p2.auth_id = auth.uid()
          AND p2.deleted_at IS NULL
        LIMIT 1
      )
    )
  );

COMMENT ON POLICY "notifications_select" ON public.notifications IS
  'SELECT: super_admin všechen obsah; authenticated jen řádky kde tenant_id a profile_id odpovídají přihlášenému uživateli (profiles.auth_id).';

COMMENT ON POLICY "notifications_insert" ON public.notifications IS
  'INSERT: super_admin; authenticated v rámci svého tenantu pro platného příjemce – včetně worker→admin zvoněčku.';

COMMENT ON POLICY "notifications_update" ON public.notifications IS
  'UPDATE: super_admin; authenticated pouze vlastní řádky (např. is_read).';

COMMENT ON POLICY "notifications_delete" ON public.notifications IS
  'DELETE: super_admin; authenticated pouze vlastní řádky.';

-- -----------------------------------------------------------------------------
-- 2. APARTMENT_OWNERS – explicitní zapnutí RLS (politiky z dřívějších migrací)
-- -----------------------------------------------------------------------------

ALTER TABLE public.apartment_owners ENABLE ROW LEVEL SECURITY;
