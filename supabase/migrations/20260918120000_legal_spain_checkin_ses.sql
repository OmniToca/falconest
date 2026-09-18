-- =============================================================================
-- FalcoNest – Modul legal_spain: registrace hostů (RD 933/2021) + SES Hospedajes
-- =============================================================================
-- PROČ: Placený add-on pro check-in (parte de viajeros), e-podpis 14+, knihu 3 roky
-- a automatické SOAP odeslání na SES. NEaktivuje se všem tenantům – příplatek.
-- Subjekt povinnosti: arrendador (majitel nebo agentura jako intermediario) ukládá
-- SES kódy u bytu. PV (hosté) vždy; RH jen u přímých rezervací (ne OTA).
-- GDPR: doklady a podpisy 3 roky, pak úklid v maintenance (viz níže).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0) Katalogový modul – BEZ seedu do tenant_modules
-- ---------------------------------------------------------------------------
INSERT INTO public.modules (
  key,
  name,
  description,
  price_eur,
  pricing_type,
  show_in_menu,
  order_index
)
VALUES (
  'legal_spain',
  'Check-in a SES Hospedajes',
  'Online check-in hostů, e-podpis části a automatické odeslání na SES Hospedajes (RD 933/2021).',
  4.95,
  'per_apartment',
  true,
  32
)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price_eur = EXCLUDED.price_eur,
  pricing_type = EXCLUDED.pricing_type,
  show_in_menu = EXCLUDED.show_in_menu,
  order_index = EXCLUDED.order_index;

-- ---------------------------------------------------------------------------
-- 1) Pomocná funkce: je modul legal_spain u tenanta aktivní (trial/valid_until)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_legal_spain_module_active(p_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.tenant_modules tm
    JOIN public.modules m ON m.id = tm.module_id
    WHERE tm.tenant_id = p_tenant_id
      AND m.key = 'legal_spain'
      AND tm.deleted_at IS NULL
      AND (tm.valid_until IS NULL OR tm.valid_until > now())
      AND (tm.trial_ends_at IS NULL OR tm.trial_ends_at > now())
  );
$$;

COMMENT ON FUNCTION public.is_legal_spain_module_active(uuid) IS
  'True, pokud tenant má zaplacený/trial modul legal_spain. Používá Edge i RPC check-inu.';

GRANT EXECUTE ON FUNCTION public.is_legal_spain_module_active(uuid) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2) E-mail hosta na rezervaci (import už sloupec čte)
-- ---------------------------------------------------------------------------
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS guest_email text;

COMMENT ON COLUMN public.reservations.guest_email IS
  'E-mail hlavního hosta – odkaz na veřejný check-in a kontakt SES (correo).';

-- ---------------------------------------------------------------------------
-- 3) SES / právní nastavení bytu (veřejné kódy, ne heslo WS)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.apartment_legal_settings (
  apartment_id uuid PRIMARY KEY REFERENCES public.apartments (id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  ses_establishment_code text,
  ses_landlord_code text,
  legal_authority text NOT NULL DEFAULT 'ses'
    CHECK (legal_authority IN ('ses', 'mossos', 'ertzaintza')),
  tourist_license text,
  default_payment_type text NOT NULL DEFAULT 'EFECTIVO',
  house_rules text,
  public_web_origin text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_apartment_legal_settings_tenant
  ON public.apartment_legal_settings (tenant_id);

COMMENT ON TABLE public.apartment_legal_settings IS
  'Kódy SES (establecimiento, arrendador) a výchozí typ platby u bytu. Heslo WS je v ses_ws_credentials.';

ALTER TABLE public.apartment_legal_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS apartment_legal_settings_select ON public.apartment_legal_settings;
CREATE POLICY apartment_legal_settings_select
  ON public.apartment_legal_settings FOR SELECT
  USING (
    tenant_id = public.my_tenant_id()
    AND (
      public.is_tenant_admin_or_manager()
      OR public.is_super_admin()
      OR EXISTS (
        SELECT 1 FROM public.apartment_owners ao
        JOIN public.profiles p ON p.id = ao.owner_id
        WHERE ao.apartment_id = apartment_legal_settings.apartment_id
          AND ao.deleted_at IS NULL
          AND p.auth_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS apartment_legal_settings_write ON public.apartment_legal_settings;
CREATE POLICY apartment_legal_settings_write
  ON public.apartment_legal_settings FOR ALL
  USING (
    tenant_id = public.my_tenant_id()
    AND (public.is_tenant_admin_or_manager() OR public.is_super_admin())
  )
  WITH CHECK (
    tenant_id = public.my_tenant_id()
    AND (public.is_tenant_admin_or_manager() OR public.is_super_admin())
  );

-- Majitel nesmí číst WS heslo – proto samostatná tabulka bez SELECT pro property_owner.
CREATE TABLE IF NOT EXISTS public.ses_ws_credentials (
  apartment_id uuid PRIMARY KEY REFERENCES public.apartments (id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  ws_username text,
  ws_password text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.ses_ws_credentials IS
  'WS login SES Hospedajes. SELECT hesla jen service_role (Edge). Admin vidí username přes view.';

ALTER TABLE public.ses_ws_credentials ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.ses_ws_credentials FROM PUBLIC, anon, authenticated;
GRANT SELECT (apartment_id, tenant_id, ws_username, updated_at, created_at)
  ON public.ses_ws_credentials TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.ses_ws_credentials TO authenticated;
GRANT ALL ON public.ses_ws_credentials TO service_role;

DROP POLICY IF EXISTS ses_ws_credentials_admin ON public.ses_ws_credentials;
CREATE POLICY ses_ws_credentials_admin
  ON public.ses_ws_credentials FOR ALL
  USING (
    tenant_id = public.my_tenant_id()
    AND (public.is_tenant_admin_or_manager() OR public.is_super_admin())
  )
  WITH CHECK (
    tenant_id = public.my_tenant_id()
    AND (public.is_tenant_admin_or_manager() OR public.is_super_admin())
  );

-- ---------------------------------------------------------------------------
-- 4) Hosté u rezervace + session check-inu
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.guest_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES public.reservations (id) ON DELETE CASCADE,
  public_token uuid NOT NULL DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'queued', 'accepted', 'reported', 'rejected', 'timeout')),
  signed_at timestamptz,
  parte_pdf_url text,
  last_error text,
  sla_alerted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reservation_id),
  UNIQUE (public_token)
);

CREATE INDEX IF NOT EXISTS idx_guest_checkins_tenant_status
  ON public.guest_checkins (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_guest_checkins_token
  ON public.guest_checkins (public_token);

COMMENT ON TABLE public.guest_checkins IS
  'Jedna session check-inu na rezervaci: veřejný token, stav SES, SLA alert.';

CREATE TABLE IF NOT EXISTS public.reservation_guests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES public.reservations (id) ON DELETE CASCADE,
  first_name text NOT NULL DEFAULT '',
  last_name text NOT NULL DEFAULT '',
  second_last_name text,
  birth_date date,
  nationality text,
  sex text,
  document_type text,
  document_number text,
  document_support text,
  address_line text,
  address_city text,
  address_country text,
  phone text,
  email text,
  kinship text,
  is_minor_under_14 boolean NOT NULL DEFAULT false,
  signed_at timestamptz,
  signature_png_base64 text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reservation_guests_reservation
  ON public.reservation_guests (reservation_id);
CREATE INDEX IF NOT EXISTS idx_reservation_guests_tenant
  ON public.reservation_guests (tenant_id);

COMMENT ON TABLE public.reservation_guests IS
  'Osoby k pobytu (RD 933/2021). Podpis 14+ v signature_png_base64; retence 3 roky.';

ALTER TABLE public.guest_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservation_guests ENABLE ROW LEVEL SECURITY;

-- SELECT: admin/manager tenanta, majitel bytu, worker přiřazený k úkolu s reservation_id
DROP POLICY IF EXISTS guest_checkins_select ON public.guest_checkins;
CREATE POLICY guest_checkins_select
  ON public.guest_checkins FOR SELECT
  USING (
    tenant_id = public.my_tenant_id()
    AND (
      public.is_super_admin()
      OR public.is_tenant_admin_or_manager()
      OR EXISTS (
        SELECT 1 FROM public.reservations r
        JOIN public.apartment_owners ao ON ao.apartment_id = r.apartment_id AND ao.deleted_at IS NULL
        JOIN public.profiles p ON p.id = ao.owner_id
        WHERE r.id = guest_checkins.reservation_id
          AND p.auth_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.tasks t
        WHERE t.reservation_id = guest_checkins.reservation_id
          AND public.is_worker_assigned_to_task(t.id)
      )
    )
  );

DROP POLICY IF EXISTS guest_checkins_write ON public.guest_checkins;
CREATE POLICY guest_checkins_write
  ON public.guest_checkins FOR ALL
  USING (
    tenant_id = public.my_tenant_id()
    AND (
      public.is_super_admin()
      OR public.is_tenant_admin_or_manager()
      OR EXISTS (
        SELECT 1 FROM public.reservations r
        JOIN public.apartment_owners ao ON ao.apartment_id = r.apartment_id AND ao.deleted_at IS NULL
        JOIN public.profiles p ON p.id = ao.owner_id
        WHERE r.id = guest_checkins.reservation_id
          AND p.auth_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.tasks t
        WHERE t.reservation_id = guest_checkins.reservation_id
          AND public.is_worker_assigned_to_task(t.id)
      )
    )
  )
  WITH CHECK (
    tenant_id = public.my_tenant_id()
  );

DROP POLICY IF EXISTS reservation_guests_select ON public.reservation_guests;
CREATE POLICY reservation_guests_select
  ON public.reservation_guests FOR SELECT
  USING (
    tenant_id = public.my_tenant_id()
    AND (
      public.is_super_admin()
      OR public.is_tenant_admin_or_manager()
      OR EXISTS (
        SELECT 1 FROM public.reservations r
        JOIN public.apartment_owners ao ON ao.apartment_id = r.apartment_id AND ao.deleted_at IS NULL
        JOIN public.profiles p ON p.id = ao.owner_id
        WHERE r.id = reservation_guests.reservation_id
          AND p.auth_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.tasks t
        WHERE t.reservation_id = reservation_guests.reservation_id
          AND public.is_worker_assigned_to_task(t.id)
      )
    )
  );

DROP POLICY IF EXISTS reservation_guests_write ON public.reservation_guests;
CREATE POLICY reservation_guests_write
  ON public.reservation_guests FOR ALL
  USING (
    tenant_id = public.my_tenant_id()
    AND (
      public.is_super_admin()
      OR public.is_tenant_admin_or_manager()
      OR EXISTS (
        SELECT 1 FROM public.reservations r
        JOIN public.apartment_owners ao ON ao.apartment_id = r.apartment_id AND ao.deleted_at IS NULL
        JOIN public.profiles p ON p.id = ao.owner_id
        WHERE r.id = reservation_guests.reservation_id
          AND p.auth_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.tasks t
        WHERE t.reservation_id = reservation_guests.reservation_id
          AND public.is_worker_assigned_to_task(t.id)
      )
    )
  )
  WITH CHECK (tenant_id = public.my_tenant_id());

-- ---------------------------------------------------------------------------
-- 5) Audit komunikací SES (lote / kód / chyba)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ses_communications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES public.reservations (id) ON DELETE CASCADE,
  guest_checkin_id uuid REFERENCES public.guest_checkins (id) ON DELETE SET NULL,
  communication_type text NOT NULL CHECK (communication_type IN ('PV', 'RH')),
  operation_type text NOT NULL DEFAULT 'A' CHECK (operation_type IN ('A', 'C', 'B')),
  lote_id text,
  communication_code text,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'accepted', 'reported', 'rejected', 'timeout')),
  last_error text,
  attempt_count integer NOT NULL DEFAULT 0,
  request_xml text,
  response_xml text,
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ses_communications_tenant_status
  ON public.ses_communications (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_ses_communications_reservation
  ON public.ses_communications (reservation_id);

COMMENT ON TABLE public.ses_communications IS
  'Fronta a audit SOAP na SES: alta PV/RH, lote, poll, chyby. Edge ses-hospedajes.';

ALTER TABLE public.ses_communications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ses_communications_select ON public.ses_communications;
CREATE POLICY ses_communications_select
  ON public.ses_communications FOR SELECT
  USING (
    tenant_id = public.my_tenant_id()
    AND (
      public.is_super_admin()
      OR public.is_tenant_admin_or_manager()
      OR EXISTS (
        SELECT 1 FROM public.reservations r
        JOIN public.apartment_owners ao ON ao.apartment_id = r.apartment_id AND ao.deleted_at IS NULL
        JOIN public.profiles p ON p.id = ao.owner_id
        WHERE r.id = ses_communications.reservation_id
          AND p.auth_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS ses_communications_admin_write ON public.ses_communications;
CREATE POLICY ses_communications_admin_write
  ON public.ses_communications FOR ALL
  USING (
    tenant_id = public.my_tenant_id()
    AND (public.is_super_admin() OR public.is_tenant_admin_or_manager())
  )
  WITH CHECK (
    tenant_id = public.my_tenant_id()
    AND (public.is_super_admin() OR public.is_tenant_admin_or_manager())
  );

-- ---------------------------------------------------------------------------
-- 6) Veřejné RPC check-inu (anon) – SECURITY DEFINER, jen známý token
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_legal_checkin_bootstrap(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token uuid;
  v_gc public.guest_checkins%ROWTYPE;
  v_res public.reservations%ROWTYPE;
  v_apt_name text;
  v_house_rules text;
  v_guests jsonb;
BEGIN
  IF p_token IS NULL OR length(trim(p_token)) = 0 THEN
    RETURN NULL;
  END IF;
  BEGIN
    v_token := trim(p_token)::uuid;
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;

  SELECT * INTO v_gc FROM public.guest_checkins WHERE public_token = v_token;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  IF NOT public.is_legal_spain_module_active(v_gc.tenant_id) THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_res FROM public.reservations
   WHERE id = v_gc.reservation_id AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT a.name INTO v_apt_name
    FROM public.apartments a WHERE a.id = v_res.apartment_id;

  SELECT s.house_rules INTO v_house_rules
    FROM public.apartment_legal_settings s
   WHERE s.apartment_id = v_res.apartment_id;

  SELECT COALESCE(jsonb_agg(to_jsonb(g.*) ORDER BY g.created_at), '[]'::jsonb)
    INTO v_guests
    FROM public.reservation_guests g
   WHERE g.reservation_id = v_res.id;

  RETURN jsonb_build_object(
    'checkin_id', v_gc.id,
    'status', v_gc.status,
    'reservation_id', v_res.id,
    'start_date', v_res.start_date,
    'end_date', v_res.end_date,
    'guest_name', v_res.guest_name,
    'apartment_name', v_apt_name,
    'house_rules', v_house_rules,
    'guests', v_guests
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_legal_checkin_bootstrap(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_legal_checkin_bootstrap(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.upsert_legal_checkin_guest(
  p_token text,
  p_guest jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token uuid;
  v_gc public.guest_checkins%ROWTYPE;
  v_id uuid;
  v_row public.reservation_guests%ROWTYPE;
BEGIN
  IF p_token IS NULL OR p_guest IS NULL THEN
    RAISE EXCEPTION 'missing_token_or_guest';
  END IF;
  v_token := trim(p_token)::uuid;

  SELECT * INTO v_gc FROM public.guest_checkins WHERE public_token = v_token FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_token';
  END IF;
  IF NOT public.is_legal_spain_module_active(v_gc.tenant_id) THEN
    RAISE EXCEPTION 'module_inactive';
  END IF;

  v_id := NULLIF(trim(p_guest->>'id'), '')::uuid;

  IF v_id IS NULL THEN
    INSERT INTO public.reservation_guests (
      tenant_id, reservation_id,
      first_name, last_name, second_last_name,
      birth_date, nationality, sex,
      document_type, document_number, document_support,
      address_line, address_city, address_country,
      phone, email, kinship, is_minor_under_14
    ) VALUES (
      v_gc.tenant_id,
      v_gc.reservation_id,
      COALESCE(trim(p_guest->>'first_name'), ''),
      COALESCE(trim(p_guest->>'last_name'), ''),
      NULLIF(trim(p_guest->>'second_last_name'), ''),
      NULLIF(p_guest->>'birth_date', '')::date,
      NULLIF(trim(p_guest->>'nationality'), ''),
      NULLIF(trim(p_guest->>'sex'), ''),
      NULLIF(trim(p_guest->>'document_type'), ''),
      NULLIF(trim(p_guest->>'document_number'), ''),
      NULLIF(trim(p_guest->>'document_support'), ''),
      NULLIF(trim(p_guest->>'address_line'), ''),
      NULLIF(trim(p_guest->>'address_city'), ''),
      NULLIF(trim(p_guest->>'address_country'), ''),
      NULLIF(trim(p_guest->>'phone'), ''),
      NULLIF(trim(p_guest->>'email'), ''),
      NULLIF(trim(p_guest->>'kinship'), ''),
      COALESCE((p_guest->>'is_minor_under_14')::boolean, false)
    )
    RETURNING * INTO v_row;
  ELSE
    UPDATE public.reservation_guests SET
      first_name = COALESCE(trim(p_guest->>'first_name'), first_name),
      last_name = COALESCE(trim(p_guest->>'last_name'), last_name),
      second_last_name = COALESCE(NULLIF(trim(p_guest->>'second_last_name'), ''), second_last_name),
      birth_date = COALESCE(NULLIF(p_guest->>'birth_date', '')::date, birth_date),
      nationality = COALESCE(NULLIF(trim(p_guest->>'nationality'), ''), nationality),
      sex = COALESCE(NULLIF(trim(p_guest->>'sex'), ''), sex),
      document_type = COALESCE(NULLIF(trim(p_guest->>'document_type'), ''), document_type),
      document_number = COALESCE(NULLIF(trim(p_guest->>'document_number'), ''), document_number),
      document_support = COALESCE(NULLIF(trim(p_guest->>'document_support'), ''), document_support),
      address_line = COALESCE(NULLIF(trim(p_guest->>'address_line'), ''), address_line),
      address_city = COALESCE(NULLIF(trim(p_guest->>'address_city'), ''), address_city),
      address_country = COALESCE(NULLIF(trim(p_guest->>'address_country'), ''), address_country),
      phone = COALESCE(NULLIF(trim(p_guest->>'phone'), ''), phone),
      email = COALESCE(NULLIF(trim(p_guest->>'email'), ''), email),
      kinship = COALESCE(NULLIF(trim(p_guest->>'kinship'), ''), kinship),
      is_minor_under_14 = COALESCE((p_guest->>'is_minor_under_14')::boolean, is_minor_under_14),
      updated_at = now()
    WHERE id = v_id AND reservation_id = v_gc.reservation_id
    RETURNING * INTO v_row;
  END IF;

  RETURN to_jsonb(v_row);
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_legal_checkin_guest(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_legal_checkin_guest(text, jsonb) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_legal_checkin_signature(
  p_token text,
  p_guest_id uuid,
  p_png_base64 text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token uuid;
  v_gc public.guest_checkins%ROWTYPE;
  v_row public.reservation_guests%ROWTYPE;
  v_unsigned int;
BEGIN
  v_token := trim(p_token)::uuid;
  SELECT * INTO v_gc FROM public.guest_checkins WHERE public_token = v_token FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_token';
  END IF;
  IF NOT public.is_legal_spain_module_active(v_gc.tenant_id) THEN
    RAISE EXCEPTION 'module_inactive';
  END IF;
  IF p_png_base64 IS NULL OR length(p_png_base64) < 32 THEN
    RAISE EXCEPTION 'empty_signature';
  END IF;

  UPDATE public.reservation_guests
     SET signature_png_base64 = p_png_base64,
         signed_at = now(),
         updated_at = now()
   WHERE id = p_guest_id
     AND reservation_id = v_gc.reservation_id
     AND is_minor_under_14 = false
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'guest_not_found';
  END IF;

  SELECT count(*) INTO v_unsigned
    FROM public.reservation_guests g
   WHERE g.reservation_id = v_gc.reservation_id
     AND g.is_minor_under_14 = false
     AND g.signed_at IS NULL;

  IF v_unsigned = 0 THEN
    UPDATE public.guest_checkins
       SET status = CASE WHEN status IN ('reported', 'accepted') THEN status ELSE 'queued' END,
           signed_at = now(),
           updated_at = now()
     WHERE id = v_gc.id;
  END IF;

  RETURN to_jsonb(v_row);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_legal_checkin_signature(text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_legal_checkin_signature(text, uuid, text) TO anon, authenticated;

-- Zajistí session + token pro přihlášeného admina/majitele
CREATE OR REPLACE FUNCTION public.ensure_legal_checkin_session(p_reservation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tid uuid;
  v_row public.guest_checkins%ROWTYPE;
BEGIN
  SELECT tenant_id INTO v_tid FROM public.reservations
   WHERE id = p_reservation_id AND deleted_at IS NULL;
  IF v_tid IS NULL THEN
    RAISE EXCEPTION 'reservation_not_found';
  END IF;
  IF NOT public.is_legal_spain_module_active(v_tid) THEN
    RAISE EXCEPTION 'module_inactive';
  END IF;

  INSERT INTO public.guest_checkins (tenant_id, reservation_id)
  VALUES (v_tid, p_reservation_id)
  ON CONFLICT (reservation_id) DO UPDATE SET updated_at = now()
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'public_token', v_row.public_token,
    'status', v_row.status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_legal_checkin_session(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_legal_checkin_session(uuid) TO authenticated;

-- Ruční zařazení do SES fronty (oprava + znovu odeslat)
CREATE OR REPLACE FUNCTION public.enqueue_ses_pv_for_reservation(p_reservation_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tid uuid;
  v_id uuid;
  v_gc_id uuid;
BEGIN
  SELECT tenant_id INTO v_tid FROM public.reservations WHERE id = p_reservation_id;
  IF v_tid IS NULL OR v_tid <> public.my_tenant_id() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF NOT (public.is_tenant_admin_or_manager() OR public.is_super_admin()) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_gc_id FROM public.guest_checkins WHERE reservation_id = p_reservation_id;

  INSERT INTO public.ses_communications (
    tenant_id, reservation_id, guest_checkin_id, communication_type, operation_type, status
  ) VALUES (
    v_tid, p_reservation_id, v_gc_id, 'PV', 'A', 'queued'
  )
  RETURNING id INTO v_id;

  UPDATE public.guest_checkins
     SET status = 'queued', last_error = NULL, updated_at = now()
   WHERE reservation_id = p_reservation_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.enqueue_ses_pv_for_reservation(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enqueue_ses_pv_for_reservation(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 7) GDPR úklid: podpisy a doklady starší 3 let (volá existující weekly cleanup)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.legal_spain_gdpr_cleanup()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.reservation_guests
     SET signature_png_base64 = NULL,
         document_number = NULL,
         document_support = NULL,
         updated_at = now()
   WHERE created_at < now() - interval '3 years'
     AND signature_png_base64 IS NOT NULL;
END;
$$;

COMMENT ON FUNCTION public.legal_spain_gdpr_cleanup() IS
  'Po 3 letech smaže podpisy a čísla dokladů (RD 933/2021 retence).';

-- Napojení na existující weekly cleanup, pokud funkce existuje – voláme samostatným cronem.
INSERT INTO public.cron_edge_config (key, value)
VALUES
  ('ses_hospedajes_url', 'https://REPLACE_WITH_PROJECT_REF.supabase.co/functions/v1/ses-hospedajes')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.invoke_ses_hospedajes()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public._automation_invoke_http_post('ses_hospedajes_url');
END;
$$;

COMMENT ON FUNCTION public.invoke_ses_hospedajes() IS
  'POST na Edge ses-hospedajes (dispatch + poll + SLA). Token = automation_edge_auth_token.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ses-hospedajes-quarter-hour') THEN
    PERFORM cron.unschedule('ses-hospedajes-quarter-hour');
  END IF;
  PERFORM cron.schedule(
    'ses-hospedajes-quarter-hour',
    '*/15 * * * *',
    'SELECT public.invoke_ses_hospedajes()'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – zaregistruj job ručně: SELECT public.invoke_ses_hospedajes();';
  WHEN OTHERS THEN RAISE;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'legal-spain-gdpr-weekly') THEN
    PERFORM cron.unschedule('legal-spain-gdpr-weekly');
  END IF;
  PERFORM cron.schedule(
    'legal-spain-gdpr-weekly',
    '15 3 * * 0',
    'SELECT public.legal_spain_gdpr_cleanup()'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – GDPR cleanup spusť ručně.';
  WHEN OTHERS THEN RAISE;
END $$;

-- ---------------------------------------------------------------------------
-- 8) RH u přímých rezervací (OTA Booking/Airbnb posílají samy)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.legal_spain_enqueue_rh()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_legal_spain_module_active(NEW.tenant_id) THEN
    RETURN NEW;
  END IF;
  IF NEW.reservation_source IN ('Booking', 'Airbnb') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.ses_communications (
      tenant_id, reservation_id, communication_type, operation_type, status
    ) VALUES (
      NEW.tenant_id, NEW.id, 'RH', 'A', 'queued'
    );
  ELSIF TG_OP = 'UPDATE'
     AND NEW.status = 'cancelled'
     AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    INSERT INTO public.ses_communications (
      tenant_id, reservation_id, communication_type, operation_type, status
    ) VALUES (
      NEW.tenant_id, NEW.id, 'RH', 'B', 'queued'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_legal_spain_enqueue_rh ON public.reservations;
CREATE TRIGGER trg_legal_spain_enqueue_rh
  AFTER INSERT OR UPDATE OF status, reservation_source
  ON public.reservations
  FOR EACH ROW
  EXECUTE FUNCTION public.legal_spain_enqueue_rh();

-- PV do fronty, jakmile jsou všichni 14+ podepsáni (status guest_checkins = queued)
CREATE OR REPLACE FUNCTION public.legal_spain_enqueue_pv_on_queued()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'queued' AND (OLD.status IS DISTINCT FROM 'queued') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.ses_communications c
       WHERE c.reservation_id = NEW.reservation_id
         AND c.communication_type = 'PV'
         AND c.status IN ('queued', 'accepted')
    ) THEN
      INSERT INTO public.ses_communications (
        tenant_id, reservation_id, guest_checkin_id, communication_type, operation_type, status
      ) VALUES (
        NEW.tenant_id, NEW.reservation_id, NEW.id, 'PV', 'A', 'queued'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_legal_spain_enqueue_pv_on_queued ON public.guest_checkins;
CREATE TRIGGER trg_legal_spain_enqueue_pv_on_queued
  AFTER INSERT OR UPDATE OF status
  ON public.guest_checkins
  FOR EACH ROW
  EXECUTE FUNCTION public.legal_spain_enqueue_pv_on_queued();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.apartment_legal_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.guest_checkins TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reservation_guests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ses_communications TO authenticated;

NOTIFY pgrst, 'reload schema';
