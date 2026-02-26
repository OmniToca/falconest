# FalcoNest V1.0 Release Readiness Audit

**Datum:** 23. února 2025  
**Typ:** READ-ONLY audit – žádné změny kódu  
**Cíl:** Příprava na vydání V1.0 pro 10 B2B Pioneer klientů (property management agentury)

---

## 🔴 CRITICAL BLOCKERS (opravit před V1.0)

### 1. Žádné zjištěno ✅

Během auditu nebyly nalezeny kritické blokující chyby (crash aplikace, masivní únik dat mezi tenanty, rozbitá offline synchronizace Worker flow).

---

## 🟠 WARNINGS & TECH DEBT (mělo by se opravit před V1.0)

### 1. MULTI-TENANT SECURITY – reservation_services bez tenant_id filtru

**Soubor:** `lib/features/admin/providers/reservation_services_repository.dart`

**Problém:** Metody `fetchByReservationIds()` a `fetchByReservationId()` filtrují pouze podle `reservation_id`, nikoli podle `tenant_id`. Tabulka `reservation_services` má sloupec `tenant_id` (používaný při insert).

**Riziko:** Defense in depth – pokud by RLS bylo nesprávně nastaveno, teoreticky by mohl být možný přístup k datům jiného tenanta. V praxi caller (admin) vždy předává `reservation_id` pouze z rezervací vlastních bytů tenanta.

**Doporučení:** Přidat explicitní `.eq('tenant_id', tenantId)` do obou fetch metod (vyžaduje předání `tenantId` parametrem).

---

### 2. i18n – hardcoded text v planning_calendar_provider

**Soubor:** `lib/features/calendar/providers/planning_calendar_provider.dart` (řádky 404, 444)

**Problém:** `CalendarResource` pro nepřiřazené úkoly má `displayName: 'NEPŘIŘAZENO'` (český text). Tento text se zobrazuje v řádcích kalendáře pro nepřiřazené úkoly. V `planning_calendar_screen.dart` je dropdown správně používá `'planning_calendar.unassigned_row'.tr()`, ale samotný provider předává hardcoded řetězec.

**Doporučení:** Provider musí přijímat lokalizovaný text nebo použít klíč a tr() v místě zobrazení. Ideálně předat `displayName` jako i18n klíč a tr() volat v UI komponentě, která resources vykresluje.

---

### 3. i18n – hardcoded symbol měny € v Check-in / Check-out

**Soubory:**
- `lib/features/worker/screens/task_types/checkin_task_screen.dart` (ř. 495)
- `lib/features/worker/screens/task_types/checkout_task_screen.dart` (ř. 366)

**Problém:** `Text('$val €')` – symbol € je hardcoded. Aplikace podporuje `preferred_currency` v profilu uživatele. Pro multi-currency tenancy (např. klienti v jiných měnách) by měl být použit symbol z nastavení.

**Doporučení:** Použít `ref.watch(authNotifierProvider).state.preferredCurrency` nebo lokální formátování podle tenanta a vykreslit správný symbol (€, Kč, $, …).

---

### 4. i18n – ostatní minoritní hardcoded prvky

**Placeholder „—“ (em dash):** Používá se v mnoha místech jako fallback pro prázdná data (např. `addr.isEmpty ? '—' : addr`). Univerzální symbol, nízká priorita.

**Symbol „?“ pro chybějící iniciály:** `admin_team_screen.dart`, `tenant_detail_screen.dart` – fallback pro prázdné jméno. Akceptovatelné.

---

### 5. ERROR HANDLING – některé Supabase volání bez try-catch

**IssueReporterDialog** (`lib/features/worker/widgets/issue_reporter_dialog.dart`): `_submit()` volá `enqueueMutation` bez try-catch. Na webu je to no-op, na mobilu při selhání Isar write by mohla být neohlášená výjimka. V praxi `MutationQueueService.enqueueMutation` má vnitřní try-catch a pouze loguje. Doporučeno: obalit `_submit` try-catch pro zobrazení SnackBar při chybě.

**WorkerTaskStatusNotifier:** Má try-catch, ale při chybě nastaví `state = AsyncValue.error(e, st)`. UI task screens to pravděpodobně nezobrazují jako dialog – uživatel může být zmaten. Doporučeno: ověřit, že chyba updateStatus je zobrazena (SnackBar / toast).

---

### 6. admin_tasks_screen – delete task bez tenant_id v některých cestách

**Kontrola:** Soft delete task (`admin_tasks_screen.dart` cca ř. 409) používá `.eq('id', taskId).eq('tenant_id', tenantId)` – v pořádku ✅.

---

## 🔵 MISSING V1.0 FEATURES (logické mezery v flow)

### 1. Worker – fotografie u závad (Issue)

**Stav:** UI má placeholder kartu „Fotografie závady“ s textem „Žádná fotografie“. Skutečný upload a ukládání fotografií není implementováno.

**V1.0 rozhodnutí:** Akceptovat jako známé omezení – připraveno pro v2.0. Placeholder nevadí.

---

### 2. Worker – výběr hotovosti při offline

**Stav:** ✅ **IMPLEMENTOVÁNO.** `CashWalletRepository.recordCashCollection` zachytává síťové chyby a ukládá do `MutationQueueService` s akcí `OFFLINE_CASH_COLLECTION`. `processOfflineCashCollection` při reconnect provede celý flow. (Pozn.: dokument WORKER_CASH_WALLET_AUDIT.md je zastaralý – popisuje stav před implementací.)

---

### 3. Admin / Owner moduly – offline

**Stav:** Admin, Owner portál a Super Admin jsou **online-only**. Při offline všechny Supabase dotazy selžou. Pro V1.0 Pioneer klienty (agentury) je typický scénář práce z kanceláře s připojením – přijatelné.

---

### 4. Web build – Isar neběží

**Stav:** Na webu je Isar zakázán (`kIsWeb`), Worker na webu by četl ze Supabase. MutationQueueService na webu je no-op. Pro mobilní Worker flow (primární cíl V1.0) je to v pořádku.

---

## 🟢 READY FOR PRODUCTION (co je solidní)

### 1. MULTI-TENANT SECURITY ✅

- **admin_tasks_provider:** Všechny dotazy na `tasks` používají `.eq('tenant_id', tenantId)`.
- **apartments_provider:** `.eq('tenant_id', tenantId)`.
- **apartment_services_repository:** fetch i save s tenant_id.
- **zones_provider:** `.eq('tenant_id', tenantId)`.
- **cash_wallet_repository:** Všechny operace s tenant_id.
- **task_repository_web / worker_sync_service_mobile:** Filtrování podle tenant_id.
- **admin_reservations_provider:** Filtruje přes `apartment_id IN (byty tenanta)` – rezervace nemají přímý tenant_id.
- **RLS na Supabase:** Backend vynucuje izolaci; aplikace dodržuje defense in depth v klíčových místech.

### 2. OFFLINE-FIRST STABILITY (Worker) ✅

- **Status updates:** WorkerTaskStatusNotifier → TaskRepositoryMobile → zápis do Isar (syncStatus=pending). `WorkerSyncService.pushPendingUpdates()` odesílá při reconnect. NetworkSyncWatcher volá push při OFFLINE→ONLINE.
- **Cash collection:** Při síťové chybě → `enqueueMutation(OFFLINE_CASH_COLLECTION)` → processQueue při reconnect → `processOfflineCashCollection` → `recordCashCollection`.
- **Issue reporting:** `IssueReporterDialog` ukládá výhradně přes `enqueueMutation(INSERT)` – vždy do fronty; na mobilu do Isar, při reconnect do Supabase.
- **Admin task create/update:** Při síťové chybě → `enqueueMutation` (INSERT/UPDATE) v `admin_tasks_provider`.
- **Audit log restore/delete:** PendingAuditAction + processPendingAuditActions při reconnect.

### 3. i18n – většina UI ✅

- Worker screens, Admin dialogy, Super Admin – drtivá většina textů používá `.tr()` s klíči z `cs.json`, `en.json`, `es.json`.
- SyncStatusIcon, cash collection dialogy, confirm dialogy – vše přeloženo.
- Výjimky viz výše (NEPŘIŘAZENO, €).

### 4. STATE MANAGEMENT ✅

- Riverpod používán konzistentně. `ref.watch` v build metodách pro FutureProvider / StateNotifier – správný pattern.
- Žádné zjevné stream subscriptions v build bez proper disposal.
- WorkerTaskStatusNotifier, workerTaskDetailProvider – čistá architektura.

### 5. ERROR HANDLING – klíčové cesty ✅

- **CashWalletRepository:** try-catch + enqueue na network error.
- **admin_tasks_provider:** try-catch při insert/update + enqueue.
- **WorkerSyncService:** try-catch v push metodách, onSyncError callback.
- **WorkerTaskStatusNotifier:** try-catch v updateStatus.
- **MutationQueueService.processQueue:** try-catch s rozlišením network vs. ostatní chyby.
- **network_sync_watcher:** Při reconnect volá sync – chyby se logují.

### 6. WORKER FLOW COMPLETENESS ✅

| Obrazovka        | Adresa | Navigovat | Lockbox | Popis / instrukce | Cash collection | Status flow |
|------------------|--------|-----------|---------|-------------------|------------------|-------------|
| Cleaning         | ✅     | ✅        | ✅      | ✅ Time estimate, Custom instructions | N/A | Zahájit → Dokončit |
| Check-in         | ✅     | ✅        | ✅      | ✅                 | ✅ Dialog         | ✅ |
| Check-out        | ✅     | ✅        | ✅      | ✅                 | Informační       | ✅ |
| Transfer         | ✅     | ✅        | ✅      | ✅                 | ✅ Dialog         | ✅ |
| Issue/Maintenance| ✅     | ✅        | ✅      | ✅ Popis závady    | N/A              | Zahájit → Vyřešeno |
| Material         | ✅     | ✅        | -      | ✅                 | N/A              | ✅ |
| Default          | ✅     | -         | -      | ✅                 | N/A              | ✅ |

---

## Shrnutí

| Kategorie            | Stav | Počet položek |
|----------------------|------|---------------|
| 🔴 CRITICAL BLOCKERS | 0    | -             |
| 🟠 WARNINGS           | 6    | viz výše      |
| 🔵 MISSING FEATURES  | 1 (akceptováno) | Issue fotky |
| 🟢 READY             | 6 oblastí | -        |

**Závěr:** Aplikace je **vhodná pro V1.0 release** s následujícími doporučeními před vydáním:

1. Opravit hardcoded `'NEPŘIŘAZENO'` v planning_calendar_provider – používat i18n.
2. Zvážit použití `preferred_currency` pro zobrazení částek (€) v Check-in/Check-out.
3. Přidat tenant_id do reservation_services fetch (defense in depth).
4. Obalit IssueReporterDialog._submit do try-catch pro lepší UX při chybě.

Po těchto úpravách bude aplikace připravena pro 10 Pioneer B2B klientů s vysokou mírou spolehlivosti a dodržením architektonických pravidel.
