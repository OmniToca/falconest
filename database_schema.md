# FalcoNest – Oficiální schéma databáze

> **Pravidlo:** Při generování SQL dotazů, RLS politik nebo Dart modelů (.fromJson) vždy nejdříve zkontroluj tento soubor a ověř přesné názvy sloupců a datové typy. Nikdy nehádej názvy sloupců.

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
| apartment_owners | id | uuid | NO |
| apartment_owners | apartment_id | uuid | NO |
| apartment_owners | owner_id | uuid | NO |
| apartment_owners | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
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
| app_super_admins | id | uuid | NO |
| audit_logs | id | uuid | NO |
| audit_logs | tenant_id | uuid | YES |
| audit_logs | user_id | uuid | YES |
| audit_logs | action_type | text | NO |
| audit_logs | table_name | text | YES |
| audit_logs | record_id | text | YES |
| audit_logs | details | jsonb | YES |
| audit_logs | created_at | timestamp with time zone | NO |
| billing_snapshots | id | uuid | NO |
| billing_snapshots | tenant_id | uuid | NO |
| billing_snapshots | client_id | uuid | NO |
| billing_snapshots | billing_period | date | NO |
| billing_snapshots | snapshot_data | jsonb | NO |
| billing_snapshots | locked_at | timestamp with time zone | NO |
| billing_snapshots | locked_by | uuid | NO |
| client_addresses | id | uuid | NO |
| client_addresses | tenant_id | uuid | NO |
| client_addresses | client_id | uuid | NO |
| client_addresses | label | text | NO |
| client_addresses | address | text | NO |
| client_addresses | created_at | timestamp with time zone | YES |
| client_addresses | updated_at | timestamp with time zone | YES |
| client_addresses | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
| clients | id | uuid | NO |
| clients | tenant_id | uuid | NO |
| clients | name | text | NO |
| clients | email | text | YES |
| clients | phone | text | YES |
| clients | client_type | text | YES |
| clients | created_at | timestamp with time zone | YES |
| clients | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
| clients | profile_id | uuid | YES |
| clients | agency_id | uuid | YES |
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
| invitations | tenant_id | uuid | YES – NULL = pozvánka pro HQ (Super-Admin / Account Manager) |
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
| notification_preferences | daily_summary_enabled | boolean | NO |
| notification_preferences | upcoming_task_enabled | boolean | NO |
| notification_preferences | new_task_assigned_enabled | boolean | NO |
| notification_preferences | template_reminders_enabled | boolean | NO |
| notifications | id | uuid | NO |
| notifications | tenant_id | uuid | NO |
| notifications | profile_id | uuid | NO |
| notifications | title | text | NO |
| notifications | message | text | NO |
| notifications | type | text | YES |
| notifications | is_read | boolean | NO |
| notifications | created_at | timestamp with time zone | YES |
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
| reservations | agency_collects_payment | boolean | YES |
| reservations | reference_number | text | YES |
| reservations | external_uid | text | YES |
| staff_absences | id | uuid | NO |
| staff_absences | profile_id | uuid | YES |
| staff_absences | start_date | text | NO |
| staff_absences | end_date | text | NO |
| staff_absences | reason | text | YES |
| staff_absences | invitation_id | uuid | YES |
| staff_absences | tenant_id | uuid | YES |
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
| tasks | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
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
| tasks | reference_number | text | YES |
| tasks | assigned_user_ids | ARRAY | NO |
| tasks | updated_at | timestamp with time zone | YES – Čas poslední změny na serveru (UTC). Pro Timestamp Merging při push pending updates z mobilu – detekce konfliktu a Smart Merge. |
| tenant_message_templates | id | uuid | NO |
| tenant_message_templates | tenant_id | uuid | NO |
| tenant_message_templates | key | text | NO |
| tenant_message_templates | name | text | NO |
| tenant_message_templates | body | text | NO |
| tenant_message_templates | channel | text | YES |
| tenant_message_templates | language_code | text | YES |
| tenant_message_templates | trigger_context | text | YES |
| tenant_message_templates | order_index | integer | NO |
| tenant_message_templates | created_at | timestamp with time zone | YES |
| tenant_message_templates | deleted_at | timestamp with time zone | YES |
| tenant_modules | id | uuid | NO |
| tenant_modules | tenant_id | uuid | YES |
| tenant_modules | module_id | uuid | YES |
| tenant_modules | status | text | YES |
| tenant_modules | valid_until | timestamp with time zone | YES |
| tenant_modules | created_at | timestamp with time zone | YES |
| tenant_modules | is_trial | boolean | NO |
| tenant_modules | trial_ends_at | timestamp with time zone | YES |
| tenant_modules | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
| tenant_modules | stripe_subscription_id | text | YES |
| tenant_modules | stripe_price_id | text | YES |
| tenant_modules | cancel_at_period_end | boolean | NO |
| tenant_services | id | uuid | NO |
| tenant_services | tenant_id | uuid | NO |
| tenant_services | name | text | NO |
| tenant_services | description | text | YES |
| tenant_services | service_type | text | NO |
| tenant_services | default_price | numeric | YES |
| tenant_services | is_active | boolean | NO |
| tenant_services | deleted_at | timestamp with time zone | YES |
| tenant_services | order_index | integer | YES |
| tenant_services | required_role | text | YES |
| tenant_services | duration_minutes | integer | YES |
| tenant_services | requires_photo | boolean | NO |
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
| tenants | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
| tenants | stripe_customer_id | text | YES |
| tenants | billing_email | text | YES |
| tenants | paid_until | timestamp with time zone | YES |
| tenants | acquired_by | uuid | YES |
| tenants | managed_by | uuid | YES |
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
| zones | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |

---

### Indexy pro výkonnostní optimalizaci (škálování)

Pro Realtime streamy a časté filtry na `tenant_id` / `apartment_id` jsou zásadní následující indexy. Bez nich dochází u velkých tenantů (1000+ záznamů) k full table scan.

| Tabulka | Index | Sloupec(y) | Účel |
|---------|-------|------------|------|
| tasks | idx_tasks_tenant_id | tenant_id | Admin Realtime stream – `inFilter('tenant_id', [tenantId])`. Zrychlení výběru úkolů tenanta. |
| reservations | idx_reservations_apartment_id | apartment_id | Admin Realtime stream – `inFilter('apartment_id', apartmentIds)`. Zrychlení výběru rezervací dle bytů tenanta. |
| billing_snapshots | idx_billing_snapshots_tenant_client_period | tenant_id, client_id, billing_period | UNIQUE – jeden snapshot na klienta a měsíc. |
| billing_snapshots | idx_billing_snapshots_tenant_period | tenant_id, billing_period | Admin přehled uzamčených měsíců. |
| task_payouts | idx_task_payouts_tenant_id | tenant_id | RLS a filtrování podle tenanta. |
| task_payouts | idx_task_payouts_task_id | task_id | Výplaty k úkolu. |
| task_payouts | idx_task_payouts_profile_id | profile_id | Výplaty pracovníka. |
| task_commissions | idx_task_commissions_tenant_id | tenant_id | RLS a filtrování podle tenanta. |
| task_commissions | idx_task_commissions_task_id | task_id | Provize k úkolu. |
| task_commissions | idx_task_commissions_client_id | client_id | Provize partnerovi. |

**SQL pro vytvoření (spustit v Supabase SQL Editoru):**

```sql
CREATE INDEX IF NOT EXISTS idx_tasks_tenant_id ON public.tasks(tenant_id);
CREATE INDEX IF NOT EXISTS idx_reservations_apartment_id ON public.reservations(apartment_id);
```

---

### Tabulka tasks – Timestamp Merging (Smart Merge)

Sloupec **tasks.updated_at** (timestamptz, nullable) se na serveru nastavuje triggerem při každém UPDATE. Mobilní aplikace při push pending updates (WorkerSyncService) před odesláním lokální změny stáhne aktuální řádek úkolu včetně `updated_at`. Pokud je `updated_at` ze serveru novější než lokální `last_synced_at`, došlo ke konfliktu (admin mezitím upravil úkol na webu). Aplikace pak aplikuje **Smart Merge**: status zůstává z mobilu (pracovník byl na místě), poznámky se sloučí (append), ostatní pole přebírají hodnoty ze serveru. Bez tohoto mechanismu by platilo „Last-write-wins“ a změny administrátora by mobil přepsal.

---

### Tabulka notifications – Realtime notifikace pro uživatele

Tabulka **notifications** slouží pro zobrazení oznámení v Top Baru (zvoneček). Každá notifikace je určena konkrétnímu uživateli (`profile_id`) a agentuře (`tenant_id`).

**RLS:** Uživatel vidí a může upravovat (např. označit jako přečtené) pouze notifikace, kde `tenant_id` odpovídá jeho agentuře a `profile_id` odpovídá jeho profilu. Super Admin má plný přístup. Tabulka musí být přidána do Supabase Realtime publikace (Dashboard → Database → Replication), aby stream v aplikaci fungoval.

---

### Push Notifikace (FCM) – Fáze 1 – Infrastruktura

**user_devices** – FCM tokeny zařízení pro doručení push notifikací. Každé zařízení (iOS, Android, Web) má unikátní `fcm_token`. Sloupec `last_active_at` slouží pro čištění neaktivních tokenů.

**notification_preferences** – Nastavení preferencí notifikací na uživatele (1:1 s profilem). Povoluje/vypíná: ranní souhrn (`daily_summary_enabled`), upozornění před úkolem (`upcoming_task_enabled`), notifikace při přiřazení nového úkolu (`new_task_assigned_enabled`), šablony připomínek (`template_reminders_enabled`).

**RLS:** Uživatel čte a zapisuje pouze své tokeny a preference (`profile_id` = vlastní profil). Super Admin má plný přístup. Edge Functions a budoucí `firebase_messaging` v aplikaci budou tyto tabulky využívat pro targeting.

**Edge Function `daily-task-summary`:** Cíl pro cron job (např. pg_cron každé ráno v 6:00). Načte úkoly se `status` IN ('assigned','in_progress'), `scheduled_start` dnes, seskupí podle `assigned_to`, zkontroluje `notification_preferences.daily_summary_enabled` a rozešle FCM zprávy na tokeny z `user_devices`. Vyžaduje Supabase secrets: `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON`.

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
- **transaction_type**: `COLLECTED_FROM_GUEST` (výběr od hosta při Check-in/Transfer), `HANDED_TO_AGENCY` (odevzdání agentuře), `COMPANY_EXPENSE` (firemní výdaj z hotovosti).
- **note**, **receipt_image_url** – volitelné u firemních výdajů; poznámka a URL fotky účtenky.
- **amount**: kladné = výběr (zvyšuje balance), záporné = odevzdání (snižuje balance).
- **task_id** – volitelná vazba na úkol (Check-in, Transfer) pro audit.
- **apartment_id** – volitelná vazba na apartmán u firemních výdajů (např. materiál do bytu); pro automatické stržení nákladů ve faktuře majitele.

**RLS:** Oba tabulky mají RLS zapnuté; přístup pouze na řádky, kde tenant_id odpovídá tenant_id přihlášeného uživatele (profiles.auth_id = auth.uid()). Super Admin má plný přístup.

**Registr modulů:**
- **finance** – hlavní modul, zdarma (price_eur = 0), show_in_menu = true.
- **finance_export** – placený sub-modul, parent_module_key = 'finance', show_in_menu = false, price_eur = 29, pricing_type = 'fixed'.

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

**Unikátní index** `(tenant_id, client_id, billing_period)` – jeden snapshot na klienta a měsíc.

**RLS:**
- **SELECT (Admin/Worker):** Zaměstnanci agentury (role != property_owner) vidí snapshoty své agentury. Super Admin vidí vše.
- **SELECT (Owner):** Majitel (property_owner) vidí POUZE snapshoty, kde `client_id IN (SELECT id FROM clients WHERE profile_id = jeho profil)`.
- **INSERT:** Pouze Admin (role = 'admin') nebo Super Admin v rámci svého tenant_id.

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

**Sloupce:** `id`, `tenant_id` (FK → tenants), `name` (povinné), `email`, `phone`, `client_type` (owner/external/agency), `created_at`, `deleted_at`, `profile_id`, `agency_id`.

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
- Jakékoli stržení kreditů probíhá **výhradně přes RPC funkci** `deduct_wallet_credits()`, která používá zámek řádku (`FOR UPDATE`) pro ochranu proti souběhu (více dispečerů generuje úkoly současně).
- Doplňování kreditů (TOP_UP) provádí Super Admin nebo Stripe webhook přes service_role / SECURITY DEFINER funkci.

**RLS:** Role admin a manager smí pouze SELECT vlastní data; super_admin a service_role mají plná práva. Na tenant_wallets není povolena přímá INSERT/UPDATE pro běžné uživatele.

---

### Registr modulů (modules.key) – reference

- **finance** – Hlavní modul Finance a Hotovost (zdarma). Obsahuje Zaměstnaneckou pokladnu. show_in_menu = true.
- **finance_export** – Placený sub-modul Podklady pro fakturaci. parent_module_key = 'finance', show_in_menu = false, price_eur = 29.
- **automatic_tasks** – Feature flag / sub-modul patřící k modulu `tasks`. Odemkne premium funkce na obrazovce Úkoly (Generovat návrhy, Přepočítat personál). Nemá vlastní obrazovku: v tabulce `modules` má `show_in_menu = false` a `parent_module_key = 'tasks'`. V Super Admin Tenant Detail se zobrazuje s lokalizovaným názvem a ikonou díky `ModuleIconMapper` (ikona: auto_awesome, label: admin.menu_automatic_tasks).

---

### 3-úrovňový model dynamických služeb (Override Pattern)

Služby jsou definovány na třech úrovních: **Katalog agentury** → **Ceník/pravidla bytu** → **Služby vybrané k pobytu**. Cena a popis se na každé úrovni mohou **přepsat** (override); pokud není přepis zadaný, použije se hodnota z úrovně nadřazené.

| Úroveň | Tabulka | Cena | Popis / poznámka | Plátce |
|--------|---------|------|------------------|--------|
| 1. Katalog | **tenant_services** | `default_price` – výchozí cena služby v rámci tenanta | `description` – co služba standardně obsahuje | – |
| 2. Byt | **apartment_services** | `custom_price` – přepis ceny pro tento byt (NULL = použít výchozí z katalogu) | `custom_description` – přepis obsahu pro tento byt (NULL = použít z katalogu) | `payer_type` – výchozí plátce: 'owner' (majitel – faktura) nebo 'guest' (host – na místě) |
| 3. Rezervace | **reservation_services** | `charged_price` – skutečně účtovaná cena za tuto službu u této rezervace (NULL = dopočítat z bytu/katalogu) | `custom_note` – **specifická poznámka klienta k této jedné službě** (např. „Potřebujeme dětskou sedačku“ u transferu). | `payer_type` – kdo platí u tohoto pobytu (NULL = použít z apartment_services) |

**Kaskádové přepisování (Override Pattern):**

- **Cena:** Aplikace při zobrazení/účtování bere v pořadí: `reservation_services.charged_price` → pokud NULL, pak `apartment_services.custom_price` → pokud NULL, pak `tenant_services.default_price`.
- **Popis obsahu služby:** Aplikace bere v pořadí: `apartment_services.custom_description` → pokud NULL, pak `tenant_services.description`. Pole `reservation_services.custom_note` je **pouze poznámka klienta** k této konkrétní službě u pobytu, ne přepis oficiálního popisu.
- **Plátce služby (kdo platí):** Na úrovni bytu se nastaví výchozí `apartment_services.payer_type` (majitel vs. host). U konkrétní rezervace lze přepsat v `reservation_services.payer_type`; pokud je NULL, použije se hodnota z bytu.
- **Číslo letu (transfery):** Nativní sloupec `reservation_services.flight_number` – např. FR1495 pro sledování na FlightRadar24. Dříve se ukládalo do `custom_note` s prefixem `[FLIGHT:XXX]`; nyní samostatný sloupec.
- **reservation_services.requires_photo** – volitelný přepis požadavku na fotodokumentaci u této služby u této rezervace.

**Poznámka k rezervacím:** Textové poznámky ke konkrétním službám (co klient chce u transferu, u úklidu atd.) se ukládají výhradně do **reservation_services.custom_note**. Do tabulky **reservations** se nepřidávají žádná další textová pole pro služby; rozšíření rezervace jsou sloupce **guest_adults**, **guest_children** (počty hostů) a **arrival_time** (předpokládaný čas příjezdu).

---

## Storage Buckets

Supabase Storage používá systémovou tabulku `storage.objects`. RLS politiky se vytváří nad touto tabulkou pro jednotlivé buckety.

### Bucket falconest_media

| Vlastnost | Hodnota |
|-----------|---------|
| **Typ** | Public |
| **Účel** | Ukládání fotek z aplikace – účtenky k firemním výdajům, budoucí hlášení škod |
| **Struktura cest** | `tenant_id/modul/soubor.jpg` (např. `uuid/expenses/uuid.jpg`) |

**RLS politiky (storage.objects):**

- **INSERT** – povolen pouze pro `authenticated` uživatele; podmínka `bucket_id = 'falconest_media'`. Pouze přihlášení pracovníci či dispečeři mohou nahrávat soubory.
- **SELECT** – povoleno pro čtení s podmínkou `bucket_id = 'falconest_media'`. Public bucket umožňuje přímé URL (`getPublicUrl`), politika SELECT pokrývá dotazy přes Storage API.
