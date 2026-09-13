-- =============================================================================
-- Owner Portal View Sessions – audit převtělení dispečera do Klientského portálu
-- =============================================================================
-- PROČ: Admin/manager může z CRM prohlížet OwnerLayout „jako majitel“ (read-only MVP).
-- Každé spuštění a ukončení náhledu musí být auditováno: kdo, kterého majitele,
-- v jakém tenantu, kdy začalo a kdy skončilo. Tabulka je tenant-scoped (na rozdíl
-- od globální support_interventions pro HQ Magic Login).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.owner_portal_view_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Dispečer (admin/manager), který spustil náhled
  admin_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  -- Majitel (profiles.id), jehož portál se prohlíží
  viewed_owner_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  -- CRM kontext – řádek clients, ze kterého dispečer náhled spustil
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
  -- Agentura (tenant), ve které probíhá náhled
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

COMMENT ON TABLE public.owner_portal_view_sessions IS
  'Audit náhledu Klientského portálu dispečerem (admin/manager) – kdo prohlížel portál kterého majitele a kdy.';
COMMENT ON COLUMN public.owner_portal_view_sessions.admin_profile_id IS
  'Profil dispečera (admin/manager), který spustil režim „Zobrazit portál jako klient“.';
COMMENT ON COLUMN public.owner_portal_view_sessions.viewed_owner_profile_id IS
  'Profil majitele (property_owner), jehož data se v OwnerLayout zobrazují.';
COMMENT ON COLUMN public.owner_portal_view_sessions.client_id IS
  'CRM klient (clients.id), ze kterého dispečer náhled spustil – pro audit a návrat do detailu.';
COMMENT ON COLUMN public.owner_portal_view_sessions.tenant_id IS
  'Agentura (tenant), ve které probíhá náhled.';
COMMENT ON COLUMN public.owner_portal_view_sessions.started_at IS
  'Začátek náhledu portálu; ended_at NULL = session ještě probíhá (MVP: jen v paměti klienta).';
COMMENT ON COLUMN public.owner_portal_view_sessions.ended_at IS
  'Konec náhledu (tlačítko „Ukončit převtělení“ nebo ztráta session po F5).';

CREATE INDEX IF NOT EXISTS idx_owner_portal_view_sessions_admin_profile_id
  ON public.owner_portal_view_sessions(admin_profile_id);
CREATE INDEX IF NOT EXISTS idx_owner_portal_view_sessions_viewed_owner_profile_id
  ON public.owner_portal_view_sessions(viewed_owner_profile_id);
CREATE INDEX IF NOT EXISTS idx_owner_portal_view_sessions_tenant_id
  ON public.owner_portal_view_sessions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_owner_portal_view_sessions_client_id
  ON public.owner_portal_view_sessions(client_id);
CREATE INDEX IF NOT EXISTS idx_owner_portal_view_sessions_started_at
  ON public.owner_portal_view_sessions(started_at DESC);

ALTER TABLE public.owner_portal_view_sessions ENABLE ROW LEVEL SECURITY;

-- SELECT: super_admin vše; admin/manager jen záznamy svého tenanta.
DROP POLICY IF EXISTS "owner_portal_view_sessions_select" ON public.owner_portal_view_sessions;
CREATE POLICY "owner_portal_view_sessions_select"
  ON public.owner_portal_view_sessions
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      public.is_tenant_admin_or_manager()
      AND tenant_id = public.my_tenant_id()
    )
  );

-- INSERT: admin/manager tenanta; admin_profile_id musí být volající; majitel a klient patří do tenanta.
DROP POLICY IF EXISTS "owner_portal_view_sessions_insert" ON public.owner_portal_view_sessions;
CREATE POLICY "owner_portal_view_sessions_insert"
  ON public.owner_portal_view_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_tenant_admin_or_manager()
    AND tenant_id = public.my_tenant_id()
    AND admin_profile_id = (
      SELECT p.id FROM public.profiles p WHERE p.auth_id = auth.uid() LIMIT 1
    )
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = viewed_owner_profile_id
        AND p.tenant_id = owner_portal_view_sessions.tenant_id
        AND p.deleted_at IS NULL
    )
    AND EXISTS (
      SELECT 1
      FROM public.clients c
      WHERE c.id = client_id
        AND c.tenant_id = owner_portal_view_sessions.tenant_id
        AND c.deleted_at IS NULL
    )
  );

-- UPDATE: admin/manager může uzavřít jen vlastní session (admin_profile_id = volající).
DROP POLICY IF EXISTS "owner_portal_view_sessions_update" ON public.owner_portal_view_sessions;
CREATE POLICY "owner_portal_view_sessions_update"
  ON public.owner_portal_view_sessions
  FOR UPDATE
  TO authenticated
  USING (
    public.is_tenant_admin_or_manager()
    AND tenant_id = public.my_tenant_id()
    AND admin_profile_id = (
      SELECT p.id FROM public.profiles p WHERE p.auth_id = auth.uid() LIMIT 1
    )
  )
  WITH CHECK (
    public.is_tenant_admin_or_manager()
    AND tenant_id = public.my_tenant_id()
    AND admin_profile_id = (
      SELECT p.id FROM public.profiles p WHERE p.auth_id = auth.uid() LIMIT 1
    )
  );

-- DELETE: pouze super_admin (stejný princip jako support_interventions).
DROP POLICY IF EXISTS "owner_portal_view_sessions_delete" ON public.owner_portal_view_sessions;
CREATE POLICY "owner_portal_view_sessions_delete"
  ON public.owner_portal_view_sessions
  FOR DELETE
  TO authenticated
  USING (public.is_super_admin());
