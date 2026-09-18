# FalcoNest – Oficiální schéma databáze

> **Pravidlo:** Při generování SQL dotazů, RLS politik nebo Dart modelů (.fromJson) vždy nejdříve zkontroluj tento soubor a ověř přesné názvy sloupců a datové typy. Nikdy nehádej názvy sloupců.

---

### Synchronizace s fyzickou databází (export `information_schema`)

Hlavní tabulka sloupců níže byla **srovnána 2026-04-09** se živým exportem sloupců z produkční Supabase (CSV: tabulka, sloupec, datový typ, nullable). Typy odpovídají přesně tomu, co vrací **`information_schema.columns`** (u PostGIS geometrií je ve sloupci „Typ dat“ hodnota **USER-DEFINED**, nikoli text `geometry`).

**Poslední synchronizace (2026-04-09) oproti předchozí verzi MD:**

- **Doplněno (2026-09-18, legal_spain):** migrace **`20260918120000_legal_spain_checkin_ses.sql`** – katalog **`modules.key = legal_spain`** (bez seedu všem tenantům), **`reservations.guest_email`**, tabulky **`apartment_legal_settings`**, **`ses_ws_credentials`**, **`guest_checkins`**, **`reservation_guests`**, **`ses_communications`**, RPC veřejného check-inu, cron **`ses-hospedajes`**.
- **Doplněno (2026-09-13, owner portal read-only):** migrace **`20260913140000_owner_portal_view_readonly_guard.sql`** – funkce **`my_profile_id`**, **`has_active_owner_portal_view_session`** (TTL 8 h), **`close_my_open_owner_portal_view_sessions`**, **`assert_not_owner_portal_viewing`**; **RESTRICTIVE** RLS na **`tasks`**, **`owner_cash_disposition_requests`**, **`billing_snapshot_offset_proposals`** + trigger na proposals (RPC SECURITY DEFINER). Cleanup orphan session při loginu admin/manager a před `startSession`.
- **Doplněno (2026-09-13, P2):** migrace **`20260913132000_p2_automation_dispatch_idle_skip.sql`** – `invoke_automation_dispatch()` nevolá Edge, pokud ve frontě není splatná `pending` položka.
- **Doplněno (2026-09-13, P1 bezpečnost):** migrace **`20260913130000_p1_rls_role_split_cash_tasks_invitations.sql`** – `deduct_wallet_credits` jen super_admin / admin|manager vlastního tenanta; invitations INSERT/UPDATE admin|manager, DELETE i vlastníci ghost `profile_id` (accept invite); `employee_cash_wallets` INSERT/UPDATE admin|manager nebo vlastní `profile_id`; `employee_cash_transactions` UPDATE jen admin|manager; `tasks` UPDATE admin|manager nebo `is_worker_assigned_to_task`.
- **Doplněno (2026-09-13, P1 výkon):** migrace **`20260913131000_p1_tasks_composite_indexes.sql`** – indexy **`idx_tasks_tenant_scheduled_start`**, **`idx_tasks_tenant_completed_at`**.
- **Doplněno (2026-08-28):** migrace **`20260828160000_billing_snapshot_offset_proposals.sql`** – tabulka **`billing_snapshot_offset_proposals`** (Approval Loop doplatku faktury); RPC **`respond_billing_offset_proposal`** (majitel approve/reject, atomický zápočet); interní **`apply_billing_snapshot_offset_core`**, **`_billing_offset_compute_plan`**, **`_billing_offset_owner_pool_sum`**. Partial unique index: max. jeden **`pending_owner`** návrh na **`billing_snapshot_id`**. RLS: admin/manager INSERT + SELECT + UPDATE (zrušení); majitel SELECT only (bez přímého UPDATE).
- **Doplněno (2026-08-28):** migrace **`20260828140000_billing_snapshots_offset_amount.sql`** – **`billing_snapshots.offset_amount`**, **`offset_request_id`**, **`offset_applied_at`**; validace zápočtu přes **`OwnerCashOffsetCalculator`** + **`applyOffsetToSnapshot`** (pool majitele).
- **Doplněno (2026-08-28):** migrace **`20260828120000_owner_portal_view_sessions.sql`** – tabulka **`owner_portal_view_sessions`**: audit náhledu Klientského portálu dispečerem (admin/manager) z CRM – sloupce **`admin_profile_id`**, **`viewed_owner_profile_id`**, **`client_id`**, **`tenant_id`**, **`started_at`**, **`ended_at`**, **`created_at`**, **`updated_at`**. **RLS:** **SELECT** pro **super_admin** nebo **admin/manager** tenanta (`is_tenant_admin_or_manager` + **`tenant_id = my_tenant_id()`**); **INSERT** jen admin/manager s **`admin_profile_id`** = volající a validací, že majitel a klient patří do tenanta; **UPDATE** jen vlastní session (uzavření **`ended_at`**); **DELETE** jen **super_admin**. Dart: **`OwnerPortalViewSessionsRepository`** (**`startSession`**, **`endSession`**), provider **`ownerPortalViewSessionsRepositoryProvider`**. MVP: session se neobnovuje po F5.
- **Doplněno (2026-04-20):** migrace **`20260420150000_update_cash_audit_view.sql`** – přepis VIEW **`public.vw_cash_collection_audit`** pro PostgREST bez FK relationship nad SQL view. Nové denormalizované sloupce ve výstupu: **`task_title`**, **`scheduled_start`**, **`apartment_name`** (JOIN na `tasks` + `apartments` uvnitř view), aby frontend mohl číst **`select('*')** bez vnořených `tasks(...)` / `apartments(...)`.
- **Doplněno (2026-04-20):** migrace **`20260420130000_cash_audit_view.sql`** – VIEW **`public.vw_cash_collection_audit`** pro audit hotovosti nad **`tasks`** + **`employee_cash_transactions`**. Vrací sloupce **`tenant_id`**, **`task_id`**, **`apartment_id`**, **`expected_cash`**, **`collected_cash`**, **`collected_count`**, **`anomaly_type`** (`missing_cash`, `duplicate_cash`, `amount_mismatch`, `ok`) pro **completed** úkoly s očekávanou hotovostí (`amount_to_collect + transit_amount_to_collect > 0`), včetně odečtu storna **`CASH_COLLECTION_REVERSAL`**.
- **Doplněno (2026-04-21):** migrace **`20260421120000_owner_reservation_services_rls.sql`** – RLS politika **`reservation_services_property_owner_select`**: role **`property_owner`** smí **SELECT** na **`reservation_services`**, pokud řádek patří k **rezervaci** na apartmánu z **`apartment_owners`** (stejný vzor jako u úkolů). **PROČ:** jinak `my_tenant_id()` u majitele bývá NULL a mapy ceny/plátce z RS v aplikaci nejdou načíst.
- **Doplněno (2026-04-21):** migrace **`20260421133000_owner_cash_transit_task_settlement.sql`** – tabulka **`owner_cash_transit_settlements`** je rozšířená pro long-term nájem bez rezervace: **`reservation_id`** nově nullable, nové sloupce **`apartment_id`** a **`task_id`** (FK), nové indexy pro apartment/task a upravená owner SELECT RLS politika (vlastník vidí settlement i přes přímý `apartment_id`, nejen přes `reservation_id`).
- **Doplněno (2026-04-21):** migrace **`20260421140000_employee_cash_handover_allocations.sql`** – nová auditní tabulka **`employee_cash_handover_allocations`** (FIFO rozpad bulk převzetí hotovosti: source_tx → handed_tx + transit podíl) a RPC funkce **`process_worker_cash_handover_fifo`** (SECURITY DEFINER): atomicky provede FIFO alokaci, vloží `HANDED_TO_AGENCY`, alokační řádky, owner settlementy z transit části a sníží `employee_cash_wallets.balance`.
- **Doplněno (2026-05-23):** migrace **`20260523120000_clients_can_bill_external_tasks.sql`** – sloupec **`clients.can_bill_external_tasks`** (boolean NOT NULL DEFAULT **false**): hybridní B2B partner (typicky majitel) se zobrazí v roletce klienta u úkolu **Externí služba**; fakturace zůstává pod stejným **`clients.id`**. Seed: **ESP House** = **true**.
- **Doplněno (2026-04-30):** migrace **`20260430140000_tenant_services_name_i18n.sql`** – **`tenant_services.name_i18n`** (**jsonb NOT NULL**, výchozí **`{}`**) — překlady názvu služby v katalogu (stejná očekávaná struktura jako **`tasks.title_i18n`**). Při **INSERT** úkolu s **`service_id`** aplikace zkopíruje neprázdné překlady do **`tasks.title_i18n`** (snapshot), aby historické podklady nezávisely na budoucích úpravách ceníku.
- **Doplněno (2026-04-30):** migrace **`20260430120000_tasks_title_i18n.sql`** – **`tasks.title_i18n`** (**jsonb NOT NULL**, výchozí **`{}`**) pro uložené překlady názvu úkolu (PDF / vícejazyčné výstupy). Trigger **`tasks_invalidate_title_i18n_on_title_change`** (**BEFORE UPDATE OF** **`title`**, **`custom_title`**) volá **`tasks_invalidate_title_i18n_before_update()`**: při skutečné změně zdrojového titulku nastaví **`title_i18n`** na **`{}`**, aby v DB nezůstaly překlady k předchozímu znění. Detail struktury JSON a sémantiky viz konvence u **`tasks`** níže.
- **Doplněno (2026-04-21):** migrace **`20260421150000_owner_lifecycle_notifications.sql`** – propojení **`notification_preferences`** (majitel **`owner_task_*` / `owner_cash_*`**) s **`automation_message_queue`** a **`notifications`**: triggery **`tasks_owner_lifecycle_notify`** (přechod **`tasks.status`** na **`in_progress`** / **`completed`**) a **`employee_cash_transactions_owner_notify_on_collect`** (**`INSERT`** **`COLLECTED_FROM_GUEST`**). Jádro **`enqueue_owner_lifecycle_notifications`** (SECURITY DEFINER): pro majitele z **`apartment_owners`** zařadí **`internal_push`** / **`email`** (payload **`internal_push_kind`**: **`owner_task_started`**, **`owner_task_completed`**, **`owner_cash_collected`**) a při zapnutém **web** vloží in-app řádek (**`type`**: stejné názvy). Edge **`automation-dispatch`** musí tyto **`internal_push_kind`** odbavit (FCM **`route`**: **`/owner`**).
- **Doplněno (2026-04-15):** migrace **`20260415103000_get_invitation_for_accept_rpc.sql`** – funkce **`public.get_invitation_for_accept(p_token text)`** (SECURITY DEFINER, **RETURNS jsonb**): vrátí jeden řádek **`invitations`** jako JSON, pokud `trim(p_token)` je platné UUID a odpovídá **`id`** nebo **`profile_id`**; jinak **NULL**. **`GRANT EXECUTE`** pro **`anon`** a **`authenticated`**. **PROČ:** přímý **SELECT** na **`invitations`** blokuje RLS pro nepřihlášené a pro uživatele mimo tenant pozvánky (viz **`20260319100000`**). Načtení pro obrazovku **`/invite`** řeší klient přes **RPC** (`InviteRepository.fetchInvitationByToken`).
- **Doplněno (2026-04-14):** migrace **`20260414100000_long_term_rent_pnl_trigger_and_admin_confirm.sql`** – trigger **`tasks_apply_rent_collection_to_pnl`** na **`tasks`** (AFTER UPDATE **status**), funkce **`apply_rent_collection_task_to_pnl()`** (SECURITY DEFINER): při prvním přechodu úkolu na **completed** s **`task_type = rent_collection`**, byt **`rental_mode = long_term`** a **`rent_collection_mode = task`**, upsert **`income`** do **`apartment_investment_pnl_entries`** (částka **`apartments.rent_amount`**, měsíc z **`metadata.rent_cycle_key`** = text za prvním **`:`** jako datum → **`date_trunc('month')`**). **RLS** navíc: politiky **`apartment_investment_pnl_entries_admin_long_term_income_upsert`** a **`apartment_investment_pnl_entries_admin_long_term_income_update`** – **INSERT**/**UPDATE** řádků **`entry_type = income`** pro **super_admin** nebo **admin/manager** tenanta jen u bytu **`long_term`** + **`rent_collection_mode = notification`** (potvrzení přijetí nájmu z admin UI / majitel volá stejný upsert).
- **Doplněno (2026-04-13):** migrace **`20260413120000_apartment_long_term_rent_due_automation.sql`** – **`apartments`**: **`rent_amount`** (numeric NOT NULL DEFAULT 0), **`rent_due_day`** (int NOT NULL DEFAULT 1, CHECK 1–31), **`rent_collection_mode`** (text NOT NULL DEFAULT **`notification`**, CHECK **`notification`** | **`task`**), **`rent_task_assignee_id`** (uuid, FK **`profiles`**, nullable). Tabulka **`apartment_rent_due_runs`** (idempotence měsíčního běhu: UNIQUE **`apartment_id`**, **`billing_month`**, **`run_kind`**). **`cron_edge_config.rent_monitor_url`**, funkce **`invoke_rent_monitor()`** (POST přes **`_automation_invoke_http_post`**, token **`automation_edge_auth_token`**), pg_cron **`rent-monitor-daily`**. Edge **`rent-monitor`**: den splatnosti v zóně **Europe/Madrid**, notifikace nebo úkol **`rent_collection`**. Drift **`Apartments`** schema **v18**.
- **Doplněno (2026-04-12):** migrace **`20260412120000_apartment_rental_mode_lease.sql`** – **`apartments.rental_mode`** (text NOT NULL DEFAULT **`short_term`**, CHECK **`short_term`** | **`long_term`**); **`lease_start_date`**, **`lease_end_date`** (date, nullable). Dart: **`ApartmentModel`**, **`ApartmentRow`**, Drift **`Apartments`** (schema **v17**), admin dialogy bytu; worker sync rozšířený select apartmánů.
- **Doplněno (2026-04-11):** migrace **`20260411160000_owner_investment_pnl.sql`** – tabulka **`apartment_investment_pnl_entries`**: měsíční **`income`** / **`expense`** na byt, **`entry_month`** = první den měsíce (CHECK), **UNIQUE** `(apartment_id, entry_month, entry_type)`, trigger **`updated_at`**. **RLS:** majitel (**`property_owner`**) **SELECT/INSERT/UPDATE/DELETE** u vlastních bytů; **admin/manager** **SELECT** a **DELETE**; omezené **INSERT**/**UPDATE** jen na **`income`** u **`long_term`** + **`rent_collection_mode = notification`** viz migrace **`20260414100000_...`**. Dart: **`ApartmentInvestmentPnlEntry`**, **`OwnerApartmentPnlRepository`** (**`upsertIncomeEntry`** pro potvrzení převodu), **`apartmentInvestmentPnlEntriesProvider`**, **`ownerInvestmentRoiProvider`**, **`OwnerInvestmentDashboard`**.
- **Doplněno (2026-04-11):** migrace **`20260411150000_apartment_investment_metrics_owner_insert.sql`** – RLS **INSERT** pro **`property_owner`** na **`apartment_investment_metrics`** (jen vlastní byt přes **`apartment_owners`** a **`apartments.investment_tracking_enabled = true`**). Umožňuje majiteli první uložení metrik z Klientského portálu (upsert).
- **Doplněno (2026-04-11):** migrace **`20260411140000_apartment_investment_tracking.sql`** – sloupec **`apartments.investment_tracking_enabled`** (boolean NOT NULL DEFAULT false); tabulka **`apartment_investment_metrics`** (PK/FK **`apartment_id`**, částky numeric, **`market_price_updated_at`**, **`updated_at`** + trigger **`set_dynamic_checklist_updated_at`**). **RLS:** admin/manager tenanta (`is_tenant_admin_or_manager` + byt v **`my_tenant_id()`**) plný přístup; **`property_owner`** **SELECT** / **UPDATE** / **INSERT** (viz výše) u svých bytů. Dart: **`ApartmentModel`**, **`ApartmentInvestmentMetrics`** (Freezed), **`ApartmentRow.investmentTrackingEnabled`**, Drift **`Apartments.investmentTrackingEnabled`** (schema v16), majitel: **`apartmentInvestmentMetricsProvider`**, **`OwnerInvestmentDashboard`**.
- **Doplněno (2026-04-11):** migrace **`20260411120000_owner_notification_prefs.sql`** – tabulka **`notification_preferences`**: 9 sloupců **`owner_task_started_*`**, **`owner_task_completed_*`**, **`owner_cash_collected_*`** (web / push / email, výchozí **true**) pro nastavení majitele v Klientském portálu. **Drift:** tabulka se v projektu nelokálně nereplikuje – změna jen Supabase + Dart model.
- **Doplněno (2026-04-10, Klientské centrum – checklisty):** migrace **`20260410130000_task_checklists_property_owner_select.sql`** – nové RLS politiky **SELECT** pro roli **property_owner** na **`task_checklists`** a **`task_checklist_items`** (úkoly na apartmánech z **`apartment_owners`**). Umožňuje majiteli číst **`photo_url`** položek checklistu v aplikaci.
- **Doplněno (2026-04-10, Fáze 3):** migrace **`20260410020000_pickup_date_and_status.sql`** – **`owner_cash_disposition_requests.pickup_date`** (timestamptz, nullable); CHECK **`status`** rozšířen o **`ready_for_pickup`**; RLS **`owner_cash_disposition_requests_update_owner_pending`** (majitel **property_owner** může UPDATE vlastní řádek jen ve stavu **`pending`** – změna **`pickup_date`**). Validace v aplikaci: **`OwnerCashDispositionRepository.createRequest`** (IBAN u bank_transfer, datum u vault_pickup + 48 h), **`updateOwnerRequestPickupDate`**, výjimka **`OwnerDispositionValidationException`** (l10n klíče).
- **Doplněno (2026-04-10, pokračování):** migrace **`20260410010000_partial_offsets.sql`** – **`owner_cash_disposition_requests.used_amount`** (numeric NOT NULL DEFAULT 0, CHECK ≥ 0); rozšíření CHECK **`status`** o **`partially_completed`**; rozšíření CHECK **`billing_snapshots.payment_status`** o **`partially_paid`**; RLS **`billing_snapshots_update_admin_manager`** (UPDATE pro **admin** / **manager** tenanta). Aplikace: **`OwnerCashDispositionRepository.applyOffsetToSnapshot`**, audit **`DISPOSITION_OFFSET_APPLIED`**.
- **Doplněno (2026-04-10):** migrace **`20260410000000_cash_disposition_extensions.sql`** – **`owner_cash_disposition_requests.iban`** (text, nullable, IBAN u bankovního převodu); **`billing_snapshots.payment_status`** (text NOT NULL DEFAULT `'unpaid'`, CHECK: **`unpaid`**, **`paid`**, **`cash_offset`**), **`billing_snapshots.paid_at`** (timestamptz, nullable), **`billing_snapshots.invoice_pdf_url`** (text, nullable). Dart: **`OwnerCashDispositionRequest.iban`**, **`BillingSnapshotModel`** (payment_status, paid_at, invoice_pdf_url).
- **Doplněno / opraveno (2026-04-09):** tabulka **owner_cash_disposition_requests** – migrace `20260409143000_owner_cash_dispositions.sql` (začíná `DROP TABLE IF EXISTS … CASCADE`, pak `CREATE TABLE`, indexy, RLS). **RLS:** sloupce řádku žádosti vždy prefixovat `owner_cash_disposition_requests.` (kvůli **ERROR 42702** ambiguous `tenant_id` vs. `profiles.tenant_id`). Pro instance, kde už stará verze 143000 proběhla, navazuje stejný DDL v `20260409160000_owner_cash_disposition_requests_rls_reapply.sql`. **Bez změn** u **owner_cash_transit_settlements**. **updated_at** při změně stavu řeší aplikace (`OwnerCashDispositionRepository.updateRequestStatus`).
- **owner_cash_transit_settlements – dvě reálné podoby:** v repu je kanonická migrace `20260404120000_owner_cash_transit_settlements.sql` (**`note`**, **`created_by`**, **`settled_at`**, bez `status` / `settled_by` / `employee_cash_transaction_id`). V některých exportech se objevily rozšířené sloupce (**`notes`**, **`status`**, **`settled_by`**, **`employee_cash_transaction_id`**). Klient **`syncOwnerSettlementAfterHandedToAgency`** INSERTuje podle staršího tvaru: **`note`** (včetně textu s ID transakce HANDED), **`created_by`** = profil dispečera; **`AuditLogService.log`** používá **`auth.users.id`** (`currentUser?.id`), ne `profiles.id`.
- **Typy ve sloupci „Typ dat“:** **apartments.geo_location**, **clients.geo_location**, **tasks.geo_location** přepsány na **USER-DEFINED** (v CSV z exportu); fyzický typ v PostgreSQL zůstává PostGIS **geometry(Point, 4326)** – viz migrace a sekce PostGIS níže.
- **V tomto exportu nefiguruje** tabulka **upcoming_task_reminder_log** (historicky migrace `20260403280000_upcoming_task_reminder_log.sql`). Není uvedena v kanonické tabulce sloupců níže; pokud ji potřebuješ v dotazech, ověř existenci v konkrétní instanci (`to_regclass('public.upcoming_task_reminder_log')`).

**Starší doplňky (kontext, stále platné pro produkt):**

- Tabulky **automation_message_queue**, **automation_rules** – fronta a pravidla automatizovaných zpráv; sloupce typu **USER-DEFINED** odpovídají PostgreSQL enumům (např. kanál, stav fronty) – přesné názvy typů viz migrace / `\dT` v psql.
- Tabulky **checklist_templates**, **checklist_template_items** – šablony checklistů pro úkoly.
- Tabulky **task_checklists**, **task_checklist_items** – instance checklistu u konkrétního úkolu (včetně dokončení a fotky).
- Tabulka **tenant_message_log** – log odeslaných/příchozích zpráv (Twilio/WhatsApp apod.).
- Tabulka **tenant_usage_monthly** – agregace počtu odeslaných zpráv podle měsíce a kanálu.
- Tabulka **platform_messaging_rates** – referenční ceny zpráv pro HQ / fakturaci.
- Sloupce **apartment_services.checklist_template_id**, **apartments.parking_instructions**, **apartments.review_link**, **tenants.integration_settings** (jsonb NOT NULL – prázdný objekt `{}` pokud bez integrací).
- Tabulka **tenant_ui_preferences** – brandové barvy UI na úrovni tenanta (primární/sekundární HEX); **updated_at** pro Timestamp Merging při synci z klienta.
- Rozšíření **postgis** (schéma `extensions`), sloupce **apartments.geo_location**, **tasks.geo_location**, **clients.geo_location** (ve schématu **geometry(Point, 4326)**), GIST indexy **idx_apartments_geo**, **idx_tasks_geo**, **idx_clients_geo** – migrace `20260403000000_enable_postgis_and_geo.sql` + `20260403020000_add_geo_to_clients.sql` (2026-04-03).
- Sloupce **search_vector** (tsvector, `GENERATED ... STORED`, konfigurace `simple`) na **clients**, **apartments**, **tasks**, **reservations** + GIN indexy **idx_*_search** – migrace `20260403010000_add_fts_vectors.sql` (2026-04-03).
- Tabulka **notification_preferences** – místo čtyř sloupců `*_enabled` je matice kanálů (4 typy událostí pro personál × 3 kanály + **3 typy událostí pro majitele** × 3 kanály) – migrace `20260403220000_notification_preferences_channels.sql` a **`20260411120000_owner_notification_prefs.sql`** (`owner_task_started_*`, `owner_task_completed_*`, `owner_cash_collected_*`).
- Tabulka **notifications** – sloupec **metadata** (jsonb NOT NULL, výchozí `{}`) pro data UI (např. `task_id` u prokliku) – migrace `20260403240000_notifications_metadata_new_task_web.sql` (2026-04-03).
- Trigger **`tasks_enqueue_new_assignment_push`** na **tasks** (AFTER INSERT OR UPDATE OF **assigned_to**) volá funkci **`enqueue_internal_push_on_new_task_assignment()`** – multi-channel doručení (fronta **internal_push** / **email**, řádek v **notifications**) podle kanálových přepínačů; typování času v těle zprávy viz sekce *notifications* níže.
- Konvence **JSONB `tasks.metadata`**: kromě stávajících klíčů (hotovost, odhad minut, …) klient ukládá volitelně **`custom_tags`** — pole `{ "label": string, "color": "#RRGGBB" }` pro vlastní štítky na admin Kanbanu (2026-04).
- Konvence **JSONB `tasks.title_i18n`** (2026-04-30): očekávaný tvar objektu **`{ "translations": { "cs": "…", "en": "…", "es": "…" }, "source_hash": "<hex>" }`**. Klíč **`translations`** je mapa kódů jazyka (ISO 639-1, v souladu s locale exportu v aplikaci) na přeložený řetězec. Klíč **`source_hash`** je volitelný SHA-256 (hex) kanonického zdrojového textu z **`title`** + **`custom_title`** v době uložení překladů (audit / budoucí kontrola konzistence). Hodnota **`{}`** znamená žádné uložené překlady — UI a exporty mají použít **`title`** / **`custom_title`**. **Invalidace:** při **UPDATE**, který mění **`title`** nebo **`custom_title`**, trigger přepíše **`title_i18n`** na **`{}`** (i kdyby klient ve stejném požadavku poslal nové překlady); kanonický stav určuje Postgres.
- Konvence **JSONB `tenant_services.name_i18n`** (2026-04-30): stejný tvar jako **`tasks.title_i18n`** (`translations` + volitelně `source_hash` vůči kanonickému **`tenant_services.name`**). **Snapshot:** při vytvoření úkolu s **`service_id`** klient zkopíruje neprázdné překlady do **`tasks.title_i18n`**, aby uzavřené měsíce a PDF nečetly „živý“ ceník po změně názvu služby.
- **Údržba DB (Fáze 5.2)** – funkce **`public.maintenance_data_cleanup()`** (migrace `20260407220000_maintenance_cleanup_cron.sql`): fyzické mazání řádků v **tenant_message_log** a **audit_logs** starších než **6 měsíců**; fyzické mazání soft-deleted záznamů v **tasks** a **reservations** s **deleted_at** starším než **1 rok**; pg_cron job **`maintenance-data-cleanup-weekly`** (neděle **03:00 UTC**). **VACUUM ANALYZE** pro **apartments**, **tasks**, **clients** kvůli PostGIS/GIST (PostgreSQL neumožňuje VACUUM uvnitř PL/pgSQL funkce) – tři samostatné pg_cron joby **`maintenance-vacuum-geo-apartments`**, **`maintenance-vacuum-geo-tasks`**, **`maintenance-vacuum-geo-clients`** v neděli **04:00–04:02 UTC**; dokumentační funkce **`public.maintenance_vacuum_geo()`** vrací text s odkazem na cron (migrace `20260407221000_postgis_vacuum_cron.sql`).

**Co bylo odstraněno z dokumentace (v DB fyzicky neexistuje):**

- **tenant_message_templates.body** a **tenant_message_templates.language_code** – nahrazeno reálným stavem: texty šablon v **translations** (jsonb), volitelný **email_subject**; kanál zůstává na **channel**.

**Úpravy typů / NULL podle exportu:**

- **clients.language_code** a **reservations.guest_language**: typ v exportu je obecné **character varying** (bez délky v CSV); nullable **YES**. Vlastní constraint `varchar(2)` nebo default může být v DB nad rámec tohoto exportu – ověř v SQL, pokud na tom závisí migrace.
- U řady sloupců byly v MD rozšířené poznámky v buňce „NULL“ (např. soft delete); v hlavní tabulce jsou nyní jen **YES** / **NO** jako ve **realna_db.csv**. Sémantiku (soft delete, výchozí hodnoty) drží textové sekce níže u příslušných tabulek.

**Pořadí řádků:** řazeno podle pořadí tabulek a sloupců v posledním schváleném exportu z produkce (stejné pořadí jako vstupní CSV z `information_schema`).

---

| Tabulka | Sloupec | Typ dat | Může být NULL? |
|---------|---------|---------|----------------|
| agency_management_settlements | id | uuid | NO |
| agency_management_settlements | profile_id | uuid | NO |
| agency_management_settlements | tenant_id | uuid | NO |
| agency_management_settlements | settlement_period | date | NO |
| agency_management_settlements | role_type | text | NO |
| agency_management_settlements | amount | numeric | NO |
| agency_management_settlements | status | text | NO |
| agency_management_settlements | approved_by | uuid | YES |
| agency_management_settlements | approved_at | timestamp with time zone | YES |
| agency_management_settlements | created_at | timestamp with time zone | NO |
| agency_management_settlements | updated_at | timestamp with time zone | NO |
| apartment_ical_sources | id | uuid | NO |
| apartment_ical_sources | tenant_id | uuid | NO |
| apartment_ical_sources | apartment_id | uuid | NO |
| apartment_ical_sources | ical_url | text | NO |
| apartment_ical_sources | source_label | text | NO |
| apartment_ical_sources | last_synced_at | timestamp with time zone | YES |
| apartment_ical_sources | created_at | timestamp with time zone | YES |
| apartment_ical_sources | updated_at | timestamp with time zone | YES |
| apartment_investment_metrics | apartment_id | uuid | NO |
| apartment_investment_metrics | purchase_price | numeric | NO |
| apartment_investment_metrics | initial_renovation_cost | numeric | NO |
| apartment_investment_metrics | estimated_market_price | numeric | NO |
| apartment_investment_metrics | market_price_updated_at | timestamp with time zone | YES |
| apartment_investment_metrics | updated_at | timestamp with time zone | NO |
| apartment_investment_pnl_entries | id | uuid | NO |
| apartment_investment_pnl_entries | apartment_id | uuid | NO |
| apartment_investment_pnl_entries | entry_month | date | NO |
| apartment_investment_pnl_entries | entry_type | text | NO |
| apartment_investment_pnl_entries | amount | numeric | NO |
| apartment_investment_pnl_entries | description | text | YES |
| apartment_investment_pnl_entries | created_at | timestamp with time zone | NO |
| apartment_investment_pnl_entries | updated_at | timestamp with time zone | NO |
| apartment_owners | id | uuid | NO |
| apartment_owners | apartment_id | uuid | NO |
| apartment_owners | owner_id | uuid | NO |
| apartment_owners | deleted_at | timestamp with time zone | YES |
| apartment_owners | is_primary_billing | boolean | YES |
| apartment_rent_due_runs | id | uuid | NO |
| apartment_rent_due_runs | tenant_id | uuid | NO |
| apartment_rent_due_runs | apartment_id | uuid | NO |
| apartment_rent_due_runs | billing_month | date | NO |
| apartment_rent_due_runs | run_kind | text | NO |
| apartment_rent_due_runs | created_task_id | uuid | YES |
| apartment_rent_due_runs | created_at | timestamp with time zone | NO |
| apartment_services | id | uuid | NO |
| apartment_services | tenant_id | uuid | NO |
| apartment_services | apartment_id | uuid | NO |
| apartment_services | service_id | uuid | NO |
| apartment_services | custom_price | numeric | YES |
| apartment_services | custom_description | text | YES |
| apartment_services | trigger_type | text | NO |
| apartment_services | schedule_interval | text | YES |
| apartment_services | is_mandatory | boolean | NO |
| apartment_services | payer_type | text | NO |
| apartment_services | requires_photo | boolean | YES |
| apartment_services | checklist_template_id | uuid | YES |
| apartment_services | metadata | jsonb | NO |
| apartments | id | uuid | NO |
| apartments | tenant_id | uuid | NO |
| apartments | name | text | NO |
| apartments | address | text | YES |
| apartments | keybox | text | YES |
| apartments | status | text | YES |
| apartments | check_in_time | text | YES |
| apartments | check_out_time | text | YES |
| apartments | standard_cleaning_duration | integer | YES |
| apartments | owner_notes | text | YES |
| apartments | deleted_at | timestamp with time zone | YES |
| apartments | zone_id | uuid | YES |
| apartments | code | text | YES |
| apartments | monthly_management_fee | numeric | YES |
| apartments | managed_from | date | YES |
| apartments | parking_instructions | text | YES |
| apartments | review_link | text | YES |
| apartments | investment_tracking_enabled | boolean | NO |
| apartments | rental_mode | text | NO |
| apartments | lease_start_date | date | YES |
| apartments | lease_end_date | date | YES |
| apartments | rent_amount | numeric | NO |
| apartments | rent_due_day | integer | NO |
| apartments | rent_collection_mode | text | NO |
| apartments | rent_task_assignee_id | uuid | YES |
| apartments | geo_location | USER-DEFINED | YES |
| apartments | search_vector | tsvector | NO |
| app_super_admins | id | uuid | NO |
| audit_logs | id | uuid | NO |
| audit_logs | tenant_id | uuid | YES |
| audit_logs | user_id | uuid | YES |
| audit_logs | action_type | text | NO |
| audit_logs | table_name | text | YES |
| audit_logs | record_id | text | YES |
| audit_logs | details | jsonb | YES |
| audit_logs | created_at | timestamp with time zone | NO |
| automation_message_queue | id | uuid | NO |
| automation_message_queue | tenant_id | uuid | NO |
| automation_message_queue | rule_id | uuid | YES |
| automation_message_queue | entity_id | uuid | NO |
| automation_message_queue | entity_type | text | NO |
| automation_message_queue | scheduled_for | timestamp with time zone | NO |
| automation_message_queue | status | USER-DEFINED | NO |
| automation_message_queue | channel | USER-DEFINED | NO |
| automation_message_queue | recipient_contact | text | YES |
| automation_message_queue | editable_payload | jsonb | NO |
| automation_message_queue | attempt_count | integer | NO |
| automation_message_queue | last_error | text | YES |
| automation_message_queue | created_at | timestamp with time zone | NO |
| automation_message_queue | updated_at | timestamp with time zone | NO |
| automation_rules | id | uuid | NO |
| automation_rules | tenant_id | uuid | NO |
| automation_rules | name | text | NO |
| automation_rules | is_active | boolean | NO |
| automation_rules | trigger_event | text | NO |
| automation_rules | offset_minutes | integer | NO |
| automation_rules | channel | USER-DEFINED | NO |
| automation_rules | template_id | uuid | NO |
| automation_rules | target_entity | text | NO |
| automation_rules | staff_profile_id | uuid | YES |
| automation_rules | quiet_hours_start | time without time zone | YES |
| automation_rules | quiet_hours_end | time without time zone | YES |
| automation_rules | created_at | timestamp with time zone | NO |
| automation_rules | updated_at | timestamp with time zone | NO |
| billing_shortfall_transfers | id | uuid | NO |
| billing_shortfall_transfers | tenant_id | uuid | NO |
| billing_shortfall_transfers | client_id | uuid | NO |
| billing_shortfall_transfers | amount | numeric | NO |
| billing_shortfall_transfers | description | text | YES |
| billing_shortfall_transfers | task_id | uuid | YES |
| billing_shortfall_transfers | cash_transaction_id | uuid | NO |
| billing_shortfall_transfers | created_at | timestamp with time zone | NO |
| billing_snapshots | id | uuid | NO |
| billing_snapshots | tenant_id | uuid | NO |
| billing_snapshots | client_id | uuid | NO |
| billing_snapshots | billing_period | date | NO |
| billing_snapshots | snapshot_data | jsonb | NO |
| billing_snapshots | locked_at | timestamp with time zone | NO |
| billing_snapshots | locked_by | uuid | NO |
| billing_snapshots | payment_status | text | NO |
| billing_snapshots | paid_at | timestamp with time zone | YES |
| billing_snapshots | invoice_pdf_url | text | YES |
| billing_snapshots | offset_amount | numeric | NO |
| billing_snapshots | offset_request_id | uuid | YES |
| billing_snapshots | offset_applied_at | timestamp with time zone | YES |
| billing_snapshot_offset_proposals | id | uuid | NO |
| billing_snapshot_offset_proposals | tenant_id | uuid | NO |
| billing_snapshot_offset_proposals | billing_snapshot_id | uuid | NO |
| billing_snapshot_offset_proposals | owner_profile_id | uuid | NO |
| billing_snapshot_offset_proposals | settlement_id | uuid | NO |
| billing_snapshot_offset_proposals | proposed_amount | numeric | NO |
| billing_snapshot_offset_proposals | applied_amount | numeric | YES |
| billing_snapshot_offset_proposals | currency | text | NO |
| billing_snapshot_offset_proposals | status | text | NO |
| billing_snapshot_offset_proposals | proposed_by_profile_id | uuid | NO |
| billing_snapshot_offset_proposals | disposition_request_id | uuid | YES |
| billing_snapshot_offset_proposals | owner_responded_at | timestamp with time zone | YES |
| billing_snapshot_offset_proposals | owner_rejection_note | text | YES |
| billing_snapshot_offset_proposals | admin_notes | text | YES |
| billing_snapshot_offset_proposals | created_at | timestamp with time zone | NO |
| billing_snapshot_offset_proposals | updated_at | timestamp with time zone | NO |
| checklist_template_items | id | uuid | NO |
| checklist_template_items | tenant_id | uuid | NO |
| checklist_template_items | template_id | uuid | NO |
| checklist_template_items | title | text | NO |
| checklist_template_items | is_photo_required | boolean | NO |
| checklist_template_items | sort_order | integer | NO |
| checklist_template_items | created_at | timestamp with time zone | NO |
| checklist_template_items | updated_at | timestamp with time zone | NO |
| checklist_templates | id | uuid | NO |
| checklist_templates | tenant_id | uuid | NO |
| checklist_templates | name | text | NO |
| checklist_templates | description | text | YES |
| checklist_templates | is_active | boolean | NO |
| checklist_templates | created_at | timestamp with time zone | NO |
| checklist_templates | updated_at | timestamp with time zone | NO |
| client_addresses | id | uuid | NO |
| client_addresses | tenant_id | uuid | NO |
| client_addresses | client_id | uuid | NO |
| client_addresses | label | text | NO |
| client_addresses | address | text | NO |
| client_addresses | created_at | timestamp with time zone | YES |
| client_addresses | updated_at | timestamp with time zone | YES |
| client_addresses | deleted_at | timestamp with time zone | YES |
| clients | id | uuid | NO |
| clients | tenant_id | uuid | NO |
| clients | name | text | NO |
| clients | email | text | YES |
| clients | phone | text | YES |
| clients | client_type | text | YES |
| clients | created_at | timestamp with time zone | YES |
| clients | deleted_at | timestamp with time zone | YES |
| clients | profile_id | uuid | YES |
| clients | agency_id | uuid | YES |
| clients | can_bill_external_tasks | boolean | NO |
| clients | language_code | character varying | YES |
| clients | geo_location | USER-DEFINED | YES |
| clients | search_vector | tsvector | NO |
| cron_edge_config | key | text | NO |
| cron_edge_config | value | text | NO |
| currencies | code | text | NO |
| currencies | symbol | text | NO |
| currencies | rate | numeric | NO |
| currencies | name | text | YES |
| currencies | created_at | timestamp with time zone | YES |
| employee_cash_transactions | id | uuid | NO |
| employee_cash_transactions | tenant_id | uuid | NO |
| employee_cash_transactions | wallet_id | uuid | NO |
| employee_cash_transactions | task_id | uuid | YES |
| employee_cash_transactions | amount | numeric | NO |
| employee_cash_transactions | transaction_type | text | NO |
| employee_cash_transactions | created_by | uuid | NO |
| employee_cash_transactions | created_at | timestamp with time zone | YES |
| employee_cash_transactions | note | text | YES |
| employee_cash_transactions | receipt_image_url | text | YES |
| employee_cash_transactions | expected_amount | numeric | YES |
| employee_cash_transactions | apartment_id | uuid | YES |
| employee_cash_transactions | client_id | uuid | YES |
| employee_cash_transactions | is_shortfall_resolved | boolean | NO |
| employee_cash_transactions | shortfall_resolution_type | text | YES |
| employee_cash_transactions | shortfall_resolution_note | text | YES |
| employee_cash_transactions | metadata | jsonb | NO |
| employee_cash_wallets | id | uuid | NO |
| employee_cash_wallets | tenant_id | uuid | NO |
| employee_cash_wallets | profile_id | uuid | NO |
| employee_cash_wallets | balance | numeric | NO |
| employee_cash_wallets | updated_at | timestamp with time zone | YES |
| hq_staff_contracts | id | uuid | NO |
| hq_staff_contracts | profile_id | uuid | NO |
| hq_staff_contracts | employment_type | text | NO |
| hq_staff_contracts | position_label | text | YES |
| hq_staff_contracts | fixed_salary_monthly | numeric | YES |
| hq_staff_contracts | bonus_per_acquired_agency | numeric | YES |
| hq_staff_contracts | commission_percent_managed | numeric | YES |
| hq_staff_contracts | valid_from | date | NO |
| hq_staff_contracts | valid_to | date | YES |
| hq_staff_contracts | created_at | timestamp with time zone | NO |
| hq_staff_contracts | updated_at | timestamp with time zone | NO |
| invitations | id | uuid | NO |
| invitations | email | text | NO |
| invitations | tenant_id | uuid | YES |
| invitations | role | text | NO |
| invitations | first_name | text | NO |
| invitations | last_name | text | NO |
| invitations | created_at | timestamp with time zone | YES |
| invitations | roles | ARRAY | YES |
| invitations | start_date | text | YES |
| invitations | end_date | text | YES |
| invitations | weekly_hours | integer | YES |
| invitations | profile_id | uuid | YES |
| invoices | id | uuid | NO |
| invoices | tenant_id | uuid | NO |
| invoices | stripe_invoice_id | text | YES |
| invoices | amount_due | numeric | NO |
| invoices | amount_paid | numeric | NO |
| invoices | currency | text | NO |
| invoices | status | text | NO |
| invoices | invoice_pdf_url | text | YES |
| invoices | created_at | timestamp with time zone | NO |
| invoices | paid_at | timestamp with time zone | YES |
| modules | id | uuid | NO |
| modules | key | text | NO |
| modules | name | text | NO |
| modules | description | text | YES |
| modules | price_eur | numeric | YES |
| modules | created_at | timestamp with time zone | YES |
| modules | order_index | integer | YES |
| modules | pricing_type | text | NO |
| modules | show_in_menu | boolean | NO |
| modules | parent_module_key | text | YES |
| notification_preferences | profile_id | uuid | NO |
| notification_preferences | tenant_id | uuid | NO |
| notification_preferences | daily_summary_web | boolean | NO |
| notification_preferences | daily_summary_push | boolean | NO |
| notification_preferences | daily_summary_email | boolean | NO |
| notification_preferences | upcoming_task_web | boolean | NO |
| notification_preferences | upcoming_task_push | boolean | NO |
| notification_preferences | upcoming_task_email | boolean | NO |
| notification_preferences | new_task_assigned_web | boolean | NO |
| notification_preferences | new_task_assigned_push | boolean | NO |
| notification_preferences | new_task_assigned_email | boolean | NO |
| notification_preferences | template_reminders_web | boolean | NO |
| notification_preferences | template_reminders_push | boolean | NO |
| notification_preferences | template_reminders_email | boolean | NO |
| notification_preferences | owner_task_started_web | boolean | NO |
| notification_preferences | owner_task_started_push | boolean | NO |
| notification_preferences | owner_task_started_email | boolean | NO |
| notification_preferences | owner_task_completed_web | boolean | NO |
| notification_preferences | owner_task_completed_push | boolean | NO |
| notification_preferences | owner_task_completed_email | boolean | NO |
| notification_preferences | owner_cash_collected_web | boolean | NO |
| notification_preferences | owner_cash_collected_push | boolean | NO |
| notification_preferences | owner_cash_collected_email | boolean | NO |
| notifications | id | uuid | NO |
| notifications | tenant_id | uuid | NO |
| notifications | profile_id | uuid | NO |
| notifications | title | text | NO |
| notifications | message | text | NO |
| notifications | type | text | YES |
| notifications | is_read | boolean | NO |
| notifications | metadata | jsonb | NO |
| notifications | created_at | timestamp with time zone | YES |
| owner_cash_transit_settlements | id | uuid | NO |
| owner_cash_transit_settlements | tenant_id | uuid | NO |
| owner_cash_transit_settlements | reservation_id | uuid | YES |
| owner_cash_transit_settlements | apartment_id | uuid | YES |
| owner_cash_transit_settlements | task_id | uuid | YES |
| owner_cash_transit_settlements | amount | numeric | NO |
| owner_cash_transit_settlements | currency | text | NO |
| owner_cash_transit_settlements | settled_at | timestamp with time zone | YES |
| owner_cash_transit_settlements | settled_by | uuid | YES |
| owner_cash_transit_settlements | status | text | NO |
| owner_cash_transit_settlements | employee_cash_transaction_id | uuid | YES |
| owner_cash_transit_settlements | notes | text | YES |
| owner_cash_transit_settlements | created_at | timestamp with time zone | YES |
| owner_cash_transit_settlements | updated_at | timestamp with time zone | YES |
| owner_cash_disposition_requests | id | uuid | NO |
| owner_cash_disposition_requests | tenant_id | uuid | NO |
| owner_cash_disposition_requests | settlement_id | uuid | NO |
| owner_cash_disposition_requests | owner_profile_id | uuid | NO |
| owner_cash_disposition_requests | disposition_type | text | NO |
| owner_cash_disposition_requests | amount | numeric | NO |
| owner_cash_disposition_requests | used_amount | numeric | NO |
| owner_cash_disposition_requests | status | text | NO |
| owner_cash_disposition_requests | pickup_date | timestamp with time zone | YES |
| owner_cash_disposition_requests | iban | text | YES |
| owner_cash_disposition_requests | admin_notes | text | YES |
| owner_cash_disposition_requests | created_at | timestamp with time zone | NO |
| owner_cash_disposition_requests | updated_at | timestamp with time zone | NO |
| owner_portal_view_sessions | id | uuid | NO |
| owner_portal_view_sessions | admin_profile_id | uuid | NO |
| owner_portal_view_sessions | viewed_owner_profile_id | uuid | NO |
| owner_portal_view_sessions | client_id | uuid | NO |
| owner_portal_view_sessions | tenant_id | uuid | NO |
| owner_portal_view_sessions | started_at | timestamp with time zone | NO |
| owner_portal_view_sessions | ended_at | timestamp with time zone | YES |
| owner_portal_view_sessions | created_at | timestamp with time zone | NO |
| owner_portal_view_sessions | updated_at | timestamp with time zone | NO |
| payout_snapshots | id | uuid | NO |
| payout_snapshots | tenant_id | uuid | NO |
| payout_snapshots | payout_period | date | NO |
| payout_snapshots | is_employee | boolean | NO |
| payout_snapshots | profile_id | uuid | YES |
| payout_snapshots | client_id | uuid | YES |
| payout_snapshots | recipient_name | text | NO |
| payout_snapshots | total_amount | numeric | NO |
| payout_snapshots | items_data | jsonb | NO |
| payout_snapshots | locked_at | timestamp with time zone | NO |
| payout_snapshots | locked_by | uuid | NO |
| platform_messaging_rates | id | uuid | NO |
| platform_messaging_rates | channel | text | NO |
| platform_messaging_rates | price_eur | numeric | NO |
| platform_messaging_rates | valid_from | timestamp with time zone | NO |
| platform_messaging_rates | created_at | timestamp with time zone | NO |
| profiles | id | uuid | NO |
| profiles | auth_id | uuid | YES |
| profiles | email | text | YES |
| profiles | first_name | text | YES |
| profiles | last_name | text | YES |
| profiles | name | text | YES |
| profiles | status | text | NO |
| profiles | tenant_id | uuid | YES |
| profiles | role | text | YES |
| profiles | roles | ARRAY | YES |
| profiles | weekly_hours | integer | YES |
| profiles | start_date | date | YES |
| profiles | end_date | date | YES |
| profiles | language_code | text | YES |
| profiles | preferred_currency | text | YES |
| profiles | last_sign_in_at | timestamp with time zone | YES |
| profiles | created_at | timestamp with time zone | YES |
| profiles | updated_at | timestamp with time zone | YES |
| profiles | deleted_at | timestamp with time zone | YES |
| profiles | zone_preferences | jsonb | YES |
| reservation_services | id | uuid | NO |
| reservation_services | tenant_id | uuid | NO |
| reservation_services | reservation_id | uuid | NO |
| reservation_services | apartment_service_id | uuid | NO |
| reservation_services | custom_note | text | YES |
| reservation_services | charged_price | numeric | YES |
| reservation_services | payer_type | text | YES |
| reservation_services | requires_photo | boolean | YES |
| reservation_services | flight_number | text | YES |
| reservations | id | uuid | NO |
| reservations | apartment_id | uuid | NO |
| reservations | start_date | date | NO |
| reservations | end_date | date | NO |
| reservations | special_requests | text | YES |
| reservations | guest_name | text | YES |
| reservations | guest_email | text | YES |
| reservations | check_in | text | YES |
| reservations | check_out | text | YES |
| reservations | needs_transfer | boolean | YES |
| reservations | status | text | YES |
| reservations | tenant_id | uuid | YES |
| reservations | deleted_at | timestamp with time zone | YES |
| reservations | guest_adults | integer | NO |
| reservations | guest_children | integer | NO |
| reservations | arrival_time | timestamp with time zone | YES |
| reservations | guest_phone | text | YES |
| reservations | reservation_source | text | YES |
| reservations | departure_time | timestamp with time zone | YES |
| reservations | internal_note | text | YES |
| reservations | reference_number | text | YES |
| reservations | external_uid | text | YES |
| reservations | last_communication_template_context | text | YES |
| reservations | last_communication_at | timestamp with time zone | YES |
| reservations | last_communication_template_id | uuid | YES |
| reservations | guest_language | character varying | YES |
| reservations | updated_at | timestamp with time zone | YES |
| reservations | metadata | jsonb | NO |
| reservations | search_vector | tsvector | NO |
| staff_absences | id | uuid | NO |
| staff_absences | profile_id | uuid | YES |
| staff_absences | start_date | text | NO |
| staff_absences | end_date | text | NO |
| staff_absences | reason | text | YES |
| staff_absences | invitation_id | uuid | YES |
| staff_absences | tenant_id | uuid | YES |
| staff_absences | status | text | YES |
| support_interventions | id | uuid | NO |
| support_interventions | profile_id | uuid | NO |
| support_interventions | tenant_id | uuid | NO |
| support_interventions | started_at | timestamp with time zone | NO |
| support_interventions | ended_at | timestamp with time zone | YES |
| support_interventions | work_report | text | YES |
| support_interventions | created_at | timestamp with time zone | NO |
| support_interventions | updated_at | timestamp with time zone | NO |
| task_categories | id | uuid | NO |
| task_categories | code | text | NO |
| task_categories | color_hex | text | NO |
| task_categories | icon_name | text | YES |
| task_categories | order_index | integer | YES |
| task_categories | planning_priority | integer | NO |
| task_checklist_items | id | uuid | NO |
| task_checklist_items | tenant_id | uuid | NO |
| task_checklist_items | task_checklist_id | uuid | NO |
| task_checklist_items | title | text | NO |
| task_checklist_items | is_photo_required | boolean | NO |
| task_checklist_items | sort_order | integer | NO |
| task_checklist_items | is_completed | boolean | NO |
| task_checklist_items | completed_at | timestamp with time zone | YES |
| task_checklist_items | completed_by | uuid | YES |
| task_checklist_items | photo_url | text | YES |
| task_checklist_items | created_at | timestamp with time zone | NO |
| task_checklist_items | updated_at | timestamp with time zone | NO |
| task_checklists | id | uuid | NO |
| task_checklists | tenant_id | uuid | NO |
| task_checklists | task_id | uuid | NO |
| task_checklists | template_id | uuid | YES |
| task_checklists | created_at | timestamp with time zone | NO |
| task_checklists | updated_at | timestamp with time zone | NO |
| task_commissions | id | uuid | NO |
| task_commissions | tenant_id | uuid | NO |
| task_commissions | task_id | uuid | NO |
| task_commissions | client_id | uuid | YES |
| task_commissions | amount | numeric | NO |
| task_commissions | status | text | NO |
| task_commissions | created_at | timestamp with time zone | NO |
| task_commissions | updated_at | timestamp with time zone | NO |
| task_commissions | profile_id | uuid | YES |
| task_payouts | id | uuid | NO |
| task_payouts | tenant_id | uuid | NO |
| task_payouts | task_id | uuid | NO |
| task_payouts | profile_id | uuid | NO |
| task_payouts | amount | numeric | NO |
| task_payouts | status | text | NO |
| task_payouts | created_at | timestamp with time zone | NO |
| task_payouts | updated_at | timestamp with time zone | NO |
| tasks | id | uuid | NO |
| tasks | tenant_id | uuid | NO |
| tasks | apartment_id | uuid | YES |
| tasks | assigned_user_id | uuid | YES |
| tasks | scheduled_start | timestamp with time zone | NO |
| tasks | status | text | NO |
| tasks | photo_url | text | YES |
| tasks | local_updated_at | timestamp with time zone | NO |
| tasks | assigned_to | uuid | YES |
| tasks | task_type | text | YES |
| tasks | due_date | text | YES |
| tasks | description | text | YES |
| tasks | title | text | YES |
| tasks | deleted_at | timestamp with time zone | YES |
| tasks | reservation_id | uuid | YES |
| tasks | service_id | uuid | YES |
| tasks | metadata | jsonb | NO |
| tasks | started_at | timestamp with time zone | YES |
| tasks | completed_at | timestamp with time zone | YES |
| tasks | created_by | uuid | YES |
| tasks | media_urls | ARRAY | YES |
| tasks | invoiced_at | timestamp with time zone | YES |
| tasks | client_id | uuid | YES |
| tasks | custom_location | text | YES |
| tasks | custom_title | text | YES |
| tasks | title_i18n | jsonb | NO |
| tasks | reference_number | text | YES |
| tasks | assigned_user_ids | ARRAY | NO |
| tasks | updated_at | timestamp with time zone | YES |
| tasks | unassigned_info | jsonb | YES |
| tasks | last_communication_template_id | uuid | YES |
| tasks | last_communication_template_context | text | YES |
| tasks | last_communication_at | timestamp with time zone | YES |
| tasks | geo_location | USER-DEFINED | YES |
| tasks | search_vector | tsvector | NO |
| tenant_calendar_feed_tokens | id | uuid | NO |
| tenant_calendar_feed_tokens | tenant_id | uuid | NO |
| tenant_calendar_feed_tokens | token_hash | text | NO |
| tenant_calendar_feed_tokens | label | text | YES |
| tenant_calendar_feed_tokens | revoked_at | timestamp with time zone | YES |
| tenant_calendar_feed_tokens | created_at | timestamp with time zone | NO |
| tenant_calendar_feed_tokens | apartment_id | uuid | YES |
| tenant_calendar_feed_tokens | owner_visible_calendar_url | text | YES |
| tenant_message_log | id | uuid | NO |
| tenant_message_log | tenant_id | uuid | NO |
| tenant_message_log | queue_id | uuid | YES |
| tenant_message_log | sent_at | timestamp with time zone | NO |
| tenant_message_log | channel | USER-DEFINED | NO |
| tenant_message_log | external_api_id | text | YES |
| tenant_message_log | status | text | NO |
| tenant_message_log | unit_price | numeric | YES |
| tenant_message_log | recipient_masked | text | YES |
| tenant_message_log | content_snapshot | text | NO |
| tenant_message_log | error_details | text | YES |
| tenant_message_log | created_at | timestamp with time zone | NO |
| tenant_message_log | direction | text | NO |
| tenant_message_log | inbound_text | text | YES |
| tenant_message_log | metadata | jsonb | NO |
| tenant_message_templates | id | uuid | NO |
| tenant_message_templates | tenant_id | uuid | NO |
| tenant_message_templates | key | text | NO |
| tenant_message_templates | name | text | NO |
| tenant_message_templates | channel | text | YES |
| tenant_message_templates | trigger_context | text | YES |
| tenant_message_templates | order_index | integer | NO |
| tenant_message_templates | created_at | timestamp with time zone | YES |
| tenant_message_templates | deleted_at | timestamp with time zone | YES |
| tenant_message_templates | email_subject | text | YES |
| tenant_message_templates | translations | jsonb | YES |
| tenant_modules | id | uuid | NO |
| tenant_modules | tenant_id | uuid | YES |
| tenant_modules | module_id | uuid | YES |
| tenant_modules | status | text | YES |
| tenant_modules | valid_until | timestamp with time zone | YES |
| tenant_modules | created_at | timestamp with time zone | YES |
| tenant_modules | is_trial | boolean | NO |
| tenant_modules | trial_ends_at | timestamp with time zone | YES |
| tenant_modules | deleted_at | timestamp with time zone | YES |
| tenant_modules | stripe_subscription_id | text | YES |
| tenant_modules | stripe_price_id | text | YES |
| tenant_modules | cancel_at_period_end | boolean | NO |
| tenant_services | id | uuid | NO |
| tenant_services | tenant_id | uuid | NO |
| tenant_services | name | text | NO |
| tenant_services | name_i18n | jsonb | NO |
| tenant_services | description | text | YES |
| tenant_services | service_type | text | NO |
| tenant_services | default_price | numeric | YES |
| tenant_services | is_active | boolean | NO |
| tenant_services | deleted_at | timestamp with time zone | YES |
| tenant_services | order_index | integer | YES |
| tenant_services | required_role | text | YES |
| tenant_services | duration_minutes | integer | YES |
| tenant_services | requires_photo | boolean | NO |
| tenant_ui_preferences | id | uuid | NO |
| tenant_ui_preferences | tenant_id | uuid | NO |
| tenant_ui_preferences | primary_color | text | YES |
| tenant_ui_preferences | secondary_color | text | YES |
| tenant_ui_preferences | updated_at | timestamp with time zone | NO |
| tenant_usage_monthly | id | uuid | NO |
| tenant_usage_monthly | tenant_id | uuid | NO |
| tenant_usage_monthly | billing_month | text | NO |
| tenant_usage_monthly | channel | USER-DEFINED | NO |
| tenant_usage_monthly | sent_count | integer | NO |
| tenant_usage_monthly | created_at | timestamp with time zone | NO |
| tenant_usage_monthly | updated_at | timestamp with time zone | NO |
| tenant_wallets | tenant_id | uuid | NO |
| tenant_wallets | balance | integer | NO |
| tenant_wallets | updated_at | timestamp with time zone | YES |
| tenants | id | uuid | NO |
| tenants | name | text | NO |
| tenants | notes | text | YES |
| tenants | is_active | boolean | YES |
| tenants | trial_ends_at | date | YES |
| tenants | system_announcement | text | YES |
| tenants | billing_info | jsonb | YES |
| tenants | price_per_apartment | numeric | YES |
| tenants | currency | text | YES |
| tenants | discount_percentage | integer | NO |
| tenants | deleted_at | timestamp with time zone | YES |
| tenants | stripe_customer_id | text | YES |
| tenants | billing_email | text | YES |
| tenants | paid_until | timestamp with time zone | YES |
| tenants | acquired_by | uuid | YES |
| tenants | managed_by | uuid | YES |
| tenants | integration_settings | jsonb | NO |
| user_devices | id | uuid | NO |
| user_devices | tenant_id | uuid | NO |
| user_devices | profile_id | uuid | NO |
| user_devices | fcm_token | text | NO |
| user_devices | device_type | text | NO |
| user_devices | last_active_at | timestamp with time zone | YES |
| wallet_transactions | id | uuid | NO |
| wallet_transactions | tenant_id | uuid | NO |
| wallet_transactions | amount | integer | NO |
| wallet_transactions | transaction_type | text | NO |
| wallet_transactions | reference_id | text | YES |
| wallet_transactions | created_at | timestamp with time zone | YES |
| zones | id | uuid | NO |
| zones | tenant_id | uuid | NO |
| zones | name | text | NO |
| zones | created_at | timestamp with time zone | YES |
| zones | deleted_at | timestamp with time zone | YES |

### Export kalendáře (.ics) – `get_calendar_feed_data`

Funkce **`public.get_calendar_feed_data(p_token_hash text)`** (SECURITY DEFINER, `GRANT EXECUTE` jen **`service_role`**) vrací úkoly tenanta pro Edge Function **`supabase/functions/export_calendar`**. Výstupní tabule obsahuje mimo jiné **`location_text`**, **`geo_latitude`**, **`geo_longitude`** (nullable double precision): souřadnice z **`tasks.geo_location`**, pokud je vyplněná, jinak z **`apartments.geo_location`**. V SQL se používají **`extensions.ST_Y` / `extensions.ST_X`** (PostGIS je v projektu ve schématu `extensions`; nekvalifikované `ST_*` při `search_path = public` by RPC rozbily).

**Majitelský portál:** funkce **`public.get_owner_calendar_feed_url_for_apartment(p_apartment_id uuid) RETURNS text`** (SECURITY DEFINER, `GRANT EXECUTE` pro **`authenticated`**) vrátí uloženou hodnotu **`tenant_calendar_feed_tokens.owner_visible_calendar_url`** pro aktivní token daného bytu, pokud je volající **`property_owner`** s vazbou v **`apartment_owners`**; jinak `NULL`. Sloupec **`owner_visible_calendar_url`** se při generování tokenu v adminu plní stejnou URL jako v dialogu (plain `export_token` v query – hash v DB zůstává jediným tajným stavem pro ověření).

**Rozšířená pole pro Home Assistant (od migrace `20260405120000_calendar_feed_ha_automation_fields.sql`):**

| Sloupec | Význam |
|---------|--------|
| **`feed_task_type`** | Typ služby / úkolu pro HA (strojově čitelný řetězec): priorita **`tenant_services.service_type`** → **`tasks.task_type`** → zkrácený **`tasks.title`** (max. 200 znaků, bez zalomení řádků) → výchozí **`other`**. |
| **`feed_agency_price`** | Cena agentury z metadat úkolu – nullable **`numeric`**, JSON klíč **`tasks.metadata.amount_to_collect`**. |
| **`feed_transit_price`** | Průtoková (transit) cena z metadat – nullable **`numeric`**, JSON klíč **`tasks.metadata.transit_amount_to_collect`**. |

Edge funkce **`export_calendar`** sestaví VEVENT: vlastnost **GEO** jen při platném páru souřadnic, rozšířené **LOCATION**, v **DESCRIPTION** text pro personál (Host, Byt, Pracovník, poznámka), případně odkaz „Navigovat“ na Google Maps, a **na úplný konec** strukturovaný blok oddělený řádkem **`---`**, s řádky **`Type:`**, **`AgencyPrice:`**, **`TransitPrice:`** (hodnoty z **`feed_*`**; chybějící ceny v `.ics` jako **`0.00`**) – určeno pro regex / šablony automatizací v **Home Assistant**.

**Migrace:** rozšíření RPC včetně **`DROP FUNCTION IF EXISTS public.get_calendar_feed_data(text)`** před **`CREATE`**, protože PostgreSQL při změně návratového typu funkce vrací chybu **42P13** (`CREATE OR REPLACE` nestačí).

---

### Indexy pro výkonnostní optimalizaci (škálování)

Pro Realtime streamy a časté filtry na `tenant_id` / `apartment_id` jsou zásadní následující indexy. Bez nich dochází u velkých tenantů (1000+ záznamů) k full table scan.

**PostGIS** (rozšíření ve schématu `extensions`): sloupce `geo_location` na `apartments`, `tasks` a `clients` (v PostgreSQL typ **geometry(Point, 4326)**; v exportu **`information_schema`** se typ často ukáže jako **USER-DEFINED**) + GIST indexy pro prostorové dotazy.

**Full-Text Search:** sloupce `search_vector` (tsvector, generované, konfigurace `simple`) na `clients`, `apartments`, `tasks`, `reservations` + GIN indexy pro `@@` / `plainto_tsquery`.

| Tabulka | Index | Sloupec(y) | Účel |
|---------|-------|------------|------|
| apartments | idx_apartments_geo | geo_location (GIST) | Prostorové filtry a mapové výřezy na bodech WGS 84 (SRID 4326). |
| tasks | idx_tasks_geo | geo_location (GIST) | Geolokace úkolů / místa výkonu. |
| clients | idx_clients_search | search_vector (GIN) | Full-text nad jménem, e-mailem, telefonem (`simple`). |
| apartments | idx_apartments_search | search_vector (GIN) | Full-text nad názvem, adresou, kódem bytu. |
| tasks | idx_tasks_search | search_vector (GIN) | Full-text nad titulkem, popisem, custom poli, referencí. |
| reservations | idx_reservations_search | search_vector (GIN) | Full-text nad hostem, telefonem, reference_number, external_uid. |
| tasks | idx_tasks_tenant_id | tenant_id | Admin Realtime stream – `inFilter('tenant_id', [tenantId])`. Zrychlení výběru úkolů tenanta. |
| tasks | idx_tasks_tenant_scheduled_start | tenant_id, scheduled_start (partial WHERE deleted_at IS NULL) | P1 (2026-09-13): měsíční Kanban / ops okno / dashboard filtry. Migrace `20260913131000_p1_tasks_composite_indexes.sql`. |
| tasks | idx_tasks_tenant_completed_at | tenant_id, completed_at (partial WHERE deleted_at IS NULL) | P1: otevřené vs nedávno dokončené úkoly. Migrace `20260913131000_p1_tasks_composite_indexes.sql`. |
| reservations | idx_reservations_apartment_id | apartment_id | Admin Realtime stream – `inFilter('apartment_id', apartmentIds)`. Zrychlení výběru rezervací dle bytů tenanta. |
| billing_snapshots | idx_billing_snapshots_tenant_client_period | tenant_id, client_id, billing_period | UNIQUE – jeden snapshot na klienta a měsíc. |
| billing_snapshots | idx_billing_snapshots_tenant_period | tenant_id, billing_period | Admin přehled uzamčených měsíců. |
| billing_snapshot_offset_proposals | idx_billing_snapshot_offset_proposals_one_pending | billing_snapshot_id | UNIQUE WHERE status = `pending_owner` – max. jeden aktivní návrh na fakturu. |
| billing_snapshot_offset_proposals | idx_billing_snapshot_offset_proposals_tenant | tenant_id | Filtry podle tenanta. |
| billing_snapshot_offset_proposals | idx_billing_snapshot_offset_proposals_owner_status | owner_profile_id, status | Seznam návrhů majitele (Owner portál). |
| billing_snapshot_offset_proposals | idx_billing_snapshot_offset_proposals_snapshot | billing_snapshot_id | Vazba na podklad fakturace. |
| task_payouts | idx_task_payouts_tenant_id | tenant_id | RLS a filtrování podle tenanta. |
| task_payouts | idx_task_payouts_task_id | task_id | Výplaty k úkolu. |
| task_payouts | idx_task_payouts_profile_id | profile_id | Výplaty pracovníka. |
| task_commissions | idx_task_commissions_tenant_id | tenant_id | RLS a filtrování podle tenanta. |
| task_commissions | idx_task_commissions_task_id | task_id | Provize k úkolu. |
| task_commissions | idx_task_commissions_client_id | client_id | Provize partnerovi. |
| payout_snapshots | idx_payout_snapshots_tenant_period_recipient | tenant_id, payout_period, COALESCE(profile_id), COALESCE(client_id) | UNIQUE – jeden snapshot na příjemce a měsíc. |
| payout_snapshots | idx_payout_snapshots_tenant_period | tenant_id, payout_period | Historie výplat podle měsíce. |
| billing_shortfall_transfers | idx_billing_shortfall_transfers_tenant | tenant_id | Rychlý výběr převodů nedoplatků v rámci tenanta. |
| billing_shortfall_transfers | idx_billing_shortfall_transfers_client_created | client_id, created_at | Chronologický výpis převodů nedoplatků pro klienta. |
| owner_cash_transit_settlements | idx_owner_cash_transit_settlements_tenant | tenant_id | RLS a přehledy transit vyúčtování v rámci tenanta (migrace `20260404120000`). |
| owner_cash_transit_settlements | idx_owner_cash_transit_settlements_reservation | reservation_id | Jeden pohled na záznamy podle pobytu; ochrana proti duplicitnímu settlementu řeší aplikační vrstva / unikátní constraint podle nasazení. |
| owner_cash_transit_settlements | idx_owner_cash_transit_settlements_apartment | apartment_id | Long-term nájem bez rezervace; načítání owner zůstatku přes byt. |
| owner_cash_transit_settlements | idx_owner_cash_transit_settlements_task | task_id | Auditní dohledání settlementu zpět na konkrétní úkol/handover. |
| owner_cash_disposition_requests | idx_owner_cash_disposition_requests_tenant | tenant_id | Filtry podle tenanta (RLS staff). |
| owner_cash_disposition_requests | idx_owner_cash_disposition_requests_owner | owner_profile_id | Seznam žádostí majitele. |
| owner_cash_disposition_requests | idx_owner_cash_disposition_requests_settlement | settlement_id | Vazba na settlement; součty „zamčených“ částek. |
| owner_cash_disposition_requests | idx_owner_cash_disposition_requests_status | tenant_id, status | Přehledy podle stavu žádosti. |
| owner_portal_view_sessions | idx_owner_portal_view_sessions_admin_profile_id | admin_profile_id | Historie náhledů podle dispečera. |
| owner_portal_view_sessions | idx_owner_portal_view_sessions_viewed_owner_profile_id | viewed_owner_profile_id | Audit – kdo prohlížel portál konkrétního majitele. |
| owner_portal_view_sessions | idx_owner_portal_view_sessions_tenant_id | tenant_id | RLS a přehledy v rámci agentury. |
| owner_portal_view_sessions | idx_owner_portal_view_sessions_client_id | client_id | Návrat do CRM kontextu / audit podle klienta. |
| owner_portal_view_sessions | idx_owner_portal_view_sessions_started_at | started_at DESC | Seřazení historie od nejnovějších. |
| tenant_ui_preferences | (UNIQUE constraint tenant_ui_preferences_tenant_id_key) | tenant_id | Jedinečnost tenant_id – jeden řádek vzhledu na agenturu (index vzniká z UNIQUE). |

**SQL pro vytvoření (spustit v Supabase SQL Editoru):**

```sql
CREATE INDEX IF NOT EXISTS idx_tasks_tenant_id ON public.tasks(tenant_id);
CREATE INDEX IF NOT EXISTS idx_reservations_apartment_id ON public.reservations(apartment_id);

-- PostGIS + FTS (migrace 20260403000000_enable_postgis_and_geo.sql, 20260403020000_add_geo_to_clients.sql, 20260403010000_add_fts_vectors.sql)
CREATE INDEX IF NOT EXISTS idx_apartments_geo ON public.apartments USING GIST (geo_location);
CREATE INDEX IF NOT EXISTS idx_tasks_geo ON public.tasks USING GIST (geo_location);
CREATE INDEX IF NOT EXISTS idx_clients_geo ON public.clients USING GIST (geo_location);
CREATE INDEX IF NOT EXISTS idx_clients_search ON public.clients USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_apartments_search ON public.apartments USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_tasks_search ON public.tasks USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_reservations_search ON public.reservations USING GIN (search_vector);
```

---

### Tabulka tenant_ui_preferences

**Účel:** Ukládání značkových barev aplikace na úrovni agentury (tenant): **primary_color** a **secondary_color** jako text (HEX, např. `#1E3A8A` nebo formát sladěný s klientem – ověř v aplikaci při zápisu). NULL = použít výchozí paletu FalcoNest pro danou osu.

**Vazba:** `tenant_id` NOT NULL, FK → **tenants** (ON DELETE CASCADE). Doporučeně **jeden řádek na tenant** (UNIQUE na `tenant_id` v migraci).

**updated_at (timestamptz, NOT NULL):** Poslední změna záznamu v UTC. Kritické pro **Timestamp Merging** při offline-first synci: klient při PUT/PATCH porovnává svůj známý `updated_at` se serverem (nebo použije podmíněný update), aby nepřepsal novější stav z jiného zařízení bez rozhodnutí.

**RLS (navrhované pravidlo):**

- **SELECT:** Všichni **autentizovaní členové daného tenanta** smí číst řádek svého `tenant_id` (worker i owner potřebují stejnou paletu v UI). Super Admin smí číst vše (stejný vzor jako u jiných tenant tabulek přes `is_super_admin()`).
- **INSERT / UPDATE:** Pouze **admin** nebo **manager** tenanta (`is_tenant_admin_or_manager()`), případně Super Admin. Worker/owner nemění globální brandové barvy agentury.

*Přesné názvy policy v SQL viz migrace v `supabase/migrations/`.*

**Lokální Drift (`packages/falconest_drift`):** tabulka **`tenant_ui_preferences`** (Dart třída tabulky `TenantUiPreferences`, řádek `TenantUiPreference`) kopíruje stejné sloupce jako PostgreSQL pro offline-first zápis a sync; verze schématu Drift **13**.

---

### Tabulka tasks – Timestamp Merging (Smart Merge)

Sloupec **tasks.updated_at** (timestamptz, nullable) se na serveru nastavuje triggerem při každém UPDATE. Mobilní aplikace při push pending updates (WorkerSyncService) před odesláním lokální změny stáhne aktuální řádek úkolu včetně `updated_at`. Pokud je `updated_at` ze serveru novější než lokální `last_synced_at`, došlo ke konfliktu (admin mezitím upravil úkol na webu). Aplikace pak aplikuje **Smart Merge**: status zůstává z mobilu (pracovník byl na místě), poznámky se sloučí (append), ostatní pole přebírají hodnoty ze serveru. Bez tohoto mechanismu by platilo „Last-write-wins“ a změny administrátora by mobil přepsal.

---

### Tabulka notifications – Realtime notifikace pro uživatele

Tabulka **notifications** slouží pro zobrazení oznámení v Top Baru (zvoneček). Každá notifikace je určena konkrétnímu uživateli (`profile_id`) a agentuře (`tenant_id`).

**metadata (jsonb, NOT NULL, výchozí `{}`):** Volitelná data pro UI – např. **`task_id`** a **`entity`** pro navigaci na detail úkolu po kliknutí na řádek v seznamu oznámení. Aplikace musí počítat s prázdným objektem u starších řádků i u typů událostí bez prokliku.

**Typy řádků z Edge/cron (pole `type`):** mimo jiné **`new_task`** (trigger DB), **`daily_summary`** (ranní souhrn – metadata často **`task_count`**, volitelně **`task_id`** prvního úkolu), **`template_reminder`** (připomenutí transferu – **`task_id`**), **`upcoming_task`** (cca 1 h před **`scheduled_start`** – **`task_id`**, **`scheduled_start`** v metadata).

**RLS:** Uživatel vidí a může upravovat (např. označit jako přečtené) pouze notifikace, kde `tenant_id` odpovídá jeho agentuře a `profile_id` odpovídá jeho profilu. Super Admin má plný přístup. Tabulka musí být přidána do Supabase Realtime publikace (Dashboard → Database → Replication), aby stream v aplikaci fungoval.

---

### Tabulka notification_preferences – kanály (web / push / e-mail)

Jeden řádek na **profile_id** (s **tenant_id**). **Personál / dispečink:** čtyři typy událostí × tři kanály (`daily_summary_*`, `upcoming_task_*`, `new_task_assigned_*`, `template_reminders_*`). **Majitel (Klientský portál):** tři typy událostí z terénu × tři kanály – migrace **`20260411120000_owner_notification_prefs.sql`**.

| Typ události | Web (in-app) | Push (FCM) | E-mail |
|--------------|--------------|------------|--------|
| Ranní souhrn | `daily_summary_web` | `daily_summary_push` | `daily_summary_email` |
| Blížící se termín úkolu | `upcoming_task_web` | `upcoming_task_push` | `upcoming_task_email` |
| Přiřazení nového úkolu | `new_task_assigned_web` | `new_task_assigned_push` | `new_task_assigned_email` |
| Připomenutí šablon | `template_reminders_web` | `template_reminders_push` | `template_reminders_email` |
| Majitel: zahájení práce u bytu | `owner_task_started_web` | `owner_task_started_push` | `owner_task_started_email` |
| Majitel: dokončení práce | `owner_task_completed_web` | `owner_task_completed_push` | `owner_task_completed_email` |
| Majitel: vybrání hotovosti | `owner_cash_collected_web` | `owner_cash_collected_push` | `owner_cash_collected_email` |

Dřívější jednosloupcové příznaky `*_enabled` byly nahrazeny maticí (migrace `20260403220000_notification_preferences_channels.sql`).

---

### Trigger na `tasks` – multi-channel notifikace při přiřazení úkolu

**Trigger:** `tasks_enqueue_new_assignment_push` — **AFTER INSERT OR UPDATE OF `assigned_to`** na **`public.tasks`**, pro každý řádek volá **`public.enqueue_internal_push_on_new_task_assignment()`** (SECURITY DEFINER, `search_path = public`).

**Účel:** Při novém přiřazení (nebo změně assignee) zkontroluje existenci profilu, načte z **`notification_preferences`** příznaky kanálů pro událost „nový úkol“ a podle toho:

- zařadí zprávu do **`automation_message_queue`** s kanálem **`internal_push`** a/nebo **`email`** (text z **`profiles.email`**);
- při zapnutém **`new_task_assigned_web`** vloží řádek do **`notifications`** (typ např. `new_task`, v **`metadata`** může být **`task_id`**).

**Čas v textu zprávy (push / e-mail / in-app):** Pro řádek úkolu platí **`scheduled_start`** jako **`timestamp with time zone`** a **`due_date`** jako **text** (ISO řetězec z klienta). Funkce sjednocuje „kdy“ do jedné proměnné **`timestamptz`**: bere **`scheduled_start`**, jinak neprázdné **`due_date`** převedené přes **`btrim` → `::timestamptz`** (prázdný řetězec ignoruje). Tím se vyhneme chybě typu `COALESCE(timestamptz, text)` a tělo zprávy formátuje **`to_char(... AT TIME ZONE 'Europe/Prague', ...)`** jen z jednotného časového typu (migrace `20260403260000_fix_enqueue_new_task_coalesce_timestamptz_text.sql`).

---

### Push Notifikace (FCM) – Fáze 1 – Infrastruktura

**user_devices** – FCM tokeny zařízení pro doručení push notifikací. Každé zařízení (iOS, Android, Web) má unikátní `fcm_token`. Sloupec `last_active_at` slouží pro čištění neaktivních tokenů.

**notification_preferences** – Viz výše: matice kanálů včetně **majitelovských** trojic (`owner_*`). Pro cron/edge logiku se používají odpovídající sloupce podle typu události.

**RLS:** Uživatel čte a zapisuje pouze své tokeny a preference (`profile_id` = vlastní profil). Super Admin má plný přístup. Edge Functions a budoucí `firebase_messaging` v aplikaci budou tyto tabulky využívat pro targeting.

**Edge Functions (cron) – matice kanálů:**

- **`daily-task-summary`** – úkoly `assigned` na **dnešní den** (časová zóna provozu v kódu). Čte **`daily_summary_web` / `daily_summary_push` / `daily_summary_email`**. **Push:** FCM s lokalizačními klíči (jako dříve). **Web:** INSERT do **`notifications`** (`type` = `daily_summary`). **E-mail:** řádek ve **`automation_message_queue`** (kanál `email`, `editable_payload.source` = `daily_summary`). Push lze vypnout bez Firebase – web/e-mail fungují i bez `FIREBASE_*` secrets.
- **`template-reminders`** – pg_cron 7/11/15/19 (Madrid). Transfer úkoly, časová okna T1/T2/T3. Čte **`template_reminders_*`**. **Push:** FCM (loc klíče). **Web:** `notifications` (`type` = `template_reminder`). **E-mail:** fronta s `source` = `template_reminder`.
- **`upcoming-task-reminder`** – pg_cron každých **15 min** (`invoke_upcoming_task_reminder`). Úkoly se **`scheduled_start`** v okně cca **50–70 min** od teď (UTC). Idempotence závisí na nasazení (např. dedikovaná log tabulka v migraci `20260403280000` – v aktuálním exportu `information_schema` z 2026-04-09 **nebyla uvedena**; ověř v DB). Čte **`upcoming_task_*`**. **Web / e-mail / push** stejný vzor; push používá český text + `data.route` na `/worker/task/<id>`.

**Konfigurace cronu:** `cron_edge_config` klíče `*_url` a `*_anon_key` (např. `upcoming_task_reminder_url`, `template_reminders_url`). Vyžaduje secrets u funkcí používajících FCM: `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON`.

**Edge `automation-dispatch` (e-mail + deep link):** kanál **e-mail** používá HTML šablonu FalcoNest (`emailTemplates.ts` – bílá karta, inline CSS, záhlaví značky, volitelné CTA „Otevřít v aplikaci“) a zároveň vždy **plain text** (`text`) pro klienty bez HTML. Pokud `editable_payload` obsahuje platné **`task_id`** (UUID), doplní se deep link. Základ URL: env **`FALCONEST_WEB_APP_BASE_URL`** (výchozí `https://admin.falconestapp.com`), cesta hash routeru: `/#/worker/task/<task_id>`. Stejné **`task_id`** putuje do FCM **`data.task_id`** a **`data.route`** u `internal_push` (např. `/worker/task/<uuid>`).

---

### Automatizace zpráv, šablony, log a checklisty

**automation_rules** – pravidla tenantů (spouštěcí událost, odsazení v minutách, kanál včetně enum hodnoty **`internal_push`** (FCM dispečer, migrace `20260403180000`), šablona `template_id` → `tenant_message_templates`, tišící hodiny). Sloupec **`staff_profile_id`** (nullable, FK `profiles`) určuje příjemce interního push při `target_entity = staff` (migrace `20260403190000`). **automation_message_queue** – odchozí fronta: entita (`entity_type` + `entity_id`), naplánovaný čas, stav a kanál jako PostgreSQL enumy (v hlavní tabulce exportováno jako **USER-DEFINED**), JSON **editable_payload**, počítadlo pokusů.

**tenant_message_templates** – šablony zpráv: logický klíč `key`, název, kanál (`sms` / `email` / `whatsapp` / **`internal_push`**, migrace `20260403190000`), kontext spuštění, pořadí, měkký delete. Texty těla zpráv jsou v **translations** (jsonb, mapa jazyk → obsah); pro e-mail existuje volitelný **email_subject**. U `internal_push` je text šablony hlavně pro náhled ve frontě – odeslaný titulek/tělo push generuje Edge `automation-dispatch`. Sloupce **body** ani **language_code** v aktuální DB nejsou – multijazyk řeší JSON.

**tenant_message_log** – audit odeslání a příchozích zpráv (včetně **direction**, **content_snapshot**, maskovaný příjemce, cena jednotky **unit_price**, vazba **queue_id** na frontu). **tenant_usage_monthly** – součty **sent_count** za **billing_month** a kanál. **platform_messaging_rates** – referenční ceny za kanál (EUR) platné od **valid_from** (pro přehledy HQ).

**checklist_templates** / **checklist_template_items** – definice šablon (název, položky, pořadí, povinná fotka). **task_checklists** / **task_checklist_items** – instance u úkolu: dokončení, autor, fotka u položky.

**tenants.integration_settings** – jsonb NOT NULL: konfigurace integrací (např. Twilio) na úrovni agentury; při „prázdnu“ očekávej `{}` v aplikaci.

**apartments:** **parking_instructions** a **review_link** – volitelné texty pro terén a zpětnou vazbu (mapy, odkaz na recenze).

---

### Tabulka invitations

Sloupec **tenant_id** je nullable: **NULL** znamená pozvánku pro účty bez agentury (HQ – Super Admin / Account Manager). Ostatní pozvánky mají `tenant_id` vyplněný.

**RLS (SELECT):** admin/manager vidí jen řádky svého **`my_tenant_id()`**, super_admin vše – viz **`20260319100000_fix_security_advisor.sql`**. **Anon** tedy **nemá** oprávnění číst tabulku přímo. Obrazovka **`/invite`** načítá pozvánku přes RPC **`get_invitation_for_accept(p_token)`** (vrací jeden JSON řádek podle UUID tokenu, bez možnosti listovat celou tabulku).

---

### Modul Finance – Zaměstnanecká pokladna (Cash Accountability)

Modul **Finance** je hlavní modul (zdarma) obsahující **Zaměstnaneckou pokladnu** pro evidenci hotovosti vybrané od hostů. Placený sub-modul **finance_export** (Podklady pro fakturaci) bude přidán později.

**Systém je nezávislý na tenant_wallets a wallet_transactions** – ty slouží pro předplacené kredity, nikoliv pro hotovostní evidenci.

**employee_cash_wallets** – Kapsa zaměstnance:
- Jeden řádek na (tenant_id, profile_id); UNIQUE constraint.
- **balance** – aktuální dlužná hotovost u zaměstnance (kladná = má u sebe peníze vybrané od hostů).
- **updated_at** – poslední změna stavu.

**employee_cash_transactions** – Účetní kniha výběrů:
- Append-only záznamy transakcí.
- **transaction_type**: `COLLECTED_FROM_GUEST` (výběr od hosta při Check-in/Transfer), `HANDED_TO_AGENCY` (odevzdání agentuře), `COMPANY_EXPENSE` (firemní výdaj z hotovosti), `FLOAT_ISSUED` (vklad základu od agentury na začátku směny).
- **note**, **receipt_image_url** – volitelné u firemních výdajů; poznámka a URL fotky účtenky.
- **amount**: kladné = výběr (zvyšuje balance), záporné = odevzdání (snižuje balance).
- **task_id** – volitelná vazba na úkol (Check-in, Transfer, **rent_collection**) pro audit.
- **apartment_id** – vazba na byt (z úkolu u výběru nájmu / u firemních výdajů).
- **expected_amount** – plánovaná částka k výběru (z UI dialogu nebo metadat úkolu).
- **metadata** (jsonb) u **COLLECTED_FROM_GUEST**: při odchylce od plánu klient zapisuje **`expected_amount`**, **`collected_amount`**, **`variance`** (audit trail pro Hlídač hotovosti); sloupec **amount** = skutečně převzatá hotovost do peněženky.

**RLS:** Oba tabulky mají RLS zapnuté; přístup pouze na řádky, kde tenant_id odpovídá tenant_id přihlášeného uživatele (profiles.auth_id = auth.uid()). Super Admin má plný přístup.

**employee_cash_handover_allocations** – auditní FIFO alokace převzetí:
- Každý řádek popisuje, kolik z jedné transakce `HANDED_TO_AGENCY` bylo alokováno na konkrétní zdroj `COLLECTED_FROM_GUEST`.
- Klíčové sloupce: `handed_transaction_id`, `source_transaction_id`, `allocated_amount`, `allocated_transit_amount`, volitelně `task_id`, `reservation_id`, `apartment_id`.
- Použití: přesné účetní párování bulk handoveru + deterministické připsání transit hotovosti majitelům.

**RPC `process_worker_cash_handover_fifo` (20260421140000, deduplikace 20260522100000):**
- Vstupy: tenant, worker profile, admin profile, celková částka převzetí.
- Chování: FIFO nad nealokovanými `COLLECTED_FROM_GUEST` transakcemi (fallback pro legacy bez alokačních řádků), vytvoření jedné souhrnné `HANDED_TO_AGENCY` transakce, zápis alokací a owner settlementů z transit podílu.
- **Deduplikace settlementů (20260522100000):** před INSERT do `owner_cash_transit_settlements` ověří existující řádek v rámci `tenant_id` (priorita: `reservation_id` → `task_id` → `apartment_id` bez rezervace). Pokud už existuje záznam (typicky `auto_handoff`), transit settlement se nevytvoří; alokace v `employee_cash_handover_allocations` zůstává.
- Výstup: JSON se souhrnem (`handed_transaction_id`, počet alokací, transit total, balance before/after).

**Registr modulů:**
- **finance** – hlavní modul, zdarma (price_eur = 0), show_in_menu = true.
- **finance_export** – placený sub-modul, parent_module_key = 'finance', show_in_menu = false, price_eur = 29, pricing_type = 'fixed'.

### Tabulka owner_cash_transit_settlements – transit hotovost vůči majiteli

**Účel:** Uzavřít průtokovou hotovost u pobytu: částka, která prošla přes pracovníka/agenturu a má být **vyúčtována majiteli** (ne tržba agentury). Záznam je vždy vázaný na **rezervaci** (`reservation_id`) a **tenant_id** (multi-tenant).

**Sloupce:** před použitím v dotazu ověř `\d public.owner_cash_transit_settlements` v cílové instanci.

- **Základ (migrace `20260404120000`):** **amount**, **currency**, **tenant_id**, **reservation_id**, **settled_at** (default `now()`), **note** (volitelná), **created_by** → **profiles** (NOT NULL).
- **Rozšířený export (některé instance):** navíc např. **status**, **settled_by**, **employee_cash_transaction_id**, **notes** místo **note** – klient pro automatický zápis po **`HANDED_TO_AGENCY`** počítá s **základním** tvarem; vazbu na transakci pokladny ukládá do textu **note** (`auto_handoff: … (tx: …)`).

**Aplikační vrstva:** `lib/features/owner/repositories/reservation_cash_transit_repository.dart` – `ReservationCashTransitRepository` (`resolve`, `settleTransitCash`, `listSettlementsForOwnerProfile`, `listAvailableSettlementsForOwner`, `getAvailableBalanceForOwner`); model **`OwnerCashTransitSettlement`**.

**RLS:** Politiky z migrace `20260404120000_owner_cash_transit_settlements.sql` – staff tenanta (kromě property_owner) SELECT; majitel SELECT jen pro rezervace na svých bytech; INSERT/UPDATE/DELETE admin/manager (a super_admin).

### Tabulka owner_cash_disposition_requests – žádost majitele o dispozici

**Účel:** Odděleně od uznané částky zaznamenat **co má agentura s penězi udělat** (výplata na účet, zápočet na fakturu, vyzvednutí v trezoru). Vazba **`settlement_id`** → **`owner_cash_transit_settlements`** (povinná).

- **disposition_type** – CHECK: `bank_transfer`, `invoice_credit`, `vault_pickup`.
- **used_amount** – již uplatněná část žádosti (výchozí 0; migrace `20260410010000`).
- **status** – CHECK: `pending`, `approved`, `rejected`, `completed`, `partially_completed`, `ready_for_pickup`.
- **pickup_date** – plánované vyzvednutí u `vault_pickup` (migrace `20260410020000`).
- **admin_notes** – text viditelný agentuře; při INSERTu z klientského portálu může majitel zadat zprávu (např. účet), po zpracování ho doplňuje/upřesňuje dispečink.
- **iban** – volitelný IBAN / číslo účtu pro **`bank_transfer`** (migrace `20260410000000`).

**Aplikační vrstva:** `OwnerCashDispositionRepository` (`lib/features/owner/repositories/owner_cash_disposition_repository.dart`), model **`OwnerCashDispositionRequest`** (včetně **`used_amount`**), pro admin seznam s embedem profilu **`AdminOwnerCashDispositionRow`** (`getRequestsForTenant` + join `profiles!owner_cash_disposition_requests_owner_profile_id_fkey`). Při **`updateRequestStatus`** s novou poznámkou dispečinku se text **připojuje** do `admin_notes` (`Owner:` / řádky `Admin:`), majitelův obsah se nepřepisuje. Částečné umoření faktury: **`applyOffsetToSnapshot`** (žádost **`invoice_credit`**, stav **`approved`** nebo **`partially_completed`**).

**RLS (migrace `20260409143000`, finální verze):** všechny odkazy na sloupce řádku žádosti v politikách musí být **kvalifikované** tabulkou `owner_cash_disposition_requests` (např. `owner_cash_disposition_requests.tenant_id`). Bez prefixu PostgreSQL hlásí **ERROR 42702** („column reference `tenant_id` is ambiguous“), protože stejné názvy sloupců existují i u `profiles` / joinů. Migrace začíná `DROP TABLE IF EXISTS … CASCADE` a tabulku znovu vytváří (žádný zásah do `owner_cash_transit_settlements`). V poddotazech jsou aliasy `p_sel`, `p_staff`, `p0`–`p4` atd. Logika: majitel SELECT jen vlastní `owner_profile_id`; staff tenanta (role ≠ `property_owner`) SELECT při `tenant_id = my_tenant_id()`; INSERT jen `property_owner` s platnou vazbou settlement → rezervace → `apartment_owners`; admin/manager UPDATE/DELETE v rámci tenanta řádku. **UPDATE majitele (pending):** politika **`owner_cash_disposition_requests_update_owner_pending`** (`20260410020000`) – majitel může měnit řádek jen ve stavu **`pending`** (např. **`pickup_date`**).

**updated_at:** migrace nedefinuje trigger; při změně stavu žádosti nastavuje aplikace (`updateRequestStatus`).

---

### Modul Vyúčtování a Provize (Settlements & Commissions) – task_payouts, task_commissions

Prémiový modul **zcela oddělený** od Podkladů pro fakturaci (billing_snapshots). Řeší výdaje agentury: výplaty zaměstnancům a provize externím partnerům z jednotlivých úkolů.

**task_payouts** – Výplaty pracovníkům:
- **tenant_id** – agentura (multi-tenant izolace).
- **task_id** – vazba na úkol (FK → tasks ON DELETE CASCADE).
- **profile_id** – komu se platí (FK → profiles – zaměstnanec).
- **amount** – částka výplaty v měně tenanta.
- **status** – 'pending' (čeká), 'approved' (schváleno), 'paid' (vyplaceno).

**task_commissions** – Provize partnerům:
- **tenant_id** – agentura.
- **task_id** – vazba na úkol.
- **client_id** – externí agentura/partner v CRM (FK → clients), kterému platíme provizi (nullable).
- **profile_id** – volitelná vazba na profil (nullable).
- **amount** – částka provize.
- **status** – stejné hodnoty jako task_payouts.

**RLS:**
- **task_payouts**: Admin vidí všechny výplaty v tenantu a může je spravovat. Pracovník vidí pouze své výplaty (`profile_id` = jeho profil). Super Admin má plný přístup.
- **task_commissions**: Pouze Admin v rámci tenantu vidí a spravuje provize. Super Admin má plný přístup.

---

### Tabulka billing_snapshots – Zmražená vyúčtování (Snapshotting)

Tabulka **billing_snapshots** ukládá při uzamčení měsíce přesná data vyúčtování (ceny, úkoly, výdaje) jako JSONB. Místo generování a ukládání fyzických PDF do cloudu si majitelé mohou v Klientské zóně kdykoliv vygenerovat PDF On-Demand z těchto dat.

**Sloupce:**
- **tenant_id** – agentura (multi-tenant izolace).
- **client_id** – klient (majitel) – FK na clients; BillingGroup.groupKey ve fakturaci.
- **billing_period** – první den měsíce (např. 2026-02-01).
- **snapshot_data** – JSONB: items (úkoly s cenami), total_to_invoice, total_expenses, final_to_invoice, client_name, currency.
- **locked_at** – kdy bylo vyúčtování uzamčeno.
- **locked_by** – profil Admina, který uzamčení provedl (NOT NULL).
- **payment_status** – stav úhrady: **`unpaid`** | **`paid`** | **`cash_offset`** | **`partially_paid`** (CHECK, výchozí **`unpaid`**; migrace `20260410000000` + `20260410010000`).
- **paid_at** – čas uhrazení nebo zápočtu (nullable).
- **invoice_pdf_url** – odkaz na nahranou fakturu PDF (nullable).
- **offset_amount** – částka uhrazená zápočtem z hotovostní zálohy majitele (numeric NOT NULL DEFAULT 0; migrace `20260828140000`).
- **offset_request_id** – FK na **`owner_cash_disposition_requests`** (nullable).
- **offset_applied_at** – UTC čas zápisu zápočtu (nullable).

**Unikátní index** `(tenant_id, client_id, billing_period)` – jeden snapshot na klienta a měsíc.

**RLS:**
- **SELECT (Admin/Worker):** Zaměstnanci agentury (role != property_owner) vidí snapshoty své agentury. Super Admin vidí vše.
- **SELECT (Owner):** Majitel (property_owner) vidí POUZE snapshoty, kde `client_id IN (SELECT id FROM clients WHERE profile_id = jeho profil)`.
- **INSERT:** Pouze Admin (role = 'admin') nebo Super Admin v rámci svého tenant_id.
- **UPDATE:** Politika **`billing_snapshots_update_admin_manager`** – **admin** / **manager** (nebo super_admin) v rámci **`tenant_id`** řádku; úpravy úhrad, **`invoice_pdf_url`** atd. (migrace `20260410010000`).

---

### Tabulka billing_snapshot_offset_proposals – Approval Loop doplatku ze zálohy

**Účel:** Dispečer navrhne majiteli doplatek **`partially_paid`** faktury z volné hotovostní rezervy. Majitel schválí nebo zamítne přes RPC **`respond_billing_offset_proposal`** – stav návrhu majitel **nemění** přímým UPDATE (RLS).

**Sloupce:**
- **tenant_id** – agentura (multi-tenant).
- **billing_snapshot_id** – FK → **`billing_snapshots`** (konkrétní uzamčený podklad).
- **owner_profile_id** – FK → **`profiles`** (majitel).
- **settlement_id** – FK → **`owner_cash_transit_settlements`** (zdroj poolu pro novou **`invoice_credit`** žádost).
- **proposed_amount** – navrhovaná částka doplatku (CHECK > 0).
- **applied_amount** – skutečně uplatněná částka po schválení (nullable).
- **currency** – měna (výchozí **`EUR`**).
- **status** – CHECK: **`pending_owner`** | **`applied`** | **`rejected_by_owner`** | **`cancelled_by_admin`** | **`stale`**.
- **proposed_by_profile_id** – dispečer, který návrh vytvořil.
- **disposition_request_id** – FK → **`owner_cash_disposition_requests`** (vytvořená schválená žádost po approve).
- **owner_responded_at** – čas reakce majitele.
- **owner_rejection_note** – volitelná poznámka při zamítnutí.
- **admin_notes** – interní poznámka dispečera.
- **created_at**, **updated_at** – UTC razítka.

**Indexy:**
- **`idx_billing_snapshot_offset_proposals_one_pending`** – UNIQUE **`(billing_snapshot_id) WHERE status = 'pending_owner'`**.
- **`idx_billing_snapshot_offset_proposals_owner_status`**, **`idx_billing_snapshot_offset_proposals_tenant`**, **`idx_billing_snapshot_offset_proposals_snapshot`**.

**RLS (migrace `20260828160000`):**
- **SELECT staff:** **super_admin** nebo **admin/manager** tenanta (`tenant_id = my_tenant_id()`).
- **SELECT owner:** **`owner_profile_id`** = profil volajícího **`property_owner`**.
- **INSERT:** jen **admin/manager** (nebo super_admin); WITH CHECK: snapshot **`partially_paid`**, **`proposed_amount ≤ zbývající doplatek`**, majitel odpovídá **`clients.profile_id`**, settlement patří majiteli.
- **UPDATE:** jen **admin/manager** – zrušení **`pending_owner` → `cancelled_by_admin`**.
- **Majitel:** **žádný** INSERT/UPDATE/DELETE – pouze RPC.

**RPC a interní funkce:**
- **`respond_billing_offset_proposal(p_proposal_id, p_action, p_owner_rejection_note)`** – **SECURITY DEFINER**, **GRANT EXECUTE** pro **`authenticated`**. Akce **`approve`** | **`reject`**. Approve: zamkne návrh + snapshot, ověří pool, vytvoří **`approved` `invoice_credit`** žádost, zavolá **`apply_billing_snapshot_offset_core`**, nastaví návrh na **`applied`**, audit **`BILLING_OFFSET_PROPOSAL_APPROVED`**. Reject: **`rejected_by_owner`**, audit **`BILLING_OFFSET_PROPOSAL_REJECTED`**.
- **`apply_billing_snapshot_offset_core(...)`** – interní jádro zápočtu (žádost + snapshot + záporný settlement + UPDATE **`billing_snapshots`**); **bez GRANT** pro klienta.
- **`_billing_offset_compute_plan`**, **`_billing_offset_owner_pool_sum`**, **`_billing_offset_eps`** – pomocné funkce bez veřejného GRANT.

**Audit:** **`audit_logs`**: **`BILLING_OFFSET_PROPOSAL_APPROVED`**, **`BILLING_OFFSET_PROPOSAL_REJECTED`**.

---

### Tabulka task_categories [GLOBAL DICTIONARY] – globální číselník typů úkolů

Tabulka **task_categories** je **platformový globální číselník** typů úkolů. Na rozdíl od per-tenant tabulek zde **chybí sloupec tenant_id** – kategorie jsou sdílené pro celou platformu a spravuje je majitel FalcoNestu. To zjednodušuje onboarding nových agentur: nemusejí definovat vlastní kategorie, dostanou jednotnou výchozí sadu.

**Proč chybí tenant_id a name:**
- **tenant_id** – kategorie nejsou vázané na agenturu; jsou globální.
- **name** – zobrazované názvy se **nelokalizují v DB**. Lokalizace probíhá výhradně přes i18n JSON soubory (např. `admin.task_type_cleaning`). Databáze uchovává pouze logiku: kódy, barvy a ikony.

**Sloupce:**
- **id** – UUID primární klíč
- **code** – systémový klíč (UNIQUE), např. `cleaning`, `transfer_in`, `check_in`; mapuje se na `tasks.task_type` a `tenant_services.service_type`
- **color_hex** – barva pozadí karty v HEX formátu
- **icon_name** – název Material Icons ikony
- **order_index** – pořadí v legendě a dropdownu
- **planning_priority** – priorita v plánování (integer, NOT NULL)

**RLS politiky:**
- **SELECT** – všichni autentizovaní uživatelé (s platným profilem v `public.profiles`) mohou číst.
- **INSERT, UPDATE, DELETE** – pouze Super Admin (`public.is_super_admin()`).

**Napojení:** Úkoly (`tasks.task_type`) a služby (`tenant_services.service_type`) používají hodnoty odpovídající sloupci `code`. Flutter mapuje `code` na i18n klíč `admin.task_type_{code}` pro lokalizovaný název.

---

### Tabulka clients – CRM Klienti (Externí úkoly)

Tabulka **clients** slouží pro zákazníky agentury – majitelé bytů (owner), externí klienti bez apartmánu (external) a agentury (agency). Umožňuje fakturaci externích úkolů (např. transfer pro cizího člověka bez rezervace) přes `tasks.client_id`. Sloupec **profile_id** propojuje CRM klienta s přihlašovacím profilem (Klientský portál majitelů). Sloupec **agency_id** slouží pro vazbu na nadřazenou agenturu (FK → clients).

**Sloupce:** `id`, `tenant_id` (FK → tenants), `name` (povinné), `email`, `phone`, `client_type` (owner/external/agency), `language_code`, `created_at`, `deleted_at`, `profile_id`, `agency_id`.

**RLS:** Uživatel vidí a upravuje pouze klienty svého `tenant_id`. Super Admin má plný přístup.

---

### Soft delete (deleted_at)

U tabulek **tasks**, **apartments**, **profiles**, **reservations**, **tenant_services**, **zones**, **apartment_owners**, **clients**, **client_addresses**, **tenants** a **tenant_modules** sloupec **deleted_at** (timestamptz, nullable) znamená „měkké smazání“: místo fyzického DELETE se volá UPDATE s `deleted_at = now()`. Záznamy s `deleted_at IS NOT NULL` aplikace při načítání vynechává (filtr `.is_('deleted_at', null)`). Audit záznam (SOFT_DELETE) se zapisuje do `audit_logs`.

---

### Prepaid Wallet (Předplacená peněženka) – kredity pro prémiové moduly

Systém **tenant_wallets** + **wallet_transactions** slouží pro předplacené kredity (např. generování úkolů přes automatizaci). Klienti si kupují balíčky kreditů; každé použití (např. „Generovat návrhy úkolů“) strhne určitý počet kreditů.

**Princip:**
- **tenant_wallets** – jeden řádek na tenanta; sloupec `balance` drží aktuální stav kreditů. Záznamy vznikají automaticky pomocí triggeru `trg_tenant_wallet_after_insert` (AFTER INSERT) na tabulce `tenants`; stávající tenanty doplňuje zpětně migrace (backfill).
- **wallet_transactions** – append-only účetní kniha; každá změna (dobití TOP_UP, útrata USAGE_AUTO_TASKS) vytvoří nový záznam s kladnou nebo zápornou částkou.

**Bezpečnost a Race Condition:**
- Klient (admin, manager) smí **pouze číst** (SELECT) vlastní peněženku a transakce – zákaz INSERT/UPDATE z aplikace!
- Jakékoli stržení kreditů probíhá **výhradně přes RPC funkci** `deduct_wallet_credits()`, která používá zámek řádku (`FOR UPDATE`) pro ochranu proti souběhu (více dispečerů generuje úkoly současně). **P1 (2026-09-13):** funkce navíc vyžaduje **super_admin** nebo **admin/manager** volajícího ve stejném `tenant_id` jako `p_tenant_id` (worker/owner volání vrací `false`).
- Doplňování kreditů (TOP_UP) provádí Super Admin nebo Stripe webhook přes service_role / SECURITY DEFINER funkci.

**RLS:** Role admin a manager smí pouze SELECT vlastní data; super_admin a service_role mají plná práva. Na tenant_wallets není povolena přímá INSERT/UPDATE pro běžné uživatele.

---

### Legal Spain – check-in a SES Hospedajes (2026-09-18)

**Fáze 0 (produkt / právo):** Subjekt povinnosti je **arrendador** (majitel bytu, nebo agentura jako intermediario) registrovaný na sede Interior se zapnutými „comunicaciones vía servicio web“. FalcoNest jen ukládá kódy a WS login u bytu. **PV (hosté)** se posílá vždy; **RH (smlouva)** jen u přímých rezervací (`reservation_source` mimo Booking/Airbnb – OTA posílají RH samy). GDPR: doklady a podpisy **3 roky** (`legal_spain_gdpr_cleanup` weekly cron). SOAP běží jen při aktivním `tenant_modules` (`is_legal_spain_module_active`). Modelo 210 / SanFolio mimo rozsah.

**Tabulky:** `apartment_legal_settings` (kódy establecimiento/arrendador, house_rules, public_web_origin), `ses_ws_credentials` (WS heslo – SELECT hesla jen service_role), `guest_checkins` (token, status draft/queued/accepted/reported/rejected/timeout), `reservation_guests` (osoby + podpis 14+), `ses_communications` (lote, PV/RH, audit XML).

**RPC (anon token):** `get_legal_checkin_bootstrap`, `upsert_legal_checkin_guest`, `submit_legal_checkin_signature`. Autentizované: `ensure_legal_checkin_session`, `enqueue_ses_pv_for_reservation`.

**Edge:** `ses-hospedajes` (cron */15) – SOAP alta → poll lote → in-app notifikace při reject/timeout/SLA 22:00 Madrid.

---

### Registr modulů (modules.key) – reference

- **legal_spain** – Placený check-in + SES Hospedajes (RD 933/2021). `pricing_type = per_apartment`, `show_in_menu = true`, `order_index` 32, **bez** auto-aktivace v `tenant_modules`. Admin tabIndex 12. Migrace `20260918120000_legal_spain_checkin_ses.sql`.
- **map** – Mapový dispečink (OpenStreetMap): záložka v admin [IndexedStack], `order_index` cca 45 (za plánovacím kalendářem). Migrace `20260403030000_add_map_module.sql` registruje modul a aktivuje ho pro všechny existující tenanty v `tenant_modules`.
- **finance** – Hlavní modul Finance a Hotovost (zdarma). Obsahuje Zaměstnaneckou pokladnu. show_in_menu = true.
- **finance_export** – Placený sub-modul Podklady pro fakturaci. parent_module_key = 'finance', show_in_menu = false, price_eur = 29.
- **automatic_tasks** – Feature flag / sub-modul patřící k modulu `tasks`. Odemkne premium funkce na obrazovce Úkoly (Generovat návrhy, Přepočítat personál). Nemá vlastní obrazovku: v tabulce `modules` má `show_in_menu = false` a `parent_module_key = 'tasks'`. V Super Admin Tenant Detail se zobrazuje s lokalizovaným názvem a ikonou díky `ModuleIconMapper` (ikona: auto_awesome, label: admin.menu_automatic_tasks).

---

### 3-úrovňový model dynamických služeb (Override Pattern)

Služby jsou definovány na třech úrovních: **Katalog agentury** → **Ceník/pravidla bytu** → **Služby vybrané k pobytu**. Cena a popis se na každé úrovni mohou **přepsat** (override); pokud není přepis zadaný, použije se hodnota z úrovně nadřazené.

| Úroveň | Tabulka | Cena | Popis / poznámka | Plátce |
|--------|---------|------|------------------|--------|
| 1. Katalog | **tenant_services** | `default_price` – výchozí cena služby v rámci tenanta | `description` – co služba standardně obsahuje | – |
| 2. Byt | **apartment_services** | `custom_price` – přepis ceny pro tento byt (NULL = použít výchozí z katalogu) | `custom_description` – přepis obsahu pro tento byt (NULL = použít z katalogu), `metadata.transit_price` – průtoková částka (např. nájem) | `payer_type` – výchozí plátce: 'owner' (majitel – faktura) nebo 'guest' (host – na místě) |
| 3. Rezervace | **reservation_services** | `charged_price` – skutečně účtovaná cena za tuto službu u této rezervace (NULL = dopočítat z bytu/katalogu) | `custom_note` – **specifická poznámka klienta k této jedné službě** (např. „Potřebujeme dětskou sedačku“ u transferu). | `payer_type` – kdo platí u tohoto pobytu (NULL = použít z apartment_services) |

**Kaskádové přepisování (Override Pattern):**

- **Cena:** Aplikace při zobrazení/účtování bere v pořadí: `reservation_services.charged_price` → pokud NULL, pak `apartment_services.custom_price` → pokud NULL, pak `tenant_services.default_price`.
- **Popis obsahu služby:** Aplikace bere v pořadí: `apartment_services.custom_description` → pokud NULL, pak `tenant_services.description`. Pole `reservation_services.custom_note` je **pouze poznámka klienta** k této konkrétní službě u pobytu, ne přepis oficiálního popisu.
- **Plátce služby (kdo platí):** Na úrovni bytu se nastaví výchozí `apartment_services.payer_type` (majitel vs. host). U konkrétní rezervace lze přepsat v `reservation_services.payer_type`; pokud je NULL, použije se hodnota z bytu.
- **Checklist u služby bytu:** `apartment_services.checklist_template_id` (nullable) – volitelná šablona checklistu navázaná na konkrétní vazbu služba–byt; použije se při generování instance u úkolu, pokud to aplikační logika podporuje.
- **Číslo letu (transfery):** Nativní sloupec `reservation_services.flight_number` – např. FR1495 pro sledování na FlightRadar24. Dříve se ukládalo do `custom_note` s prefixem `[FLIGHT:XXX]`; nyní samostatný sloupec.
- **reservation_services.requires_photo** – volitelný přepis požadavku na fotodokumentaci u této služby u této rezervace.

**Poznámka k rezervacím:** Textové poznámky ke konkrétním službám (co klient chce u transferu, u úklidu atd.) se ukládají výhradně do **reservation_services.custom_note**. Další sloupce tabulky **reservations** mimo služby: **guest_adults**, **guest_children**, **arrival_time**, **departure_time**, **guest_language**, komunikační metadata (**last_communication_***) atd. Sloupce **is_owner_block** a **agency_collects_payment** byly odstraněny (migrace `20260402000000_remove_ai_legacy_flags.sql`) – neodpovídaly B2B modelu operativy.

---

## Storage Buckets

Supabase Storage používá systémovou tabulku `storage.objects`. RLS politiky se vytváří nad touto tabulkou pro jednotlivé buckety.

### Bucket falconest_media

Bucket pro účtenky, fotky škod, podpisy hostů a další média.

**Multi-tenant cesta:** `tenant_id/modul/soubor` (např. `…/receipts/uuid.jpg`).

**P0 (2026-09-13):** bucket je **private** (`public = false`). Klient po uploadu používá **signed URL** (`createSignedUrl`, TTL 10 let).

**Provozní návod:** `docs/ops/STORAGE_MEDIA.md` (regenerace starých public URL, QA checklist).

**RLS (migrace `20260913120000_storage_falconest_media_private_rls.sql`):**
- **INSERT / UPDATE / DELETE** – `authenticated`; první složka cesty = `my_tenant_id()` nebo `is_super_admin()`.
- **SELECT** – stejný tenant scope (žádné veřejné čtení světem).

| Vlastnost | Hodnota |
|-----------|---------|
| **Typ** | **Private** (signed URL) |
| **Účel** | Účtenky, škody, podpisy hostů, fotodokumentace |
| **Struktura cest** | `tenant_id/modul/soubor` |
