-- =============================================================================
-- FalcoNest – Push Notifikace – Fáze 1 (Infrastruktura a Tokeny)
-- =============================================================================
-- Příprava databáze pro FCM (Firebase Cloud Messaging): ukládání FCM tokenů
-- zařízení a nastavení preferencí notifikací uživatelů.
-- Fáze 1: pouze DB schéma – bez firebase_messaging v aplikaci.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka user_devices (FCM tokeny zařízení)
-- -----------------------------------------------------------------------------
-- Každé zařízení (telefon, tablet, web) má unikátní FCM token.
-- Uživatel může mít více zařízení; last_active_at pro čištění neaktivních tokenů.
CREATE TABLE public.user_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  device_type text NOT NULL CHECK (device_type IN ('ios', 'android', 'web')),
  last_active_at timestamptz DEFAULT now(),
  UNIQUE (fcm_token)
);

COMMENT ON TABLE public.user_devices IS 'FCM tokeny zařízení – každý řádek = jedno zařízení uživatele s platným tokenem.';
COMMENT ON COLUMN public.user_devices.fcm_token IS 'Unikátní FCM token z Firebase SDK – používá se pro doručení push notifikací.';
COMMENT ON COLUMN public.user_devices.device_type IS 'Typ platformy: ios, android, web. Pro targeting a cleanup.';
COMMENT ON COLUMN public.user_devices.last_active_at IS 'Poslední aktivita – při každém refresh tokenu se aktualizuje. Pro čištění starých tokenů.';

CREATE INDEX idx_user_devices_profile ON public.user_devices(profile_id);
CREATE INDEX idx_user_devices_tenant ON public.user_devices(tenant_id);
CREATE INDEX idx_user_devices_last_active ON public.user_devices(last_active_at);

-- -----------------------------------------------------------------------------
-- 2. Tabulka notification_preferences (Preference notifikací na uživatele)
-- -----------------------------------------------------------------------------
-- Jeden řádek na profil (profile_id = PK). Default true = všechny typy povoleny.
CREATE TABLE public.notification_preferences (
  profile_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  daily_summary_enabled boolean NOT NULL DEFAULT true,
  upcoming_task_enabled boolean NOT NULL DEFAULT true,
  new_task_assigned_enabled boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE public.notification_preferences IS 'Preference notifikací – ranní souhrny, upozornění před úkolem, nový úkol přiřazen.';
COMMENT ON COLUMN public.notification_preferences.daily_summary_enabled IS 'Ranní souhrn úkolů na den.';
COMMENT ON COLUMN public.notification_preferences.upcoming_task_enabled IS 'Upozornění před plánovaným úkolem.';
COMMENT ON COLUMN public.notification_preferences.new_task_assigned_enabled IS 'Notifikace při přiřazení nového úkolu.';

CREATE INDEX idx_notification_preferences_tenant ON public.notification_preferences(tenant_id);

-- -----------------------------------------------------------------------------
-- 3. Row Level Security – user_devices
-- -----------------------------------------------------------------------------
-- Uživatel čte/zapisuje pouze své tokeny (profile_id = vlastní profil).
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_devices_select"
  ON public.user_devices FOR SELECT
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "user_devices_insert"
  ON public.user_devices FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
        AND tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1))
  );

CREATE POLICY "user_devices_update"
  ON public.user_devices FOR UPDATE
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "user_devices_delete"
  ON public.user_devices FOR DELETE
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- -----------------------------------------------------------------------------
-- 4. Row Level Security – notification_preferences
-- -----------------------------------------------------------------------------
-- Uživatel čte/zapisuje pouze své preference.
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notification_preferences_select"
  ON public.notification_preferences FOR SELECT
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "notification_preferences_insert"
  ON public.notification_preferences FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
        AND tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1))
  );

CREATE POLICY "notification_preferences_update"
  ON public.notification_preferences FOR UPDATE
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );
