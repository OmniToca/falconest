-- =============================================================================
-- Owner portal view – server-side read-only guard (aditivní)
-- =============================================================================
-- PROČ: Dispečer v režimu „Prohlížíte jako majitel“ má admin JWT → širší RLS než
-- skutečný property_owner. UI gate (OwnerReadOnlyGate) nestačí proti přímému
-- PostgREST. Aktivní řádek v owner_portal_view_sessions (ended_at IS NULL,
-- started_at < 8 h) blokuje mutace přes RESTRICTIVE RLS + assert RPC.
-- Orphan session po F5: TTL 8 h + close_my_open_owner_portal_view_sessions().
-- =============================================================================

CREATE OR REPLACE FUNCTION public.my_profile_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id
  FROM public.profiles p
  WHERE p.auth_id = auth.uid()
    AND p.deleted_at IS NULL
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.my_profile_id() IS
  'profiles.id přihlášeného uživatele (auth.uid); SECURITY DEFINER kvůli stabilnímu RLS.';

CREATE OR REPLACE FUNCTION public.has_active_owner_portal_view_session()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.owner_portal_view_sessions s
    WHERE s.admin_profile_id = public.my_profile_id()
      AND s.ended_at IS NULL
      AND s.started_at > ((now() AT TIME ZONE 'utc') - interval '8 hours')
  );
$$;

COMMENT ON FUNCTION public.has_active_owner_portal_view_session() IS
  'True = dispečer má otevřený náhled Owner portálu (read-only); mutace se mají odmítnout.';

CREATE OR REPLACE FUNCTION public.close_my_open_owner_portal_view_sessions()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  n integer;
BEGIN
  UPDATE public.owner_portal_view_sessions s
  SET
    ended_at = (now() AT TIME ZONE 'utc'),
    updated_at = (now() AT TIME ZONE 'utc')
  WHERE s.admin_profile_id = public.my_profile_id()
    AND s.ended_at IS NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

COMMENT ON FUNCTION public.close_my_open_owner_portal_view_sessions() IS
  'Ukončí všechny otevřené owner portal view session volajícího admina (cleanup orphan).';

CREATE OR REPLACE FUNCTION public.assert_not_owner_portal_viewing()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.has_active_owner_portal_view_session() THEN
    RAISE EXCEPTION 'owner_portal_view_readonly'
      USING ERRCODE = '42501',
            HINT = 'Ukončete náhled Owner portálu před mutací.';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.assert_not_owner_portal_viewing() IS
  'RPC: vyhodí 42501 pokud má volající aktivní owner portal view session.';

GRANT EXECUTE ON FUNCTION public.my_profile_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_active_owner_portal_view_session() TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_my_open_owner_portal_view_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.assert_not_owner_portal_viewing() TO authenticated;

-- -----------------------------------------------------------------------------
-- RESTRICTIVE policies – doplňují existující PERMISSIVE, nemění jejich logiku
-- -----------------------------------------------------------------------------

-- Disposition: majitel INSERT / UPDATE pending; admin UPDATE status
DROP POLICY IF EXISTS "owner_cash_disposition_block_insert_owner_view"
  ON public.owner_cash_disposition_requests;
CREATE POLICY "owner_cash_disposition_block_insert_owner_view"
  ON public.owner_cash_disposition_requests
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (NOT public.has_active_owner_portal_view_session());

DROP POLICY IF EXISTS "owner_cash_disposition_block_update_owner_view"
  ON public.owner_cash_disposition_requests;
CREATE POLICY "owner_cash_disposition_block_update_owner_view"
  ON public.owner_cash_disposition_requests
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (NOT public.has_active_owner_portal_view_session())
  WITH CHECK (NOT public.has_active_owner_portal_view_session());

-- Offset proposals: admin INSERT / UPDATE cancel; majitel přes SECURITY DEFINER RPC
DROP POLICY IF EXISTS "billing_offset_proposals_block_insert_owner_view"
  ON public.billing_snapshot_offset_proposals;
CREATE POLICY "billing_offset_proposals_block_insert_owner_view"
  ON public.billing_snapshot_offset_proposals
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (NOT public.has_active_owner_portal_view_session());

DROP POLICY IF EXISTS "billing_offset_proposals_block_update_owner_view"
  ON public.billing_snapshot_offset_proposals;
CREATE POLICY "billing_offset_proposals_block_update_owner_view"
  ON public.billing_snapshot_offset_proposals
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (NOT public.has_active_owner_portal_view_session())
  WITH CHECK (NOT public.has_active_owner_portal_view_session());

-- Tasks: obejití OwnerReadOnlyGate (report issue) pod admin JWT
DROP POLICY IF EXISTS "tasks_block_insert_during_owner_portal_view" ON public.tasks;
CREATE POLICY "tasks_block_insert_during_owner_portal_view"
  ON public.tasks
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (NOT public.has_active_owner_portal_view_session());

DROP POLICY IF EXISTS "tasks_block_update_during_owner_portal_view" ON public.tasks;
CREATE POLICY "tasks_block_update_during_owner_portal_view"
  ON public.tasks
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (NOT public.has_active_owner_portal_view_session())
  WITH CHECK (NOT public.has_active_owner_portal_view_session());

-- Trigger pro SECURITY DEFINER RPC (respond_billing_offset_proposal obchází RLS)
CREATE OR REPLACE FUNCTION public.trg_assert_not_owner_portal_viewing()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_not_owner_portal_viewing();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_billing_offset_proposals_owner_view_guard
  ON public.billing_snapshot_offset_proposals;
CREATE TRIGGER trg_billing_offset_proposals_owner_view_guard
  BEFORE INSERT OR UPDATE ON public.billing_snapshot_offset_proposals
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_assert_not_owner_portal_viewing();
