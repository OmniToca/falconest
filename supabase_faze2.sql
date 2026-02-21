-- =============================================================================
-- FalcoNest – Fáze 2: Role a zabezpečení
-- =============================================================================
-- Tento skript rozšiřuje databázové schéma o novou roli property_owner,
-- tabulku apartment_owners a RLS politiky pro apartments a tasks.
--
-- Předpoklady: Tabulky profiles, apartments a tasks již existují.
-- Spusť v Supabase SQL Editoru. Skript je idempotentní (lze spustit vícekrát).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ROLE property_owner V TABULCE PROFILES
-- -----------------------------------------------------------------------------
-- Přidáme novou roli property_owner. Existují dvě varianty implementace:
--
-- VARIANTA A: Pokud profiles používá sloupec role s TEXT nebo VARCHAR:
--    Stačí přidat CHECK constraint nebo dokumentovat povolené hodnoty.
--
-- VARIANTA B: Pokud profiles používá enum typ pro role:
--    Rozšíříme enum o novou hodnotu.
--
-- Zde implementujeme obě varianty – nejprve zkusíme enum, pak fallback na
-- komentář k textovému sloupci. Uprav podle své aktuální schématu.
-- -----------------------------------------------------------------------------

-- Pokus o rozšíření enum (pokud existuje typ user_role nebo app_role)
-- Pokud typ neexistuje, příkaz selže – to je v pořádku, použij variantu níže.
DO $$
BEGIN
  -- Kontrola existence enum typu (typické názvy: user_role, app_role, role_type)
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    -- Přidání hodnoty property_owner do enum (PostgreSQL 9.1+)
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'property_owner' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')) THEN
      ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'property_owner';
    END IF;
  ELSIF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'property_owner' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'app_role')) THEN
      ALTER TYPE app_role ADD VALUE IF NOT EXISTS 'property_owner';
    END IF;
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    -- Enum typ neexistuje – ponecháme pouze komentář
    NULL;
END $$;

-- Komentář pro dokumentaci: Povolené hodnoty role v profiles jsou:
-- 'admin', 'manager', 'worker', 'property_owner'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
  ) THEN
    COMMENT ON COLUMN profiles.role IS 'Povolené: admin, manager, worker, property_owner. Admin a manager mají plný přístup. Worker vidí přiřazené úkoly. Property_owner vidí pouze své byty a související úkoly.';
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 2. TABULKA apartment_owners
-- -----------------------------------------------------------------------------
-- Propojuje byty (apartments) s majiteli (profiles). Jeden byt může mít
-- více majitelů, jeden majitel může mít více bytů (M:N vztah).
-- RLS zajistí, že property_owner vidí jen své záznamy.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS apartment_owners (
  -- Primární klíč – UUID generované na straně klienta nebo default gen_random_uuid()
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Cizí klíč na byt – který byt je přiřazen
  apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,

  -- Cizí klíč na profil majitele – který uživatel je majitelem
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Unikátní kombinace – jeden záznam pro jednu dvojici byt+majitel
  UNIQUE(apartment_id, owner_id)
);

-- Index pro rychlé vyhledávání bytů daného majitele (používá se v RLS)
CREATE INDEX IF NOT EXISTS idx_apartment_owners_owner_id ON apartment_owners(owner_id);

-- Index pro opačný směr – které majitele má daný byt
CREATE INDEX IF NOT EXISTS idx_apartment_owners_apartment_id ON apartment_owners(apartment_id);

-- Zapnutí Row Level Security – bez politik je přístup odepřen všem
ALTER TABLE apartment_owners ENABLE ROW LEVEL SECURITY;

-- Politika: Admin a manager smí vše v apartment_owners
CREATE POLICY "apartment_owners_admin_manager_all"
  ON apartment_owners
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  );

-- Politika: Property_owner smí číst jen své záznamy (kde je owner_id = já)
CREATE POLICY "apartment_owners_property_owner_select_own"
  ON apartment_owners
  FOR SELECT
  TO authenticated
  USING (
    owner_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'property_owner'
    )
  );

COMMENT ON TABLE apartment_owners IS 'Propojení bytů a majitelů. Slouží pro RLS – property_owner vidí jen byty, kde je zapsán jako majitel.';

-- -----------------------------------------------------------------------------
-- 3. RLS POLITIKY PRO TABULKU apartments
-- -----------------------------------------------------------------------------
-- Admin a manager: plný přístup (SELECT, INSERT, UPDATE, DELETE).
-- Property_owner: pouze SELECT na byty, se kterými je propojen v apartment_owners.
-- Ostatní role (worker atd.): standardně bez přístupu, pokud nemají vlastní politiku.
-- -----------------------------------------------------------------------------

-- Ujisti se, že RLS je zapnuté
ALTER TABLE apartments ENABLE ROW LEVEL SECURITY;

-- Odstranění starých politik s těmito názvy (kvůli opakovanému spuštění skriptu)
DROP POLICY IF EXISTS "apartments_admin_manager_all" ON apartments;
DROP POLICY IF EXISTS "apartments_property_owner_select_own" ON apartments;

-- Politika: Admin a manager smí provádět VŠECHNO (ALL = SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "apartments_admin_manager_all"
  ON apartments
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  );

-- Politika: Property_owner smí pouze ČÍST byty, které jsou pro něj v apartment_owners
-- Pouze SELECT – žádné INSERT/UPDATE/DELETE na apartments
CREATE POLICY "apartments_property_owner_select_own"
  ON apartments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM apartment_owners ao
      WHERE ao.apartment_id = apartments.id
      AND ao.owner_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- 4. RLS POLITIKY PRO TABULKU tasks
-- -----------------------------------------------------------------------------
-- Admin a manager: plný přístup.
-- Worker: číst a upravovat pouze úkoly přiřazené jí (assigned_user_id = auth.uid()).
-- Property_owner: pouze číst úkoly, které se týkají jeho bytů (přes apartment_owners).
--
-- Předpoklad: Tabulka tasks má sloupec assigned_user_id (UUID odkaz na auth.users/profiles)
-- a apartment_id (UUID odkaz na apartments). Uprav názvy sloupců, pokud se liší.
-- -----------------------------------------------------------------------------

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tasks_admin_manager_all" ON tasks;
DROP POLICY IF EXISTS "tasks_worker_select_assigned" ON tasks;
DROP POLICY IF EXISTS "tasks_worker_update_assigned" ON tasks;
DROP POLICY IF EXISTS "tasks_property_owner_select_own_apartments" ON tasks;

-- Politika: Admin a manager smí provádět VŠECHNO
CREATE POLICY "tasks_admin_manager_all"
  ON tasks
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'manager')
    )
  );

-- Politika: Worker smí ČÍST pouze úkoly přiřazené jí
-- assigned_user_id musí odpovídat auth.uid() (přihlášený uživatel)
CREATE POLICY "tasks_worker_select_assigned"
  ON tasks
  FOR SELECT
  TO authenticated
  USING (
    assigned_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'worker'
    )
  );

-- Politika: Worker smí UPRAVOVAT pouze úkoly přiřazené jí
-- (např. změna stavu na in_progress, completed, upload fotky)
CREATE POLICY "tasks_worker_update_assigned"
  ON tasks
  FOR UPDATE
  TO authenticated
  USING (
    assigned_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'worker'
    )
  )
  WITH CHECK (
    assigned_user_id = auth.uid()
  );

-- Politika: Property_owner smí pouze ČÍST úkoly svých bytů
-- Úkol se týká bytu majitele, pokud apartment_id je v apartment_owners pro daného owner_id
CREATE POLICY "tasks_property_owner_select_own_apartments"
  ON tasks
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM apartment_owners ao
      WHERE ao.apartment_id = tasks.apartment_id
      AND ao.owner_id = auth.uid()
    )
  );

-- =============================================================================
-- POZNÁMKY K ÚPRAVÁM
-- =============================================================================
-- 1. Pokud tabulka profiles neexistuje, vytvoř ji (např. triggerem z auth.users).
-- 2. Pokud sloupec profiles.role má jiný název (např. app_role, user_type), uprav
--    všechny výskyty p.role v politikách.
-- 3. Pokud tasks používá assigned_user_id s jiným názvem (assigned_to, worker_id),
--    uprav politiky tasks_worker_select_assigned a tasks_worker_update_assigned.
-- 4. Pokud tasks používá apartment_id s jiným názvem (apartment_supabase_id),
--    uprav politiku tasks_property_owner_select_own_apartments.
-- 5. Role jsou case-sensitive – ujisti se, že hodnoty v DB odpovídají ('admin'
--    ne 'Admin').
-- 6. apartment_owners REFERENCES profiles(id) – pokud profiles odkazuje na
--    auth.users, ujisti se, že profiles.id = auth.users.id. Alternativně lze
--    owner_id REFERENCES auth.users(id).
-- 7. Před spuštěním zkontroluj existující RLS politiky – tento skript pouze
--    přidává/obnovuje politiky s uvedenými názvy.
-- =============================================================================
