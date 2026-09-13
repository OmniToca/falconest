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
| **Drift DB** | SQLite instance, repozitáře úkolů, bytů, rezervací, fronta mutací, checklisty, šablony. Byty: mimo základních polí i **`investment_tracking_enabled`** (schema v16, parita s Supabase). | `driftDatabaseProvider`, `driftTaskRepositoryProvider`, `driftApartmentRepositoryProvider`, `driftClientRepositoryProvider`, `driftReservationRepositoryProvider`, `driftTenantRepositoryProvider`, `driftMessageTemplateRepositoryProvider`, `driftPendingMutationRepositoryProvider`, `driftTaskChecklistRepositoryProvider`, `driftSyncReposProvider` |
| **Modely bytu / investiční metriky (core)** | Freezed + JSON serializace pro odpovědi PostgREST: celý řádek **`apartments`** včetně **`investment_tracking_enabled`**, a 1:1 **`apartment_investment_metrics`**. Admin grid dál používá **`ApartmentRow`** (`apartments_provider.dart`) – pole synchronizováno. | `lib/core/models/apartment_model.dart`, `lib/core/models/apartment_investment_metrics.dart`, pomocné konvertory `model_date_time_json.dart`, `model_numeric_json.dart` |
| **Premium karty (dekorace)** | Sjednocený vizuál karet (surface + stín z tématu) pro nástěnku a CRM dlaždice. | `premiumCardDecoration` (`lib/core/theme/premium_card_decoration.dart`) |
| **LazyIndexedStack** | Náhrada `IndexedStack` pro Admin/Owner layout: mountuje child až při první návštěvě tabu, poté drží stav přes `Offstage`. Snižuje cold start – neaktivní záložky nespouští providery hned po loginu. | `lib/core/widgets/lazy_indexed_stack.dart` – použití v `AdminLayout`, `OwnerLayout` |
| **Task repository (platforma)** | Web: Supabase; mobil: Drift. | `taskRepositoryProvider` (export z `task_repository_provider_*`) |
| **Konektivita** | Sledování online/offline. | `isOfflineProvider` (`core/providers/connectivity_provider.dart`) |
| **Sync stav (globální)** | Indikace běžící synchronizace. | `syncInProgressProvider`, `syncStatusProvider` |
| **Notifikace** | Nepřečtené notifikace. | `notificationRepositoryProvider`, `unreadNotificationsProvider` |
| **Měna tenanta** | Formátování částek podle tenanta. | `currentTenantCurrencyProvider` |
| **Sazby zpráv (Twilio atd.)** | Admin přehled nákladů na SMS/WhatsApp. | `platformMessagingRatesProvider` |
| **Mutation queue** | Fronta offline mutací: mobil Drift; na webu `enqueueMutation` vyhodí `OfflineWebException` (fail-fast proti tiché ztrátě dat). | `mutationQueueServiceProvider` |
| **Transient i18n Snack** | Jednorázový lokalizovaný SnackBar bez `BuildContext` v Notifieru; host `TransientI18nSnackHost` v `app.dart`. | `transientI18nSnackKeyProvider` |
| **Editor překladů pro export (PDF)** | Sdílený dialog CS/EN/ES pro strukturu `name_i18n` / `title_i18n` (`translations` + volitelně `source_hash`). Napojen z editoru služeb a z formuláře manuálního úkolu v adminu. | `lib/core/widgets/export_i18n_editor_dialog.dart` |

### Služby bez vlastního „modulového“ screenu (jen volané z kódu)

| Služba | Účel |
|--------|------|
| `SupabaseService` | Klient a bezpečné dotazy s `tenant_id`. |
| **`tenant_ui_preferences` (DB)** | Supabase + Drift: brandové barvy tenanta (`primary_color`, `secondary_color`, `updated_at` pro Timestamp Merging). RLS: čte kdokoli v tenantovi, zapisuje admin/manager. Migrace `20260402140000_tenant_ui_preferences.sql`. |
| `AuditLogService` | Zápis auditních událostí. |
| **Údržba DB (Supabase)** | pg_cron: `maintenance_data_cleanup()` (mazání starých logů a soft-delete záznamů), tři joby `VACUUM ANALYZE` pro mapové tabulky; Edge **export_calendar** – in-memory rate limit 20 req/min na hash iCal tokenu. Migrace `20260407220000`, `20260407221000`. |
| `MediaService` / `PhotoService` | Upload médií (úkoly, checklisty). |
| **`FalconestNetworkImage`** | P2: `CachedNetworkImage` + `memCacheWidth/Height` pro náhledy (Kanban, účtenky, owner fotky). | `lib/core/widgets/falconest_network_image.dart` |
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
| **Login, waiting room, suspended** | Přihlášení, čekání na schválení, zablokování. Responzivní formulář a pole jsou ve **`lib/features/auth/widgets/`** (`AuthLayout`, `AuthTextField`, barvy) – obrazovka drží jen stav a handlery. | `authNotifierProvider` |
| **PIN setup / verify / change** | Lokální PIN na zařízení. | `pinUnlockedProvider`, auth |
| **Invite** | Obrazovka **`/invite`** – token z URL; načtení dat přes RPC **`get_invitation_for_accept`** v **`InviteRepository`** (RLS na **`invitations`** neumožňuje anon přímý SELECT). | `inviteDataProvider`, `InviteRepository` |
| **Hesla** | Set/update password flow. | auth |
| **Onboarding (public)** | Registrace / úvodní flow. | — |
| **Payment required** | Blokace při nezaplaceném modulu. | auth, moduly |

---

## 3. Admin – dispečink (`lib/features/admin`)

Hlavní layout: `AdminLayout` (spodní navigace / sekce).

| Oblast | Popis | Hlavní providery |
|--------|--------|------------------|
| **Dashboard** | Operativní přehled (plán, flotila, lehká KPI: komunikace/automatizace, CRM, absence); bez těžkých analytických dotazů. Sekce **Data Insights**: karta efektivity úklidů (`AdminTaskEfficiencyInsightsCard`, `admin_efficiency_chart.dart`) agreguje z [adminDashboardTasksProvider] délku (`completed_at`−`started_at`) a zpoždění Startu (`started_at`−`scheduled_start`); výpočet `computeAdminTaskEfficiencySummary` v `admin_task_efficiency_stats.dart`. | `dashboardSummaryProvider`, `adminDashboardTasksProvider`, `adminTasksTrendProvider`, `automationSummaryProvider`, `messagingHealthProvider`, `messagingFailuresProvider`, `newClientsThisMonthProvider`, `upcomingAbsencesProvider` |
| **Úkoly** | Seznam, filtry, měsíc, stream, přiřazování. Kanban karta zobrazuje počet fotek z `media_urls`, pokud není prázdné. Změna statusu (`updateTaskStatus` / `updateTaskInAdmin`) doplní Time Tracking `started_at` / `completed_at` přes `applyAdminTaskStatusTimestampsToUpdate`. Formulář Externí služba: vyhledávací výběr klienta + rychlé vytvoření (`TaskExternalClientPicker`). **AI prefill z textu (Fáze 3 multimodal):** tlačítko „Z textu“ → text a/nebo screenshot (Cmd/Ctrl+V / upload, komprese JPEG) → Edge `parse-task-draft` (Gemini `inlineData` + Structured Output; wall-clock čas; resolution apartmán/`clients`/`tenant_services`; cena + hotovost) → preview → `_AddTaskDialog` bez auto-INSERT. | `adminTasksProvider`, `adminTasksStreamProvider`, `adminTasksOpsWindowProvider`, `selectedTaskMonthProvider`, `tasksForReservationProvider`, `taskByIdProvider`, `tasksForApartmentProvider`, `tasksForMemberProvider`, `clientTasksProvider`, `adminDashboardTasksProvider`, `apartmentsNameByIdLiteProvider`, `teamNameByProfileIdLiteProvider`, `admin_task_status_timestamps.dart`, `task_external_client_picker.dart`, `task_form_draft.dart`, `task_draft_parse_service.dart`, `task_draft_from_text_dialog.dart`, `task_draft_image_prepare.dart`, `task_draft_clipboard_image.dart` |
| **Úkoly – těžký výpočet mimo UI** | Smart generátor (fáze C: kolize, přiřazení) a simulace přepočtu personálu běží v `Isolate.run` na iOS/Android/desktop; na webu stejná logika synchronně (`kIsWeb`). Soubor nesmí importovat `admin_tasks_provider` (cyklus). | `lib/features/admin/providers/admin_tasks_isolate_workers.dart` |
| **Kanban – granulární sloupce** | `tasksBySystemStatusProvider` (`Provider.family` + `KanbanColumnTasks` s value equality) filtruje úkoly podle systémového statusu a `kanbanTasksSearchQueryProvider`; sloupec se překreslí jen při změně „svých“ dat. `kanbanHasVisibleTasksProvider` řídí prázdný stav bez globálního `watch` celého streamu na Scaffoldu. | `tasksBySystemStatusProvider`, `kanbanTasksSearchQueryProvider`, `kanbanHasVisibleTasksProvider` v `admin_tasks_provider.dart` |
| **Rezervace** | Kanban / seznam, trendy; bez polí `is_owner_block` / `agency_collects_payment` v UI ani modelech. Kanban (záložka Seznam): granulární sloupce přes `reservationsBySystemStatusProvider` (`Provider.family` + `KanbanColumnReservations`), vyhledávání `kanbanReservationsSearchQueryProvider`, prázdný stav `kanbanHasVisibleReservationsProvider`; karty používají `premiumCardDecoration` stejně jako úkoly. Model `ReservationRow` obsahuje `created_at` pro štítek stáří záznamu v Kanbanu (`reservationRecordAgeLabel` v `admin_reservation_utils.dart`). | `adminReservationsProvider`, `adminReservationsStreamProvider`, `reservationsBySystemStatusProvider`, `kanbanReservationsSearchQueryProvider`, `kanbanHasVisibleReservationsProvider`, `clientReservationsProvider`, `reservationsForApartmentProvider`, `adminReservationsTrendsProvider` |
| **Apartmány** | Seznam bytů, stránkování; měsíční obsazenost z přesného SQL řezu; stav bytu nezávislý na měsíci v modulu Úkoly. Editace bytu: **`rental_mode`**, **`lease_*`**, u dlouhodobého **`rent_amount`**, **`rent_due_day`**, **`rent_collection_mode`**, **`rent_task_assignee_id`**. Při **`investment_tracking_enabled`** + **`long_term`** + **`notification`**: v záložce Základní blok **Přijetí nájmu (P&L)** – potvrzení upsertu **`income`** přes **`OwnerApartmentPnlRepository.upsertIncomeEntry`** (stejná logika jako majitel). Denní Edge **`rent-monitor`** + tabulka **`apartment_rent_due_runs`**. | `apartmentsProvider`, `apartmentsFullListProvider`, `apartmentsNameByIdLiteProvider`, `apartmentsLoadingMoreProvider`, `currentMonthReservationsProvider`, `apartmentStatusContextReservationsProvider`, `todayApartmentTasksProvider`, `apartmentStatusProvider` |
| **Stav apartmánů** | Dashboard flotila + karty bytů: rezervace v okně ~400 dní, úklidy přes `watchTasksRawForApartmentStatus` (ne `selectedTaskMonthProvider`). | `apartmentStatusProvider`, `todayApartmentTasksProvider`, `apartmentStatusContextReservationsProvider` |
| **Tým** | Členové, absence, finance člena, dostupnost k úkolu + absence radar. Vytížení na kartě personálu z úzkého okna úkolů (ne měsíc ze záložky Úkoly). | `adminTeamProvider`, `teamFullListProvider`, `teamNameByProfileIdLiteProvider`, `staffAbsencesProvider`, `upcomingAbsencesProvider`, `availableTeamForTaskProvider`, `memberFinancesProvider`, `teamLoadingMoreProvider`, `teamWeeklyWorkloadTasksProvider`, `adminTasksOpsWindowProvider` |
| **Klienti (CRM)** | Stránkované vyhledávání přes Supabase `.textSearch('search_vector', …, config: simple, type: websearch)` v `ClientRepository.getPaginatedClients` (GIN/tsvector); tři záložky = tři dotazy s filtrem `client_type`. Lehká mapa agentur, COUNT doporučení, adresář, portál, finance. **Hybridní B2B partner:** sloupec `clients.can_bill_external_tasks` – Switch v `client_form_dialog.dart`; při `true` se klient zobrazí v roletce u **Externí služby** (`admin_tasks_screen.dart`) i když má `client_type = owner` (např. ESP House – jedna faktura za měsíc). V detailu klienta (`client_detail_dialog`) jsou e-mail a telefon klikatelné (`mailto:` / `tel:` přes `url_launcher`). | `paginatedClientsByTabProvider`, `clientsLoadingMoreByTabProvider`, `agencyNamesMapProvider`, `recommendedClientsCountByAgencyProvider`, `clientsRecommendedListByAgencyProvider`, `clientsFullListProvider`, `invalidatePaginatedClientTabs`, `clientAddressesProvider`, `clientPortalStatusProvider`, `addClientProvider`, `updateClientProvider`, `softDeleteClientProvider`, `clientFinancesProvider` |
| **Finance – fakturace** | Přehledy fakturace, reporty; před uzamčením měsíce varování při úkolech bez přiřazení (`assigned_to` + `assigned_user_ids`) nebo s povinnou fotkou bez `media_urls`. Výpočet ceny/plátce u úkolu v podkladech sdílí modul **`lib/core/billing/billing_task_financials.dart`** (`buildBillingReservationServiceMaps`, `billingChargedPriceAndPayerForTask`) s Klientským portálem. **COMPANY_EXPENSE** v `billingReportProvider` (Krok 3b): přiřazení klientovi přes `apartment_id` → majitel bytu, nebo **fallback `client_id`** bez bytu (hybridní náklady). PDF/UI: úkoly mimo rezervaci rozděleny funkcí **`splitBillingTasksWithoutReservation`** na sekce `billing_apartment_bound_services` / `billing_external_services` (`BillingTaskItem.apartmentId`). U **uzamčeného** měsíce načítá `billingReportProvider` i `id`, `payment_status`, `invoice_pdf_url` ze `billing_snapshots`; v `FinanceBillingContent` menu ⋮ mění stav úhrady a URL PDF (`FinanceRepository.updateSnapshotPaymentStatus` / `updateSnapshotInvoicePdfUrl`), štítek úhrady = `BillingPaymentStatusChip`. Kurzy měn: `currenciesProvider` (TTL 1 h). | `billingReportProvider`, `clientBillingProvider`, `financeTabProvider`, `currenciesProvider`, `FinanceRepository`, `splitBillingTasksWithoutReservation` |
| **Finance – hotovost / peněženky** | Peněženky zaměstnanců, transakce, výpadky výběru; **průtoková hotovost majitele** – po uzavření pobytu záznamy v Supabase tabulce **`owner_cash_transit_settlements`** (vazba na **rezervaci**, volitelně **`employee_cash_transaction_id`**) řídí **`ReservationCashTransitRepository`** (`resolve`, `settleTransitCash`). **Žádosti majitelů o výplatu** – záložka ve `FinanceDashboardScreen` (`AdminOwnerCashRequestsScreen`), provider `adminOwnerCashRequestsProvider`, detail `showAdminOwnerCashRequestDetailSheet`. **Hlídač hotovosti** – záložka `AdminCashAuditScreen` nad view **`vw_cash_collection_audit`** s filtrem anomálií (`missing_cash`/`duplicate_cash`/`amount_mismatch`/`ok`) a proklikem na editaci úkolu; data načítá `cashAuditRowsProvider` + `cashAuditAnomalyFilterProvider`. | `employeeCashWalletsProvider`, `myCashWalletProvider`, `myCashTransactionsProvider`, `walletTransactionsProvider`, `failedCashCollectionsProvider`, `cashShortfallsCountProvider`, `walletBalanceProvider`, `adminOwnerCashRequestsProvider`, `cashAuditRowsProvider`, `cashAuditAnomalyFilterProvider` |
| **Vyúčtování / settlements** | Čekající výplaty, historie, seskupení. | `pendingSettlementsProvider`, `taskSettlementsProvider`, `groupedPendingPayoutsProvider`, `payoutHistoryReportProvider`, `taskIdsWithPayoutsProvider`, `taskIdsWithCommissionsProvider`, `lockedFinancialTaskIdsProvider` |
| **Reporty** | Měsíční reporty provozu (grafy fl_chart). Agregace v Dartu z úkolů měsíce (limit 2000); jména bytů/personálu jsou v `ApartmentRevenue.displayName` a `EmployeePerformance.memberDisplayName` (snapshot při výpočtu), aby UI grafů nesledovalo `apartmentsFullListProvider` / `teamFullListProvider`. Apartmány/tým se v `reportsDataProvider` načítají přes `ref.read(...future)` (ne watch listů). | `reportsMonthProvider`, `reportsDataProvider` |
| **Moduly tenanta** | Aktivní moduly, katalog. | `allModulesProvider`, `activeModuleKeysProvider`, `tenantActiveModuleIdsProvider`, `tenantModuleCancelAtPeriodEndIdsProvider` |
| **Zóny** | Parkování / zóny k bytům. | `zonesProvider` |
| **Kategorie úkolů** | Ikony a barvy typů úkolů. | `taskCategoriesProvider` |
| **Služby apartmánu** | Volby služeb pro úkoly / ceny + průtoková částka služby (`apartment_services.metadata.transit_price`) pro generování `transit_amount_to_collect`. | `apartmentServicesOptionsProvider`, `manualTaskServicePriceProvider` |
| **Majitelé nemovitostí** | Propojení majitel–byt. | `apartmentOwnersForApartmentProvider`, `ownerApartmentCountsProvider`, `apartmentsForProfileProvider`, `propertyOwnersInTenantProvider` |
| **iCal synchronizace** | Externí kalendáře. | `icalSourcesProvider`, `icalSyncNotifierProvider` |
| **Automatizace – pravidla** | Pravidla zpráv/automatizací. | `automationRulesProvider` |
| **Automatizace – fronta** | Odchozí fronta akcí. | `automationQueueProvider` |
| **Automatizace – log** | Historie odeslaných zpráv tenantům. | `automationLogProvider` |
| **Automatizace – dispatch internal_push** | Edge `automation-dispatch`: položky fronty s kanálem `internal_push` odbaví FCM HTTP v1 (tokeny `user_devices`), nikoli Twilio/WhatsApp; titulek/tělo a `data.route` / `reservation_id` z rezervace. **Majitel (Klientský portál):** DB triggery (`20260421150000_owner_lifecycle_notifications.sql`) vkládají frontu s `internal_push_kind` **`owner_task_started`**, **`owner_task_completed`**, **`owner_cash_collected`** — dispatch posílá FCM s `data.route` **`/owner`** a doplněnými `task_id` / `apartment_id` z payloadu. Naplánování fronty: `automation-enqueue` + existující pg_cron (typicky každou minutu). | Supabase Edge `automation-dispatch`, `automation-enqueue` |
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
| **`FinanceRepository`** | Fakturace: `invoiceTasks`; UPDATE `billing_snapshots` – `updateSnapshotPaymentStatus` (při `paid` nastaví `paid_at`, jinak vymaže), `updateSnapshotInvoicePdfUrl`; nepárovaná hotovost v trezoru (`getUnpairedVaultCash`). |
| **`AutomationsSeederService`** | Počáteční data automatizací. |
| **`IcalSyncService`** | Stahování a zpracování iCal. |

---

## 4. Worker – terén (`lib/features/worker`)

| Modul | Popis | Providery |
|-------|--------|-----------|
| **Dashboard úkolů** | Seznam úkolů přiřazených pracovníkovi; kalendářní sekce (Po termínu / Dnes / Zítra / Později) a chronologické řazení přes `groupWorkerTasksForDashboard`. | `workerTasksProvider`, `worker_task_dashboard_grouper.dart` |
| **Motivační měsíční statistiky** | Karta „úspěchů“ nad seznamem: dokončené úkoly v měsíci, spolehlivost (dokončení v den plánu) nebo odpracované hodiny, progress k měsíčnímu cíli. Drift stream / web Supabase. | `workerMotivationStatsProvider`, `WorkerMotivationDashboardCard` (`widgets/statistics/worker_motivation_card.dart`), agregace v `TaskRepository` / `DriftTaskRepository.watchMonthlyMotivationStats` |
| **Detail úkolu** | Master `WorkerTaskDetailScreen`: typ úkolu → `WorkerTaskBodySpec.resolve` v `worker_task_body_resolver.dart`; rychlá poznámka → `showWorkerTaskQuickNoteDialog` (`worker_task_quick_note_dialog.dart`). Patička `TaskCompleteWithPhotoSection` kontroluje `workerTaskStatusNotifierProvider.hasError` po `updateStatus`. | `workerTaskDetailProvider`, `workerTaskStatusNotifierProvider` |
| **Scribble podpis hosta** | Ruční podpis hosta na mobilu (`GestureDetector` + `CustomPainter`), export PNG s bílým pozadím a černou fixou; upload do `falconest_media` a `guest_signature_url` v `tasks.metadata`. UI karta + dialog + loading při ukládání: `WorkerTaskSignatureSection`. | `WorkerTaskSignatureSection` (`widgets/worker_task_signature_section.dart`), `SignaturePad`, `SignatureService`, `workerTaskStatusNotifierProvider` |
| **Checklist u úkolu** | Drift instance + fotky (IO/stub); při odškrtnutí `try-catch` + `AppLogger` + SnackBar `worker.checklist_update_failed`. | `workerTaskChecklistProvider`, `workerTaskChecklistOpsControllerProvider` |
| **Synchronizace** | Pull úkolů, šablon, push pending (Timestamp merge). Po dokončení úkolu online `flushPendingUpdatesBestEffort`; při `paused`/`inactive` flush v `AppLifecycleFcmListener`. | `workerSyncStateProvider`, `workerPendingSyncCountProvider`, `WorkerSyncService.flushPendingUpdatesBestEffort`, `AppLifecycleFcmListener` |
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
| **Dashboard** | Přehled pro majitele; první záložka v `OwnerLayout`, routa `/owner/dashboard`. Vizuál klientského produktu: `owner_portal_ui.dart` (max šířka obsahu, měkké sekce), gradient karta hotovosti, metriky s ikonami. **Rozpad nákladů:** donut graf `OwnerCostBreakdownDashboardCard` (`owner_cost_breakdown_chart.dart`), data `ownerCostBreakdownProvider` + `computeOwnerCostBreakdown` – agregace z posledního `billing_snapshots` (úkoly plátce majitel podle `task_type`, výdaje s `apartment_id`, poměr paušálu) a `ownerUninvoicedCompanyExpensesProvider`. | `ownerCostBreakdownProvider`, `ownerBillingSnapshotsProvider`, `ownerUninvoicedCompanyExpensesProvider`, … |
| **Klientský portál – sdílené UI** | `ownerPortalConstrainBody`, `ownerPortalSectionDecoration`, `ownerPortalMutedTaskFill`, `ownerPortalCalendarTaskIcon`, Kanban karty: `ownerPortalKanbanCardDecoration` / `ownerPortalKanbanCardShadows` / `kOwnerPortalKanbanCardRadius` (rezervace + úkoly majitele); rezervace / úkoly: horizontální Kanban od šířky 600 px, pod 600 px sloupce pod sebou. | — |
| **Nastavení majitele** | `OwnerSettingsScreen` – záložka v `OwnerLayout` (ikona ozubeného kola): sekce **Upozornění z terénu** (zahájení / dokončení práce, vybrání hotovosti) × kanály e-mail, zvoneček, push; zápis přes **`notificationPreferencesProvider`** do **`notification_preferences`** (`owner_*` sloupce). | `notificationPreferencesProvider` |
| **Apartmány** | Seznam bytů majitele; **stav chipu**: nejdřív aktivní pobyt z rezervací (`OwnerApartmentStatus.occupied`), jinak nejnovější úklidový úkol (Čistý / Probíhá / Čeká). Detail v dialogu (grid) nebo routa `/owner/apartments/:id` – záložky **Přehled a provoz** / **Investice a P&L** (`owner.tab_*`) jen při `investment_tracking_enabled`. | `ownerApartmentsProvider` |
| **Detail apartmánu** | Stav, údaje jednoho bytu; odkaz `review_link`, sekce iCal (RPC `get_owner_calendar_feed_url_for_apartment`); sekce **Provozní informace pro personál** (`parking_instructions`, `code`, `monthly_management_fee`, `managed_from`). Při `investment_tracking_enabled`: sekce **Investice a zhodnocení** – **`OwnerInvestmentDashboard`**: metriky (**`apartment_investment_metrics`**), karta **Celkový výnos** (**`ownerInvestmentRoiProvider`**: kapitál + Σ měsíční čistý zisk vč. agentury), měsíční bilance přes **`ownerCombinedPnlProvider`** (spojuje **`apartmentInvestmentPnlEntriesProvider`** a agenturní částky z **`ownerBillingSnapshotsProvider`** / výpočet **`OwnerApartmentAgencyCostsFromSnapshots`**: úkoly s plátcem majitel + poměr měsíčního paušálu dle `apartments.monthly_management_fee`). U **`rental_mode = long_term`** se v měsíční bilanci neukazuje ruční pole příjmů (short-term); **`rent_collection_mode = notification`**: očekávaný nájem + tlačítko potvrzení převodu (**`OwnerApartmentPnlRepository.upsertIncomeEntry`**), po zápisu stav „uhrazeno“; **`task`**: text, že hotovost řeší agentura; serverový trigger **`tasks_apply_rent_collection_to_pnl`** doplňuje **`income`** po dokončení úkolu **`rent_collection`**. Tabulka **Přehled posledních měsíců** u sloupce příjmů zobrazuje časovou osu výběru (plán **`tasks.due_date`** vs. realita **`tasks.completed_at`**, párování měsíce přes **`metadata.rent_cycle_key`** nebo **`billing_month`**) a bilanci nájemníka (**`OwnerRentPaymentDetailsService`**: FIFO amortizace plateb od nejstaršího měsíce, kauce v **`description`** mimo pool; hotovost přes **`task_id`**, P&L **`apartment_investment_pnl_entries`**; pole **`rentPlannedCollectionDate`**, **`rentActualCollectionDate`**, **`rentBalanceDifference`**, **`rentDepositAmount`**). | `ownerApartmentDetailProvider`, `apartmentInvestmentMetricsProvider`, `apartmentInvestmentPnlEntriesProvider`, `ownerCombinedPnlProvider`, `ownerBillingSnapshotsProvider`, `ownerInvestmentRoiProvider` |
| **Úkoly** | Záložky **Aktivní práce** (Kanban Zadáno / Probíhá, bez dokončených) a **Historie** (dokončené včetně vyfakturovaných); štítek **Moje hlášení** u údržby (`maintenance`) s `created_by` = majitel. Karta řádku: **`OwnerTaskCard`** (`owner_task_card.dart`). Detail: **`OwnerTaskDetailDialog`** + **`ownerTaskChecklistPhotosProvider`** (fotky z `task_checklist_items`). | `ownerTasksProvider`, `ownerTaskHistoryProvider`, `ownerTaskChecklistPhotosProvider` |
| **Rezervace** | Rezervace u majitele; blokace vlastního pobytu (`metadata.is_owner_stay`, `guest_name` konstanta); legacy sloupce `is_owner_block` / `agency_collects_payment` z produktu odstraněny (2026-04). Formulář `_NewReservationForm` v `owner_reservations_screen.dart`: u aktivní služby podmíněně pole **číslo letu** (`ReservationServiceEditState.flightNumber` → `reservation_services.flight_number`) pro transfer / letiště / `serviceType` obsahující `transfer`; při plátci **host** pole **hotovost k vybrání** (`transitCashToCollectEur` → `transit_cash_to_collect`). Uložení přes `saveForReservation`. **Detail pobytu** (bottom sheet): související úkoly přes **`ownerReservationRelatedTasksProvider`** (`tasks.reservation_id`). | `ownerReservationsProvider`, `ownerReservationRelatedTasksProvider` |
| **Plánovací kalendář** | Úkoly + all-day rezervace; rezervace z DB jen pro kalendářní měsíc obsahující zobrazený týden (`ownerReservationsForPlanningCalendarProvider`), ne celá historie; volitelný výběr jednoho bytu (`ownerPlanningCalendarApartmentFilterProvider` = null = všechny vlastněné). | `ownerPlanningCalendarTasksProvider`, `ownerPlanningCalendarEventsProvider`, `ownerReservationsForPlanningCalendarProvider`, `ownerPlanningCalendarApartmentFilterProvider` |
| **Služby bytu** | Volitelné služby z pohledu majitele. | `ownerApartmentServicesOptionsProvider` |
| **Fakturace majitele** | Snapshots vyúčtování (**`ownerBillingSnapshotsProvider`**); při otevření investičního přehledu v detailu bytu se provider invaliduje (IndexedStack drží záložku Fakturace v subtree – jinak by se nové uzamčené faktury neprojevily). Sekce firemních výdajů (COMPANY_EXPENSE) se schválením v `metadata`; na kartě Vyúčtování seznam výdajů z **`ownerUninvoicedCompanyExpensesProvider`** (bez řádků již uvedených v `snapshot_data.expenses[].id` uzamčených snapshotů). Transit hotovost – přehled uzavřených částek vázaných na pobyt odpovídá řádkům **`owner_cash_transit_settlements`**. UI: štítky `payment_status`, odkaz `invoice_pdf_url`, aktivní žádosti, úprava `pickup_date` (`pickOwnerVaultPickupDateTime`). | `ownerBillingSnapshotsProvider`, `ownerCompanyExpensesProvider`, `ownerUninvoicedCompanyExpensesProvider` |
| **Nástěnka – metriky** | Počty pobytů 14 dní + součet **dokončených úkolů** s **`invoiced_at` IS NULL** a plátcem majitel (`billingChargedPriceAndPayerForTask` / `buildBillingReservationServiceMaps` v `lib/core/billing/billing_task_financials.dart`; RLS **`reservation_services_property_owner_select`**). | `ownerDashboardMetricsProvider` |
| **Hlášení závad / task detail** | `OwnerReportIssueDialog`, read-only **`OwnerTaskDetailDialog`** (galerie `media_urls` + checklist). | owner task providery |

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
| **Plánovací kalendář (admin)** | Úkoly + rezervace v měsíčním pohledu; týdenní mřížka: rozložení karet přes `planningWeekGridProcessedProvider` + `PlanningWeekGridLayoutKey` (cache, ne přepočet při každém rebuildu). | `planningCalendarDataProvider`, `planningWeekGridProcessedProvider`, `planningCalendarDataForMonthProvider`, `planningCalendarAllTasksProvider`, `planningCalendarAllTasksForMonthProvider` |

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
- **`worker_task_detail_screen.dart`** – FAB volá `showWorkerTaskQuickNoteDialog` (`worker_task_quick_note_dialog.dart`).
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

- **`lib/features/admin/admin_tasks_screen.dart`** – výběr více úkolů (režim výběru / dlouhé podržení), hromadná změna stavu a přiřazení přes **`AdminTasksNotifier.bulkUpdateTaskStatus`** / **`bulkAssignTasks`**, hromadné soft-delete přes **`SupabaseService.safeFrom('tasks').update(deleted_at).inFilter('id', …)`** + **`AuditLogService`** na řádek; při hromadných akcích overlay **`_isProcessingBulk`**. Vlastní štítky v **`tasks.metadata.custom_tags`** (**`TaskCustomTag`**).
- **`lib/features/admin/providers/automation_log_repository.dart`** – **`fetchForReservation`**: log z **`tenant_message_log`** přes frontu **`automation_message_queue`** s **`entity_id`** = rezervace.
- **`reservationMessageLogProvider`** (`automation_log_provider.dart`) – data pro záložku historie.
- **`lib/features/admin/widgets/reservation_communication_history_section.dart`** – záložka v **`EditReservationDialog`**.

### Skryté backendové mechanismy (audit 2026-04)

- **XLSX import pipeline rezervací** – `lib/features/admin/services/reservation_import_service.dart` (`generateExcelTemplate`, `processImport`, `parseServiceCell`): tenant-specific šablona se `srv_*` sloupci, dávkové zpracování rezervací, mapování služeb (`tenant_services` + `apartment_services`), fallback časů a oddělený insert do `reservation_services`, včetně „soft warning“ přístupu pro neznámé služby.
- **iCal sync idempotence a deduplikace** – `lib/features/admin/services/ical_sync_service.dart` (`syncIcalUrl`): synchronizace přes Edge funkci, validace eventů, deduplikace dle `external_uid`, insert pouze nových rezervací, návrat metrik (`insertedCount`, `skippedDuplicates`) pro bezpečný opakovaný sync.
- **Automation queue runtime řízení** – `lib/features/admin/providers/automation_queue_repository.dart` (`cancelMessage`, `scheduleSendNow`, `invokeAutomationDispatch`, `insertAdhocMessage`, `updateMessagePayload`): ruční operativa fronty (cancel/send-now), ad-hoc zprávy, manuální dispatch mimo cron a konzistentní úpravy payloadu.
- **Cash transit state engine rezervace/long-term nájmu** – `lib/features/owner/repositories/reservation_cash_transit_repository.dart` (`resolve`, `settleTransitCash`, `ownerTransitCollectedTotalForReservation`, `syncOwnerSettlementAfterHandedToAgency`, `listSettlementsForOwnerProfile`, `getAvailableBalanceForOwner`, `listAvailableSettlementsForOwner`): fáze průtokové hotovosti z úkolů/rezervace/**employee_cash_transactions**; uznané částky jako **`OwnerCashTransitSettlement`** / tabulka **`owner_cash_transit_settlements`**. Po **`HANDED_TO_AGENCY`** volá admin dialog (`wallet_detail_modal`) **`syncOwnerSettlementAfterHandedToAgency`** s preferencí `reservation_id`, nově i fallback přes **`task_id`** + **`apartment_id`** pro **rent_collection** bez rezervace (migrace `20260421133000_owner_cash_transit_task_settlement.sql`). Větev long-term zapisuje popis „Vybraný nájem“ do `note`, aby byl zdroj připsání transparentní v auditu. Metoda vrací `bool` (`true` = success/no-op, `false` = chyba) a modal se po úspěšném převzetí hotovosti vždy zavře; párovací selhání se řeší následným warning SnackBarem. Při selhání zápisu se loguje audit **`TRANSIT_SETTLEMENT_FAILED`** s **`user_id` = `auth.users.id`** (`SupabaseService.client.auth.currentUser?.id`); chyby auditu i služby se tisknou přes **`debugPrint`** (ne `assert`). Pro dohled „sirotků“ volá `FinanceRepository.getUnpairedVaultCash`: načte HANDED transakce a settlementy s **`note` ILIKE `%HANDED_TO_AGENCY%`**, z poznámky parsuje **`(tx: <uuid>)`** a v Dartu odfiltruje již spárovaná ID (bez sloupce FK v DB). **Žádosti majitele o dispozici** – `OwnerCashDispositionRepository` + tabulka **`owner_cash_disposition_requests`** (migrace `20260409143000`).
- **FIFO bulk handover engine (2026-04-21)** – migrace `20260421140000_employee_cash_handover_allocations.sql`: auditní tabulka **`employee_cash_handover_allocations`** + RPC **`process_worker_cash_handover_fifo`**. Admin modal „Převzít hotovost“ (`wallet_detail_modal`) už nepáruje jen jeden `reservation_id`/`task_id`, ale volá FIFO backend, který atomicky: vytvoří `HANDED_TO_AGENCY`, rozdělí částku na source `COLLECTED_FROM_GUEST`, zapíše transit podíly do `owner_cash_transit_settlements` a aktualizuje zůstatek peněženky. Repository: `CashWalletRepository.receiveCashFromWorkerBulkFifo`. **Deduplikace (2026-05-22):** migrace `20260522100000_fifo_handover_skip_existing_settlements.sql` – RPC před `fifo_bulk_handover` INSERTem přeskočí rezervaci/úkol/byt, který už má řádek v `owner_cash_transit_settlements` (např. po `auto_handoff` z `ReservationCashTransitRepository.syncOwnerSettlementAfterHandedToAgency`).
- **Dispozice hotovosti majitele – rozšíření (2026-04):** migrace `20260410000000_cash_disposition_extensions.sql` – sloupec **`iban`** u **`owner_cash_disposition_requests`**; u **`billing_snapshots`** stavy úhrad **`payment_status`** (`unpaid` / `paid` / `cash_offset`), **`paid_at`**, **`invoice_pdf_url`**. Modely **`OwnerCashDispositionRequest`**, **`BillingSnapshotModel`** (`owner_billing_provider.dart`).
- **Dispozice – validace a vyzvednutí (Fáze 3):** migrace `20260410020000_pickup_date_and_status.sql` – **`pickup_date`**, status **`ready_for_pickup`**, RLS UPDATE majitele pro **`pending`**. Repozitář: **`createRequest`** (IBAN + vault 48 h), **`updateOwnerRequestPickupDate`**, **`OwnerDispositionValidationException`**. UI: dialog dispozice (IBAN, výběr termínu).
- **Částečné umoření / UPDATE snapshotů:** migrace `20260410010000_partial_offsets.sql` – **`used_amount`**, stav žádosti **`partially_completed`**, **`payment_status`** hodnota **`partially_paid`**, RLS UPDATE **`billing_snapshots`** pro admin/manager. Repozitář: **`OwnerCashDispositionRepository.applyOffsetToSnapshot`**, audit **`DISPOSITION_OFFSET_APPLIED`**. **Validace poolu (2026-08-28):** migrace **`20260828140000_billing_snapshots_offset_amount.sql`** – sloupce **`offset_amount`**, **`offset_request_id`**, **`offset_applied_at`**; čistá logika **`OwnerCashOffsetCalculator`** (min faktura / žádost / pool); Admin dialog **`billing_snapshot_payment_dialog.dart`** (volba „Použít hotovost ze zálohy“, auto **`cash_offset`** vs **`partially_paid`**). **Doplňkový zápočet doplatku:** u **`partially_paid`** lze opakovat zápočet z nové schválené žádosti – **`offset_amount`** se kumuluje (`existing + amountToApply`), dialog nabízí „Zápočet doplatku ze zálohy“; UI souhrn **`BillingOffsetPaymentSummary`** u stavu **`paid`** neukazuje zbývající doplatek. **Approval Loop (Fáze 3, 2026-08-28):** migrace **`20260828160000_billing_snapshot_offset_proposals.sql`** – tabulka **`billing_snapshot_offset_proposals`**, RPC **`respond_billing_offset_proposal`**. Flutter: **`BillingOffsetProposalsRepository`**, **`billing_offset_proposals_provider.dart`** (`ownerPendingOffsetProposalProvider`), Admin **`billing_offset_proposal_admin_section.dart`**, Owner **`billing_offset_proposal_owner_card.dart`** (RPC approve/reject, **`OwnerReadOnlyGate`** při impersonation).
- **Owner portál – hotovost u agentury (UI)** – `lib/features/owner/providers/owner_cash_providers.dart` (`ownerAvailableBalanceProvider`, `ownerAvailableSettlementsProvider`, `ownerCashRequestsProvider`, `ownerPortalTabIndexRequestProvider` přepíná záložku v `owner_layout.dart`); karta na `owner_dashboard_screen.dart`; sekce Vyúčtování + dialog `owner_cash_disposition_dialog.dart` v `owner_billing_screen.dart`. Dropdown dispozice: `listAvailableSettlementsForOwner` sloučí řádky se stejným `reservation_id` (Σ amount včetně záporných zápočtů), odečte rezervace žádostí, capne globálním zůstatkem; jedna položka na pobyt + `availableAmount` / `amountForDisposition`. Konstanty indexů záložek: `owner_portal_tabs.dart` (`OwnerPortalTabIndex`). **Dostupný zůstatek (2026-05-22):** `getAvailableBalanceForOwner` = součet `owner_cash_transit_settlements.amount` − součet `(amount - used_amount)` schválených žádostí (`approved` / `partially_completed` / `ready_for_pickup`) – schválení 250 EUR neodečte celý settlement 666 EUR. **Zápočet faktury z adminu:** `finance_billing_screen` při `cash_offset` / `partially_paid` volá `OwnerCashDispositionRepository.applyOffsetToSnapshot` (ne jen `FinanceRepository.updateSnapshotPaymentStatus`). **Mapování klienta:** `BillingGroup.groupKey` = `clients.id` → `resolveOwnerProfileIdForBillingClient` → `owner_profile_id` u žádosti. **Účetní protipohyb (2026-05-22):** po UPDATE žádosti vloží záporný řádek do `owner_cash_transit_settlements` (`amount` záporné, `note` s ID podkladu a žádosti, volitelně `status=settled`) – pool = součet settlementů, jinak by `used_amount` snížilo jen rezervaci a zůstatek by rostl chybně. Uzamčený měsíc archiv **neblokuje** úpravu snapshotu. Načítání řádků z `owner_cash_transit_settlements`: `ReservationCashTransitRepository.listSettlementsForOwnerProfile` řadí podle **`settled_at`** (základní migrace nemá `created_at`); **`OwnerCashTransitSettlement`** čte JSON klíč **`note`**, chybějící **`status`/`currency`** doplní výchozí hodnoty, volitelné rozšířené sloupce zůstávají nullable; při parsování řádku `debugPrint('Chyba při čtení settlementu: …')`.
- **Task insert guardrail (sanitizace payloadu)** – `lib/core/repositories/task/supabase_task_insert_repository.dart` + `lib/core/repositories/task/task_insert_sanitizer.dart`: centralizované vynucení `tenant_id`, normalizace času (`scheduled_start`, `due_date`), doplnění `metadata.estimated_minutes` a bezpečný merge metadata bez přepsání kritických klíčů.
- **Team offboarding logic (odpojení otevřených úkolů)** – `lib/features/admin/providers/admin_team_repository.dart` (`softDeleteTeamMember`, `unassignOpenTasksForMember`): při odchodu člena bezpečné odpojení úkolů z `assigned_to`/`assigned_user_ids`, reset workflow statusu a auditní stopa (`unassigned_info`).

### Owner View Impersonation (2026-08, Fáze 1 MVP – Varianta C)

Náhled Klientského portálu majitele z CRM admin/managerem **bez odhlášení**, read-only, s auditním zápisem v DB. Frontend spoofing přes `effectiveProfileId` – **bez** swapu JWT.

- **`lib/core/auth/auth_notifier.dart`** – `AppAuthState.isOwnerViewImpersonating`, `impersonatedOwnerProfileId`, `impersonatedOwnerClientId`, `impersonatedOwnerDisplayName`; gettery `effectiveProfileId` / `realProfileId`; metody **`startOwnerView()`** / **`stopOwnerView()`** (vzájemná exkluze s HQ `isImpersonating`, jen admin/manager).
- **`lib/core/auth/owner_view_impersonation_providers.dart`** – `effectiveProfileIdProvider`, `isOwnerViewReadOnlyProvider`, `ownerViewImpersonationInfoProvider`, `realProfileIdProvider`; helper **`returnFromOwnerView(context, ref)`** – ukončí session, přepne admin na záložku Klienti, znovu otevře `ClientDetailDialog` přes `adminCrossNavPendingProvider`, `context.go('/admin')`.
- **`lib/features/admin/services/owner_portal_view_sessions_repository.dart`** + migrace **`20260828120000_owner_portal_view_sessions.sql`** – tabulka **`owner_portal_view_sessions`** (audit start/end, RLS).
- **`lib/core/router/app_router.dart`** – admin/manager smí na `/owner/*` jen při `isOwnerViewImpersonating`; během owner view redirect z `/admin/*` a `/worker/*` na `/owner/dashboard`; stav se po F5 neobnovuje.
- **`lib/features/admin/widgets/client_detail_dialog.dart`** – tlačítko **`_OwnerPortalViewButton`** (owner klient, aktivní profil, bez HQ impersonation) → `startOwnerView` + `/owner/dashboard`.
- **`lib/features/owner/owner_layout.dart`** + **`owner_view_impersonation_banner.dart`** – banner s jménem majitele a ukončením přes `returnFromOwnerView`.
- **`lib/features/owner/widgets/owner_read_only_gate.dart`** – `OwnerReadOnlyGate` / `isOwnerPortalReadOnly(ref)` skrývá mutační UI na obrazovkách rezervací, úkolů, vyúčtování, investic, nastavení; guard na otevření dialogů (`owner_report_issue_dialog`, `owner_cash_disposition_dialog`).
- **Owner providery** – filtrují přes `effectiveProfileIdProvider` místo `auth.state.profileId` (`owner_apartments_provider`, `owner_billing_provider`, `owner_cash_providers`, …); **`notification_preferences_provider`** záměrně neměněn (nastavení jen disable v UI).

---

## 17. QA / Provozní standardy

### Nasazení bezpečnosti a výkonu (P0–P2, 2026-09)

**Status:** kód v repu; produkce vyžaduje migrace + deploy Edge + `cron_edge_config`.

**Provozní návody (runbooky):** složka **`docs/ops/`**

| Dokument | Účel |
|----------|------|
| `docs/ops/README.md` | Index |
| `docs/ops/DEPLOY_SECURITY_P0_P2.md` | Checklist nasazení (pořadí migrací, smoke testy) |
| `docs/ops/EDGE_FUNCTIONS.md` | Auth matice Edge funkcí |
| `docs/ops/CRON_AND_AUTOMATION.md` | `cron_edge_config`, service-role Bearer, idle skip |
| `docs/ops/STORAGE_MEDIA.md` | Private bucket, signed URL |
| `docs/ops/RLS_AND_ROLES.md` | Role-split tasks/cash/invitations/wallet |
| `docs/ops/TROUBLESHOOTING.md` | 401/403/RLS/média |

**Čti když:** nasazuješ hotfix na produkci, crony vrací 401, rozbité fotky po private storage, worker nemůže UPDATE úkolu.

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
