# Audit: Implementace Klientů (Clients) v FalcoNest

> **Datum analýzy:** 3. března 2026  
> **Účel:** Před úpravami UI a byznys logiky získat kompletní přehled aktuálního stavu implementace tří typů klientů: Majitel, Agentura, Externí.

---

## 1. DATABÁZOVÝ MODEL (Supabase)

### 1.1 Struktura tabulky `clients`

| Sloupec    | Typ                     | NULL? | Popis |
|------------|-------------------------|-------|-------|
| `id`       | uuid (PK)               | NO    | `DEFAULT gen_random_uuid()` |
| `tenant_id`| uuid (FK → tenants)     | NO    | Multi-tenant izolace |
| `name`     | text                    | NO    | Jméno klienta |
| `email`    | text                    | YES   | E-mail |
| `phone`    | text                    | YES   | Telefon |
| `client_type` | text                  | **YES** | Typ: `owner`, `external`, `agency` |
| `profile_id`  | uuid (FK → profiles)   | YES   | Propojení s přihlašovacím profilem (Klientský portál majitelů) |
| `created_at`  | timestamptz           | YES   | `DEFAULT now()` |
| `deleted_at`  | timestamptz           | YES   | Soft delete; NULL = aktivní |

**Migrace:** `supabase/migrations/20260230000000_clients_and_external_tasks.sql`

### 1.2 Definice tří typů – NENÍ Postgres ENUM

- **Typ v DB:** Obyčejný sloupec `text` (nullable).
- **Žádný CHECK constraint** – databáze nekontroluje povolené hodnoty.
- **Žádný Postgres ENUM** – hodnoty jsou volně textové.
- **Oficiální hodnoty** (dle komentářů v migraci):
  - `'owner'` – Majitel (vlastník bytů)
  - `'external'` – Externí klient (bez apartmánů)
  - `'agency'` – Agentura (partnerská agentura)

**Poznámka:** Pokud by uživatel zadal jinou hodnotu (např. `'custom'`), DB ji přijme. Validace je pouze v aplikační vrstvě (Flutter dropdown).

### 1.3 Vazby na další tabulky

| Tabulka            | Vazba                         | Popis |
|--------------------|-------------------------------|-------|
| **tasks**          | `tasks.client_id` → `clients.id` | Externí úkoly bez `apartment_id` – fakturace klientovi |
| **client_addresses** | `client_addresses.client_id` → `clients.id` | Adresář adres (typicky pro `agency`) – transfery |
| **billing_snapshots** | `billing_snapshots.client_id` → `clients.id` | Zmražená vyúčtování pro majitele |
| **profiles**       | `clients.profile_id` → `profiles.id` | Pro majitele – Klientský portál |

### 1.4 Nepřímá vazba klient → apartmány

**Není přímá FK `clients` ↔ `apartments`.** Propojení:

```
clients (owner) ← profile_id → profiles
                              ↑
                    apartment_owners.owner_id
                              ↓
                         apartments
```

- Majitel (client s `client_type = 'owner'`) má `profile_id`.
- Tabulka `apartment_owners` propojuje `apartment_id` s `owner_id` (= `profiles.id`).
- Apartmány tedy patří majiteli **přes profil**, ne přímo přes záznam v `clients`.

---

## 2. DART MODELY A LOGIKA

### 2.1 Hlavní model – `ClientModel`

**Soubor:** `lib/core/models/client_model.dart`

```dart
class ClientModel {
  final String id;
  final String tenantId;
  final String name;
  final String? email;
  final String? phone;
  final String? clientType;   // owner | external | agency
  final String? profileId;    // pro majitele – Klientský portál
  final DateTime? createdAt;
  final DateTime? deletedAt;
}
```

- `clientType` je `String?` – může být null (staré záznamy, ruční vklady).
- Mapování Supabase: `client_type` → `clientType`.

### 2.2 Mapování typu na UI štítek

**Lokalizované klíče (i18n):**

| DB hodnota  | i18n klíč           | cs.json | en.json   | es.json    |
|-------------|---------------------|---------|-----------|------------|
| `owner`     | `clients.type_owner` | Majitel | Owner     | Propietario |
| `external`  | `clients.type_external` | Externí | External | Externo     |
| `agency`    | `clients.type_agency`  | Agentura | Agency  | Agencia     |

**Kód mapování:**
- `admin_clients_screen.dart`: `_clientTypeLabel(context, client.clientType)` – switch podle `clientType.toLowerCase()`.
- `client_form_dialog.dart`: konstanta `_clientTypeOptions = [('owner', '…'), ('external', '…'), ('agency', '…')]` – dropdown.

**Barvy badge:** `_badgeColor(clientType)` – teal (owner), modrá (external), fialová (agency), šedá (default).

### 2.3 Byznys logika odlišující typy

| Typ      | Specifické chování |
|----------|---------------------|
| **owner** | • Má `profile_id` → Klientský portál, zvací odkaz<br>• Zobrazí se tab **Apartmány** (přes `apartment_owners`)<br>• Zobrazí se tab **Rezervace** (přes byty majitele)<br>• Tab **Úkoly** – úkoly na jeho bytech (`apartment_id IN apartments`)<br>• Při přidání úkolu: `initialApartmentId` → režim „Vázáno na apartmán“<br>• Badge „Čeká na aktivaci“ pokud owner bez `profile_id` |
| **agency** | • Zobrazí se **Adresář adres** (`_AddressDirectorySection`) – `client_addresses`<br>• Tab **Úkoly** – úkoly s `tasks.client_id = clientId`<br>• Při přidání úkolu: `initialClientId` → režim „Externí služba“ |
| **external** | • Tab **Úkoly** – úkoly s `tasks.client_id = clientId`<br>• Při přidání úkolu: `initialClientId` → režim „Externí služba“ |

**Provider `clientReservationsProvider`:**
- Vrací rezervace **jen pro majitele** s `profile_id`.
- Pro `external`/`agency` vrací prázdný seznam.

**Provider `clientTasksProvider`:**
- **Owner + profile_id:** úkoly na bytech majitele (`apartment_id IN apartmentIds`).
- **External/Agency:** úkoly s `client_id = clientId` (externí služby).

**Přiřazení majitele k bytu** (`admin_apartments_screen.dart`):
- Dropdown „Přiřadit majitele z klientů“ filtruje pouze klienty s `client_type == 'owner'`.

---

## 3. LOKÁLNÍ DATABÁZE (Offline-First / Drift)

### 3.1 Drift tabulka `Clients`

**Soubor:** `packages/falconest_drift/lib/app_database.dart`

```dart
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get phone => text().nullable()();
}
```

### 3.2 `client_type` v lokální DB **neexistuje**

- **Chybí sloupce:** `client_type`, `email`, `profile_id`.
- **Důvod:** Drift klienti slouží primárně **Worker aplikaci** – pro offline zobrazení jména a telefonu u externích úkolů (řidič, transfer).
- **Repozitář:** `DriftClientRepository` mapuje ze Supabase pouze: `id`, `tenant_id`, `name`, `phone`.

**Důsledek:** V offline módu Worker nezná typ klienta (Majitel/Agentura/Externí). Pro admin UI se klienti načítají přímo ze Supabase (`clientsProvider`), ne z Drift.

---

## 4. SOUHRN – Co je kde

| Aspekt | Supabase | Dart (ClientModel) | Drift (lokální) |
|-------|----------|-------------------|------------------|
| client_type | text, nullable, bez CHECK | String? clientType | **chybí** |
| Hodnoty | owner, external, agency | stejné | – |
| UI štítek | – | _clientTypeLabel → i18n | – |
| Fakturace | tasks.client_id, billing_snapshots | – | – |
| Adresář | client_addresses (agency) | – | – |

---

## 5. DOPORUČENÍ PRO BUDOUCÍ ÚPRAVY

1. **DB validace:** Přidat `CHECK (client_type IS NULL OR client_type IN ('owner','external','agency'))` pro konzistenci.
2. **Drift rozšíření:** Při potřebě offline zobrazení typu klienta v Workeru přidat `client_type` do Drift tabulky `Clients` a do sync logiky.
3. **Jednotný mapping:** Zvážit enum `ClientType` v Dartu s `extension` pro i18n, aby se zabránilo duplicitám `_clientTypeLabel` ve více souborech.
