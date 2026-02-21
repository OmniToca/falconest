-- =============================================================================
-- FalcoNest – Fáze 3: Tabulka reservations
-- =============================================================================
-- Tabulka rezervací pro byty. Propojení s apartment_owners zajišťuje RLS –
-- property_owner vidí jen rezervace u bytů, které vlastní.
--
-- Předpoklady: Tabulky apartments, apartment_owners a profiles existují.
-- Spusť v Supabase SQL Editoru. Skript je idempotentní.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TABULKA reservations
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  special_requests TEXT,
  CONSTRAINT reservations_end_after_start CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_reservations_apartment_id ON reservations(apartment_id);
CREATE INDEX IF NOT EXISTS idx_reservations_dates ON reservations(start_date, end_date);

-- -----------------------------------------------------------------------------
-- 2. RLS POLITIKY
-- -----------------------------------------------------------------------------
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reservations_admin_manager_all" ON reservations;
DROP POLICY IF EXISTS "reservations_property_owner_select" ON reservations;
DROP POLICY IF EXISTS "reservations_property_owner_insert" ON reservations;

-- Admin a manager: plný přístup
CREATE POLICY "reservations_admin_manager_all"
  ON reservations
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role IN ('admin', 'manager')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role IN ('admin', 'manager')
    )
  );

-- Property_owner: čtení rezervací u svých bytů
CREATE POLICY "reservations_property_owner_select"
  ON reservations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM apartment_owners ao
      WHERE ao.apartment_id = reservations.apartment_id
      AND ao.owner_id = auth.uid()
    )
  );

-- Property_owner: zápis rezervací jen pro své byty
CREATE POLICY "reservations_property_owner_insert"
  ON reservations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM apartment_owners ao
      WHERE ao.apartment_id = reservations.apartment_id
      AND ao.owner_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- 3. VOLITELNÉ SLOUPCE V TASKS (pro rezervace → automatické úkoly)
-- -----------------------------------------------------------------------------
-- Pokud tabulka tasks nemá description a created_by, přidej je.
-- Používá se při vytváření úkolu z rezervace (owner_reservations_screen).
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS created_by UUID;

-- -----------------------------------------------------------------------------
-- 4. RLS: Property_owner smí vkládat úkoly pro své byty (z rezervací)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "tasks_property_owner_insert_own_apartments" ON tasks;
CREATE POLICY "tasks_property_owner_insert_own_apartments"
  ON tasks
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM apartment_owners ao
      WHERE ao.apartment_id = tasks.apartment_id
      AND ao.owner_id = auth.uid()
    )
  );
