# Audit: Všechny vstupy vytváření záznamů v `tasks` (read-only)

**Datum auditu:** holistický průchod repozitáře (Dart + Supabase Edge Functions + migrace).  
**Cíl:** Mapovat **všechny přítoky** INSERT do `public.tasks` a odhalit nekonzistence vůči **záměru**: oddělený `scheduled_start`, `due_date` (konec okna), a **`metadata.estimated_minutes`** (nebo ekvivalent) srozumitelný pro kalendář/reporty — **ne** spoléhat na parsování textu `description`.

**Legenda shody se „standardem“ (zjednodušeně):**

| Symbol | Význam |
|--------|--------|
| ✓ | Odpovídá (interval z časů, případně metadata) |
| ~ | Částečně (např. interval OK, ale chybí `estimated_minutes` v metadata) |
| ✗ | Odchylka (stejný čas na start/konec, chybí metadata, závislost jen na popisu, …) |

---

## Přehled přítoků (INSERT)

| # | Entry point | Soubor / mechanismus | Popis |
|---|-------------|----------------------|--------|
| A | Automatický generátor (rezervace) | `admin_tasks_provider.dart` → `generateSmartTasks` | Batch insert návrhů úkolů z rezervací a katalogu služeb |
| B | Automatický generátor (scheduled) | `admin_tasks_provider.dart` → `generateScheduledTasks` | Pravidelné úkoly z `apartment_services` + interval |
| C | Ruční tvorba (Admin) | `admin_tasks_screen.dart` → `_AddTaskDialog` → `insertTaskInAdmin` | Jednotný vstup z UI; voláno z více míst (viz níže) |
| D | Worker – nahlášení závady | `issue_reporter_dialog.dart` | Přímý `insert` + offline fronta |
| E | Majitel – nahlášení závady | `owner_report_issue_dialog.dart` | Přímý `client.from('tasks').insert` |
| F | Edge Function – AI issue | `supabase/functions/process-issue-ai/index.ts` | `insert(payload)` (tělo požadavku) |
| G | Offline fronta (generátor / Admin insert) | `mutation_queue` → `drift_mutation_queue_service` | Replay `action: 'INSERT'` na `tasks` (payloady z A/B/C) |
| H | Offline issue | `offline_issue_task_processor.dart` | Volání F, ne přímý INSERT z klienta |

**Výhrady:** Operace **UPDATE** a **soft delete** na `tasks` nejsou v tomto dokumentu vstupy „vytvoření“, ale jsou v kódu četné (fakturace, mazání rezervace, worker dokončení, …).

---

## 1. Automatický generátor (návrhy z rezervací)

**Kód:** `lib/features/admin/providers/admin_tasks_provider.dart` – `generateSmartTasks` → `SupabaseService.safeFrom('tasks', …).insert(toInsert)` (případně fronta při offline).

**Jak vznikají `scheduled_start` a `due_date`:**  
Z výpočtu okna služby: `taskStart` / `taskEnd` z kotvy rezervace (check-in/out, trigger) a délky `_taskDurationMinutes` / `pickAssigneeWithCollisionAvoidance` → `result.start` / `result.end` → do payloadu jako ISO řetězce **`scheduled_start`** a **`due_date`** (odlišné, když je nenulové trvání).

**`metadata['estimated_minutes']`:**  
V auditovaném `toInsert` **není** ukládán `estimated_minutes` / `estimate_minutes` — metadata obsahuje např. `requires_photo`, `payer_type`, ceny, částky, `flight_number`, atd. **→ nekonzistence vůči „standardu“ s explicitním odhadem v JSONB.**

**`description`:**  
Ano – generuje se text přes `getEstimateMinutesText` / `admin.task_estimate_minutes` s **číslem minut** (`effectiveDuration`), takže odhad je **v textu popisu**, ne v metadatech.

| Shoda se standardem | ~ (časové okno OK, metadata odhad chybí) |

---

## 2. Automatický generátor (scheduled údržba / opakující se)

**Kód:** `generateScheduledTasks` ve stejném souboru; druhý batch insert.

**Časy:** `scheduled_start` = `result.start`, `due_date` = `result.end` (po `taskStart`/`taskEnd` z intervalu služby).

**`metadata['estimated_minutes']`:**  
Opět **ne** – jen `scheduledMetadata` (foto, cena, plátce, …).

**`description`:**  
Lokalizovaný text s minutami (`totalMinutes`).

| Shoda se standardem | ~ |

---

## 3. Ruční tvorba – s apartmánem (Admin / kalendář / rezervace / klient / byt)

**Jednotná implementace INSERT:** `AdminTasksNotifier.insertTaskInAdmin` v `admin_tasks_provider.dart` (payload z dialogu).

**Volání `AdminTasksScreen.showAddTaskDialog` (stejný `_AddTaskDialog` / `_onSave`):**

| Místo volání | Soubor (řádky cca) |
|--------------|-------------------|
| Nástěnka / rychlé přidání | `admin_dashboard_screen.dart` |
| Související úkoly u rezervace | `admin_reservation_forms.dart` |
| Kontext bytu | `admin_apartments_screen.dart` |
| Detail klienta (externí/agency + předvyplnění) | `client_detail_dialog.dart` |
| Seznam úkolů | `admin_tasks_screen.dart` (FAB) |

**Chování:** Po nedávné úpravě dialogu: **`scheduled_start`** a **`due_date`** = začátek + trvání; **`metadata`** merge včetně **`estimated_minutes`**.  
**Žádný další samostatný INSERT** „ručního“ úkolu s apartmánem v auditovaných souborech nenalezen (rezervační formulář jen **soft-delete** / update úkolů, ne nový insert).

| Shoda se standardem | ✓ (po zamýšlené konvenci: start, end, metadata) |

---

## 4. Ruční tvorba – externí úkoly (bez apartmánu)

**Stejný dialog:** `_AddTaskDialog` v `_TaskFormMode.externalService` – `apartment_id` null, `client_id`, `custom_title`, `custom_location`, `metadata` (hotovost, …).

**Trvání:** Stejná jako u vázaného úkolu – **plánovaný začátek + minuty** → `due_date`; **`estimated_minutes`** v metadata.  
**Časové okno** tedy existuje (není „jen den bez času“), pokud uživatel vyplní konkrétní datum/čas v pickeru.

| Shoda se standardem | ✓ (stejný jako bod 3) |

---

## 5. Worker – Issue reporter (závažnost v bytě)

**Kód:** `lib/features/worker/widgets/issue_reporter_dialog.dart` – payload s **`due_date`** a **`scheduled_start`** na **stejný** čas (`now` UTC), **`metadata`**: prázdný map `{}`.

**Důsledek:** Interval **0 minut** v DB; kalendář/reporty spoléhající na rozdíl start–konec nebo na metadata **nedostanou** smysluplné trvání; odhad není v popisu ani v metadatech.

| Shoda se standardem | ✗ |

---

## 6. Majitel – Report issue (Klientský portál)

**Kód:** `lib/features/owner/widgets/owner_report_issue_dialog.dart` – přímý insert.

**Časy:** `scheduled_start` = **now**; `due_date` = **now + 3 dny** (jiný okamžik než start).  
**Metadata:** **nevyplněno** v insert mapě (žádné `estimated_minutes`).  
**Popis:** volitelný text uživatele – **ne** strukturovaný odhad minut.

**Poznámka:** Po INSERTu může **PostgreSQL trigger** `owner_issue_notification_trigger` vložit řádky do `notifications` — **ne** nové řádky do `tasks`.

| Shoda se standardem | ~ až ✗ (okno je „dlouhé“ 3 dny, ale bez `estimated_minutes`; nesoulad s významem „délka služby“ u ostatních toků) |

---

## 7. Edge Functions a automatizace

| Soubor | INSERT do `tasks`? | Poznámka |
|--------|----------------------|----------|
| `supabase/functions/process-issue-ai/index.ts` | **Ano** | `insert(payload)` z těla HTTP – **struktura závisí na volajícím** (typicky offline issue / voice). Musí obsahovat `tenant_id` atd.; **není garantovaný** `estimated_minutes` ani konzistentní pár start/end. |
| `supabase/functions/template-reminders/index.ts` | Ne | SELECT `tasks` (připomínky transferů) |
| `supabase/functions/daily-task-summary/index.ts` | Ne | SELECT `tasks` (souhrn na den) |
| `supabase/functions/automation-enqueue/index.ts` | Ne | SELECT `tasks` / `reservations` → fronta zpráv, **nevytváří** úkoly |

**`automation_rules_repository` / fronta:**  
Vytváří záznamy v **`automation_message_queue`** (a pravidla v `automation_rules`), **ne** INSERT do `tasks`.

---

## 8. Databázové triggery

**`20260313100000_owner_issue_notification_trigger.sql`:**  
AFTER INSERT na `tasks` → INSERT do **`notifications`**. **Žádný** INSERT nových řádků do `tasks`.

---

## 9. Lokální Drift / offline replika

**`packages/falconest_drift` / `drift_task_repository.dart`:**  
INSERT do **lokální** tabulky `tasks` v zařízení (offline-first replika). **Není** to přímý Supabase INSERT; synchronizace jde jinými cestami (update workeru, fronta).  
V auditu **„přítoků do DB“** na serveru jako samostatná kategorie **volitelná**.

---

## Shrnutí nekonzistencí (proti jednotnému standardu)

| Oblast | Problém |
|--------|---------|
| **generateSmartTasks / generateScheduledTasks** | `scheduled_start`/`due_date` **správně oddělené**, ale **`metadata.estimated_minutes` chybí**; odhad jen v **`description`**. |
| **Worker issue** | **`scheduled_start` = `due_date`**, prázdné metadata → **nulové plánované trvání** z hlediska intervalu/metadata. |
| **Majitel report** | `due_date` jako **+3 dny** od startu; **bez `estimated_minutes`**; sémantika jiná než „délka úkolu v minutách“. |
| **process-issue-ai** | Obecný INSERT – **žádná aplikační garance** konzistence časů/metadata bez smluvního payloadu. |

**Počet významných serverových přítoků INSERT:** **4** primární cesty (generátor smart, generátor scheduled, `insertTaskInAdmin`, issue reporter worker + majitel + EF jako varianty) + **replay** fronty (stejné payloady) + **EF** jako externí.

---

*Tento dokument neobsahuje návrhy oprav – pouze mapu stavu kódu.*
