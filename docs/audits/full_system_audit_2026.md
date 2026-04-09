# FalcoNest – full system audit (2026)

Externí technický pohled. Zdroj pravdy: aktuální stav souborů `.dart`, `.sql`, `.ts` a migrací v repozitáři. Dokument nehodnotí záměry roadmapy ani marketing.

---

## Část 1: Co v systému reálně máme (fakta z kódu)

### 1.1 Jádro (`lib/core`)

- **Supabase**: `supabase_flutter`, inicializace z `assets/config.env` (`SupabaseService.init`). Klient přes singleton; dokumentovaná **Frontend Firewall** – `safeFrom` / `safeInsertPayload` vynucují `tenant_id` u tenantových tabulek, pokud je ID zadáno (ochrana před omylem u Super Admin globálních dotazů).
- **Stav**: Riverpod (`flutter_riverpod`), směrování **GoRouter** (`app_router.dart`) s redirecty podle auth, PIN a `UiMode` (admin / worker / owner / super_admin).
- **Lokální DB**: **Drift** přes balíček `falconest_drift` (vlastní `packages/falconest_drift`). Offline fronta mutací: `DriftMutationQueueService`, platformní varianty (`mutation_queue_service_mobile.dart`, `mutation_queue_service_web.dart`), `network_sync_watcher`.
- **Auth**: `AuthNotifier`, invite flow, profil cache, PIN úložiště.
- **Notifikace**: `PushNotificationService` – **Firebase Messaging** (`firebase_messaging`, `firebase_core`), zápis tokenů do DB, deep link přes `data.route` (testováno v `test/core/push_notification_route_test.dart`). Edge **automation-dispatch** v dokumentaci slovníku popisován jako FCM HTTP v1 pro internal_push (logika na serveru; klient jen FCM SDK).
- **Téma / měna**: `app_theme.dart`, `CurrencyService` + TTL cache kurzů u provideru.
- **Audit (enterprise)**: payloady v `core/audit/`.
- **Ostatní služby**: PDF fakturace, billing export, settlement export, absence notifikace, atd. (viz importy v `lib/core/services`).

### 1.2 Databáze a DevOps (Supabase)

- **Migrace**: řádově **170+** SQL souborů v `supabase/migrations` (postupné evoluce RLS, modulů, financí, checklistů, PostGIS, FTS, kalendářů, owner portálu, údržby).
- **RLS**: politika napříč tabulkami tenantů je v migracích rozšířená a opakovaně opravovaná (`fix_*`, `rls_*`). Konkrétní počet politik není v jednom čísle agregován – existuje desítky souborů s `CREATE POLICY` / `ENABLE ROW LEVEL SECURITY`.
- **Rozšíření**: mimo jiné **PostGIS** (`geo_location` u apartmánů, úkolů, klientů), **pg_cron** (automation enqueue/dispatch, upcoming-task-reminder, údržba `maintenance_data_cleanup`, VACUUM joby), **pg_net** (HTTP z DB kde je nakonfigurováno).
- **Údržba (nedávné migrace)**: `maintenance_data_cleanup()` – mazání starých logů a soft-delete záznamů; samostatné cron joby `VACUUM ANALYZE` na `apartments` / `tasks` / `clients` (PostgreSQL neumožňuje VACUUM uvnitř PL/pgSQL – řešeno přímo v cron příkazu).
- **Časové pásmo tenanta**: migrace `tenants_timezone` – existence sloupce / konvence v DB (aplikace musí konzistenci dodržovat vlastní logikou).
- **Zálohování**: v repozitáři **není** žádný skript ani dokumentace pro PITR / dump – produkční zálohy závisí výhradně na Supabase projektu / manuálním procesu mimo Git.

### 1.3 Edge funkce (Deno, `supabase/functions`)

Prokazatelně existující `index.ts` u:

| Funkce | Účel (z kódu / hlaviček) |
|--------|---------------------------|
| `export_calendar` | GET iCal podle hashe tokenu, RPC `get_calendar_feed_data`; **in-memory rate limit** (hash tokenu, 20/min). |
| `create-checkout` | Stripe Checkout Session (`npm:stripe`), metadata `tenant_id`. |
| `automation-enqueue` / `automation-dispatch` | Fronta automatizací; volání z pg_cron přes `cron_edge_config`. |
| `template-reminders` | Šablony / připomínky. |
| `daily-task-summary` | Denní souhrn úkolů. |
| `upcoming-task-reminder` | Připomínky nadcházejících úkolů. |
| `ical-fetch` | Stahování externích iCal. |
| `twilio-provision-number`, `twilio-inbound`, `twilio-webhook` | Telefonní kanál. |
| `resend-webhook` | E-mailový provider. |
| `process-issue-ai` | AI zpracování hlášení. |

### 1.4 Super Admin (`lib/features/super_admin`)

- Dashboard tenantů, MRR, vyhledávání, detail tenanta, moduly, onboarding wizard.
- Audit log (web/mobilní repozitáře), billing overview, HQ staff / kontrakty / absence, agency settlements, support interventions.
- Nastavení (včetně kurzů měn) – sdílené vzory s `settings_screen` (invalidace `currenciesProvider` + cache).

### 1.5 Admin / dispečink (`lib/features/admin`)

- Layout s navigací, dashboard (KPI, trendy, komunikace/automatizace).
- **Úkoly**: velký surface (`admin_tasks_screen.dart`), Kanban, streamy, smart generátor – část výpočtu v **Isolate** (`Isolate.run` v `admin_tasks_provider.dart`, workery v `admin_tasks_isolate_workers.dart`); na webu synchronně (`kIsWeb`).
- **Jádro přiřazování**: soubor `task_assignment_engine.dart` – v projektu označen jako uzamčený pro změny (pravidla v `.cursorrules`); logika se nepřepisuje v tomto auditu, pouze existence.
- **Rezervace**, apartmány, tým, CRM klienti (FTS `search_vector`), finance (fakturace, hotovost, settlements), reporty (`fl_chart`), moduly, zóny, iCal sync, automatizace (pravidla, fronta, log), checklisty (šablony + instance), mapa dispečinku (**flutter_map** + polyline v `admin_map_dispatch_screen.dart`).
- **CustomPaint**: časová osa rezervací (`admin_reservations_screen.dart`).
- **Fakturace**: `finance_billing_screen`, `BillingActionService`, snapshoty v DB, varování před uzamčením (úkoly bez přiřazení / fotky dle metadat).

### 1.6 Worker (`lib/features/worker`)

- Dashboard, detail úkolu, typové obrazovky (checkout, maintenance, materiál, …), peněženka, výdělky, absence.
- **Synchronizace**: `WorkerSyncService` – mobil vs web; timestamp merge / konflikty dle projektových pravidel.
- **Fotky**: komprese, upload, **anotace** – `photo_annotation_screen.dart` + `CustomPaint` / `CustomPainter`.
- Offline kontext na kartách, checklisty (Drift + IO/stub).

### 1.7 Owner (`lib/features/owner`)

- Layout, dashboard, apartmány, detail bytu (včetně calendar feed URL z RPC), úkoly, rezervace, plánovací kalendář (filtr bytu), fakturace ze snapshotů, firemní výdaje, metriky.

### 1.8 Veřejné / auth / nastavení

- Login, invite, PIN, onboarding, čekárna, suspended, payment required.
- `settings_screen` – profil, moduly, integrace, Twilio provision služba, barvy tenanta, atd.
- Část platebních routes v `app_router` **zakomentovaná** (`payment_success` / `payment_cancel` – importy jsou v souboru vypnuté).

---

## Část 2: Dluh a mezery

### 2.1 Nedotažené nebo explicitně odložené funkce

- **TODO v kódu** (grep): např. `client_billing_tab.dart` – skrytý seznam faktur do doby „Super-Admin fakturační modulu“ (MVP poznámka v komentáři).
- **Zakomentované routy** plateb v `app_router.dart` – flow po Stripe checkoutu v aplikaci není kompletně zapojené v navigaci (Edge `create-checkout` přitom existuje).
- **Prázdné `catch (_) {}`**: opakovaně v `worker_sync_service_mobile.dart`, `drift_task_repository.dart`, `admin_tasks_screen.dart`, providerech, exportech – chyby se polykají bez logování ani metriky; debug v produkci je ztížený.
- **Super Admin „fakturační modul“** pro klienta**: zmíněný jako blokátor v TODO u billing UI – produktově nedokončená návaznost.

### 2.2 Bezpečnost a stabilita

- **Rate limiting**: implementován u **export_calendar** (in-memory na instanci). Ostatní veřejné nebo poloveřejné Edge endpointy bez jednotného vzoru limitu v repozitáři – riziko DoS závisí na konfiguraci Supabase / Cloudflare mimo kód.
- **Super Admin + RLS**: `SupabaseService` dokumentuje, že při `tenant_id == null` jde o nefiltrovaný přístup; ochrana je na aplikaci. Chyba v jednom provideru může stáhnout cizí data – vyžaduje disciplínu a review.
- **Offline sync**: složitá větev mobil vs web, prázdné catch bloky – riziko tiché nekonzistence bez uživatelské viditelnosti.
- **Údržba DB**: agresivní DELETE v `maintenance_data_cleanup` – bez rozšířeného logování do samostatné audit tabulky v migraci; provozní dopad (smazání audit_logs) musí odpovídat compliance – není řešeno v aplikační vrstvě.

### 2.3 Infrastruktura a kvalita kódu

- **Testy**: v repozitáři jsou **2** soubory `*_test.dart` (`push_notification_route_test`, `theme_refactor_smoke_test`). Žádné integrační testy prodb, žádné testy repozitářů proti mock Supabase, žádné golden testy UI kromě zmíněného smoke testu.
- **CI/CD**: složka **`.github` v repozitáři chybí** – žádný verifikovaný pipeline (analyze, test, build) ve zdrojácích; kvalita závisí na lokálním běhu vývojáře.
- **Statická analýza**: `analysis_options.yaml` – základ **flutter_lints**; exclude zahrnuje `**/web/**` (globální vyloučení web složky projektu může omezit analýzu web buildu – ověřit záměr).
- **Velikost souborů**: `admin_tasks_screen.dart` a související obrazovky mají řádově tisíce řádků – refaktoring zvyšuje riziko regrese bez testů.
- **Generovaný kód Drift**: komentář v `pubspec` odkazuje na ruční / podmíněnou generaci – technický dluh v procesu buildu.

### 2.4 Produktové a logické díry (co typicky ERP očekává, v kódu chybí nebo je slabé)

- **Účetní exporty**: Excel/PDF existují v kontextu fakturace a reportů; standardní **pevný most** do účetních systémů (SAP, Pohoda, API účtárny) **není** v repozitáři jako kontraktní integrace – jen obecné exporty.
- **Storno rezervací / právní stavy**: business logika je rozptýlená v rezervačních službách a automatech; jednotný **stavový stroj** rezervace jako dokumentovaný model v jednom místě **není** z tohoto auditu prokázán.
- **Časová pásma**: `tenants_timezone` + UTC v úkolech; **konzistence napříč všemi obrazovkami a reporty** vyžaduje manuální ověření – automatizované testy chybí.
- **Více instancí Edge**: in-memory rate limit u iCal **nesdílí** stav mezi replikami – při škálování více workerů limit je „best effort“.
- **Zálohy a obnova**: mimo Supabase dashboard **není** v repo disaster recovery runbook.
- **Observabilita**: roztroušené `debugPrint` u FCM; chybí jednotný **strukturovaný log** (např. OpenTelemetry) pro Flutter klienta vůči backendu.

### 2.5 Shrnutí rizik (priorita)

1. **Nulové / minimální testovací pokrytí** kritických domén (finance, sync, přiřazování okolí engine).
2. **Tiché catch bloky** – zamlžení produkčních chyb.
3. **Chybějící CI** – regrese se nechytají automaticky.
4. **Super Admin data scope** – závislost na konzistentním použití `safeFrom`.
5. **Produkty s právními nároky na audit** – mazání `audit_logs` po 6 měsících v údržbě může být v rozporu s požadavky klienta (nutné smluvní vyjasnění).

---

*Konec auditu. Datum odvození ze stavu repozitáře: 2026-04.*
