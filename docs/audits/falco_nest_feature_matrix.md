# FalcoNest – funkční matice (audit kódu)

**Zdroje:** `lib/features/`, `lib/core/`, `supabase/migrations/`, `supabase/functions/`.  
**Legenda:** ✅ E2E (UI + Supabase + logika v kódu) · ⚠️ částečně / omezení · ❌ chybí / jen obal

---

## 1. SUPER-ADMIN (HQ)

| Oblast | Stav | Fakta z repozitáře |
|--------|------|-------------------|
| Seznam agentur (tenantů), MRR/dashboard | ✅ | `tenantsWithStatusProvider`, `super_admin_dashboard.dart`, dotazy na `tenants`. |
| Vytvoření nové agentury | ✅ | `super_admin_dashboard.dart` → `insert` do `tenants`, seed `tenant_modules` (moduly za 0 EUR), `profiles` + `invitations` (admin pozvánka). |
| Blokace / kill-switch | ✅ | `tenants.is_active` – přepínač v UI (`super_admin_dashboard.dart` ~update `is_active`), redirect na `suspended_screen`, `current_tenant_name_provider`. |
| Soft-delete agentury | ✅ | `tenant_command_modal.dart` – `tenants.deleted_at` (ne tvrdý DELETE). |
| Detail agentury (CRM, fakturace, poznámky, moduly) | ✅ | `tenant_detail_screen.dart`, `tenant_detail_provider.dart`, zápisy na `tenants` (json `billing_info` atd.). |
| Aktivace modulů pro tenanty | ✅ | `SuperAdminService.toggleModule` → `tenant_modules`; UI `tenant_command_modal.dart`, `module_subscription_dialog.dart`. |
| Katalog modulů (CRUD) | ✅ | `SuperAdminService` → tabulka `modules` (insert/update/delete). |
| Globální měny (kurzovní lístek) | ✅ | Tabulka `currencies`; `CurrencyService.fetchCurrencies` / `updateRate` / `insertCurrency`; UI `_ExchangeRatesCard` v `settings_screen.dart` **jen pro `role == super_admin`** (sekce katalogu modulů). |
| Globální jazyky jako DB číselník | ⚠️ | Jazyky pro komunikaci/app: statický katalog `core/constants/app_languages.dart` + `supported_languages`; profil drží `language_code` – **není** správa „jazyků“ v tabulce jako u měn. |
| Onboarding import (Excel → DB) | ✅ | `onboarding_wizard_screen.dart` + `OnboardingDbService` – zápis do `tenant_services`, apartmánů, vazeb atd. pod existujícím `tenant_id`. |
| Audit log | ✅ | `audit_log_screen.dart`, `audit_log_repository*.dart`. |
| HQ tým / vyúčtování HQ | ✅ | Samostatné obrazovky v `super_admin/` (`hq_team_screen`, `agency_settlements_screen`, providery). |

---

## 2. ADMIN (tenant / agentura)

| Oblast | Stav | Fakta z repozitáře |
|--------|------|-------------------|
| Dashboard (operativa) | ✅ | `admin_dashboard_screen.dart` – `adminDashboardTasksProvider`, `adminReservationsProvider`, `apartmentsFullListProvider`, `teamFullListProvider` atd. |
| Rezervace (Kanban / přehled) | ✅ | `admin_reservations_provider.dart`, UI napojené na `reservations` (RLS). |
| Rezervace – formuláře / editace | ✅ | `admin_reservation_forms.dart` a související dialogy (komunikace, služby). |
| iCal import | ✅ | `IcalSyncService` volá Edge Function `ical-fetch`, ukládá zdroje v `apartment_ical_sources`, nové řádky v `reservations` (idempotence `external_uid`, komentáře v kódu – bez auto `generateSmartTasks`). |
| Apartmány (seznam, detail, CRUD) | ✅ | `admin_apartments_screen.dart`, `apartments_provider.dart`; pole `keybox` = text v DB, ne integrace zámků. |
| Přiřazení majitele / klienta | ✅ | Vazby přes modely/CRM (`clients`, `apartment_owners` – dle providerů v admin části). |
| Úkoly (Kanban – velká obrazovka) | ✅ | **`admin_tasks_screen.dart`** je v `admin_layout` – reálná obrazovka; soubor `admin_tasks_placeholder.dart` existuje jako starší placeholder, **není** hlavní routa. |
| Úkoly – provider a DB | ✅ | `admin_tasks_provider.dart` – Supabase dotazy, přetahování / stavy. |
| Tým – pozvánky, role | ✅ | `admin_team_repository.dart` – `invitations`, `profiles`; `inviteStaffMember`, mazání pozvánek. |
| Finance – podklady k fakturaci | ✅ | `finance_billing_provider.dart` – agregace z úkolů, `reservation_services`, výdaje, měna tenanta. |
| Finance – uzamčení měsíce | ✅ | `BillingActionService.lockBillingMonth` → `billing_snapshots` (JSONB), nastavení `invoiced_at` na úkolech. |
| Finance – PDF (admin) | ✅ | `BillingPdfService.generateAndDownloadPdf` – stáhne fotky z URL, generuje PDF (`pdf` + `printing`). |
| Reporty (grafy, výkon) | ✅ | `reports_screen.dart` + `reports_provider.dart` – agregace z `tasks` / služeb (stejná cenová logika jako fakturace, bez filtru `invoiced_at` dle komentáře v provideru). |
| Komunikace (šablony, pravidla, Twilio, fronty) | ✅ | Modul v `lib/features/communication/`; Edge: `twilio-inbound`, `twilio-webhook`, `template-reminders`, `automation-enqueue`, `automation-dispatch`, `daily-task-summary`. |
| Smart lock / TTLock / API | ❌ | Žádná integrace – pouze textové pole **`keybox`** na apartmánu a šablony (`keybox` placeholder); žádný klientský kód k vendor API. |
| Pokladna / peněženka (cash) | ✅ | `finance_cash_provider`, `cash_wallet_repository.dart`, admin finance dashboard – napojeno na DB (včetně typů transakcí v migracích). |

---

## 3. WORKER (personál)

| Oblast | Stav | Fakta z repozitáře |
|--------|------|-------------------|
| „Můj plán“ / seznam úkolů | ✅ | `worker_dashboard_screen.dart`, `workerTasksProvider` → `taskRepositoryProvider`. |
| Web vs mobil – zdroj dat | ⚠️ | **Web:** `task_repository_provider_web.dart` → přímý Supabase. **Mobil (IO):** `DriftTaskRepository` + SQLite. |
| Detail úkolu podle typu | ✅ | `worker_task_detail_screen.dart` → `CleaningTaskScreen`, `CheckinTaskScreen`, … |
| Dokončení, stav, time tracking | ✅ | `WorkerTaskStatusNotifier.updateStatus` → `taskRepository.updateTaskStatus` (metadata, started_at, completed_at). |
| Fotky → Storage | ✅ | `MediaService.uploadMedia` → bucket `falconest_media`, cesta `tenantId/module/...`; `TaskCompleteWithPhotoSection` volá upload před dokončením (`kIsWeb` omezení u výběru fotek v `MediaService`). |
| „Checklist“ jako samostatné UI | ⚠️ | **Žádný** dedikovaný seznam odškrtávacích položek v worker screens; úklid je MVP (popis + dokončení + foto). Metadata se pro některé typy upravují (např. check-in), ale nejde o obecný checklist modul. |
| Offline + sync | ✅ (mobil) | `worker_sync_service_mobile.dart` – pull úkolů do Drift, `pushPendingUpdates` s „timestamp merging“ na `tasks`; `MutationQueueService` / offline fronta ve flow dokončení. |
| Offline | ❌ (web) | `worker_sync_service_web.dart` – no-op sync, žádná lokální DB. |

---

## 4. KLIENTSKÁ ZÓNA (majitel, `property_owner`)

| Oblast | Stav | Fakta z repozitáře |
|--------|------|-------------------|
| Přihlášení | ✅ | Stejný `login_screen` / `loginWithEmailPassword` jako ostatní role; `app_router.dart` při `role == 'property_owner'` → `/owner`. |
| Layout / menu portálu | ✅ | `owner_layout.dart` – `IndexedStack`: apartmány, rezervace, úkoly, plánovací kalendář, fakturace. |
| Přehled apartmánů | ✅ | `OwnerApartmentsScreen` + `owner_apartments_provider`. |
| Rezervace vlastních bytů | ✅ | `owner_reservations_provider` – filtr přes vlastněné apartmány, komentář k RLS policy v kódu. |
| Plánovací kalendář | ✅ | `OwnerPlanningCalendarScreen` – **read-only**; události z `ownerPlanningCalendarEventsProvider` (úkoly + rezervace). |
| Blokace termínů (osobní pobyt majitele) | ❌ | **Žádný** výskyt logiky vytvoření blokace / speciální rezervace pro majitele v `lib/features/owner/` (grep „block“, „personal“ – 0). Kalendář jen zobrazuje data. |
| Finanční výpisy – čísla | ✅ | `OwnerBillingScreen` – čte `billing_snapshots` přes `ownerBillingSnapshotsProvider`. |
| Finanční výpisy – PDF | ✅ | Stejný `BillingPdfService.generateAndDownloadPdf` z dat snapshotu (`owner_billing_screen.dart`). |

---

## Shrnutí technických poznámek

- **iCal:** parsování probíhá na serveru (`ical-fetch`), klient ukládá výsledek do DB – není to mock.  
- **PDF:** generuje se v aplikaci z dat DB/snapshotu, neukládá se statický soubor při locku (snapshot JSON + on-demand PDF).  
- **Smart locks:** pouze doménová data (`keybox`), žádný vendor/API kód.  
- **Číselník jazyků:** pevně v kódu + i18n JSON; měny v DB se super-admin úpravou v Nastavení.

*Vygenerováno jako statický audit zdrojového stavu repozitáře.*
