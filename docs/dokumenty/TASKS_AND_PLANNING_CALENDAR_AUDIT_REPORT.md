# Hloubkový audit: Úkoly (Task List) a Plánovací kalendář (Planning Calendar)

**Datum:** 3. 3. 2026  
**Rozsah:** Výkon, byznys logika, propojení s financemi, i18n. **Žádné změny v kódu** – pouze analýza a doporučení.

---

## 1. Kapacita a výkon (tisíce úkolů v čase)

### 1.1 Z jakých providerů čerpá záložka „Úkoly“ a z jakých „Kalendář“?

| Pohled | Provider | Zdroj dat |
|--------|----------|-----------|
| **Záložka Úkoly** | `adminTasksStreamProvider` | `AdminTasksRepository.instance.watchTasksRaw(tenantId)` – Realtime stream z tabulky `tasks` (Supabase), initial fetch + WebSocket. |
| **Plánovací kalendář (týden)** | `planningCalendarDataProvider(weekStart)` | Závisí na `planningCalendarAllTasksProvider(weekStart)` – jednorázový `FutureProvider` s dotazem na `tasks` pro daný týden. |
| **Plánovací kalendář (měsíc)** | `planningCalendarDataForMonthProvider(dayInMonth)` | Závisí na `planningCalendarAllTasksForMonthProvider(dayInMonth)` – jednorázový dotaz na `tasks` pro daný měsíc. |
| **Nástěnka** | `adminDashboardTasksProvider` | `watchTasksForDashboard(tenantId, from, to)` – Realtime stream s **časovým oknem** (včera 00:00 → dnes + 14 dní), limit 300. |

**Shrnutí:** Úkoly = jeden globální stream (limit 500). Kalendář = oddělené dotazy podle **týdne** resp. **měsíce** (časové okno na serveru).

---

### 1.2 Stahují se všechny úkoly tenanta najednou? Je tam časové okno?

- **Záložka Úkoly**
  - **Ne** – nestahují se všechny úkoly. Používá se `.limit(500)` a řazení `scheduled_start DESC`.
  - **Žádné časové okno** – filtr je pouze `tenant_id`, `deleted_at IS NULL`, `invoiced_at IS NULL`. Do klienta tedy přijde **maximálně 500 nejnovějších úkolů** podle `scheduled_start` (bez ohledu na to, zda jsou v minulosti nebo v budoucnu).
  - Lokální filtr v UI: `_dateFilter` (Vše / Dnes / Zítra) a vyhledávání – aplikují se **až na již načtených 500 záznamech**.

- **Plánovací kalendář**
  - **Ano, časové okno je**:
    - Týden: `scheduled_start >= weekStart` a `< weekEnd` (7 dní).
    - Měsíc: `scheduled_start` v rámci daného měsíce.
  - Při přepnutí týdne/měsíce se volá nový dotaz jen pro zobrazené období.

- **Nástěnka**
  - Časové okno: včera 00:00 → dnes + 14 dní, limit 300.

**Závěr:** Kalendář je z hlediska výkonu v pořádku (načítání po týdnu/měsíci). Záložka Úkoly načítá fixně 500 úkolů bez časového omezení – při velkém objemu dat uživatel nevidí starší úkoly a nemá možnost „načíst další“.

---

### 1.3 Riziko OOM nebo extrémního zpomalení při 5000+ dokončených úkolech?

- **Záložka Úkoly**
  - **OOM nepravděpodobné** – vždy max 500 záznamů (TaskRow). Paměťově únosné.
  - **Riziko:** Pokud má agentura tisíce úkolů a většina má `scheduled_start` v minulosti, uživatel vidí jen „vrchních“ 500 podle tohoto řazení. Starší dokončené úkoly (např. z minulého roku) v seznamu **neuvidí** – nejde o pád, ale o neúplná data a chybějící paginace / filtr podle data.

- **Kalendář**
  - Načítá jen úkoly daného týdne/měsíce. Ani při 5000 úkolech v DB se do jednoho pohledu nedostane víc než řádově stovky záznamů. **OOM ani výrazné zpomalení se neočekává.**

- **Nástěnka**
  - Limit 300 + časové okno → bezpečné.

**Doporučení:** Úkoly připravit na škálování: **paginace nebo časové okno** (např. výchozí zobrazení „tento měsíc + příští měsíc“) a volitelně „Načíst starší“ místo fixního limitu 500 bez kontextu data.

---

## 2. Byznys logika a Drag & Drop

### 2.1 Je v kalendáři implementované přesouvání úkolů (Drag & Drop)?

**Ne.** V kódu plánovacího kalendáře (`lib/features/calendar/screens/planning_calendar_screen.dart`, související widgety) **není** použit `Draggable` / `LongPressDraggable` ani `DragTarget`. Jediná interakce s úkolem je **tap na kartu úkolu** (`onTap`), která otevře **dialog pro editaci úkolu** (`AdminTasksScreen.showEditTaskDialog`). Změna data nebo přiřazení tedy probíhá **ručně v dialogu**, ne přetažením v mřížce.

**Shrnutí:** Drag & Drop v plánovacím kalendáři **není implementováno**. Přesun na jiný den / jiného pracovníka lze pouze úpravou úkolu v edit dialogu.

---

### 2.2 Uložení změny (den / pracovník) do Supabase

- Po uložení v `_EditTaskDialog` se volá `ref.read(adminTasksProvider.notifier).updateTaskInAdmin(taskId, updateFields)`.
- `updateTaskInAdmin` provádí `SupabaseService.client.from('tasks').update(updateFields).eq('id', taskId).eq('tenant_id', tenantId)`.
- Při síťové chybě se použije offline fronta mutací (`enqueueMutation`) a optimistická aktualizace lokálního stavu.

**Závěr:** Změna data nebo přiřazení z dialogu **se ukládá do Supabase** (nebo do fronty při offline). Samotné uložení je v pořádku; chybí pouze D&D v UI a níže popsaná ochrana vyplacených úkolů.

---

### 2.3 OCHRANA FINANCÍ: Úpravy úkolů s výplatami a provizemi

- V modulu Vyúčtování (Settlements) existuje `getTaskIdsWithPayouts(tenantId)` a provider `taskIdsWithPayoutsProvider`, který vrací množinu ID úkolů, které **už mají záznam v `task_payouts`**. Tato množina se používá v **frontě „Ke schválení“** – úkoly s výplatou se z fronty skryjí.
- V **dialogu editace úkolu** (`_EditTaskDialog`) je zámek editace odvozen **pouze od statusu**:
  - `isReadOnly = (_normalizeToSystemStatus(widget.task.status) == 'completed')`.
- **Nikde v kódu** (admin tasks provider, repository, kalendář, edit dialog) **není kontrolováno**, zda úkol má záznamy v `task_payouts` nebo `task_commissions`. Blokace úprav tedy **není vázaná na vyplacení**, ale jen na to, zda je status „dokončeno“.

**Rizika:**

1. Pokud by se status dokončeného úkolu změnil (např. chybou nebo budoucím API) na jiný, zámek by zmizel a úkol by šel znovu editovat – včetně data a přiřazení – i když už má výplaty/provize.
2. Úpravy úkolu, který už má záznamy v `task_payouts`/`task_commissions`, mohou rozbít konzistenci účetnictví (změna data, přiřazení, bytu bez úprav výplat).

**Doporučení:** Zámek editace **rozšířit o finance**: pokud `taskIdsWithPayoutsProvider` (příp. i úkoly s `task_commissions`) obsahuje dané `task.id`, považovat úkol za **uzamčený** bez ohledu na status (nebo v backendu/RLS zakázat update vyplacených úkolů).

---

## 3. i18n a hardcoded texty

### 3.1 Admin Tasks (Úkoly)

| Soubor | Typ | Text / kontext |
|--------|-----|----------------|
| `admin_tasks_provider.dart` | StateError | `'Chybí tenant_id'` |
| `admin_tasks_provider.dart` | Status (logika) | `s == 'hotovo' \|\| s == 'dokončeno'` v `_isCompletedStatus`; `'návrh'`, `'Návrh'`, `'pending'`, `'draft'` jinde – jde o **byznys hodnoty** z DB, ne UI; pro konzistenci by měly vycházet z jednoho zdroje (např. konstanty nebo i18n klíče pro hodnoty). |
| `admin_tasks_provider.dart` | print (debug) | `'--- CHYBÍ SLOUPCE V TABULCE tasks...'`, `_buildAlterTableSql()` – pouze debug, ale české texty. |
| `settlements_provider.dart` | StateError | `'Nelze schválit vyúčtování bez tenant ID.'` |

UI texty v `admin_tasks_screen.dart` (prázdný stav, chyby, tlačítka) jsou vedeny přes `.tr()` (např. `admin.tasks_empty`, `admin.tasks_load_error`, `admin.task_saved`, `tasks.task_locked_info`).

### 3.2 Plánovací kalendář

| Soubor | Typ | Text / kontext |
|--------|-----|----------------|
| `planning_calendar_provider.dart` | Fallback v parsování | V `_parseTasksFromResponse`: `workerName = 'Nepřiřazeno'`, `aptName = 'Neznámý'`, `taskType ?? 'Jiné'` – **hardcoded české** řetězce. V UI se pro řádek „Nepřiřazeno“ už používá `planning_calendar.unassigned_row`.tr(), ale v datové vrstvě zůstávají české fallbacky. |
| `planning_calendar_provider.dart` | Parsování délky | `parseDurationMinutesFromDescription` – regex `(\d+)\s*hod` a `(\d+)\s*min` – závisí na českém tvaru v popisu; v multijazyčné verzi by mohlo selhat. |
| `planning_calendar_screen.dart` | Dny v týdnu | Používá `_dayKeys` s i18n klíči `planning_calendar.mon` … `planning_calendar.sun` – **v pořádku**. |

**Shrnutí:** V providerech a v byznys logice jsou stále **hardcoded české texty** (chybové hlášky, fallbacky „Nepřiřazeno“, „Neznámý“, „Jiné“, regex pro „hod“/„min“). Doporučuje se přesunout do i18n a pro hodnoty statusů/typů používat jednotný zdroj (konstanty / klíče).

---

## 4. Návrh architektury (bez implementace)

### 4.1 Výkon a načítání dat

- **Záložka Úkoly**
  - Zavést **časové okno** na straně serveru (např. výchozí: od „dnes − 1 měsíc“ do „dnes + 2 měsíce“) a **paginaci** nebo tlačítko „Načíst starší / mladší“, aby se nikdy nenačítalo „vše“ a zároveň byl přístup k historii předvídatelný.
  - Případně druhou větev: „Archiv úkolů“ s vlastním endpointem/providerem s filtrem např. po roce/měsíci a stránkováním.

- **Kalendář**
  - Ponechat načítání po týdnu/měsíci; při přepnutí období invalidovat příslušný provider (`planningCalendarAllTasksProvider` / `planningCalendarAllTasksForMonthProvider`) a načíst pouze nové období. Současný návrh tomu odpovídá.

### 4.2 Ochrana financí (vyplacené úkoly)

- **Zámek na úrovni UI:** V `_EditTaskDialog` (a všude, kde se úkol edituje) kromě `status == completed` kontrolovat i to, zda `task.id` je v množině z `taskIdsWithPayoutsProvider` (a případně úkoly s provizemi). Pokud ano → **read-only** a zobrazit hlášku typu „Úkol již byl vyúčtován; úpravy nejsou povoleny.“.
- **Zámek na úrovni backendu (doporučeno):** V RLS nebo v API (Edge Function / trigger) **zakázat UPDATE** u úkolů, které mají alespoň jeden záznam v `task_payouts` nebo `task_commissions` (nebo pouze povolit změny určitých polí, která neovlivní vyúčtování). Tím se ochrana nezávisí na klientovi.

### 4.3 Drag & Drop v kalendáři (budoucí feature)

- Přetažení karty úkolu na jiný den nebo na jiný řádek (pracovníka) by mělo:
  - Vypočítat nové `scheduled_start` (den + zachovat čas) resp. nové `assigned_to`.
  - Zavolat stejnou cestu jako edit dialog: `updateTaskInAdmin` s příslušnými poli.
  - **Před odesláním** aplikovat stejnou kontrolu jako v dialogu: úkoly s výplatami/provizemi **nepřesouvat** (disabled drag nebo vizuální indikace „uzamčeno“).

### 4.4 i18n

- Nahradit všechny hardcoded české řetězce v providerech a byznys logice:
  - `StateError` a podobné hlášky → klíče např. `errors.missing_tenant_id`, `errors.cannot_approve_settlement_no_tenant`.
  - Fallbacky v `_parseTasksFromResponse`: „Nepřiřazeno“, „Neznámý“, „Jiné“ → buď i18n v místě použití, nebo konstanty z konfigurace/jazyka.
- Parsování délky z popisu: buď ukládat délku strukturovaně (např. `metadata.duration_minutes`), nebo mít i18n-aware regex / parser pro „hod“/„min“ vs „h“/„min“ v jiných jazycích.

---

## 5. Shrnutí tabulkou

| Oblast | Stav | Riziko | Priorita doporučení |
|--------|------|--------|----------------------|
| Úkoly – zdroj dat | Stream, limit 500, bez časového okna | U velkých tenantů neúplná historie, žádný OOM | Zavedení časového okna / paginace |
| Kalendář – zdroj dat | Týden / měsíc, časové okno | Nízké | Udržovat |
| Drag & Drop | Není implementováno | Pouze UX – přesun jen přes dialog | Volitelně D&D + stejná pravidla jako u editace |
| Zámek vyplacených úkolů | Pouze podle statusu „completed“ | Rozbití účetnictví při úpravě vyplaceného úkolu | Zámek podle `task_payouts`/`task_commissions` (UI + ideálně backend) |
| i18n v providerech | Hardcoded CZ: StateError, „Nepřiřazeno“, „Jiné“, „hod“/„min“ | Špatná lokalizace a křehký parser | Nahradit klíči a konzistentními hodnotami |

Tento dokument slouží jako podklad pro plánování úprav; **implementace není součástí této zprávy**.
