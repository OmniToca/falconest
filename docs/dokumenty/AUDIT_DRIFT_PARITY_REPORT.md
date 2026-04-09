# Audit parity: Worker sync vs Supabase vs Drift (read-only)

**Datum auditu:** 2026-03-28  
**Rozsah:** Mobilní Worker (offline-first), `WorkerSyncService` (mobilní), tabulky Drift v balíčku `packages/falconest_drift/lib/app_database.dart`, referenční schéma `docs/ai_context/database_schema.md` (srovnáno s `realna_db.csv`).

**Metodologie:** Porovnání sloupců dokumentovaného Supabase schématu s (a) řetězci `.select()` v `lib/features/worker/data/services/worker_sync_service_mobile.dart`, (b) definicemi tabulek Drift, (c) mapováním v repozitářích (`upsertFromSupabaseMap`, `upsertTaskFromSupabaseMap`, checklist upserty). **Žádné úpravy kódu** – pouze diagnostika.

**Poznámka k očekávání:** Worker záměrně nepoužívá plnou kopii všech tenant tabulek; cílem auditu je odhalit místa, kde by personál v terénu mohl **postrádat data, která na serveru existují a UI je u jiných rolí může potřebovat**, nebo kde **parita schématu** brání budoucím funkcím (např. komunikační indikátory, jazyk šablon).

---

## 1. Globální pozorování ke `WorkerSyncService`

- **Časové okno úkolů:** Stažení je omezeno na `scheduled_start` mezi −7 a +14 dny od „teď“ (UTC). Úkoly mimo okno se do Driftu v rámci sync nedostanou (záměr výkonu / rozsahu).
- **Filtry dotazu na `tasks`:** `assigned_to` nebo `assigned_user_ids` obsahuje workera; `status != 'pending'`; `deleted_at IS NULL`; **`invoiced_at IS NULL`** – fakturované úkoly se workerovi v pull vůbec nestáhnou.
- **`scheduled_start`:** Ve schématu je NOT NULL; filtr `.gte/.lte('scheduled_start', …)` je konzistentní. Sloupec **`due_date`** (text, nullable) na serveru existuje, ale **není v pull selectu ani v Drift `Tasks`** – pokud by někdy business logika spoléhala na `due_date` odděleně od `scheduled_start`, mobil by ho neměl.
- **Push vs pull u `tasks`:** Při konfliktu se pro merge volá `_fetchCurrentTaskFromServer` s vlastním selectem včetně **`updated_at`**; tento sloupec **není v hlavním pull selectu** a **v tabulce `Tasks` v Driftu nemá dedikovaný sloupec** – merge používá `lastSyncedAt` z lokálního řádku, ne persistované `server.updated_at` po úspěšném pullu. To je konzistentní se současnou implementací, ale není to „plná“ serverová kopie časové značky v SQLite.

---

## 2. Tabulka `tasks`

### 2.1 Sloupce stažené při sync (pull)

Select (zjednodušeně): `id`, `tenant_id`, `apartment_id`, `client_id`, `custom_location`, `custom_title`, `reference_number`, `reservation_id`, `assigned_to`, `assigned_user_ids`, `title`, `description`, `task_type`, `scheduled_start`, `status`, `photo_url`, `metadata`, `media_urls`, `started_at`, `completed_at`, `invoiced_at`.

### 2.2 Sloupce v Supabase, které pull neobsahuje (a v Drift `Tasks` typicky také nejsou)

| Sloupec (Supabase) | Poznámka |
|--------------------|----------|
| `assigned_user_id` | Legacy / vedle `assigned_to`; worker filtr používá `assigned_to` + `assigned_user_ids`. |
| `local_updated_at` | Klientská/serverová sémantika – v Drift je vlastní `localUpdatedAt` / `lastSyncedAt`. |
| `due_date` | Text; není v selectu ani v Drift. |
| `service_id` | Vazba na službu; worker UI ho dnes neukládá. |
| `created_by` | Autor; offline detail ho nepotřebuje. |
| `deleted_at` | Soft delete – řádky se přes filtr nestahují (správně). |
| `updated_at` | Použit jen v `_fetchCurrentTaskFromServer` při push merge; **nepersistuje se** do Drift jako serverové `updated_at`. |
| `unassigned_info` | JSONB; admin kontext; worker pull chybí. |
| `last_communication_template_id` | UUID šablony poslední komunikace. |
| `last_communication_template_context` | Text kontextu. |
| `last_communication_at` | Časová značka. |

**Riziko pro offline-first (produkt):** Pokud má Worker zobrazovat stav „komunikace k úkolu“ (jako admin), **tato trojice sloupců na mobil není** – ani select, ani Drift.

### 2.3 Shoda pull ↔ Drift (hlavní pole)

Mapování v `DriftTaskRepository` pokrývá stažená pole včetně `media_urls` → `mediaUrlsJson`. **Žádný sloupec z aktuálního worker pull selectu nevyplývá jako „stáhne se, ale Drift zahodí“** u základních polí úkolu.

---

## 3. Tabulka `apartments`

### 3.1 Worker select

`id`, `tenant_id`, `name`, `address`, `code`, `keybox`, `owner_notes`, `check_in_time`, `check_out_time`, `zone_id` (+ filtr `deleted_at IS NULL`).

### 3.2 Supabase sloupce mimo worker select / Drift `Apartments`

Podle `database_schema.md` na serveru dále existují mimo jiné:

- `status`
- `standard_cleaning_duration`
- `monthly_management_fee`
- `managed_from`
- `parking_instructions`
- `review_link`

**V Drift tabulce `Apartments` tyto sloupce nejsou** a **worker je nestahuje**.

**Riziko pro terén:** Instrukce k parkování, odkaz na recenzi, stav bytu nebo délka standardního úklidu **nejsou offline dostupné** z lokální DB, i když admin je v Supabase má vyplněné.

---

## 4. Tabulka `reservations`

### 4.1 Worker select

`id`, `tenant_id`, `reference_number`, `status`, `guest_name`, `guest_phone`, `special_requests`.

### 4.2 Supabase – významné sloupce mimo worker sync a mimo Drift `Reservations`

Drift u rezervace drží jen: `supabaseId`, `tenantId`, `status`, `guestName`, `guestPhone`, `referenceNumber`, `specialRequests`, plus lokální `localUpdatedAt`, `syncStatus`, `lastUpdated`.

**Na serveru navíc (ne v pull, ne v Drift):** mimo jiné `apartment_id`, `start_date`, `end_date`, `check_in`, `check_out`, `needs_transfer`, `guest_adults`, `guest_children`, `arrival_time`, `departure_time`, `internal_note`, `agency_collects_payment`, `external_uid`, `reservation_source`, `last_communication_template_context`, `last_communication_at`, `last_communication_template_id`, `guest_language`, `is_owner_block`.

**Riziko:** Worker detail doplňuje z rezervace hlavně hosta a `special_requests` – to sedí se současným modelem `WorkerTaskDetail`. **Kalendářní kontext pobytu (datumy, příjezd/odjezd, jazyk hosta, owner block, interní poznámka)** v offline režimu **není** v SQLite.

**Push:** `pushPendingReservationUpdates` odesílá jen `{ status }` – ostatní sloupce rezervace worker nemění (očekávané).

---

## 5. Tabulka `clients`

### 5.1 Worker select

`id`, `tenant_id`, `name`, `phone`.

### 5.2 Supabase navíc (typicky nepotřeba pro současný Worker detail)

`email`, `client_type`, `language_code`, `profile_id`, `agency_id`, `created_at` – **nejsou v selectu ani v Drift `Clients`**.

**Riziko:** Šablony zpráv / personalizace podle **`language_code`** klienta offline **nejsou** (pokud by se v budoucnu měly odvíjet od klienta, ne jen od šablony).

---

## 6. Tabulka `tenant_message_templates`

### 6.1 Worker select

`id`, `tenant_id`, `key`, `name`, `channel`, `email_subject`, `translations`, `trigger_context`, `order_index` (+ `deleted_at IS NULL`).

### 6.2 Parita s Drift `MessageTemplates`

Sloupce Drift odpovídají staženým polím (včetně `translations` → `translationsJson`). **`created_at` a `deleted_at` z Supabase** nejsou v Drift tabulce – `deleted_at` se používá jen jako filtr dotazu (správně).

**Mezera:** Pro budoucí „incremental sync“ šablon podle `updated_at`/`created_at` **chybí lokální uložení serverových časových razítek**.

---

## 7. Tabulky `task_checklists` a `task_checklist_items`

### 7.1 Select (embed + fallback)

Hlavička: `id`, `tenant_id`, `task_id`, `template_id`, `created_at`, `updated_at` + vnořené položky včetně `created_at`, `updated_at`.

### 7.2 Drift vs odpověď serveru

- Tabulky `TaskChecklists` / `TaskChecklistItems` mají **`localUpdatedAt`**, **`syncStatus`**, ale **nemají sloupce `serverCreatedAt` / `serverUpdatedAt`**.
- V `upsertChecklistFromSupabaseMap` / `upsertItemFromSupabaseMap` se **`created_at` a `updated_at` ze serveru do dedikovaných sloupců neukládají** (hodnoty z JSON se pro tento účel zahodí).

**Dopad:** Funkčně stačí pro zobrazení a odškrtávání; **pro diagnostiku konfliktů nebo přesné „last modified na serveru“** offline chybí.

---

## 8. Tabulka `tenants`

Worker volá `from('tenants')` **bez** `safeFrom` (globální tabulka z pohledu konvence projektu – mimo tento audit RLS detailně) a stahuje **`id`, `currency`**.

Supabase má řadu dalších sloupců (`name`, `integration_settings`, billing, …). **Záměrný minimální subset** pro formátování měny offline – **ne jde o chybu parity**, pokud Worker nepotřebuje zbytek.

---

## 9. Tabulky mimo worker sync (informativně)

Následující entity **nejsou** součástí popsaného worker pullu (a v Drift worker DB ani nejsou): např. `checklist_templates`, `tenant_message_log`, `employee_cash_*`, `automation_*`, atd. To odpovídá úzkému účelu worker DB; **není to nesrovnalost**, dokud produkt nepožaduje jejich offline čtení.

---

## 10. Závěr

- **Základní řetězec úkol → byt → rezervace → klient → šablony** je u worker selectu a Drift **konzistentní pro současné DTO** (`WorkerTask`, `WorkerTaskDetail`).
- **Největší „produktové“ mezery** (data na serveru, která worker v terénu nemá):  
  - komunikační metadata u **`tasks`** a **`reservations`** (`last_communication_*`),  
  - rozšířené údaje u **`apartments`** (parkování, review, stav, délka úklidu, …),  
  - kalendářní a provozní pole u **`reservations`** (datumy pobytu, arrival/departure, `guest_language`, `is_owner_block`, interní poznámka, …),  
  - **`clients.language_code`** a související kontext.
- **Technická mezera parity:** serverová `updated_at` u úkolů při pullu se neukládá do Drift; serverová `created_at`/`updated_at` u checklistů se po stažení nepersistují do vlastních sloupců.

Žádný rozpor typu „select vrací sloupec, Drift tabulka ho nemá a mapování padá“ u **aktuálně vybraných** worker sloupců nebyl v této analýze identifikován; jde především o **záměrně úzký subset vs plné Supabase schéma** a o body výše označené jako riziko pro budoucí / pokročilé offline funkce.
