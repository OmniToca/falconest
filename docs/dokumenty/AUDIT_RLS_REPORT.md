# Audit RLS + safeFrom – diagnostický report (read-only)

**Datum auditu:** 2026-03-28  
**Rozsah:** složka `supabase/migrations/`, celá `lib/`, zaměření na multi-tenant izolaci a konzistenci s `SupabaseService.safeFrom` / `safeInsertPayload`.  
**Metoda:** statická analýza repozitáře (bez úprav kódu, bez přístupu k produkční Supabase instanci).  
**Důležité upozornění:** Skutečný stav RLS v nasazené databázi může obsahovat změny provedené mimo tento git repozitář (SQL Editor, starší migrace). Tento report proto doplňte o **`SELECT relname, relrowsecurity FROM pg_class`** / Supabase Security Advisor.

---

## 1. Executive summary

| Oblast | Závěr (stručně) |
|--------|------------------|
| **SQL migrace** | U většiny tabulek s `tenant_id` v `realna_db.csv` existuje v migračních souborech **`ALTER TABLE … ENABLE ROW LEVEL SECURITY`** a následné politiky. **Kritická mezera v repozitáři:** u tabulky **`notifications`** nebyl nalezen žádný příkaz `ENABLE ROW LEVEL SECURITY` ani `CREATE POLICY` – tabulka se v migracích objevuje jen v triggeru (`INSERT`). U **`apartment_owners`** existují `CREATE POLICY`, ale **explicitní `ENABLE ROW LEVEL SECURITY` v migračních souborech nenalezeno** – vyžaduje ověření v DB (RLS může být zapnuto mimo commitnuté migrace). |
| **Dart – Frontend Firewall** | **`safeFrom`** se používá konzistentně v řadě admin a worker sync cest (viz např. `admin_tasks_provider`, `worker_sync_service_mobile` pro úkoly/apartmány/rezervace/klienty/checklisty). Současně existuje **velký počet přímých volání** `…from('tabulka')` přes `SupabaseService.client` nebo lokální `client` – většina spoléhá na **RLS + ruční `tenant_id` / `.eq('id', tenantId)`**, což je **slabší než jednotný `safeFrom`** (riziko při budoucí úpravě dotazu bez `eq`). |
| **Worker sync → Drift** | Hlavní pull úkolů a souvisejících entit používá **`SupabaseService.safeFrom(..., tenantId)`**. Výjimky: čtení **`tenants`** (řádek podle `id == tenantId`) a **`tenant_message_templates`** přes `client.from(...).eq('tenant_id', tenantId)` – izolace závisí na RLS a správném `tenantId` ze session. |

**Orientační počty (lib):** přímé volání vzoru `.from('…')` se vyskytuje v **cca 69 souborech** `.dart` (počet unikátních cest se může mírně lišit podle vzoru grep). To **není** totéž co „69 bezpečnostních děr“ – jde o místa k **systematickému přezkumu** a sjednocení.

---

## 2. Audit SQL migrací (backend)

### 2.1 Tabulky s `tenant_id` (zdroj: `realna_db.csv`)

Následující tabulky mají sloupec `tenant_id` ve fyzickém exportu:

`agency_management_settlements`, `apartment_ical_sources`, `apartment_services`, `apartments`, `audit_logs`, `automation_message_queue`, `automation_rules`, `billing_shortfall_transfers`, `billing_snapshots`, `checklist_template_items`, `checklist_templates`, `client_addresses`, `clients`, `employee_cash_transactions`, `employee_cash_wallets`, `invitations`, `invoices`, `notification_preferences`, **`notifications`**, `payout_snapshots`, `profiles`, `reservation_services`, `reservations`, `staff_absences`, `support_interventions`, `task_checklist_items`, `task_checklists`, `task_commissions`, `task_payouts`, `tasks`, `tenant_calendar_feed_tokens`, `tenant_message_log`, `tenant_message_templates`, `tenant_modules`, `tenant_services`, `tenant_usage_monthly`, `tenant_wallets`, `user_devices`, `wallet_transactions`, `zones`.

### 2.2 Tabulky s podezřelým / chybějícím RLS v repozitáři

| Tabulka | Nález v `supabase/migrations/` | Riziko / poznámka |
|---------|--------------------------------|-------------------|
| **`notifications`** | Trigger `20260313100000_owner_issue_notification_trigger.sql` provádí `INSERT INTO public.notifications`, ale **v repozitáři chybí** `ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY` a **chybí definice politik** v migračních souborech. | **Vysoké:** pokud RLS na `notifications` v produkci není zapnuto, klient s oprávněním číst tabulku může vidět notifikace jiných tenantů. **Povinné ověření v produkci.** |
| **`apartment_owners`** | Existují politiky (`apartment_owners_admin_manager_all`, `apartment_owners_property_owner_select_own`, …), ale **`ALTER TABLE public.apartment_owners ENABLE ROW LEVEL SECURITY`** **nebyl nalezen** grep v migračních souborech. | **Střední:** bez zapnutého RLS politiky neplatí. Ověřit `relrowsecurity` v DB. |
| Ostatní tabulky z výčtu §2.1 | U většiny nalezeno `ENABLE ROW LEVEL SECURITY` v konkrétních migračních souborech (např. `tasks`, `reservations`, `clients`, `employee_cash_*`, automatizace, checklisty, …). | Průběžně kontrolovat **konzistenci politik** (např. worker SELECT, owner SELECT) při nových migracích. |

### 2.3 Tabulky bez `tenant_id` (globální / speciální)

- **`platform_messaging_rates`** – v CSV **nemá** `tenant_id`; v migraci `20260326120000_platform_messaging_rates.sql` je RLS zapnuto (typicky pro super admin / čtení katalogu).  
- **`modules`**, **`task_categories`**, **`currencies`** – globální nebo sdílený katalog; RLS v migracích řeší jiný model než „jeden tenant_id na řádek“.

### 2.4 Doporučení (backend, mimo tento report)

1. V Supabase spustit **Security Advisor** a exportovat seznam tabulek bez RLS.  
2. Pro **`notifications`** přidat migraci: `ENABLE ROW LEVEL SECURITY` + politiky SELECT/INSERT/UPDATE podle `tenant_id` + `profile_id` (a super admin).  
3. Pro **`apartment_owners`** explicitně potvrdit nebo doplnit `ENABLE ROW LEVEL SECURITY` v migraci, pokud v DB chybí.

---

## 3. Audit Dart kódu (Frontend Firewall)

### 3.1 Definice „přímého přístupu“

Za **nepoužití** wrapperu `SupabaseService.safeFrom(table, tenantId)` se v tomto reportu považuje:

- `SupabaseService.client.from('…')`
- `final client = SupabaseService.client;` následované `client.from('…')`
- případně řetězení začínající `.from('…')` na klientovi z balíčku `supabase_flutter`

**Výjimka (implementace wrapperu):** soubor `lib/core/services/supabase_service.dart` – vnitřní použití `SupabaseService.client.from(_table)` u třídy `SafeTenantTable` je **záměrné** (obal samotný).

### 3.2 Kategorie výskytů (ne všechny jsou chyba)

| Kategorie | Popis | Příklady souborů |
|-----------|--------|-------------------|
| **A – Záměrně super admin / onboarding** | Operace nad celou platformou nebo bez jednoho `tenantId` z profilu. | `super_admin_service.dart`, `all_tenants_provider.dart`, `onboarding_db_service.dart`, `onboarding_export_service.dart`, `tenant_detail_provider.dart`, `super_admin_dashboard.dart` |
| **B – Ruční `tenant_id` v payloadu / `.eq`** | Riziko nižší, pokud RLS funguje; odchylka od standardu `safeFrom`. | `settlement_repository.dart` (insert obsahuje `tenant_id`; select jen `task_id` – závislost na RLS), `cash_wallet_repository.dart`, `billing_action_service.dart`, `premium_upsell_dialog.dart` |
| **C – Owner / veřejné flow** | Dotazy pod rolí majitele nebo při registraci; musí odpovídat RLS pro `property_owner`. | `owner_*_provider.dart`, `owner_reservations_screen.dart`, `owner_report_issue_dialog.dart`, `onboarding_screen.dart`, `set_password_screen.dart` |
| **D – Worker sync výjimky** | Částečně mimo `safeFrom`, filtr `eq('tenant_id', tenantId)`. | `worker_sync_service_mobile.dart` (`tenants`, `tenant_message_templates`) |
| **E – Edge / dynamické tabulky** | `drift_mutation_queue_service.dart` (`m.tableName`), `audit_log_shared.dart` (`tableName`) – vyžaduje audit whitelistu tabulek. | viz níže |

### 3.3 Seznam souborů s přímým `.from('…')` (k přezkoumání)

Následující soubory obsahují literální `.from('` (kromě dokumentačních komentářů v některých případech – ověřit při opravách):

`lib/core/audit/enterprise_audit_payload.dart`  
`lib/core/auth/auth_notifier.dart`  
`lib/core/auth/invite_repository.dart`  
`lib/core/offline/offline_photo_task_processor.dart`  
`lib/core/providers/platform_messaging_rates_provider.dart`  
`lib/core/providers/tenant_currency_provider.dart`  
`lib/core/repositories/cash/cash_wallet_repository.dart`  
`lib/core/repositories/notification/notification_repository.dart`  
`lib/core/repositories/settlements/settlement_repository.dart`  
`lib/core/repositories/user_device/user_device_repository.dart`  
`lib/core/services/absence_notification_service.dart`  
`lib/core/services/audit_log_service.dart`  
`lib/core/services/billing_action_service.dart`  
`lib/core/services/currency_service.dart`  
`lib/core/utils/supabase_stream_helper.dart` *(pouze komentář – ověřit)*  
`lib/features/admin/admin_apartments_screen.dart`  
`lib/features/admin/admin_reservation_forms.dart`  
`lib/features/admin/admin_team_member_tabs.dart`  
`lib/features/admin/premium_upsell_dialog.dart`  
`lib/features/admin/providers/admin_reservations_repository.dart`  
`lib/features/admin/providers/apartment_owners_provider.dart`  
`lib/features/admin/providers/clients_provider.dart`  
`lib/features/admin/providers/current_tenant_name_provider.dart`  
`lib/features/admin/providers/finance_billing_provider.dart`  
`lib/features/admin/providers/module_provider.dart`  
`lib/features/admin/providers/reports_provider.dart`  
`lib/features/admin/providers/task_categories_provider.dart`  
`lib/features/admin/repositories/checklist_template_repository.dart`  
`lib/features/admin/services/automations_seeder_service.dart`  
`lib/features/admin/services/ical_sync_service.dart`  
`lib/features/auth/set_password_screen.dart`  
`lib/features/calendar/providers/planning_calendar_provider.dart`  
`lib/features/communication/repositories/message_templates_repository.dart`  
`lib/features/communication/services/whatsapp_sender_service.dart`  
`lib/features/owner/owner_reservations_screen.dart`  
`lib/features/owner/providers/owner_apartment_detail_provider.dart`  
`lib/features/owner/providers/owner_apartments_provider.dart`  
`lib/features/owner/providers/owner_apartment_services_provider.dart`  
`lib/features/owner/providers/owner_billing_provider.dart`  
`lib/features/owner/providers/owner_planning_calendar_provider.dart`  
`lib/features/owner/providers/owner_reservations_provider.dart`  
`lib/features/owner/providers/owner_tasks_provider.dart`  
`lib/features/owner/widgets/owner_report_issue_dialog.dart`  
`lib/features/public/onboarding_screen.dart`  
`lib/features/settings/client_billing_tab.dart`  
`lib/features/settings/providers/profile_provider.dart`  
`lib/features/settings/providers/tenant_integration_settings_provider.dart`  
`lib/features/settings/providers/tenant_services_provider.dart`  
`lib/features/super_admin/screens/add_hq_absence_dialog.dart`  
`lib/features/super_admin/screens/add_hq_member_dialog.dart`  
`lib/features/super_admin/services/agency_management_settlements_repository.dart`  
`lib/features/super_admin/services/audit_log_repository_mobile.dart`  
`lib/features/super_admin/services/audit_log_repository_web.dart`  
`lib/features/super_admin/services/audit_log_shared.dart`  
`lib/features/super_admin/services/hq_staff_contract_repository.dart`  
`lib/features/super_admin/services/onboarding_db_service.dart`  
`lib/features/super_admin/services/onboarding_export_service.dart`  
`lib/features/super_admin/services/support_interventions_repository.dart`  
`lib/features/super_admin/services/super_admin_service.dart`  
`lib/features/super_admin/super_admin_dashboard.dart`  
`lib/features/super_admin/tenant_command_modal.dart`  
`lib/features/super_admin/tenant_detail_screen.dart`  
`lib/features/super_admin/providers/all_tenants_provider.dart`  
`lib/features/super_admin/providers/billing_overview_provider.dart`  
`lib/features/super_admin/providers/dashboard_mrr_provider.dart`  
`lib/features/super_admin/providers/hq_staff_provider.dart`  
`lib/features/super_admin/providers/hq_team_providers.dart`  
`lib/features/super_admin/providers/tenant_detail_provider.dart`  
`lib/features/worker/data/services/worker_sync_service_mobile.dart`  
`lib/core/offline/drift_mutation_queue_service.dart` *(dynamická tabulka)*  
`lib/core/services/supabase_service.dart` *(implementace SafeTenantTable)*  

**Konkrétní řádky:** kvůli velikosti repozitáře doporučujeme lokálně spustit:

```bash
rg "\.from\(['\`\"]" lib --glob "*.dart" -n
```

a při úklidu filtrovat `lib/core/services/supabase_service.dart` (vnitřek `SafeTenantTable`) a čistě komentářové řádky.

### 3.4 Vybrané konkrétní výskyty (`SupabaseService.client.from`) – řádky v době auditu

| Soubor | Řádek (cca) | Tabulka / poznámka |
|--------|-------------|-------------------|
| `audit_log_service.dart` | 19 | `audit_logs` insert |
| `super_admin_dashboard.dart` | 328, 358, 1482 | `tenant_modules`, `invitations` |
| `support_interventions_repository.dart` | 74 | `support_interventions` update |
| `super_admin_service.dart` | 32 | `modules` insert |
| `drift_mutation_queue_service.dart` | 73 | dynamický `m.tableName` |
| `add_hq_absence_dialog.dart` | 68 | `staff_absences` |
| `premium_upsell_dialog.dart` | 121, 222 | `tenant_modules` |
| `audit_log_shared.dart` | 86, 90 | dynamický `tableName` |
| `agency_management_settlements_repository.dart` | 105 | upsert |
| `billing_action_service.dart` | 112 | `billing_snapshots` |
| `user_device_repository.dart` | 51 | `user_devices` |
| `currency_service.dart` | 150 | `currencies` insert |
| `tenant_services_provider.dart` | 37, 58 | `tenant_services` |
| `add_hq_member_dialog.dart` | 82 | `invitations` |
| `tenant_command_modal.dart` | 388, 1159 | `invitations`, `tenants` |
| `admin_apartments_screen.dart` | 997 | `apartment_owners` insert |
| `apartment_owners_provider.dart` | 261 | `apartment_owners` insert |
| `whatsapp_sender_service.dart` | 154, 166 | `reservations`, `tasks` update |
| `checklist_template_repository.dart` | 123 | `task_checklist_items` insert |

*(Další desítky výskytů používají lokální proměnnou `client` – stejný význam jako výše; kompletní výpis viz příkaz `rg`.)*

---

## 4. Worker synchronizace a Drift (offline-first)

### 4.1 Co je v pořádku

- **`syncTasksFromSupabase`:** dotazy na `tasks`, `apartments`, `reservations`, `clients` přes **`SupabaseService.safeFrom(..., tenantId)`** s filtrem přiřazení workera a časovým oknem.  
- **Checklisty:** `_syncTaskChecklistsFromSupabase` používá **`safeFrom('task_checklists', tenantId)`** (včetně vnořeného selectu položek).

### 4.2 Výjimky (ne = únik, ale konzistence)

| Místo | Volání | Poznámka |
|-------|--------|----------|
| `_syncTenant` | `SupabaseService.client.from('tenants').select(...).eq('id', tenantId)` | Jeden řádek pod PK = `tenantId`; **doporučeno** sjednotit na `safeFrom('tenants', tenantId)` kvůli jednotnému stylu. |
| `_syncMessageTemplates` | `client.from('tenant_message_templates').eq('tenant_id', tenantId)` | Explicitní filtr; **ideálně** přejít na `safeFrom` pro stejnou „Firewall“ logiku jako jinde. |

### 4.3 Závěr offline vrstvy

Data táhnutá do Driftu jsou u hlavních entit **vázaná na `tenantId`** z autentizovaného kontextu. **Zbývající riziko** je spíše **lidské** (předání špatného `tenantId`) než chybějící filtr u těchto dotazů. Důrazně doporučujeme **dokončit RLS na serveru** (`notifications`, ověření `apartment_owners`), protože klient nikdy nesmí být jediná obrana.

---

## 5. Shrnutí počtů a závěr pro rozhodnutí

| Metrika | Hodnota |
|---------|---------|
| **Podezřelé / chybějící RLS v migracích (repozitář)** | **1 jistá mezera:** `notifications`. **1 k ověření:** `apartment_owners` (ENABLE). |
| **Dart soubory s `.from('…')`** | **~69** – většina vyžaduje **klasifikaci** (super admin vs. tenant-scoped), ne okamžitou opravu. |
| **Worker → Drift** | Hlavní tok **OK** (`safeFrom`); 2 pomocné metody používají `client.from` + `eq`. |

**Doporučený další krok (Fáze 1 roadmapy):**  
1) Ověřit a **opravit RLS pro `notifications`** (migrace + test).  
2) Ověřit **`apartment_owners.relrowsecurity`**.  
3) Postupně **migrovat nejrizikovější tenant dotazy** z `client.from` na `safeFrom` (priorita: finance, settlements, cash, notifikace, owner-facing selecty).

---

*Konec diagnostického reportu – žádné změny v kódu ani SQL v rámci tohoto dokumentu.*
