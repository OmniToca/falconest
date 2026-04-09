# Refactoring / UI changelog (AI kontext)

Krátký deník změn v kódu iniciovaných refaktoringy (Fáze 1.1 Admin UI a další). Doplňovat při podobných úkolech.

---

## 2026-04-07 – Admin nástěnka: čas úkolu (Dnešní plán / externí služby)

**Problém:** Podtitulek ukazoval jen čas z `due_date` (např. „• 09:40“), bez začátku z `scheduled_start`.

**Úprava:** `formatDashboardTaskTimeWindow` v `lib/features/admin/admin_dashboard_screen.dart` – lokální formát `HH:mm - HH:mm` z `scheduled_start` + `due_date`; při nekladném rozdílu konec–začátek `Od {time}`; bez `scheduled_start` a čas 00:00 → `admin.dashboard_task_all_day`; jinak jen konec. Režim „Nejbližší“ (`formatTaskDueForUpcoming`) používá stejné časové okno + datum. **i18n:** `admin.dashboard_task_from`, `admin.dashboard_task_all_day` (cs, en, es).

---

## 2026-04-07 – Krok 4 (+ Krok 2 a Krok 3): Admin Úkoly – vyčlenění Kanbanu z `admin_tasks_screen.dart`

**Cíl:** Strukturální refaktoring „god object“ obrazovky – widgety Kanbanu a související pomocné funkce přesunuty do `lib/features/admin/widgets/kanban/` bez změny logiky, stavu ani vzhledu. Hlavní soubor zůstává u `lib/features/admin/admin_tasks_screen.dart` (ne podsložka `screens/`).

**Krok 2 (sloupce):** `KanbanColumnDef`, `KanbanBoard`, `KanbanColumn` žijí v `kanban_column.dart` jako veřejné třídy; `KanbanBoard` skládá čtyři `KanbanColumn` instance. Hlavní obrazovka importuje `kanban_column.dart` a v `Scaffold` používá jen `KanbanBoard(...)`.

**Krok 3 (karty):** `KanbanTaskTimePill`, `KanbanTaskCardContent`, `TaskCard` jsou v `kanban_task_card.dart` (veřejné názvy bez podtržítka). `kanban_column.dart` je importuje pro vykreslení karet a drag feedback; `admin_tasks_screen.dart` kartové widgety přímo neimportuje (stačí import sloupce).

**Krok 4 (ostatní Kanban UI + sdílená logika):** lišty, filtr měsíce, sdílené funkce v `kanban_shared.dart` a další soubory níže.

### Nové soubory (`lib/features/admin/widgets/kanban/`)

- `kanban_shared.dart` – sdílené funkce (normalizace statusu, lokalizace statusu, časové okno karty, `taskTypeLabelKey`, `initialDurationMinutesForTask`, hotovost při dokončení, barvy statusů přes `kanbanTaskStatusColor`).
- `kanban_bulk_selection_bar.dart` – `KanbanBulkSelectionBar`.
- `kanban_filter_bar.dart` – `TasksMonthNavigator`, `RecalculateStaffButton`, `TasksFilterBar`.
- `kanban_column.dart` – **Krok 2:** `KanbanColumnDef`, `KanbanBoard`, `KanbanColumn`.
- `kanban_task_card.dart` – **Krok 3:** `KanbanTaskTimePill`, `KanbanTaskCardContent`, `TaskCard`.

### Upravený soubor

- `lib/features/admin/admin_tasks_screen.dart` – `Consumer` + `Scaffold` skládá `KanbanBoard`, lišty a legendu; stav Kanbanu (výběr, bulk akce) zůstává ve `_AdminTasksScreenState`. Dialogy přidání/úpravy úkolu (`_AddTaskDialog`, `_EditTaskDialog`) a související sekce záměrně zůstávají v tomto souboru (nejsou součástí Kanban boardu).
- `_TopActionBar`, `_GenerateButton`, `RecalculateProposalsDialog` zůstávají v `admin_tasks_screen.dart` vedle scaffoldu.

---

## 2026-04-07 – Krok 3: Edge Security – sdílený rate limiter + webhooky

**Cíl:** In-memory limitace z `export_calendar` přesunuta do znovupoužitelného modulu; stejný mechanismus na veřejných webhookech (limit podle IP).

### Nové / upravené soubory (pouze `supabase/functions/`)

- `supabase/functions/_shared/rate_limiter.ts` – `checkRateLimit(identifier, maxRequests, windowMs, options?)`, `getClientIpForRateLimit(req)` (`cf-connecting-ip`, jinak první `x-forwarded-for`, fallback `unknown`), interní `Map` + ořez paměti.
- `supabase/functions/export_calendar/index.ts` – použití `checkRateLimit(tokenHash, 20, 60_000)` místo lokální implementace (stejný limit jako dříve).
- `supabase/functions/twilio-webhook/index.ts`, `twilio-inbound/index.ts`, `resend-webhook/index.ts` – na začátku handleru kontrola IP: 60 požadavků / minutu; při překročení **429** a tělo `Rate limit exceeded`.

---

## 2026-04-07 – Krok 2: GitHub Actions (CI – analyze + test)

**Cíl:** Automatická kontrola při push a pull request na `main` / `master`: stažení závislostí, `dart analyze`, `flutter test`.

### Soubor

- `.github/workflows/flutter_check.yml` – job `analyze-and-test` na `ubuntu-latest`, `actions/checkout@v4`, `subosito/flutter-action@v2` (kanál `stable`), pak `flutter pub get`, `dart analyze`, `flutter test`.

---

## 2026-04-07 – Krok 1.5: maskovaná tichá selhání (`catch` + `return` bez logu)

**Cíl:** U catch bloků, které pouze polykají výjimku a vracejí výchozí hodnotu (`null`, `[]`, `0`, `{}`, fallback objekt), doplnit **před `return`** volání `AppLogger.error(..., e, st)` a přejmenovat catch na `catch (e, st)`. Návratové hodnoty beze změny.

### Upravené soubory

- `lib/features/super_admin/providers/tenant_detail_provider.dart` – `tenantDetailProvider`, `tenantProfilesProvider`, fallback invitations, `tenantModuleSubscriptionMapProvider`
- `lib/features/admin/providers/current_tenant_name_provider.dart` – `_fetchCurrentTenant`
- `lib/features/super_admin/providers/all_tenants_provider.dart` – `_loadApartmentCountForTenant`
- `lib/core/auth/profile_cache_service.dart` – `save`, `load`
- `lib/features/super_admin/services/audit_log_repository_mobile.dart` – fetch + restore/hardDelete fallback
- `lib/features/super_admin/services/audit_log_repository_web.dart` – fetch metody
- `lib/core/database/drift/repositories/drift_task_repository.dart` – JSON `assigned_user_ids`, `_encodeUnassignedInfo`
- `lib/core/repositories/settlements/settlement_repository.dart` – všechny catch → `[]` / `{}` (kromě větví, kde už byl `debugPrint`)
- `lib/features/admin/providers/module_provider.dart` – moduly / aktivní klíče a UUID
- `lib/features/admin/providers/admin_team_provider.dart` – `staffAbsencesProvider`, `_parseProfileMapToTeamMember`, `teamFullListProvider`
- `lib/features/admin/providers/admin_reservations_provider.dart` – `_parseReservationCheckIn` / `CheckOut`
- `lib/features/admin/providers/admin_tasks_isolate_workers.dart` – parsování check-in/out v isolátu
- `lib/core/repositories/task/task_repository_web.dart` – `getWorkerTaskDetail`
- `lib/features/admin/providers/admin_tasks_provider.dart` – `recalculateAssignees`, parsování rezervací
- `lib/features/admin/services/reservation_import_service.dart` – parsování buňky služby (fallback `ParsedService`)
- `lib/features/owner/providers/owner_reservations_provider.dart` – plánovací kalendář rezervací
- `lib/features/owner/providers/owner_company_expenses_provider.dart`
- `lib/features/owner/providers/owner_apartment_detail_provider.dart` – RPC kalendář + hlavní dotaz
- `lib/features/admin/admin_apartments_screen.dart` – `_parseReservationStartDateForApartment`
- `lib/features/admin/widgets/client_detail_dialog.dart` – `_launchClientContactUri`, `_parseReservationStartDate`
- `lib/features/admin/premium_upsell_dialog.dart` – `_moduleByKey`, `_loadTrialState`
- `lib/features/admin/providers/finance_cash_provider.dart` – `failedCashCollectionsProvider`
- `lib/features/communication/providers/message_templates_provider_mobile.dart`
- `lib/features/owner/widgets/owner_report_issue_dialog.dart` – `_getTenantIdForApartment`
- `lib/features/admin/providers/apartments_provider.dart` – `apartmentsFullListProvider`
- `lib/features/settings/providers/tenant_integration_settings_provider.dart`
- `lib/features/communication/models/message_template_row.dart` – `parseFromStorage`
- `lib/features/settings/providers/current_user_profile_provider_web.dart`
- `lib/features/worker/providers/worker_absences_provider_web.dart`
- `lib/features/worker/widgets/worker_checklist_photo_helper_io.dart` – offline kopie fotky
- `lib/features/admin/providers/apartment_status_provider.dart` – `_parseReservationDate`
- `lib/core/audit/enterprise_audit_payload.dart` – `getCurrentActorSnapshot`, `formatStateForDisplay`
- `lib/features/communication/services/template_placeholder_service.dart` – `_locationOrFallback`
- `lib/core/providers/platform_messaging_rates_provider.dart`
- `lib/features/admin/providers/admin_tasks_repository.dart` – `fetchTasksForReservation`, `fetchTaskById`
- `lib/features/admin/providers/dashboard_provider.dart` – `_parseCheckInDate`
- `lib/features/tasks/providers/task_detail_provider_mobile.dart`
- `lib/features/super_admin/providers/hq_team_providers.dart` – portfolio + absence HQ
- `lib/features/admin/providers/task_categories_provider.dart` – `TaskCategoriesRepository.fetchAll`
- `lib/features/super_admin/providers/billing_overview_provider.dart` – `_loadSmsUsageByTenantForMonth`
- `lib/features/owner/providers/owner_dashboard_metrics_provider.dart`

---

## 2026-04-07 – Technický dluh: tiché `catch` bloky → `AppLogger.error`

**Cíl:** Nahradit prázdné / polykající `catch` voláním `AppLogger.error` (zatím `debugPrint`), beze změny byznysové logiky.

### Nový soubor

- `lib/core/utils/app_logger.dart` – třída `AppLogger`, statická metoda `error(String message, [Object? error, StackTrace? stackTrace])`.

### Upravené soubory (import `app_logger` + `catch (e, st)` + kontextová zpráva)

- `lib/features/worker/data/services/worker_sync_service_mobile.dart`
- `lib/core/database/drift/repositories/drift_task_repository.dart`
- `lib/features/admin/admin_tasks_screen.dart`
- `lib/features/admin/providers/admin_team_provider.dart`
- `lib/core/providers/tenant_currency_local_io.dart`
- `lib/core/providers/tenant_currency_provider.dart`
- `lib/core/services/photo_service.dart`
- `lib/core/models/automation/automation_queue_row.dart`
- `lib/core/auth/auth_notifier.dart`
- `lib/features/super_admin/services/audit_log_repository_mobile.dart`
- `lib/features/admin/admin_reservation_utils.dart`
- `lib/features/admin/providers/admin_reservations_provider.dart`
- `lib/core/services/settlement_export_service.dart`
- `lib/features/worker/widgets/submit_company_expense_worker_io.dart`
- `lib/features/worker/widgets/worker_task_detail_offline_context_cards.dart`
- `lib/features/admin/providers/admin_apartments_repository.dart`
- `lib/features/admin/providers/admin_reservations_repository.dart`
- `lib/features/admin/services/reservation_import_service.dart`
- `lib/features/worker/widgets/submit_worker_absence_request_io.dart`
- `lib/features/super_admin/providers/billing_overview_provider.dart`
- `lib/core/auth/profile_cache_service.dart` (prázdný catch u `clear()`)
- `lib/core/services/absence_notification_service.dart`
- `lib/features/super_admin/super_admin_dashboard.dart`
- `lib/features/super_admin/services/agency_management_settlements_repository.dart`
- `lib/core/offline/drift_mutation_queue_service.dart`
- `lib/features/worker/screens/task_types/transfer_task_screen.dart`
- `lib/core/services/billing_pdf_service.dart`
- `lib/features/worker/utils/record_cash_collection_worker_io.dart`
- `lib/features/admin/providers/admin_tasks_isolate_workers.dart`
- `lib/features/admin/providers/automation_queue_repository.dart`
- `lib/core/offline/offline_photo_task_processor.dart`
- `lib/features/worker/widgets/task_complete_with_photo_section.dart`
- `lib/features/super_admin/tenant_command_modal.dart`
- `lib/features/super_admin/services/support_interventions_repository.dart`
- `lib/features/super_admin/providers/hq_staff_provider.dart`
- `lib/features/super_admin/providers/tenant_detail_provider.dart`
- `lib/features/super_admin/providers/all_tenants_provider.dart`
- `lib/features/super_admin/providers/dashboard_mrr_provider.dart`
- `lib/features/admin/providers/current_tenant_name_provider.dart`

---

## 2026-04-07 – Fáze 5.2: údržba DB (cron), PostGIS VACUUM, rate limit iCal

### `supabase/migrations/20260407220000_maintenance_cleanup_cron.sql`

- `public.maintenance_data_cleanup()`: DELETE z `tenant_message_log` a `audit_logs` starších 6 měsíců; DELETE soft-deleted `tasks` a `reservations` (deleted_at starší než 1 rok); návrat počtů smazaných řádků.
- pg_cron: **`maintenance-data-cleanup-weekly`**, neděle 03:00 UTC → `SELECT * FROM public.maintenance_data_cleanup()`.

### `supabase/migrations/20260407221000_postgis_vacuum_cron.sql`

- `public.maintenance_vacuum_geo()`: dokumentační kotva (VACUUM nelze v PL/pgSQL); tři joby **`VACUUM ANALYZE`** pro `apartments`, `tasks`, `clients` (neděle 04:00–04:02 UTC).

### `supabase/functions/export_calendar/index.ts`

- In-memory rate limit podle SHA-256 hashe tokenu: max. 20 požadavků / min / token, ořez mapy při růstu; při překročení **429** + `Retry-After: 60` (před vytvořením Supabase klienta).

### Dokumentace

- `docs/ai_context/database_schema.md` – odstavec Údržba DB (Fáze 5.2).

---

## 2026-04-07 – Fáze 5.1: varování před uzamčením fakturace, TTL cache kurzů

### `lib/features/admin/providers/finance_billing_provider.dart`

- `BillingTaskItem`: `assignedTo`, `assignedUserIds`, `requiresPhoto`, getter `hasLockBillingRisk` (nepřiřazeno = prázdné primární i sekundární přiřazení; fotka = `metadata.requires_photo` a prázdné `media_urls`).
- Dotaz úkolů pro billing rozšířen o `assigned_to`, `assigned_user_ids`; mapování `requires_photo` z metadat.
- `BillingGroup.fromSnapshot` + snapshot JSON: nová pole pro neměnný archiv (kompatibilní výchozí hodnoty u starých snapshotů).

### `lib/core/services/billing_action_service.dart`

- Do `snapshot_data.items` ukládány `assigned_to`, `assigned_user_ids`, `requires_photo`.

### `lib/features/admin/screens/finance_billing_screen.dart`

- Před standardním potvrzením uzamčení: pokud `hasLockBillingRisk`, `AlertDialog` (`billing_lock_risk_*`) – Zrušit / Pokračovat i tak; proces neblokuje tvrdě.

### `lib/core/services/currency_service.dart`, `settings_screen.dart`, `super_admin_settings_modal.dart`

- `fetchCurrenciesCached()` + TTL 1 h; `invalidateCurrenciesCache()` před `ref.invalidate(currenciesProvider)` po úpravě kurzovního lístku.

### Překlady

- `admin.finance.billing_lock_risk_title`, `billing_lock_risk_body`, `billing_lock_risk_continue` (cs, en, es).

### Dokumentace

- `docs/ai_context/slovnik_modulu.md` – řádek Finance – fakturace.

---

## 2026-04-07 – Fáze 4.2 (Worker mobil): anotace fotek, Smart Merge snack, varování hotovosti

### `lib/features/worker/screens/photo_annotation_screen.dart`, `lib/features/worker/utils/worker_photo_annotation_flow.dart`

- Po focení (`MediaService.pickAndCompressImage`) navigace na fullscreen anotaci: `GestureDetector` + `CustomPaint`, červené freedraw tahy; uložení přes `ui.PictureRecorder` + PNG do temp souboru.

### `lib/features/worker/widgets/task_photo_uploader.dart`, `issue_reporter_dialog.dart`

- Místo přímého `pickAndCompressImage` volání `pickWorkerPhotoWithAnnotation` (web beze změny).

### `lib/features/worker/data/services/worker_sync_service_mobile.dart`, `worker_sync_service_web.dart`

- `onSmartMergeApplied` callback u `pushPendingUpdates` / `syncTasksFromSupabase`; po úspěšném Smart Merge při konfliktu (`hasConflict`) se zavolá.

### `lib/features/worker/providers/worker_sync_state_provider.dart`, `lib/core/offline/network_sync_watcher.dart`

- Nastavení `transientI18nSnackKeyProvider` na `worker.sync_smart_merge_snack` (globální SnackBar přes `TransientI18nSnackHost`).

### `lib/features/worker/screens/worker_dashboard_screen.dart`

- `_HighCashWalletWarningBanner`: `myCashWalletProvider`, zobrazení při `balance > 500`; tlačítko `/worker/wallet`.

### Překlady

- `worker.sync_smart_merge_snack`, `worker.cash_high_warning_*`, `worker.photo_annotation_*` (en, cs, es).

---

## 2026-04-07 – Fáze 4.1 (Worker mobil): swipe checklist, rychlá poznámka, seskupení úkolů podle adresy

### `lib/features/worker/widgets/worker_task_checklist_widget_io.dart`

- Položky checklistu obaleny `Dismissible` (směr `endToStart`, zelené pozadí + fajfka); `confirmDismiss` volá stejný toggle jako checkbox a vrací `false` (řádek se nemá mazat).

### `lib/core/repositories/task/task_repository.dart`, `drift_task_repository.dart`, `task_repository_web.dart`

- `ITaskRepository.appendWorkerQuickNote` — append řádku do `tasks.description`; mobil: Drift + okamžitý pokus o Supabase, při síťové chybě fronta `UPDATE`; web: čtení + merge + update.

### `lib/features/worker/screens/worker_task_detail_screen.dart`

- Malé `FloatingActionButton` (ne hotové úkoly): dialog s textem; uložení jako `[HH:mm] … — jméno: text` přes `appendWorkerQuickNote`, invalidace detailu a seznamu, `WorkerSyncService.pushPendingUpdates`.

### `lib/features/worker/screens/worker_dashboard_screen.dart`

- V rámci skupin Dnes / Zítra / Později: úkoly seřazeny časem, seskupení podle `apartment_id` nebo `displayAddress`; při ≥2 úkolech stejné skupiny hlavička `_AddressGroupHeader` + vnořené karty.

### Překlady

- `worker.worker_tasks_group_count`, `worker.quick_note_*` (en, cs, es).

---

## 2026-04-07 – Fáze 3.2 (Admin): CRM rychlé filtry, mapové trasy, mini-audit úkolu

### `lib/features/admin/screens/admin_clients_screen.dart`

- Pod vyhledáváním řada `FilterChip` (Wrap): **S přístupem do portálu** (`profile_id` neprázdné), **Bez e-mailu** (`email` null nebo prázdný); kombinace s full-textem přes `applyCrmQuickClientFilters`; prázdný stav `admin.clients_quick_filter_empty`.

### `lib/features/admin/screens/admin_map_dispatch_screen.dart`

- `ConsumerStatefulWidget`: výběr pracovníka (dropdown v `InputDecorator`); dnešní úkoly s GPS seskupené podle `assigned_to`, uvnitř skupiny řazení podle `scheduled_start` / `due_date`; pro skupiny s ≥2 body `PolylineLayer` (poloprůhledná primární barva, `strokeWidth: 3`); legenda včetně tras.

### `lib/features/super_admin/services/audit_log_repository_web.dart`, `audit_log_repository_mobile.dart`

- `AuditLogRepository.fetchLogsForRecord({ tenantId, tableName, recordId, limit })` – čtení `audit_logs` pro konkrétní záznam, řazení `created_at` vzestupně.

### `lib/features/admin/providers/task_audit_logs_provider.dart`, `lib/features/admin/widgets/task_audit_history_section.dart`

- `taskAuditLogsProvider(taskId)`; sekce v dialogu úpravy úkolu (`admin_tasks_screen`): čas, actor, typ akce, shrnutí změny stavu z `details`.

### `lib/features/admin/admin_tasks_screen.dart`

- Import `TaskAuditHistorySection` na konec scrollu v editaci úkolu.

### Překlady

- `assets/translations/en.json`, `cs.json`, `es.json` – `admin.map_legend_routes`, `admin.map_worker_filter_*`, `admin.clients_filter_*`, `admin.clients_quick_filter_empty`, `admin.task_audit_*`.

---

## 2026-04-07 – Fáze 3.1 (Admin Power-ups): Kanban hromadné akce, štítky úkolů, historie komunikace u rezervace

### `lib/features/admin/admin_tasks_screen.dart`

- Režim výběru více úkolů (ikona checklistu v horní liště nebo dlouhé podržení karty): checkboxy, plovoucí lišta „Změnit status“ / „Přiřadit pracovníka“; drag & drop zůstává vypnutý jen v režimu výběru.
- Vlastní barevné štítky (metadata `custom_tags`) pod titulkem na kartě; editor v dialogu úpravy úkolu (`TaskCustomTagsEditor`).

### `lib/features/admin/models/task_custom_tag.dart`, `lib/features/admin/widgets/task_custom_tags_editor.dart`

- Model a UI pro pole `metadata.custom_tags` (pole objektů `{ "label", "color" }` s barvou jako `#RRGGBB`).

### `lib/features/admin/providers/admin_tasks_provider.dart`

- `kanbanFilterTasksBySearchQuery` rozšířeno o texty štítků; `bulkUpdateTaskStatus`, `bulkAssignTasks` pro hromadné akce.

### `lib/features/admin/providers/automation_log_repository.dart`, `automation_log_provider.dart`

- `fetchForReservation` + `reservationMessageLogProvider` – záznamy `tenant_message_log` vázané na rezervaci přes `automation_message_queue` (`entity_type = reservation`, `entity_id`).

### `lib/features/admin/widgets/reservation_communication_history_section.dart`, `admin_reservation_forms.dart`

- Třetí záložka v dialogu úpravy rezervace: chronologický přehled kanálu, stavu a náhledu textu.

### Překlady

- `admin.*` – klíče `tasks_bulk_*`, `task_custom_tags_*`, `reservations_tab_communication_history`, `reservation_comm_log_*` (en, cs, es).

---

## 2026-04-07 – Fáze 1.1: CRM klikatelné kontakty, Kanban fotky, stáří rezervace

### `lib/features/admin/widgets/client_detail_dialog.dart`

- Přidán import `url_launcher`.
- Pomocné funkce `_clientDetailMailtoUri`, `_clientDetailTelUri`, `_launchClientContactUri` pro bezpečné otevření `mailto:` / `tel:`.
- Tab **Přehled** klienta: řádky e-mail a telefon předávají do `_DetailRow` volitelné `linkUri` a `linkTooltipKey`.
- Rozšířen widget `_DetailRow`: volitelné `linkUri` a `linkTooltipKey`; pokud je odkaz platný a hodnota není „–“, hodnota se zobrazí jako podtržený text v barvě `primary` s `InkWell`, `Tooltip`, `MouseRegion` a `Semantics`.

### `lib/features/admin/admin_tasks_screen.dart`

- V `_KanbanTaskCardContent` (patička karty vedle pilulků času/statusu): pokud `task.mediaUrls` není prázdné, zobrazí se ikona `Icons.photo_camera_outlined` a počet v závorce `(n)`.

### `lib/features/admin/providers/admin_reservations_provider.dart`

- Model `ReservationRow`: nové pole `createdAt` (`DateTime?`), mapování z JSON `created_at` ve `fromJson`, propagace do `copyWith`.

### `lib/features/admin/admin_reservation_utils.dart`

- Nová funkce `reservationRecordAgeLabel(DateTime? createdAt)` – vrací lokalizovaný text pro dnes / včera / před N dny (kalendářní dny v lokálním čase).

### `lib/features/admin/admin_reservations_screen.dart`

- V `_KanbanCardContent` (Kanban rezervací): v horním řádku vedle zdroje rezervace se zobrazí kompaktní štítek stáří záznamu, pokud je k dispozici `createdAt` (Material + `surfaceContainerHighest`).

### Překlady

- `assets/translations/en.json`, `cs.json`, `es.json` – pod klíčem `admin`: `crm_contact_open_email`, `crm_contact_open_phone`, `crm_contact_tap_to_open`, `reservation_age_today`, `reservation_age_yesterday`, `reservation_age_days_ago`.

---

## 2026-04-07 – Fáze 1.2: Absence filtry, owner služby, majitelský dashboard

### `lib/features/worker/screens/worker_absences_screen.dart`

- Převod na `ConsumerStatefulWidget`; lokální enum `_WorkerAbsenceListFilter` (vše / schválené / čekající a zamítnuté).
- Nad seznamem `SegmentedButton` – filtrování pouze v paměti, `workerAbsencesProvider` beze změny.
- Prázdný stav při neprázdném zdroji a prázdném filtru: text `worker.absences_filter_empty`.

### `lib/features/owner/providers/owner_apartment_services_provider.dart`

- Po sestavení `ApartmentServiceOption` se volá `.where(_shouldShowApartmentServiceToOwner)` – skrytí řádků s cenou 0, které zároveň nejsou povinné, nevyžadují fotku/checklist a mají `triggerType == on_demand` (ostatní triggery nebo cena > 0 zůstávají).

### `lib/features/owner/owner_layout.dart`

- Nová první záložka: `OwnerDashboardScreen()` s ikonou `Icons.dashboard_outlined`, klíč `owner.menu_dashboard`.
- Konstanty záložek posunuty (0–5); `OwnerLayout` má volitelný parametr `initialTabIndex` (výchozí 0 = nástěnka).

### `lib/core/router/app_router.dart`

- Routa `/owner/dashboard` (jméno `ownerDashboard`) → `OwnerLayout(initialTabIndex: 0)`; uvedena před obecnou `/owner`, aby se správně matchovala.

### Překlady

- `worker` – `absences_filter_all`, `absences_filter_approved`, `absences_filter_pending_rejected`, `absences_filter_empty` (en, cs, es).
- `owner` – `menu_dashboard` (en, cs, es).

---

## 2026-04-07 – Fáze 2.1: Klientská zóna (recenze, filtr kalendáře, iCal)

### Supabase

- Migrace `20260407180000_owner_calendar_feed_url_and_rpc.sql`: sloupec `tenant_calendar_feed_tokens.owner_visible_calendar_url` (plní se při vytvoření tokenu v adminu), RPC `get_owner_calendar_feed_url_for_apartment(p_apartment_id uuid) RETURNS text`, RLS `tenant_calendar_feed_tokens_select_property_owner` (SELECT pro majitele u vlastních bytů).

### `lib/features/owner/providers/owner_apartment_detail_provider.dart`

- `OwnerApartmentDetail`: `reviewLink`, `calendarFeedUrl`; dotaz na `apartments` rozšířen o `review_link`; po načtení volání RPC `get_owner_calendar_feed_url_for_apartment`.

### `lib/features/owner/owner_apartment_detail_screen.dart`

- Karta recenzí: tlačítko s `url_launcher` (http/https), pokud je `review_link` vyplněný.
- Sekce iCal: zobrazení URL + kopírování, nebo text kontaktovat agenturu (bez generování tokenu v UI).

### `lib/features/owner/providers/owner_planning_calendar_apartment_filter_provider.dart`

- `OwnerPlanningCalendarApartmentFilterProvider` – `StateProvider<String?>` (null = všechny byty).

### `lib/features/owner/providers/owner_planning_calendar_provider.dart`, `owner_reservations_provider.dart`

- `ownerPlanningCalendarTasksProvider` / `ownerReservationsForPlanningCalendarProvider`: `ref.watch` filtru; dotaz `inFilter` na jeden byt nebo všechny vlastněné.

### `lib/features/owner/owner_planning_calendar_screen.dart`

- `_OwnerCalendarApartmentFilterBar`: `DropdownButtonFormField` (skryto při ≤ 1 bytu).

### `lib/features/admin/models/calendar_feed_token_row.dart`, `calendar_feed_tokens_repository.dart`, `admin_apartments_screen.dart`

- Pole `ownerVisibleCalendarUrl`; insert při `createToken`; kopírování odkazu v adminu použije uloženou URL, pokud existuje.

### `docs/ai_context/database_schema.md` / `docs/ai_context/slovnik_modulu.md`

- Doplnění sloupce, RPC a mapa modulů (owner + worker absence filtr).

### Překlady

- `owner` – klíče `detail_guest_reviews_*`, `detail_calendar_sync_*`, `detail_link_open_failed`, `calendar_filter_*` (en, cs, es).

---

## 2026-04-07 – Fáze 2.2: Majitel – výdaje, blokace, nástěnka

### Supabase

- Migrace `20260407200000_owner_portal_reservations_expense_metadata.sql`: sloupce `metadata` (jsonb, default `{}`) u `employee_cash_transactions` a `reservations`.

### `lib/features/owner/providers/owner_company_expenses_provider.dart`

- `OwnerCompanyExpenseRow`, `ownerCompanyExpensesProvider` (COMPANY_EXPENSE + `apartment_id` ve vlastnictví), `ownerApproveCompanyExpense` – merge `owner_approved` / `owner_approved_at` do `metadata`.

### `lib/features/owner/owner_billing_screen.dart`

- Sekce firemních výdajů nad seznamem snapshotů; tlačítko „Potvrdit“ dokud není `owner_approved`.

### `lib/features/owner/providers/owner_dashboard_metrics_provider.dart`

- `ownerDashboardMetricsProvider`: počet rezervací se `start_date` v okně 14 dní; součet `charged_price` u `reservation_services` s `payer_type = owner`, kde `reservation_id` není v žádném `billing_snapshots.snapshot_data.items[].reservation_id`.

### `lib/features/owner/owner_dashboard_screen.dart`

- Dvě metrické karty (`premiumCardDecoration`) + stávající tlačítko nahlášení závady.

### `lib/features/owner/providers/owner_reservations_provider.dart`

- `kOwnerStayGuestNameDb`, `OwnerReservation.metadata`, `isOwnerStay`; select rozšířen o `metadata`.

### `lib/features/owner/owner_reservations_screen.dart`

- AppBar: blokace vlastního pobytu; dialog `_OwnerBlockStayDialog` (insert + `metadata.is_owner_stay`); mazání blokace přes `deleted_at`; Kanban s ikonou smazání u owner stay.

### `docs/ai_context/database_schema.md`

- Sloupce `metadata` u `employee_cash_transactions` a `reservations`.

### Překlady

- `owner` – dashboard metriky, company_expenses_*, vlastní pobyt, blokace (en, cs, es).
