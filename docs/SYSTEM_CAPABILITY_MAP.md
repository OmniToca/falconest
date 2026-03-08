# System Capability Map – FalcoNest

**Dokument:** Přehled toho, co je v aplikaci **skutečně naprogramované a funkční** (stav codebase).  
**Účel:** Podklad pro zátěžové testovací scénáře a produktové plánování.  
**Pravidlo:** Jsou popsány pouze existující funkce v kódu, ne záměry nebo TODO.

---

## 1. WEB ADMIN (B2B SaaS pro dispečery)

Admin sekce je dostupná pod cestou `/admin`. Layout je **AdminLayout** s **IndexedStack** – 10 záložek (bez podcest v URL). Role: `admin`, `manager`; přepínání Admin ↔ Worker podle **AdminUiMode** (forceMobile / forceDesktop / auto podle šířky).

### 1.1 Moduly a obrazovky (co reálně existuje)

| Záložka | Obrazovka | Stav |
|--------|-----------|------|
| **Nástěnka** | `AdminDashboardScreen` | Hotovo |
| **Personál** | `AdminTeamScreen` | Hotovo |
| **Apartmány** | `AdminApartmentsScreen` | Hotovo |
| **Rezervace** | `AdminReservationsScreen` | Hotovo |
| **Úkoly** | `AdminTasksScreen` | Hotovo |
| **Plánovací kalendář** | `PlanningCalendarScreen` | Hotovo |
| **Finance** | `FinanceDashboardScreen` | Hotovo |
| **Reporty** | `ReportsScreen` | Hotovo |
| **Klienti** | `AdminClientsScreen` | Hotovo |
| **Komunikace** | `CommunicationTemplatesScreen` | Hotovo |

Další admin-related: **Nastavení** (`/settings`) – záložky Zóny, Modul, Profil, Client Billing; **Admin Zóny** (`/settings/zones`).

---

### 1.2 Hlavní funkce po modulech

#### Nástěnka (Dashboard)
- **Dnešní plán:** úkoly s due_date dnes (lokální čas), rozdělení na interní (s bytem) a externí.
- **Stav apartmánů:** počty „Obsazeno“, „K úklidu“, „Čistý“ z `getApartmentStatusForToday(reservations, tasks, apartments)`.
- **Kdo je v akci:** seznam členů týmu, kteří mají dnes přiřazený úkol.
- **Action Strip:** varování (např. nepotvrzené rezervace, úkoly bez přiřazení) z `dashboardSummaryProvider`; klik vede na záložku Rezervace nebo Úkoly.
- **Rychlé akce:** přepnutí na Rezervace / Úkoly / Plánovací kalendář.

#### Personál (Team)
- **Seznam členů týmu** z `teamFullListProvider` (Supabase).
- **Detail člena:** záložky (údaje, úkoly, absence, výdělky) – `AdminTeamMemberTabs`.
- **Přidat / upravit člena:** formuláře, přiřazení k bytům (zóny), role.
- **Absence:** přidání/úprava absence; při ukládání absence se volá `_unassignTasksForMember` v daném datovém rozsahu (úkoly se odpojí od člena).
- **Magic Login (převtělení):** impersonace pracovníka; při ukončení převtělení dialog „Výkaz práce“ (text), uložení přes `stopImpersonating(workReport)`.
- **Odpojení úkolů od člena:** `_unassignTasksForMember` – u nedokončených úkolů: hlavní řešitel → `assigned_to = null`, spolupracovník → odstranění z `assigned_user_ids`.

#### Apartmány
- **Seznam bytů** z `apartmentsFullListProvider`, filtrování, vyhledávání.
- **Přidat / upravit apartmán:** dialogy (adresa, kód, keybox, majitelé, zóny, standardní doba úklidu, poznámky).
- **Služby bytu:** vazba na katalog `tenant_services` (apartment_services), trigger_type (before_checkin, after_checkout, both_ways, on_demand), is_mandatory, requires_photo.
- **iCal zdroje:** CRUD iCal zdrojů pro apartmán (`IcalSyncService`), spuštění synchronizace (volání Edge Function `ical-fetch`); importované rezervace se ukládají ve stavu `new` bez automatického generování úkolů.
- **Stav bytu:** zobrazení stavu (např. Uklizeno / K úklidu) v kontextu rezervací a úkolů.

#### Rezervace
- **Seznam rezervací** z `adminReservationsProvider` (Supabase), životní cyklus: new, confirmed, checked_in, checked_out, cancelled.
- **Přidat rezervaci:** `AddReservationDialog` – dvě záložky (Pobyt a detaily; Služby a požadavky). **Progressive Save:** při kliku na záložku Služby bez ID se spustí validace a uložení první záložky; po úspěchu se rezervace uloží (získá ID), pak přepnutí na záložku Služby a načtení služeb z DB.
- **Upravit rezervaci:** `EditReservationDialog` – úprava dat, záložka Služby s načtením `reservation_services`, uložení do `reservations` a `reservation_services`.
- **Validace:** byt, jméno hosta, období pobytu, časy příjezdu/odjezdu; kontrola kolizí (`checkReservationCollision`) s návrhem opravy (dialog kolize).
- **Služby rezervace:** výběr služeb z katalogu bytu, cena (EUR), plátce (majitel/host), číslo letu (transfery), poznámka; ukládání přes `saveForReservation`.
- **Import z Excelu (XLSX):** `ReservationImportService` – šablona s pevnými sloupci (apartment_code, guest_name, guest_phone, guest_email, check_in, check_out, časy, guest_count, internal_note) a dynamickými sloupci služeb; parsování buňky služby (cena|plátce|číslo letu|poznámka); párování bytu přes `apartments.code`; záchranná brzda – chybná služba se zapíše do internal_note místo pádu; výsledek: počet úspěšných/varování/chyb.
- **Stažení šablony XLSX:** `generateExcelTemplate(tenantId)` – list „Kódy“ (tahák), list „Rezervace“ s hlavičkou.
- **Měsíční plachta (timeline):** v `AdminReservationsScreen` – zobrazení rezervací jako bloků na časové ose (po bytech / po dnech), pastelové barvy podle stavu.

#### Úkoly
- **Seznam úkolů** z `adminTasksProvider` (Supabase), filtrování (stav, typ, datum, přiřazení).
- **Přidat / upravit úkol:** ruční úkol (apartment / client, custom_title, custom_location, assigned_to, assigned_user_ids, due_date, task_type, popis).
- **Generování úkolů z rezervací:** `generateSmartTasks()` v `AdminTasksProvider` – pouze pro rezervace se stavem `confirmed`; načtení apartment_services (trigger_type: before_checkin, after_checkout, both_ways, on_demand) a katalogu tenant_services; idempotence vůči existujícím úkolům (nesmazání/ přepsání úkolů, které už nejsou v „Návrh“/pending); přiřazení personálu přes **TaskAssignmentEngine** (soubor je v pravidlech uzamčen – nelze měnit). Volá se např. z obrazovky Úkoly (tlačítko „Vygenerovat úkoly“).
- **Detail úkolu:** metadata, rezervace, finance, dokončení s fotkami (odkazy), přiřazení.

#### Plánovací kalendář
- **Týdenní mřížka:** 15min sloty, Po–Ne, 0–24 h; výška slotu cca 18 px.
- **Zobrazení úkolů a rezervací:** bloky v čase (rezervace jako pruhy, úkoly jako karty); stavy critical / conflict / normal.
- **Navigace:** předchozí / další týden, „Dnes“ (scroll na aktuální čas nebo 08:00).
- **Filtry:** výběr zdroje (všechny / jen úkoly / jen rezervace), vyhledávání.
- **Legenda:** typy úkolů a barevné rozlišení.

#### Finance
- **Tři záložky:** Zaměstnanecká pokladna | Vyúčtování | Podklady pro fakturaci. Viditelnost záložek závisí na modulech (`settlements`, `finance_export`).
- **Zaměstnanecká pokladna:** seznam „peněženek“ (dluhy zaměstnanců) z `employeeCashWalletsProvider`; detail peněženky (wallet_detail_modal), doplnění (wallet_topup_dialog).
- **Vyúčtování:** `AdminSettlementsScreen` – (1) Fronta úkolů ke schválení / rozdělení výplat a provizí, (2) K výplatě – pending výplaty/provize, hromadné označení jako vyplaceno; settlement_split_dialog, settlement_history_dialog.
- **Podklady pro fakturaci:** `FinanceBillingContent` – export / podklady k faktuře (modul `finance_export`).

#### Reporty
- **Prémiový modul:** KPI karty, grafy (fl_chart).
- **Obsah:** výběr měsíce (`_MonthPicker`), `_KpiSection` (celkové tržby měsíce, počet úkolů), graf ziskovosti bytů, výkonnost personálu (`employeePerformances`); data z `reportsDataProvider`.

#### Klienti
- **CRM obrazovka:** seznam klientů z `clientsProvider` (Supabase), server-side vyhledávání s debounce 500 ms, stránkování (load more při scrollu).
- **Rozdělení podle typu:** owner / agency / external (tři sekce nebo karty).
- **Přidat / upravit klienta:** `ClientFormDialog`; detail klienta `ClientDetailDialog` (údaje, přiřazené byty, rychlé akce).

#### Komunikace
- **Šablony zpráv:** seznam z `messageTemplatesAdminProvider` (tenant_message_templates); řazení podle jazyka a trigger kontextu.
- **Účel:** předpřipravené texty pro řidiče (např. WhatsApp) s placeholdery (`{guest_name}`, `{flight_number}` atd.).
- **Přidat / upravit šablonu:** `TemplateEditorDialog`; multi-tenant (tenant_id).

#### iCal synchronizace
- **Služba:** `IcalSyncService` – CRUD zdrojů v `apartment_ical_sources`; sync volá Edge Function (stáhne .ics), parsování událostí, idempotence podle external_uid; vložení rezervací ve stavu `new`. **Nevolá se** `generateSmartTasks()` – úkoly se generují až ručně nebo jiným flow.

#### Nastavení
- **Zóny:** CRUD zón (`zones_provider`), zone_editor_dialog.
- **Modul:** aktivace/deaktivace modulů (např. settlements, finance_export) – `module_provider`, `ModuleEditorScreen`.
- **Profil uživatele:** user_profile_tab.
- **Client Billing:** záložka client_billing_tab.

---

## 2. WORKER APP (mobilní aplikace pro personál)

Worker sekce je pod cestou `/worker` (role: worker, cleaner, driver, maintenance; admin/manager při forceMobile nebo auto na mobilu). Hlavní obrazovka: **WorkerDashboardScreen** („Moje Práce“).

### 2.1 Co pracovník v aplikaci reálně dělá

- **Dashboard:** seznam úkolů přiřazených aktuálnímu uživateli (`assigned_to` nebo v `assigned_user_ids`), seskupených podle data (Dnes, Zítra, Později). Karty úkolů – typ, byt/adresa, čas, stav.
- **Pull-to-refresh:** spuštění synchronizace (`runSync`), invalidace `workerTasksProvider`, po úspěchu SnackBar „Sync proběhl“.
- **Otevření úkolu:** navigace na `/worker/task/:id` → **WorkerTaskDetailScreen**; podle `task_type` se zobrazí typová obrazovka (checkin, checkout, cleaning, maintenance, transfer, material, issue, default).
- **Typové obrazovky úkolů:** např. CheckinTaskScreen, CheckoutTaskScreen, CleaningTaskScreen, MaintenanceTaskScreen, TransferTaskScreen, MaterialTaskScreen, IssueTaskScreen, DefaultTaskScreen – každá má specifická pole a akce (např. dokončení s fotkou, číslo letu, poznámka).
- **Dokončení úkolu s fotkou:** `TaskCompleteWithPhotoSection`, nahrání fotek; offline se akce zapíše do fronty mutací a po připojení se zpracuje (`OFFLINE_TASK_COMPLETE_WITH_PHOTOS`).
- **Hlášení problému (Issue):** `IssueReporterDialog`; offline zpracování přes `offline_issue_task_processor`.
- **Náklady firmy:** `AddCompanyExpenseDialog`; offline přes `offline_company_expense_processor`.
- **Výběr hotovosti:** `CashCollectionDialog` (worker utils); offline přes `offline_cash_collection_processor`.
- **Absence:** `WorkerAbsencesScreen` – seznam absencí, přidání absence (`AddAbsenceDialog`).
- **Peněženka:** `WorkerWalletScreen` – stav „peněženky“ (hotovost).
- **Výdělky:** `WorkerEarningsScreen` – přehled výdělků.
- **PIN:** na mobilu podpora PIN (pin_setup, pin_verify, pin_change); `PinStorage.hasPin()`.
- **Offline banner:** při `isOfflineProvider == true` se zobrazí oranžový pruh „Offline režim“; při chybě sync se zobrazí stav z `workerSyncStateProvider`.
- **Sync ikona:** `SyncStatusIcon` v AppBar (stav synchronizace).

### 2.2 Offline-first a synchronizace (aktuální stav v kódu)

- **Lokální databáze:** Isar byl odstraněn (nestabilita na iOS). Používá se **Drift (SQLite)**. Inicializace: `database_init_io.dart` pouze připraví `path_provider`; Drift se otevře při prvním přístupu k `driftDatabaseProvider` / `driftSyncReposProvider`.
- **Čtení dat na mobilu:** `taskRepositoryProvider` na mobilu vrací `driftTaskRepositoryProvider` – úkoly se čtou z **Drift**. Stejně tak apartments, reservations, clients, message templates jsou na mobilu čteny z Drift po sync.
- **Sync směr:**  
  - **Pull:** `WorkerSyncService.syncTasksFromSupabase()` stáhne úkoly (rozsah cca -7 dní až +14 dní od teď), apartmány, rezervace, klienty, tenant (měna), šablony zpráv a zapíše je do Drift (`_clearAndWrite` / `upsertTaskFromSupabaseMap` atd.).  
  - **Push:** před pull se volá `pushPendingUpdates()` – odeslání lokálních změn z fronty mutací na Supabase.
- **Fronta mutací:** `DriftMutationQueueService` – zapisuje do Drift (`DriftPendingMutationRepository`). Typy akcí: `OFFLINE_CASH_COLLECTION`, `OFFLINE_COMPANY_EXPENSE`, `OFFLINE_ISSUE_TASK`, `OFFLINE_TASK_COMPLETE_WITH_PHOTOS`, `INSERT`, `UPDATE`. Běžné INSERT/UPDATE jdou přímo na Supabase; offline akce mají vlastní processory (sloučení stavu, byznysová pravidla).
- **Timestamp Merging (Smart Merge):** v `WorkerSyncService` (mobile) je implementován **push s Timestamp Merging**: před odesláním lokální změny úkolu se stáhne aktuální verze ze serveru; pokud `server.updated_at` > lokální `last_synced_at`, jde o konflikt. Pravidla: (1) změna statusu od pracovníka má přednost; (2) poznámky se nesmazávají, ale sloučí (append „[Admin]: … \n [Worker]: …“). Sloučený stav se odešle na Supabase a zapíše do Drift.
- **Kdy sync běží:** při otevření Worker dashboardu (microtask `runSync`), při pull-to-refresh; na webu Worker používá `WorkerSyncServiceWeb` (bez Drift – data přímo ze Supabase).
- **Shrnutí:** Offline-first je **implementován**: čtení úkolů a souvisejících dat z Drift na mobilu, zápis offline akcí do fronty mutací, push s Timestamp Merging a pull s přepsáním Drift. Isar už není; celé běží na Drift (SQLite).

---

## 3. KLIENTSKÉ CENTRUM (majitelský portál)

Samostatný modul **„client“** jako koncový portál pro hosty v kódu **neexistuje**. „Client“ v názvech znamená většinou **klienta agentury** (CRM v adminu).  
Existuje **Klientský portál pro majitele bytů** – role `property_owner`, cesta `/owner`, layout **OwnerLayout** s **IndexedStack** (5 záložek).

### 3.1 Co v kódu reálně existuje

| Záložka | Obrazovka | Obsah |
|--------|-----------|--------|
| **Apartmány** | `OwnerApartmentsScreen` | Grid kart bytů majitele; stav bytu z nejnovějšího úkolu (Čistý / Probíhá úklid / Čeká na úklid). Klik na kartu otevře dialog s **OwnerApartmentDetailScreen** (detail bytu). Data: `ownerApartmentsProvider`. |
| **Rezervace** | `OwnerReservationsScreen` | Seznam rezervací k bytům majitele (kanban nebo seznam); karta: host, byt, období, časy, stav. Editace jen u stavu `new` (např. `onEdit`). Data: `ownerReservationsProvider`. |
| **Úkoly** | `OwnerTasksScreen` | Read-only **Kanban**: tři sloupce – Zadáno, Probíhá, Hotovo. Pouze úkoly u bytů majitele; návrhy (draft) filtrovány. Data: `ownerTasksProvider`. |
| **Plánovací kalendář** | `OwnerPlanningCalendarScreen` | Plánovací kalendář v kontextu majitele (rezervace/úkoly jeho bytů). Data: `ownerPlanningCalendarProvider`. |
| **Fakturace** | `OwnerBillingScreen` | Seznam „zmrazených“ vyúčtování z `ownerBillingSnapshotsProvider` (billing_snapshots). U každého měsíce možnost **stáhnout PDF** report (on-demand z uloženého snapshot_data). Prázdný stav: i18n „owner.billing_empty“. |

### 3.2 Technické detaily

- **Data:** Vše z Supabase přes owner_* providery; RLS podle tenant_id a vazby na majitele (apartment_owners, nebo filtrování podle bytů přiřazených majiteli).
- **Design:** Konzistentní s owner_layout – světlé pozadí, tlumené akcenty, responzivní (Drawer na úzkých, Sidebar na širokých).
- **Žádná samostatná „guest“ role ani portál pro koncové hosty** – pouze role `property_owner` a obrazovky pod `/owner`.

---

## Shrnutí pro zátěžové scénáře

- **Admin:** Zaměřit se na: načítání seznamů (rezervace, úkoly, apartmány, tým, klienti), generování úkolů (`generateSmartTasks`), import XLSX, uložení rezervace včetně Progressive Save a služeb, sync iCal, plánovací kalendář (týdenní mřížka), finance (peněženky, vyúčtování, billing), reporty (KPI, grafy).
- **Worker:** Zaměřit se na: sync (pull + push s Timestamp Merging), čtení úkolů z Drift, dokončení úkolu s fotkou (včetně offline), issue/company expense/cash collection (offline fronta a processory), dashboard a typové obrazovky úkolů.
- **Owner:** Zaměřit se na: načtení bytů a rezervací, Kanban úkolů, plánovací kalendář, načtení billing snapshotů a generování PDF.

---

*Dokument vytvořen na základě analýzy codebase (lib/). Poslední revize podle stavu souborů v projektu.*
