# Architektonický návrh – Portál majitelů (Owner Portal)

**Audit FalcoNest** | Datum: únor 2025 | Kontext: B2B SaaS, Flutter + Supabase

---

## 1. Změny v databázi (Supabase)

### 1.1 Propojení majitele s apartmány – SOUČASNÝ STAV ✅

**Tabulka `apartment_owners` již existuje** v `database_schema.md` i v migracích (`supabase_faze2.sql`):

| Sloupec      | Typ    | Popis                                      |
|-------------|--------|--------------------------------------------|
| id          | uuid   | PK                                         |
| apartment_id| uuid   | FK → apartments                            |
| owner_id    | uuid   | FK → profiles(id) – profil majitele        |
| deleted_at  | timestamptz | Soft delete                        |

**Doporučení:** Používat **propojovací tabulku** `apartment_owners` (už existuje). Jeden byt může mít více majitelů, jeden majitel může mít více bytů (M:N). Sloupec `owner_id` odkazuje na `profiles.id`.

Alternativa `owner_id` přímo v tabulce apartments by znamenala pouze 1 majitele na byt a nutnost migrace – neodpovídá běžným scénářům (více spoluvlastníků).

---

### 1.2 RLS politiky – SOUČASNÝ STAV A POZNÁMKY

RLS je definované v `supabase_faze2.sql` a `supabase_faze3_reservations.sql`:

#### `apartment_owners`
- **Admin/manager:** `FOR ALL` – plný přístup
- **Property_owner:** `FOR SELECT` – pouze `owner_id = auth.uid()`

#### `apartments`
- **Property_owner:** `FOR SELECT` – pouze byty, kde existuje záznam v `apartment_owners` s `ao.owner_id = auth.uid()`

#### `reservations`
- **Property_owner SELECT:** rezervace u bytů z `apartment_owners`, kde `ao.owner_id = auth.uid()`
- **Property_owner INSERT:** stejná podmínka pro nové rezervace (jen pro své byty)

#### `tasks`
- **Property_owner SELECT:** úkoly u bytů z `apartment_owners`, kde `ao.owner_id = auth.uid()`
- **Property_owner INSERT:** úkoly pro své byty (např. z nové rezervace)

**⚠️ DŮLEŽITÁ KONTROLA – `profiles.id` vs `auth.uid()`**

Politiky používají `p.id = auth.uid()` a `owner_id = auth.uid()`. To platí pouze tehdy, pokud:
- `profiles.id` = `auth.users.id` (běžný Supabase vzor s triggerem `handle_new_user`)
- **U pozvaných uživatelů:** ghost profil má `id` = UUID vytvořené při pozvánce, `auth_id` = UUID po registraci. Pro pozvané majitele pak `profiles.id ≠ auth.uid()`, a RLS by je mohl blokovat.

**Doporučení:** Ověřit, zda ghost profily používají `id = auth.uid()` po propojení, nebo upravit RLS na:
```sql
owner_id = (SELECT id FROM profiles WHERE auth_id = auth.uid() LIMIT 1)
```

---

### 1.3 Chybějící sloupec `deleted_at` v `apartment_owners`

Schéma uvádí `deleted_at`; migrace v `supabase_faze2.sql` ji neobsahuje. Pokud je soft delete vyžadován, doplnit:

```sql
ALTER TABLE apartment_owners ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
```

A v RLS/poždavcích filtrovat `deleted_at IS NULL`.

---

## 2. Autentizace a role

### 2.1 Kde se definuje role

**Tabulka:** `profiles`
- **Sloupec:** `role` (text)
- Hodnoty: `admin`, `manager`, `worker`, `super_admin`, `property_owner`

**Soubor:** `lib/core/auth/auth_notifier.dart`
- Role se načítá z `profiles` při přihlášení (`_loadRoleAndNotify`)
- `role == 'property_owner'` → `isPropertyOwner` getter, přesměrování na `/owner`

### 2.2 Pozvání majitele – CO CHYBÍ ❌

**Invitations:** tabulka `invitations` má sloupce `role`, `roles`, `profile_id`, `tenant_id`, `email` atd.

**Problém:** V `admin_team_screen.dart` dialog „Přidat člena“ (`_AddMemberDialog`) nabízí pouze:
- `_systemRole`: `admin` | `worker` (RadioListTile řádky 1658–1669)
- `teamJobRoleKeys`: `cleaner`, `driver`, `maintenance`, `checkin_agent`

**Role `property_owner` není v UI** – admin nemůže pozvat majitele přes tým.

**Řešení:**
1. Přidat do `_AddMemberDialog` třetí hodnotu: `property_owner` (s vlastním flow)
2. Nebo vytvořit samostatný flow „Pozvat majitele bytu“ v rámci Správy bytů (např. při úpravě bytu)
3. Rozšířit `systemRoleValues` / `_systemRole` o `property_owner` a upravit logiku (majitel nemá `roles` jako cleaner/driver – má jiný onboarding)

### 2.3 Ghost profil pro majitele

Flow je shodné s workerem:
1. Admin vytvoří pozvánku → vloží do `invitations` (email, role, tenant_id, first_name, last_name)
2. Vytvoří ghost profil v `profiles` (tenant_id, role, status=pending, bez auth_id)
3. `profile_id` v invitations odkazuje na tento ghost profil
4. Uživatel přijme pozvánku → signUp → `profiles.update(auth_id=user.id).eq('id', profileId)` – propojení
5. Pozvánka se smaže

Pro `property_owner` navíc: po přijetí pozvánky musí admin **přiřadit konkrétní byty** do `apartment_owners`, jinak majitel neuvidí žádné apartmány.

---

## 3. Flutter architektura (routing a UI)

### 3.1 Struktura složek – SOUČASNÝ STAV

```
lib/features/owner/
├── owner_apartments_screen.dart   # Seznam bytů majitele
├── owner_layout.dart              # Shell s postranním panelem (apartmány, rezervace, odhlášení)
├── owner_reservations_screen.dart # Kalendář rezervací + FAB nová rezervace
├── owner_dashboard_screen.dart    # (existuje, pravděpodobně nepoužívá se – redirect jde na /owner/apartments)
└── providers/
    ├── owner_apartments_provider.dart
    └── owner_reservations_provider.dart
```

**Návrh rozšíření (additivně):**
```
lib/features/owner/
├── ... (současné)
├── owner_billing_screen.dart      # [VÝHLED] Vyúčtování – placeholder, připraveno na budoucí modul
└── providers/
    └── owner_billing_provider.dart  # [VÝHLED]
```

### 3.2 GoRouter – SOUČASNÝ STAV ✅

**Soubor:** `lib/core/router/app_router.dart`

- **Cesta:** `/owner` → ShellRoute s `OwnerLayout`
  - `/owner/apartments` – `OwnerApartmentsScreen`
  - `/owner/reservations` – `OwnerReservationsScreen`
- **Redirect po přihlášení:** `role == 'property_owner'` → `'/owner/apartments'` (řádek 267)
- **Ochrana:** `property_owner` nesmí na `/admin` ani `/worker` – přesměrování na `/owner` (řádky 407–412)
- **Super Admin:** na `/worker` nebo `/owner` se přesměruje na `/super-admin` (řádek 391)

Směrování a ochrana jsou implementované.

### 3.3 Izolace přístupu

| Role            | /admin | /worker | /owner | /super-admin |
|-----------------|--------|---------|--------|--------------|
| property_owner   | ❌ → /owner | ❌ → /owner | ✅ | ❌ → /super-admin |
| admin/manager   | ✅ | ✅ | ❌ (není guard, ale nemá důvod tam jít) | ✅ (při impersonaci) |
| worker          | ❌ | ✅ | ❌ | ❌ |
| super_admin     | ✅ (impersonace) | ❌ | ❌ | ✅ |

**Poznámka:** Guard pro admin/manager na `/owner` není – pokud by měl majitel záměrně přístup blokovat, lze doplnit. Obvykle postačí, že admin nemá v menu odkaz na Owner portál.

---

## 4. Zjištěné chyby v kódu

### 4.1 owner_reservations_screen.dart – CHYBNÝ tenant_id a created_by

Při ukládání nové rezervace (řádky 255–281):

```dart
// CHYBA: tenant_id v reservations by měl být tenant_id AGENTURY (z bytu), ne auth.uid()
await client.from('reservations').insert({
  'apartment_id': _selectedApartmentId,
  'start_date': ...,
  'end_date': ...,
  // CHYBÍ: 'tenant_id': <tenant_id z apartments>
});

// CHYBA: tasks.tenant_id je UUID agentury (tenants), ne auth.uid()
await client.from('tasks').insert({
  'tenant_id': ownerId,        // ❌ ownerId = currentUser.id (auth.uid())
  ...
  'created_by': ownerId,       // created_by může být profile id – závisí na schématu tasks
});
```

**Náprava:**
1. Načíst `tenant_id` z bytu: `apartments.tenant_id` pro vybraný `_selectedApartmentId`
2. `reservations.tenant_id` = tenant_id bytu (agentury)
3. `tasks.tenant_id` = tenant_id bytu (agentury)
4. `tasks.created_by` = `profileId` majitele (z AuthNotifier) nebo auth.uid(), podle definice sloupce `created_by` v DB

### 4.2 InviteRepository – roles parsing

V `invite_repository.dart` řádek 60: `validRoles` obsahuje pouze `['admin', 'cleaner', 'driver', 'maintenance']`. Pro `property_owner` by `rolesList` zůstal prázdný a použil by se fallback `[role]` (řádek 66). Pokud `role == 'property_owner'`, `rolesList = ['property_owner']` – to je v pořádku. Stačí zajistit, aby `property_owner` byl v invitations.role při vytvoření pozvánky adminem.

---

## 5. Návrh postupu implementace (ADDITIVE)

### Krok 1: Opravit chyby v owner_reservations_screen
- Při ukládání rezervace načíst `tenant_id` z vybraného bytu (provider/dotaz na apartments)
- Doplnit `reservations.tenant_id` a `tasks.tenant_id` správnou hodnotou
- Ověřit `created_by` dle schématu `tasks`

### Krok 2: Přidat UI pro pozvání majitele
- **Varianta A:** Rozšířit „Přidat člena“ o možnost `property_owner` – jednodušší, ale majitel se objeví v týmu spolu s workers
- **Varianta B:** Samostatný flow „Pozvat majitele“ v rámci Správy bytů (např. tlačítko u bytu „Přiřadit majitele“) – čistější oddělení

Doporučení: **Varianta B** – při editaci bytu v admin_apartments_screen sekce „Majitelé“ s možností pozvat nového (email, jméno) nebo přiřadit existujícího majitele k bytu. To přidá záznamy do `apartment_owners` a případně vytvoří ghost profil + invitation.

### Krok 3: Přiřazení bytů majiteli
- V admin flow (Správa bytů / detail bytu): multi-select nebo checklist majitelů (z profiles s role=property_owner pro daný tenant) a ukládání do `apartment_owners`
- Nebo: v rámci „Pozvat majitele“ ihned vybrat byty, které mu přiřadit

### Krok 4: Ověření RLS pro pozvané majitele
- Otestovat flow: admin pozve majitele → majitel přijme pozvánku → admin přiřadí byty → majitel se přihlásí a vidí byty
- Pokud RLS selže (0 řádků), upravit politiky na `(SELECT id FROM profiles WHERE auth_id = auth.uid())`

### Krok 5: [Výhled] Placeholder pro vyúčtování
- Přidat prázdnou route `/owner/billing` (nebo podobně) v OwnerLayout
- Placeholder obrazovka „Vyúčtování – připravujeme“
- Architektura již počítá s rozšířením – stačí doplnit obrazovku a logiku bez zásahu do jádra

---

## 6. Shrnutí

| Oblast            | Stav                      | Akce                                      |
|-------------------|---------------------------|-------------------------------------------|
| apartment_owners  | ✅ Existuje               | Pouze ověřit RLS pro invited users        |
| profiles.role     | ✅ property_owner podporováno | –                                  |
| Pozvání majitele  | ❌ Chybí v admin UI       | Přidat flow v admin (byt nebo tým)         |
| Přiřazení bytů    | ❌ Chybí v admin UI       | Sekce Majitelé u bytu, zápis do apartment_owners |
| Routing / guards  | ✅ Implementováno        | –                                         |
| owner_reservations| ⚠️ Chybný tenant_id       | Opravit INSERT rezervací a tasks          |
| Vyúčtování        | –                         | Placeholder, budoucí rozšíření             |

---

*Tento dokument slouží jako základ pro implementaci Portálu majitelů s dodržením additivního vývoje a stávající architektury.*
