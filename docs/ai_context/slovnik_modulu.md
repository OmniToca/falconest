# Slovník modulů FalcoNest

Hlavní mapa projektu: účel modulů, logických bloků a pozadí bez vlastní UI stránky. U každé sekce jsou uvedeny **hlavní Riverpod providery** (ne všechny deriváty – kompletní seznam je v příslušných `*_provider.dart`).

---

## 0. Konvence

- **UI režimy:** `UiMode` (admin / worker / owner / super_admin) řídí `uiModeNotifierProvider` a router (`goRouterProvider`).
- **Auth:** `authNotifierProvider` (ChangeNotifier) – session, tenant, role; často kombinováno s `pinUnlockedProvider`.
- **Data worker na mobilu:** Drift SQLite přes `driftDatabaseProvider`, `driftTaskRepositoryProvider`, `driftSyncReposProvider` atd.
- **Úkoly na webu / admin:** převážně Supabase přímo v providerech a repozitářích.
- **Přehled schopností produktu (CTO/PO):** věcný popis toho, co systém reálně umí podle kódu – `docs/ai_context/system_features_overview.md` (doplňuje tento slovník souhrnem pro management, ne nahrazuje provider mapu).

---

## 1. Jádro (`lib/core`)

| Blok | Popis | Providery / stav |
|------|--------|------------------|
| **Supabase Frontend Firewall** | Tenantové tabulky přes `SupabaseService.safeFrom` / `safeInsertPayload` (vč. `SafeTenantTable.upsert`). Výjimky: globální tabulky (`modules`, `tenants` přehled HQ, …), Realtime stream s `inFilter(profile_id)` u notifikací, `user_devices`. Drift mutační fronta bez `tenant_id` v payloadu → výjimka. | `lib/core/services/supabase_service.dart` |
| **Router** | GoRouter, redirecty podle přihlášení, PIN, UI módu. | `goRouterProvider` |
| **AuthNotifier** | Přihlášení, tenant, profil, ochrana dat. | `authNotifierProvider` |
| **PIN** | Rychlé odemčení aplikace na mobilu. | `pinUnlockedProvider` |
| **UI mód** | Přepínání portálů (admin/worker/owner/super_admin). | `uiModeNotifierProvider` |
| **Drift DB** | SQLite instance, repozitáře úkolů, bytů, rezervací, fronta mutací, checklisty, šablony. | `driftDatabaseProvider`, `driftTaskRepositoryProvider`, `driftApartmentRepositoryProvider`, `driftClientRepositoryProvider`, `driftReservationRepositoryProvider`, `driftTenantRepositoryProvider`, `driftMessageTemplateRepositoryProvider`, `driftPendingMutationRepositoryProvider`, `driftTaskChecklistRepositoryProvider`, `driftSyncReposProvider` |
| **Premium karty (dekorace)** | Sjednocený vizuál karet (surface + stín z tématu) pro nástěnku a CRM dlaždice. | `premiumCardDecoration` (`lib/core/theme/premium_card_decoration.dart`) |
| **Task repository (platforma)** | Web: Supabase; mobil: Drift. | `taskRepositoryProvider` (export z `task_repository_provider_*`) |
| **Konektivita** | Sledování online/offline. | `isOfflineProvider` (`core/providers/connectivity_provider.dart`) |
| **Sync stav (globální)** | Indikace běžící synchronizace. | `syncInProgressProvider`, `syncStatusProvider` |
| **Notifikace** | Nepřečtené notifikace. | `notificationRepositoryProvider`, `unreadNotificationsProvider` |
| **Měna tenanta** | Formátování částek podle tenanta. | `currentTenantCurrencyProvider` |
| **Sazby zpráv (Twilio atd.)** | Admin přehled nákladů na SMS/WhatsApp. | `platformMessagingRatesProvider` |
| **Mutation queue** | Fronta offline mutací: mobil Drift; na webu `enqueueMutation` vyhodí `OfflineWebException` (fail-fast proti tiché ztrátě dat). | `mutationQueueServiceProvider` |
| **Transient i18n Snack** | Jednorázový lokalizovaný SnackBar bez `BuildContext` v Notifieru; host `TransientI18nSnackHost` v `app.dart`. | `transientI18nSnackKeyProvider` |

### Služby bez vlastního „modulového“ screenu (jen volané z kódu)

| Služba | Účel |
|--------|------|
| `SupabaseService` | Klient a bezpečné dotazy s `tenant_id`. |
| **`tenant_ui_preferences` (DB)** | Supabase + Drift: brandové barvy tenanta (`primary_color`, `secondary_color`, `updated_at` pro Timestamp Merging). RLS: čte kdokoli v tenantovi, zapisuje admin/manager. Migrace `20260402140000_tenant_ui_preferences.sql`. |
| `AuditLogService` | Zápis auditních událostí. |
| **Údržba DB (Supabase)** | pg_cron: `maintenance_data_cleanup()` (mazání starých logů a soft-delete záznamů), tři joby `VACUUM ANALYZE` pro mapové tabulky; Edge **export_calendar** – in-memory rate limit 20 req/min na hash iCal tokenu. Migrace `20260407220000`, `20260407221000`. |
| `MediaService` / `PhotoService` | Upload médií (úkoly, checklisty). |
| `BillingActionService`, `BillingExportService`, `BillingPdfService` | Fakturace, exporty, PDF. |
| `SettlementExportService` | Export vyrovnání. |
| `CurrencyService` + `currenciesProvider` | Seznam měn. |
| `PushNotificationService` | FCM: `requestPermission`, iOS `setForegroundNotificationPresentationOptions`, polling APNS → `getToken`, upsert `user_devices` přes `UserDeviceRepository`; `onTokenRefresh`. Spouští `AuthNotifier` po profilu i po offline cache. |
| `AbsenceNotificationService` | Notifikace absencí. |
| `ProfileCacheService` | Cache profilu. |
| `LoginService` | Pomocné auth operace. |
| `DriftMutationQueueService` | Zpracování fronty mutací vůči Supabase. |

---

## 2. Autentizace a veřejné (`lib/features/auth`, `public`)

| Modul / obrazovka | Popis | Providery |
|-------------------|--------|-----------|
| **Login, waiting room, suspended** | Přihlášení, čekání na schválení, zablokování. | `authNotifierProvider` |
| **PIN setup / verify / change** | Lokální PIN na zařízení. | `pinUnlockedProvider`, auth |
| **Invite** | Dokončení pozvánky z e-mailu. | `inviteDataProvider` |
| **Hesla** | Set/update password flow. | auth |
| **Onboarding (public)** | Registrace / úvodní flow. | — |
| **Payment required** | Blokace při nezaplaceném modulu. | auth, moduly |

---

## 3. Admin – dispečink (`lib/features/admin`)

Hlavní layout: `AdminLayout` (spodní navigace / sekce).

| Oblast | Popis | Hlavní providery |
|--------|--------|------------------|
| **Dashboard** | Operativní přehled (plán, flotila, lehká KPI: komunikace/automatizace, CRM, absence); bez těžkých analytických dotazů. | `dashboardSummaryProvider`, `adminDashboardTasksProvider`, `adminTasksTrendProvider`, `automationSummaryProvider`, `messagingHealthProvider`, `messagingFailuresProvider`, `newClientsThisMonthProvider`, `upcomingAbsencesProvider` |
| **Úkoly** | Seznam, filtry, měsíc, stream, přiřazování. Kanban karta zobrazuje počet fotek z `media_urls`, pokud není prázdné. | `adminTasksProvider`, `adminTasksStreamProvider`, `selectedTaskMonthProvider`, `tasksForReservationProvider`, `taskByIdProvider`, `tasksForApartmentProvider`, `tasksForMemberProvider`, `clientTasksProvider`, `adminDashboardTasksProvider` |
| **Úkoly – těžký výpočet mimo UI** | Smart generátor (fáze C: kolize, přiřazení) a simulace přepočtu personálu běží v `Isolate.run` na iOS/Android/desktop; na webu stejná logika synchronně (`kIsWeb`). Soubor nesmí importovat `admin_tasks_provider` (cyklus). | `lib/features/admin/providers/admin_tasks_isolate_workers.dart` |
| **Kanban – granulární sloupce** | `tasksBySystemStatusProvider` (`Provider.family` + `KanbanColumnTasks` s value equality) filtruje úkoly podle systémového statusu a `kanbanTasksSearchQueryProvider`; sloupec se překreslí jen při změně „svých“ dat. `kanbanHasVisibleTasksProvider` řídí prázdný stav bez globálního `watch` celého streamu na Scaffoldu. | `tasksBySystemStatusProvider`, `kanbanTasksSearchQueryProvider`, `kanbanHasVisibleTasksProvider` v `admin_tasks_provider.dart` |
| **Rezervace** | Kanban / seznam, trendy; bez polí `is_owner_block` / `agency_collects_payment` v UI ani modelech. Kanban (záložka Seznam): granulární sloupce přes `reservationsBySystemStatusProvider` (`Provider.family` + `KanbanColumnReservations`), vyhledávání `kanbanReservationsSearchQueryProvider`, prázdný stav `kanbanHasVisibleReservationsProvider`; karty používají `premiumCardDecoration` stejně jako úkoly. Model `ReservationRow` obsahuje `created_at` pro štítek stáří záznamu v Kanbanu (`reservationRecordAgeLabel` v `admin_reservation_utils.dart`). | `adminReservationsProvider`, `adminReservationsStreamProvider`, `reservationsBySystemStatusProvider`, `kanbanReservationsSearchQueryProvider`, `kanbanHasVisibleReservationsProvider`, `clientReservationsProvider`, `reservationsForApartmentProvider`, `adminReservationsTrendsProvider` |
| **Apartmány** | Seznam bytů, stránkování; měsíční obsazenost z přesného SQL řezu; stav bytu nezávislý na měsíci v modulu Úkoly. | `apartmentsProvider`, `apartmentsFullListProvider`, `apartmentsLoadingMoreProvider`, `currentMonthReservationsProvider`, `apartmentStatusContextReservationsProvider`, `todayApartmentTasksProvider`, `apartmentStatusProvider` |
| **Stav apartmánů** | Dashboard flotila + karty bytů: rezervace v okně ~400 dní, úklidy přes `watchTasksRawForApartmentStatus` (ne `selectedTaskMonthProvider`). | `apartmentStatusProvider`, `todayApartmentTasksProvider`, `apartmentStatusContextReservationsProvider` |
| **Tým** | Členové, absence, finance člena, dostupnost k úkolu + absence radar. Vytížení na kartě personálu z úzkého okna úkolů (ne měsíc ze záložky Úkoly). | `adminTeamProvider`, `teamFullListProvider`, `staffAbsencesProvider`, `upcomingAbsencesProvider`, `availableTeamForTaskProvider`, `memberFinancesProvider`, `teamLoadingMoreProvider`, `teamWeeklyWorkloadTasksProvider` |
| **Klienti (CRM)** | Stránkované vyhledávání přes Supabase `.textSearch('search_vector', …, config: simple, type: websearch)` v `ClientRepository.getPaginatedClients` (GIN/tsvector); tři záložky = tři dotazy s filtrem `client_type`. Lehká mapa agentur, COUNT doporučení, adresář, portál, finance. V detailu klienta (`client_detail_dialog`) jsou e-mail a telefon klikatelné (`mailto:` / `tel:` přes `url_launcher`). | `paginatedClientsByTabProvider`, `clientsLoadingMoreByTabProvider`, `agencyNamesMapProvider`, `recommendedClientsCountByAgencyProvider`, `clientsRecommendedListByAgencyProvider`, `clientsFullListProvider`, `invalidatePaginatedClientTabs`, `clientAddressesProvider`, `clientPortalStatusProvider`, `addClientProvider`, `updateClientProvider`, `softDeleteClientProvider`, `clientFinancesProvider` |
| **Finance – fakturace** | Přehledy fakturace, reporty; před uzamčením měsíce varování při úkolech bez přiřazení (`assigned_to` + `assigned_user_ids`) nebo s povinnou fotkou bez `media_urls`. Kurzy měn: `currenciesProvider` používá in-memory TTL 1 h (`CurrencyService.fetchCurrenciesCached`). | `billingReportProvider`, `clientBillingProvider`, `financeTabProvider`, `currenciesProvider` |
| **Finance – hotovost / peněženky** | Peněženky zaměstnanců, transakce, výpadky výběru; **průtoková hotovost majitele** – po uzavření pobytu záznamy v Supabase tabulce **`owner_cash_transit_settlements`** (vazba na **rezervaci**, volitelně **`employee_cash_transaction_id`**) řídí **`ReservationCashTransitRepository`** (`resolve`, `settleTransitCash`). | `employeeCashWalletsProvider`, `myCashWalletProvider`, `myCashTransactionsProvider`, `walletTransactionsProvider`, `failedCashCollectionsProvider`, `cashShortfallsCountProvider`, `walletBalanceProvider` |
| **Vyúčtování / settlements** | Čekající výplaty, historie, seskupení. | `pendingSettlementsProvider`, `taskSettlementsProvider`, `groupedPendingPayoutsProvider`, `payoutHistoryReportProvider`, `taskIdsWithPayoutsProvider`, `taskIdsWithCommissionsProvider`, `lockedFinancialTaskIdsProvider` |
| **Reporty** | Měsíční reporty provozu (grafy fl_chart). Agregace v Dartu z úkolů měsíce (limit 2000); jména bytů/personálu jsou v `ApartmentRevenue.displayName` a `EmployeePerformance.memberDisplayName` (snapshot při výpočtu), aby UI grafů nesledovalo `apartmentsFullListProvider` / `teamFullListProvider`. Apartmány/tým se v `reportsDataProvider` načítají přes `ref.read(...future)` (ne watch listů). | `reportsMonthProvider`, `reportsDataProvider` |
| **Moduly tenanta** | Aktivní moduly, katalog. | `allModulesProvider`, `activeModuleKeysProvider`, `tenantActiveModuleIdsProvider`, `tenantModuleCancelAtPeriodEndIdsProvider` |
| **Zóny** | Parkování / zóny k bytům. | `zonesProvider` |
| **Kategorie úkolů** | Ikony a barvy typů úkolů. | `taskCategoriesProvider` |
| **Služby apartmánu** | Volby služeb pro úkoly / ceny. | `apartmentServicesOptionsProvider`, `manualTaskServicePriceProvider` |
| **Majitelé nemovitostí** | Propojení majitel–byt. | `apartmentOwnersForApartmentProvider`, `ownerApartmentCountsProvider`, `apartmentsForProfileProvider`, `propertyOwnersInTenantProvider` |
| **iCal synchronizace** | Externí kalendáře. | `icalSourcesProvider`, `icalSyncNotifierProvider` |
| **Automatizace – pravidla** | Pravidla zpráv/automatizací. | `automationRulesProvider` |
| **Automatizace – fronta** | Odchozí fronta akcí. | `automationQueueProvider` |
| **Automatizace – log** | Historie odeslaných zpráv tenantům. | `automationLogProvider` |
| **Automatizace – dispatch internal_push** | Edge `automation-dispatch`: položky fronty s kanálem `internal_push` odbaví FCM HTTP v1 (tokeny `user_devices`), nikoli Twilio/WhatsApp; titulek/tělo a `data.route` / `reservation_id` z rezervace. Naplánování fronty: `automation-enqueue` + existující pg_cron (typicky každou minutu). | Supabase Edge `automation-dispatch`, `automation-enqueue` |
| **Dashboard komunikace** | KPI objem/náklady zpráv + selhání ve frontě/logu pro Admin Dashboard (včetně UI přepnutí záložky v Automations). | `adminAutomationTabIndexProvider`, `automationSummaryProvider`, `messagingHealthProvider`, `messagingFailuresProvider` |
| **Dashboard – akční filtry (Automatizace)** | Předvolby záložky Automatizace z dashboardu. | `adminAutomationFilterProvider` |
| **Dashboard CRM KPI** | KPI nových klientů v aktuálním měsíci (CRM) + breakdown podle `client_type` pro rychlou orientaci. | `newClientsThisMonthProvider` |
| **Checklisty – šablony** | Seznam šablon checklistů. | `checklistTemplatesListProvider` |
| **Checklisty – editor** | Editace jedné šablony. | `checklistTemplateEditorProvider` |
| **Checklist u úkolu (admin)** | Položky instance u konkrétního úkolu. | `taskChecklistItemsProvider` |
| **Globální Omnibox (CMD/CTRL+K)** | Cross-modul fulltext vyhledávání (Klienti, Byty, Úkoly) v modálním dialogu, napojené na FTS (`search_vector`) a rychlý proklik do detailu přes `AdminLayout`. | `omniboxSearchQueryProvider`, `omniboxSearchResultsProvider` |
| **Název tenanta / realtime** | Banner, jméno agentury. | `currentTenantNameProvider`, `currentTenantAnnouncementProvider`, `currentTenantWithRealtimeProvider` |
| **Automations seeder** | Seed výchozích pravidel (servisní). | — (voláno z kódu, ne provider) |

### Pozadí (kritické, často bez vlastní stránky)

| Blok | Popis |
|------|--------|
| **`task_assignment_engine.dart`** | Jádro přiřazování úkolů – **nesahat** dle pravidel projektu. |
| **`AdminTasksRepository` / `AdminReservationsRepository` atd.** | Supabase dotazy pro admin providery. |
| **`FinanceRepository`** | Agregace finančních dat. |
| **`AutomationsSeederService`** | Počáteční data automatizací. |
| **`IcalSyncService`** | Stahování a zpracování iCal. |

---

## 4. Worker – terén (`lib/features/worker`)

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Dashboard úkolů** | Seznam úkolů přiřazených pracovníkovi. | `workerTasksProvider` |
| **Detail úkolu** | Master obrazovka typu úkolu, sticky čas, checklist. | `workerTaskDetailProvider`, `workerTaskStatusNotifierProvider` |
| **Scribble podpis hosta** | Ruční podpis hosta na mobilu (`GestureDetector` + `CustomPainter`), upload PNG do `falconest_media` a uložení `guest_signature_url` do `tasks.metadata`; v offline stavu varování bez uploadu. | `SignaturePad` (`widgets/signature_pad.dart`), `SignatureService` (`utils/signature_service.dart`) |
| **Checklist u úkolu** | Drift instance + fotky (IO/stub). | `workerTaskChecklistProvider` |
| **Synchronizace** | Pull úkolů, šablon, push pending (Timestamp merge). | `workerSyncStateProvider`, `workerPendingSyncCountProvider` (logika v `WorkerSyncService` – mobil/web) |
| **Viditelný offline/sync banner** | Stavový pruh pod AppBar na worker dashboardu: offline (`isOfflineProvider` + počet pending), syncing (spinner) a krátký „synced“ pulse po úspěšném odeslání. | `SyncStatusBanner` (`widgets/sync_status_banner.dart`), `workerPendingSyncCountProvider`, `syncInProgressProvider` |
| **Výdělky** | Souhrn odměn. | `myEarningsProvider` |
| **Absence** | Vlastní absence pracovníka; na `worker_absences_screen` lokální filtr (Vše / Schválené / Čekající a zamítnuté) nad seznamem bez změny dat v provideru. | `workerAbsencesProvider` |
| **Týdenní statistiky** | Přehled za týden. | `weeklyStatsProvider` |
| **Peněženka (worker UI)** | Zobrazení hotovostní peněženky. | sdílené s `finance_cash_provider` dle kontextu |

**Služby:** `WorkerSyncService` (mobile/web/stub), `cash_collection_dialog`, offline dokončení úkolů s fotkami.

---

## 5. Owner – majitel (`lib/features/owner`)

Layout: `OwnerLayout`.

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Dashboard** | Přehled pro majitele; první záložka v `OwnerLayout`, routa `/owner/dashboard`. | kombinace owner providerů |
| **Apartmány** | Seznam bytů majitele. | `ownerApartmentsProvider` |
| **Detail apartmánu** | Stav, údaje jednoho bytu; odkaz `review_link`, sekce iCal (RPC `get_owner_calendar_feed_url_for_apartment`). | `ownerApartmentDetailProvider` |
| **Úkoly** | Úkoly v kontextu majitele. | `ownerTasksProvider` |
| **Rezervace** | Rezervace u majitele; blokace vlastního pobytu (`metadata.is_owner_stay`, `guest_name` konstanta); legacy sloupce `is_owner_block` / `agency_collects_payment` z produktu odstraněny (2026-04). | `ownerReservationsProvider` |
| **Plánovací kalendář** | Úkoly + all-day rezervace; rezervace z DB jen pro kalendářní měsíc obsahující zobrazený týden (`ownerReservationsForPlanningCalendarProvider`), ne celá historie; volitelný výběr jednoho bytu (`ownerPlanningCalendarApartmentFilterProvider` = null = všechny vlastněné). | `ownerPlanningCalendarTasksProvider`, `ownerPlanningCalendarEventsProvider`, `ownerReservationsForPlanningCalendarProvider`, `ownerPlanningCalendarApartmentFilterProvider` |
| **Služby bytu** | Volitelné služby z pohledu majitele. | `ownerApartmentServicesOptionsProvider` |
| **Fakturace majitele** | Snapshots vyúčtování + sekce firemních výdajů (COMPANY_EXPENSE) se schválením v `metadata`; transit hotovost – přehled uzavřených částek vázaných na pobyt odpovídá řádkům **`owner_cash_transit_settlements`** (stejný business tok jako `ReservationCashTransitRepository`). | `ownerBillingSnapshotsProvider`, `ownerCompanyExpensesProvider` |
| **Nástěnka – metriky** | Počty pobytů 14 dní + součet nezařazených owner služeb vůči snapshotům. | `ownerDashboardMetricsProvider` |
| **Hlášení závad / task detail** | Dialogy vázané na úkoly. | owner task providery |

---

## 6. Super Admin – HQ (`lib/features/super_admin`)

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Dashboard** | Všechny tenanty, MRR, vyhledávání. | `allTenantsProvider`, `tenantsWithStatusProvider`, `todayTaskCountByTenantProvider`, `dashboardMrrProvider`, `superAdminSearchQueryProvider` |
| **Detail tenanta** | Statistiky, profily, moduly. | `tenantDetailProvider`, `tenantProfilesProvider`, `tenantStatsProvider`, `tenantStatsFullProvider`, `tenantModuleSubscriptionMapProvider` |
| **Audit log** | Globální audit. | `auditLogTenantFilterProvider`, `auditLogListProvider`, `auditLogActorNamesProvider` |
| **Billing overview** | Přehled plateb napříč tenanty. | `billingOverviewProvider` |
| **HQ staff** | Interní zaměstnanci HQ. | `hqStaffProvider`, `hqStaffListProvider` |
| **HQ kontrakty / portfolio** | Smlouvy a portfolio HQ lidí. | `hqStaffContractRepositoryProvider`, `hqStaffActiveContractProvider`, `hqStaffPortfolioProvider`, `hqStaffAbsencesProvider` |
| **Agency settlements** | Vyúčtování agentur. | `agencyManagementSettlementsRepositoryProvider`, `monthlyAgencySettlementsProvider` |
| **Support interventions** | Zásahy podpory. | `supportInterventionsRepositoryProvider`, `supportInterventionsListProvider` |
| **Onboarding wizard** | Průvodce založením tenanta. | `onboardingWizardProvider` |

**Repozitáře:** `AuditLogRepository` (+ mobile varianta), sdílené helpery `audit_log_shared.dart`.

---

## 7. Komunikace – šablony zpráv (`lib/features/communication`)

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Šablony (admin)** | CRUD šablon na Supabase. | `messageTemplatesAdminProvider`, `messageTemplatesAdminNotifierProvider` |
| **Šablony (worker)** | Lokální šablony z Drift po synci. | `messageTemplatesForWorkerProvider` (mobile/web/stub) |
| **Výběr šablony / WhatsApp** | Bottom sheet, odeslání přes `wa.me`. | kontext bez vlastního provideru – `MessageTemplateSelectorContext` + `WhatsAppSenderService` |
| **Placeholdery** | Nahrazení `{guest_name}` atd. | logika v `TemplatePlaceholderService` (statické metody, žádný vlastní Provider) |

---

## 8. Nastavení (`lib/features/settings`)

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Settings screen** | Profil, integrace, moduly, billing záložky; editor **primární + sekundární** barvy přes `tenantColorsProvider` (statické sémantické barvy v tématu). | `currentUserProfileProvider`, `tenantServicesProvider`, `tenantIntegrationSettingsProvider`, `tenantColorsProvider`, `appThemeFromTenantColorsProvider` |
| **Tenant UI preferences (Drift + Supabase)** | Repozitář + `tenantColorsProvider` ([AsyncNotifier]): sync při build, zápis `savePreferences`, téma jen brand primary/secondary; `FalcoNestApp` sleduje `appThemeFromTenantColorsProvider`. | `TenantUiPreferencesRepository`, `tenantColorsProvider`, `appThemeFromTenantColorsProvider` |
| **Editor modulů** | Zapnutí služeb tenanta. | `tenantServicesProvider`, moduly |
| **Integrace (Twilio…)** | Konfigurace komunikace. | `tenantIntegrationSettingsProvider` |
| **Zóny (admin screen)** | `AdminZonesScreen` z routeru. | `zonesProvider` |
| **Module editor** | Vizuální editor aktivních modulů. | `module_provider` |

**Služba:** `TwilioProvisionService` (v features/settings) – provisioning bez samostatné „stránky“.

---

## 9. Kalendář a plánování (`lib/features/calendar`)

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Plánovací kalendář (admin)** | Úkoly + rezervace v měsíčním pohledu. | `planningCalendarDataProvider`, `planningCalendarDataForMonthProvider`, `planningCalendarAllTasksProvider`, `planningCalendarAllTasksForMonthProvider` |

---

## 10. Dashboard (domů) (`lib/features/dashboard`)

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Dnešní úkoly** | Widget úkolů na přehledu (závisí na platformě). | `todaysTasksProvider` (mobile/web/stub) |
| **Konektivita (feature)** | Duplicitní/stream varianta ve feature složce. | `connectivityStatusProvider` (`dashboard/providers/connectivity_provider.dart`) |

---

## 11. Úkoly – sdílený detail (`lib/features/tasks`)

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Task detail screen** | Admin detail úkolu (jiný než worker). | `taskDetailProvider` (mobile/web/stub family) |
| **Modely checklistů** | Freezed/JSON modely šablon a instancí. | používá admin/worker checklist providery |

---

## 12. Platby (`lib/features/payment`)

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Success / Cancel** | Návrat z platební brány. | často bez vlastního provideru – router + auth |

*(V routeru mohou být routy zakomentované – ověřit aktuální `app_router.dart`.)*

---

## 13. Rezervace – modely (`lib/features/reservations`)

| Blok | Popis |
|------|--------|
| **Reservation model** | DTO pro kanban a formuláře; hlavní tok přes `admin_reservations_provider` a owner providery. |

---

## 14. Offline a fronta

| Blok | Popis | Providery |
|------|--------|-----------|
| **Mutation queue** | Ukládání operací do fronty, zpracování online. | `mutationQueueServiceProvider` |
| **Drift sync balíček** | `packages/falconest_drift` – schéma SQLite. | přes `database_provider` v app |

---

## 15. Sdílené widgety

| Soubor | Účel |
|--------|------|
| `shared/widgets/placeholder_screen.dart` | Dočasná náhrada rout. |

---

## 16. Shrnutí: logika často bez dedikované „modulové“ obrazovky

- **WorkerSyncService** – synchronizace Drift ↔ Supabase (úkoly s Timestamp Merging, rezervace s `updated_at` / `lastSyncedAt` a Smart merge při pushi statusu, byty, klienti, šablony, checklisty). `NetworkSyncWatcher` při návratu online předává `driftRepos`, aby se pending rezervace a úkoly skutečně odeslaly.
- **TemplatePlaceholderService** – náhrada proměnných v textu šablon před WhatsAppem.
- **AuditLogService + repository** – zápis a čtení auditu.
- **Billing / settlement / PDF exporty** – generování a akce na pozadí.
- **MediaService** – upload souborů do storage.
- **PushNotificationService** – FCM.
- **Task assignment engine** – business pravidla přiřazení (izolovaný soubor).
- **Offline task complete processor** (v core/offline) – dokončení úkolu s fotkami z fronty.

---

## GeoJSON / PostGIS (souřadnice v aplikaci)

- **`lib/core/utils/geo_json_point.dart`** – sdílená konverze sloupce `geo_location` mezi PostgREST (GeoJSON `Point`, `coordinates: [lon, lat]`) a poli `latitude` / `longitude` v Dart modelech; metody `validateOptionalSmartGpsText` / `tryParseSmartGpsText` pro jedno paste-ovatelné pole GPS; `workerGpsFromTaskThenApartment` pro prioritu bodu úkolu oproti bytu ve Worker DTO.
- **`lib/core/models/worker_task.dart`** + **`lib/core/models/worker_task_detail.dart`** – DTO pro Worker (`latitude`/`longitude`, `hasGps`, `displayAddress` u listu); naplnění z `TaskRepositoryWeb` ze Supabase; Drift zatím vrací GPS null (bez lokálního geo sloupce).
- **`lib/features/worker/utils/worker_google_maps_uri.dart`** – sjednocené skládání `https://www.google.com/maps/search/?api=1&query=` s předností `lat,lon` oproti textové adrese pro navigaci z dashboardu / detailu / transferu.
- **`lib/core/utils/gps_parser.dart`** – funkce `parseSmartGpsString`: vstup z Mapy.cz / Google (např. `38.0539500N, 0.7401433W` nebo `38.053, -0.740`; oddělovač čárka nebo mezery); pořadí tokenů zeměpisná šířka → délka.
- **`lib/features/admin/screens/admin_map_dispatch_screen.dart`** – mapový dispečink (flutter_map + OSM): živé markery pro byty a úkoly se souřadnicemi z `apartmentsFullListProvider` a `adminTasksStreamProvider`; záložka v `AdminLayout` [IndexedStack] pod modulem DB `key = map` ([ModuleIconMapper]).
- **`lib/core/services/geocoding_service.dart`** – geokódování textové adresy přes OSM Nominatim (`User-Agent: FalcoNest/1.0`); tlačítko „Získat GPS“ u adresy bytu a u lokace externího úkolu.
- **`supabase/functions/export_calendar`** + RPC **`get_calendar_feed_data`** – HTTP GET s `export_token` → `.ics` pro Home Assistant atd. RPC vrací mimo základní sloupce i **`feed_task_type`** (typ služby pro HA: kód z katalogu / úkolu / titulku), **`feed_agency_price`** (cena agentury z **`tasks.metadata.amount_to_collect`**) a **`feed_transit_price`** (průtoková cena z **`tasks.metadata.transit_amount_to_collect`**). Geodata: `geo_latitude` / `geo_longitude` (úkol nebo byt; v SQL **`extensions.ST_Y` / `extensions.ST_X`**). Ve VEVENT **GEO** jen při platném páru souřadnic, rozšířené **LOCATION**. Vlastnost **DESCRIPTION**: lidský kontext + případně „Navigovat: …“, a **na konci** strukturovaný blok pro HA (oddělovač **`---`**, pak **`Type:`**, **`AgencyPrice:`**, **`TransitPrice:`** z polí `feed_*`). Migrace: **`20260403150000_calendar_feed_geo_postgis_qualify.sql`** (GEO/SQL), **`20260405120000_calendar_feed_ha_automation_fields.sql`** (RPC + HA pole; obsahuje **`DROP FUNCTION …`** před **`CREATE`**, jinak chyba **42P13** při změně návratového typu).

### Worker – rychlé interakce v terénu (2026-04, fáze 4.1)

- **`worker_task_checklist_widget_io.dart`** – `Dismissible` na položce checklistu (stejný zápis jako checkbox přes **`WorkerTaskChecklistOpsController`**).
- **`ITaskRepository.appendWorkerQuickNote`** – append do **`tasks.description`** (Drift + Supabase / fronta **`UPDATE`**).
- **`worker_task_detail_screen.dart`** – FAB + dialog rychlé poznámky.
- **`worker_dashboard_screen.dart`** – seskupení karet podle bytu / adresy (`_locationGroupKey`), řazení v rámci dne chronologicky.

### Worker – média, merge, hotovost (2026-04, fáze 4.2)

- **`PhotoAnnotationScreen`** + **`pickWorkerPhotoWithAnnotation`** – červené kreslení přes fotku, export PNG; napojeno na **`TaskPhotoUploader`** a hlášení závad.
- **`WorkerSyncService.pushPendingUpdates`** – volitelný **`onSmartMergeApplied`** po Smart Merge konfliktu; snack přes **`transientI18nSnackKeyProvider`** (`WorkerSyncStateNotifier`, **`NetworkSyncWatcher`**).
- **`worker_dashboard_screen.dart`** – **`_HighCashWalletWarningBanner`** (`myCashWalletProvider`, práh 500).

### Admin – CRM rychlé filtry, mapové trasy, audit úkolu (2026-04, fáze 3.2)

- **`lib/features/admin/screens/admin_clients_screen.dart`** – rychlé filtry (`FilterChip`): klienti s **`profile_id`** (portál), klienti bez e-mailu; lokálně nad načteným seznamem spolu s vyhledáváním.
- **`lib/features/admin/screens/admin_map_dispatch_screen.dart`** – filtr pracovníka; **`PolylineLayer`**: chronologické spojnice mezi dnešními úkoly stejného assignee (≥2 GPS body).
- **`taskAuditLogsProvider`** (`task_audit_logs_provider.dart`) + **`TaskAuditHistorySection`** – audit z **`audit_logs`** pro **`table_name = tasks`** a **`record_id`** = id úkolu; **`AuditLogRepository.fetchLogsForRecord`**.

### Admin – Kanban hromadné akce, štítky úkolů, historie komunikace u rezervace (2026-04)

- **`lib/features/admin/admin_tasks_screen.dart`** – výběr více úkolů (režim výběru / dlouhé podržení), hromadná změna stavu a přiřazení přes **`AdminTasksNotifier.bulkUpdateTaskStatus`** / **`bulkAssignTasks`**; vlastní štítky ukládané do **`tasks.metadata.custom_tags`** (viz **`TaskCustomTag`**).
- **`lib/features/admin/providers/automation_log_repository.dart`** – **`fetchForReservation`**: log z **`tenant_message_log`** přes frontu **`automation_message_queue`** s **`entity_id`** = rezervace.
- **`reservationMessageLogProvider`** (`automation_log_provider.dart`) – data pro záložku historie.
- **`lib/features/admin/widgets/reservation_communication_history_section.dart`** – záložka v **`EditReservationDialog`**.

### Skryté backendové mechanismy (audit 2026-04)

- **XLSX import pipeline rezervací** – `lib/features/admin/services/reservation_import_service.dart` (`generateExcelTemplate`, `processImport`, `parseServiceCell`): tenant-specific šablona se `srv_*` sloupci, dávkové zpracování rezervací, mapování služeb (`tenant_services` + `apartment_services`), fallback časů a oddělený insert do `reservation_services`, včetně „soft warning“ přístupu pro neznámé služby.
- **iCal sync idempotence a deduplikace** – `lib/features/admin/services/ical_sync_service.dart` (`syncIcalUrl`): synchronizace přes Edge funkci, validace eventů, deduplikace dle `external_uid`, insert pouze nových rezervací, návrat metrik (`insertedCount`, `skippedDuplicates`) pro bezpečný opakovaný sync.
- **Automation queue runtime řízení** – `lib/features/admin/providers/automation_queue_repository.dart` (`cancelMessage`, `scheduleSendNow`, `invokeAutomationDispatch`, `insertAdhocMessage`, `updateMessagePayload`): ruční operativa fronty (cancel/send-now), ad-hoc zprávy, manuální dispatch mimo cron a konzistentní úpravy payloadu.
- **Cash transit state engine rezervace** – `lib/core/repositories/cash/reservation_cash_transit_repository.dart` (`resolve`, `settleTransitCash`): výpočet stavové fáze průtokové hotovosti (`awaitingCollection`, `withWorker`, `atAgencyVault`, `settledToOwner`) z úkolů/rezervace/**employee_cash_transactions**; trvalý záznam po vyúčtování majiteli v DB tabulce **`owner_cash_transit_settlements`** (ochrana proti duplicitnímu settlementu).
- **Task insert guardrail (sanitizace payloadu)** – `lib/core/repositories/task/supabase_task_insert_repository.dart` + `lib/core/repositories/task/task_insert_sanitizer.dart`: centralizované vynucení `tenant_id`, normalizace času (`scheduled_start`, `due_date`), doplnění `metadata.estimated_minutes` a bezpečný merge metadata bez přepsání kritických klíčů.
- **Team offboarding logic (odpojení otevřených úkolů)** – `lib/features/admin/providers/admin_team_repository.dart` (`softDeleteTeamMember`, `unassignOpenTasksForMember`): při odchodu člena bezpečné odpojení úkolů z `assigned_to`/`assigned_user_ids`, reset workflow statusu a auditní stopa (`unassigned_info`).

---

## 17. QA / Provozní standardy

### Theme Refactor — Admin Widgety (2024)

**Status:** ✅ Hotovo (FÁZE 1–4)

**Cíl:** Centralizace hardcoded barev v admin widgetech na theme tokeny (`context.colors` / `context.customColors`).

**Dokumenty:**
- **Report:** `docs/ai_context/admin_theming_refactor_report.md`
  - Scope, mapování barev, technické detaily, known limits
  - Čti když: chceš pochopit, co se změnilo a proč
- **QA Template:** `docs/ai_context/admin_theming_manual_qa_template.md`
  - Auditovatelný checklist pro manuální QA (light/dark mode)
  - Čti když: provádíš vizuální kontrolu nebo dokumentuješ defekty

**Dotčené soubory:**
- `lib/core/theme/custom_colors.dart` (nové sémantické barvy)
- `lib/features/admin/widgets/*` (7 widgetů refaktorováno)

**Validace:**
- `flutter analyze lib` ✅ bez chyb
- `flutter test test/features/admin/widgets/theme_refactor_smoke_test.dart` ✅ 4/4 testy

**Příští kroky:**
1. Manuální QA (light/dark mode) — viz QA template
2. Code review
3. Merge do main

---

*Dokument generován podle struktury `lib/` a grep na `final *Provider` v době poslední úpravy. Pro přesný seznam všech providerů použij vyhledávání `^final ` v souborech `*_provider.dart`.*
