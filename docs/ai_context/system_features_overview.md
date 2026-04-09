# FalcoNest – přehled schopností systému (stav dle codebase)

Dokument popisuje, co aplikace **reálně** umí v kódu (`lib/features/`, jádro, Supabase). Slouží pro produktové a technické řízení; není marketingovým materiálem. Při změnách architektury aktualizovat spolu se `slovnik_modulu.md` a `database_schema.md`.

---

## 1. Úvod: architektura a zaměření

**FalcoNest** je multi-tenant B2B platforma pro provoz úklidových a facility / správcovských agentur: jedna instance služby, více izolovaných tenantů (agentur), každý s vlastními daty a moduly.

- **Klient (Flutter):** jedna codebase; **Riverpod** pro stav; **GoRouter** podle přihlášení, PINu a **UI módu** (`admin` / `worker` / `owner` / `super_admin`).
- **Backend:** **Supabase** (PostgreSQL, Auth, Realtime, Storage, Row Level Security na tenantových tabulkách). Tenantové dotazy procházejí bezpečnostní vrstvou ve frontendu (`SupabaseService` – konzistentní `tenant_id`).
- **Mobilní worker:** **offline-first** přes lokální **Drift** (SQLite) a **frontu mutací**; synchronizace proti Supabase s **Timestamp merging** / Smart merge u konfliktů (viz jádro offline).
- **Notifikace:** **FCM** (Firebase Cloud Messaging), registrace zařízení v tabulce `user_devices`; in-app notifikace a preference kanálů (web / push / email) v `notification_preferences`.

---

## 2. Super Admin (HQ)

Rozhraní pro provoz platformy (role `super_admin` a částečně omezené role HQ, např. account manager – např. přístup k detailu tenanta dle auditních pravidel v kódu).

| Oblast | Co systém umožňuje (implementováno) |
|--------|-------------------------------------|
| **Nástěnka tenantů** | Seznam agentur, vyhledávání (in-memory nad načtenými daty; u `tenants` není FTS jako u CRM), řazení (název, MRR, aktivita, riziko). Zobrazení MRR a souhrnných metrik. |
| **Vytvoření / správa tenantů** | Založení nové agentury (dialog z FAB), přechod do detailu tenanta. |
| **Detail tenanta** | Statistiky, profily v tenantovi, mapování předplatných modulů (`tenantModuleSubscriptionMapProvider` atd.). |
| **Onboarding wizard** | Routa `/super-admin/tenant/:id/onboarding` – průvodce nastavením tenanta. |
| **Převtělení (impersonation)** | Vstup do admin rozhraní vybrané agentury jako uživatel; ukončení s dialogem „výkaz práce“ (audit). |
| **Audit log** | Globální audit (`audit_logs`), obrazovka `/super-admin/audit-log` a modal z nástěnky; filtrace podle tenanta; mobilní vs web repository. |
| **Fakturace / billing (HQ)** | Modal z nástěnky – přehled plateb napříč tenanty (`billingOverviewProvider`); v DB tabulky `invoices`, vazby na Stripe ID u modulů. |
| **Vyúčtování agentur (HQ)** | Modal **Agency settlements** – obrazovka vyúčtování managementu agentur (`agency_management_settlements`, repository `AgencyManagementSettlementsRepository`). |
| **Work reports** | Modal pro práci s výkazy práce (souvisí s ukončením impersonation / provozní procesy HQ). |
| **HQ tým** | Obrazovka týmu HQ (`hq_team_screen`), kontrakty, portfolio, absence (`hq_staff_*` providery, tabulky `hq_staff_contracts` atd.). |
| **Support interventions** | Repository a seznam zásahů podpory (`supportInterventionsRepositoryProvider`). |
| **Globální číselníky / sazby** | Např. `platform_messaging_rates` – referenční ceny zpráv pro HQ; katalog modulů v tabulce `modules`. |

**Technicky:** Super Admin čte globální / přechodné tabulky mimo běžný tenantový firewall; oprávnění řeší RLS a role na Supabase.

---

## 3. Admin (dispečink agentury)

Hlavní provozní portál agentury: **`AdminLayout`** – spodní navigace / sidebar s moduly řízenými aktivací v `tenant_modules` (klíče modulů z DB, např. mapa podle `key = map`).

| Oblast | Funkce |
|--------|--------|
| **Dashboard** | Operativní přehled: dnešní plán, tým, flotila (stav apartmánů), externí úkoly, KPI (akční pruh, komunikace/automatizace, CRM noví klienti, absence radar), lehké grafy (trend rezervací, skladba úkolů). Data z agregovaných providerů (`dashboardSummaryProvider`, `automationSummaryProvider`, `messagingHealthProvider`, …) – bez nároku na těžkou analytiku v SQL. |
| **Úkoly** | Seznam, filtry, měsíc, stream; Kanban se **systémovými statusy**, vyhledávání v kanbanu, izolované přepočty v **Isolate** na mobilu/desktopu (`admin_tasks_isolate_workers.dart`). Přiřazování úkolů využívá uzamčené jádro `task_assignment_engine.dart` (business pravidla). |
| **Rezervace** | Kanban / seznam, trendy; kanban rezervací analogicky k úkolům (granulární sloupce, vyhledávání). Import rezervací (servisní logika), iCal zdroje u bytů. |
| **Apartmány** | Seznam se stránkováním, měsíční obsazenost, stav bytu, služby u bytu (**3 vrstvy:** globální katalog služeb, vazba `apartment_services` s cenami, spouštěcí typy, checklist u služby). Zóny parkování (`zones`). Geokódování adres (**OSM Nominatim** přes `GeocodingService`). |
| **Mapový dispečink** | **`admin_map_dispatch_screen`**: **flutter_map** + OSM dlažice; markery bytů a úkolů se souřadnicemi z providerů (`apartmentsFullListProvider`, `adminTasksStreamProvider`). Geo data v DB: **PostGIS** (`geometry(Point,4326)` na `apartments`, `tasks`, `clients`). |
| **Plánovací kalendář** | Měsíční pohled úkolů a rezervací (`planning_calendar_screen`, `planningCalendarDataProvider`…). |
| **Tým** | Členové, absence, finance člena, dostupnost k úkolu, týdenní vytížení; nástěnka čerpá „absence radar“ (`upcomingAbsencesProvider`). |
| **Klienti (CRM)** | Stránkované vyhledávání přes **full-text search** (`search_vector`, GIN, `websearch` typ dotazu); záložky podle `client_type`; doporučení mezi agenturami, adresář adres, stav portálu klienta, finance klienta. |
| **Finance** | Záložka **Finance** (`finance_dashboard_screen`): fakturace / přehledy (`billingReportProvider`, `clientBillingProvider`), **hotovostní peněženky** zaměstnanců, transakce, výpadky výběru (`failedCashCollectionsProvider`). |
| **Vyúčtování / settlements** | Čekající výplaty, historie, seskupení, uzamčené úkoly z pohledu financí (providery `settlements_provider`). |
| **Reporty** | Měsíční reporty provozu (**fl_chart**); agregace v Dartu z úkolů měsíce (limit počtu záznamů). |
| **Komunikace** | Šablony zpráv (`communication_templates_screen`), kanály v DB u šablon a automatizací. |
| **Automatizace** | Pravidla (`automation_rules`), fronta (`automation_message_queue`), log (`tenant_message_log`). **Edge funkce:** `automation-dispatch`, `automation-enqueue` (plánování; typicky **pg_cron**). Kanál `internal_push` – odbavení přes **FCM HTTP v1** z `user_devices`, nikoli Twilio. Externí kanály (SMS/WhatsApp) přes integrace – náklady sleduje `tenant_usage_monthly` a sazby z `platform_messaging_rates`. |
| **iCal** | Synchronizace externích kalendářů (`apartment_ical_sources`, `IcalSyncService`, `icalSyncNotifierProvider`). |
| **Checklisty** | Šablony a položky v DB; editor šablon; instance u úkolu (`task_checklists`, `task_checklist_items`, admin providery). |
| **Nastavení (globální app route)** | `/settings` – profil, integrace (**Twilio** provisioning), moduly tenanta, brandové barvy (`tenant_ui_preferences` + Drift sync), editor modulů. |

**Technicky:** Admin na webu běží převážně přímo proti Supabase; na webu **mutation queue** často fail-fast (`OfflineWebException`), aby nedošlo k tiché ztrátě dat.

---

## 4. Worker (terénní pracovník)

**Routy:** `/worker` (dashboard úkolů), `/worker/task/:id`, `/worker/absences`, `/worker/wallet`, `/worker/earnings`, `/worker/mutation-queue`.

| Oblast | Funkce |
|--------|--------|
| **Úkoly** | Seznam přiřazených úkolů; **detail úkolu** podle typu (checkout, maintenance, materiál, …) s hlavičkou, časem, stavem. |
| **Offline** | **Drift** repozitáře úkolů a souvisejících entit; **WorkerSyncService** (pull/push); **NetworkSyncWatcher** při návratu online; indikace stavu sync (`workerSyncStateProvider`, pending počty). |
| **Checklisty** | Instance checklistu u úkolu, fotky u položek (IO vs web stub), merge při synci. |
| **Fotky / média** | Upload přes služby v jádru (`MediaService` / `PhotoService`), fronta offline dokončení úkolů s fotkami (`offline` procesory v `lib/core/offline/`). |
| **GPS / navigace** | Úkoly a byty nesou geografii v Supabase; worker DTO má lat/lon; **Google Maps** URI helper pro navigaci; parsování GPS řetězců (`gps_parser`). Drift může vracet GPS null u lokálního úkolu – zdroj pravdy online. |
| **Hotovost** | Dialogy výběru hotovosti, propojení na peněženky (`cash_collection_dialog`, `record_cash_collection_worker`). |
| **Výdělky / absence / statistiky** | Obrazovky výdělků (`myEarningsProvider`), absencí (`workerAbsencesProvider`), týdenních statistik (`weeklyStatsProvider`). |
| **PIN** | Lokální odemčení aplikace (`pinUnlockedProvider`). |

---

## 5. Klientská zóna (Owner – majitel nemovitosti)

**Routa:** `/owner` – **`OwnerLayout`**, záložky: **Apartmány**, **Rezervace**, **Úkoly**, **Plánovací kalendář**, **Fakturace**. Detail bytu: `/owner/apartments/:id`.

| Oblast | Funkce |
|--------|--------|
| **Apartmány** | Přehled bytů navázaných na profil majitele. |
| **Rezervace** | Rezervace v kontextu majitele (`ownerReservationsProvider`). |
| **Úkoly** | Úkoly související s majitelem (`ownerTasksProvider`). |
| **Kalendář** | Plánovací kalendář – úkoly a all-day rezervace; načítání rezervací omezeno na relevantní měsíc (`ownerReservationsForPlanningCalendarProvider`). |
| **Služby** | Volitelné služby bytu z pohledu majitele (`ownerApartmentServicesOptionsProvider`). |
| **Fakturace** | Uzamčené **billing snapshots** (`ownerBillingSnapshotsProvider`, tabulka `billing_snapshots`). |

Poznámka: Soubor `owner_dashboard_screen.dart` v repozitáři existuje, ale **není** zapojen do `OwnerLayout` ani routeru jako samostatná záložka – přehled majitele je veden přes uvedené záložky.

---

## 6. Architektonické a technické pilíře

| Mechanismus | Stručný popis |
|-------------|----------------|
| **Multi-tenant model** | Tabulky nesou `tenant_id`; výjimky jsou globální katalogy (`modules`, HQ tabulky). |
| **RLS** | Bezpečnost na úrovni řádků v PostgreSQL; klient používá JWT identity. |
| **Drift + Timestamp merging** | Lokální SQLite; synchronizace změn s porovnáním časových razítek (`updated_at` u preferencí UI, u rezervací/úkolů logika Smart merge ve worker sync). |
| **Fronta mutací** | `mutationQueueServiceProvider` – mobil Drift; zpracování `DriftMutationQueueService`. |
| **Úkoly – přiřazení** | Centralizovaná logika v `task_assignment_engine.dart` (v projektu označena jako neměnná bez schválení). |
| **Full-text search** | `search_vector` + GIN na vybraných tabulkách (např. `clients`, dále dle migrací). |
| **PostGIS** | Bodová geometrie WGS84 pro mapy a exporty. |
| **Automatizace** | Pravidla + fronta + Edge; **internal_push** přes FCM; externí kanály přes integrační vrstvu. |
| **Kalendářní export** | Edge **`export_calendar`**, RPC **`get_calendar_feed_data`**, tokeny v `tenant_calendar_feed_tokens`; výstup **iCalendar**; volitelně GEO a strukturovaný blok v popisu pro integrace (např. Home Assistant). |
| **Push** | Triggery/task assignment notifikace, **upcoming-task-reminder** Edge + log idempotence (`upcoming_task_reminder_log`), preference kanálů v DB. |
| **Šablony zpráv** | `tenant_message_templates` s překlady v JSON, placeholdery (`TemplatePlaceholderService`), výběr šablony a odeslání WhatsApp odkazem (`WhatsAppSenderService`). |
| **Audit** | `AuditLogService` + globální čtení v Super Admin. |
| **Fakturace / PDF** | `BillingPdfService`, `BillingActionService`, exporty settlementů (`SettlementExportService`). |

---

## 7. Co tento dokument záměrně neobsahuje

- Roadmapu a „sliby“ funkcí mimo kód.
- Výčet každého provideru – kompletní mapa je v **`docs/ai_context/slovnik_modulu.md`**.
- Detailní DDL všech tabulek – viz **`docs/ai_context/database_schema.md`**.

*Poslední srovnání: struktura `lib/features`, router (`app_router.dart`), slovník modulů a schéma DB.*
