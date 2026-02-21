-- =============================================================================
-- FalcoNest – Kompletní reset a seed databáze
-- =============================================================================
-- Spusť v Supabase SQL Editoru (Dashboard → SQL Editor).
-- Vyžaduje pgcrypto extension (Supabase ji má předinstalovanou).
--
-- KROK 1: Vyčištění – TRUNCATE tabulek a smazání 3 testovacích e-mailů z auth
-- KROK 2: Seed – tenant FalconCare Spain, 3 uživatelé, profily, apartmány, rezervace
--
-- Použity JEN sloupce, které reálně existují v tabulkách (bez created_at, updated_at).
-- auth.users: confirmed_at je generated column – používáme email_confirmed_at.
-- =============================================================================

DO $$
DECLARE
  v_super_admin_id UUID;
  v_manager_id UUID;
  v_cleaner_id UUID;
  v_tenant_id UUID;
  v_apt1_id UUID;
  v_apt2_id UUID;
BEGIN
  -- ===========================================================================
  -- KROK 1: VYČIŠTĚNÍ
  -- ===========================================================================

  SELECT id INTO v_super_admin_id FROM auth.users WHERE email = 'sokolpetr87@gmail.com' LIMIT 1;
  SELECT id INTO v_manager_id FROM auth.users WHERE email = 'monikasokolova85@gmail.com' LIMIT 1;
  SELECT id INTO v_cleaner_id FROM auth.users WHERE email = 'uklizacka@gmail.com' LIMIT 1;

  DELETE FROM auth.identities WHERE user_id IN (
    SELECT id FROM auth.users WHERE email IN (
      'sokolpetr87@gmail.com',
      'monikasokolova85@gmail.com',
      'uklizacka@gmail.com'
    )
  );

  DELETE FROM auth.users WHERE email IN (
    'sokolpetr87@gmail.com',
    'monikasokolova85@gmail.com',
    'uklizacka@gmail.com'
  );

  DELETE FROM public.profiles WHERE id IN (v_super_admin_id, v_manager_id, v_cleaner_id);

  TRUNCATE TABLE public.reservations CASCADE;
  TRUNCATE TABLE public.tasks CASCADE;
  TRUNCATE TABLE public.apartment_owners CASCADE;
  TRUNCATE TABLE public.apartments CASCADE;
  TRUNCATE TABLE public.profiles CASCADE;
  TRUNCATE TABLE public.tenants CASCADE;

  -- ===========================================================================
  -- KROK 2: SEED
  -- ===========================================================================

  -- 2.1 Tenant (firma) – pouze id, name
  INSERT INTO public.tenants (id, name)
  VALUES (gen_random_uuid(), 'FalconCare Spain')
  RETURNING id INTO v_tenant_id;

  -- 2.2 auth.users (vyžaduje pgcrypto)
  CREATE EXTENSION IF NOT EXISTS pgcrypto;

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'sokolpetr87@gmail.com',
    crypt('admin1234', gen_salt('bf', 10)),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{}'::jsonb
  )
  RETURNING id INTO v_super_admin_id;

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'monikasokolova85@gmail.com',
    crypt('monika1234', gen_salt('bf', 10)),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{}'::jsonb
  )
  RETURNING id INTO v_manager_id;

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'uklizacka@gmail.com',
    crypt('uklizecka1234', gen_salt('bf', 10)),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{}'::jsonb
  )
  RETURNING id INTO v_cleaner_id;

  -- 2.3 auth.identities (povinné pro přihlášení)
  INSERT INTO auth.identities (
    id,
    user_id,
    provider_id,
    provider,
    identity_data
  ) VALUES
  (v_super_admin_id, v_super_admin_id, v_super_admin_id::text, 'email',
   jsonb_build_object('sub', v_super_admin_id::text, 'email', 'sokolpetr87@gmail.com')),
  (v_manager_id, v_manager_id, v_manager_id::text, 'email',
   jsonb_build_object('sub', v_manager_id::text, 'email', 'monikasokolova85@gmail.com')),
  (v_cleaner_id, v_cleaner_id, v_cleaner_id::text, 'email',
   jsonb_build_object('sub', v_cleaner_id::text, 'email', 'uklizacka@gmail.com'));

  -- 2.4 Profily – id, tenant_id, name, pin_code, role
  INSERT INTO public.profiles (id, tenant_id, name, pin_code, role)
  VALUES
  (v_super_admin_id, NULL, 'Petr Sokol', '123456', 'super_admin'),
  (v_manager_id, v_tenant_id, 'Monika Sokolová', '654321', 'admin'),
  (v_cleaner_id, v_tenant_id, 'Uklízečka', '789012', 'worker')
  ON CONFLICT (id) DO UPDATE SET tenant_id = EXCLUDED.tenant_id, name = EXCLUDED.name, pin_code = EXCLUDED.pin_code, role = EXCLUDED.role;

  -- 2.5 Apartmány – id, tenant_id, name, address, keybox (+ volitelně status, check_in_time, ...)
  INSERT INTO public.apartments (id, tenant_id, name, address, keybox)
  VALUES
  (gen_random_uuid(), v_tenant_id, 'Apartmán Costa del Sol', 'Calle Mar 15, Málaga', '1234')
  RETURNING id INTO v_apt1_id;

  INSERT INTO public.apartments (id, tenant_id, name, address, keybox)
  VALUES
  (gen_random_uuid(), v_tenant_id, 'Apartmán Plaza Mayor', 'Calle Central 8, Madrid', '5678')
  RETURNING id INTO v_apt2_id;

  -- 2.6 Rezervace – apartment_id, start_date, end_date, special_requests
  INSERT INTO public.reservations (apartment_id, start_date, end_date, special_requests)
  VALUES
  (v_apt1_id, CURRENT_DATE + interval '14 days', CURRENT_DATE + interval '21 days', NULL),
  (v_apt1_id, CURRENT_DATE + interval '45 days', CURRENT_DATE + interval '52 days', NULL),
  (v_apt1_id, CURRENT_DATE + interval '80 days', CURRENT_DATE + interval '94 days', NULL),
  (v_apt2_id, CURRENT_DATE + interval '20 days', CURRENT_DATE + interval '27 days', NULL),
  (v_apt2_id, CURRENT_DATE + interval '55 days', CURRENT_DATE + interval '62 days', NULL),
  (v_apt2_id, CURRENT_DATE + interval '95 days', CURRENT_DATE + interval '109 days', NULL);

  RAISE NOTICE 'Seed dokončen. FalconCare Spain: %', v_tenant_id;
  RAISE NOTICE 'Super Admin: sokolpetr87@gmail.com / admin1234';
  RAISE NOTICE 'Manažerka: monikasokolova85@gmail.com / monika1234';
  RAISE NOTICE 'Uklízečka: uklizacka@gmail.com / uklizecka1234';

END $$;
