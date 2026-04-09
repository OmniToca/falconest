# Audit modulu Super-Admin (FalcoNest HQ) a plán implementace blueprintu

**Datum auditu:** 2026-03-05  
**Stav DB:** Migrace `20260305000000_super_admin_hq_schema.sql` byla úspěšně spuštěna (sloupce `acquired_by`, `managed_by` v `tenants`, tabulky `support_interventions`, `agency_management_settlements`).

---

## 1. Stav složky modulu Super-Admin

**Cesta:** `lib/features/super_admin/`

### 1.1 Obrazovky a modály (hotové a funkční)

| Soubor | Účel |
|--------|------|
| **super_admin_dashboard.dart** | Hlavní nástěnka HQ: mřížka karet agentur (TenantWithStatus), KPI (počet agentur, aktivní klienti, byty, MRR), vyhledávání, řazení (název A–Z, MRR, aktivita, riziko), FAB „Přidat agenturu“, AppBar (Audit log, Billing, Settings, Logout). Klik na kartu → otevře **TenantDetailModal**. Dlouhý klik / kontextová akce → **TenantCommandModal** („Smart Modal“) s tlačítkem „Přihlásit se“. |
| **tenant_detail_screen.dart** | Detail agentury (CRM karta): 3 záložky – **Info & Fakturace** (poznámky, billing_info, cena za byt, měna, sleva), **Moduly & Plán** (přepínače modulů, trial), **Tým & Statistiky** (profily, apartmány). Tlačítko **„Přihlásit se jako klient“** volá `impersonateTenant` a přesměruje na `/admin`. Zobrazení jako modál (`TenantDetailModal.show`) nebo plná stránka. |
| **tenant_command_modal.dart** | Kompaktní modál z dashboardu: MRR, uživatelé, byty, mřížka modulů s okamžitým zapínáním/vypínáním, tlačítko **„Přihlásit se“** (Login as) → `impersonateTenant` + `context.go('/admin')`. |
| **audit_log_screen.dart** | Zobrazení záznamů z tabulky **audit_logs** (globální audit změn v systému): filtr podle tenanta, restore / hard delete záznamů. Otevírá se jako modál z AppBar na dashboardu. |
| **super_admin_billing_modal.dart** | Fakturační přehled (MRR, tenanty). |
| **super_admin_settings_modal.dart** | Nastavení katalogu modulů (CRUD modulů, ceny, order_index). |
| **super_admin/onboarding_wizard_screen.dart** | Import dat z Excelu (apartmány, služby, personál) pro vybraného tenanta. |
| **module_subscription_dialog.dart** | Dialog pro úpravu trial / platnosti modulu u konkrétního tenanta. |

### 1.2 Providery (hotové a funkční)

| Provider | Soubor | Účel |
|----------|--------|------|
| `superAdminSearchQueryProvider` | super_admin_dashboard.dart | Stav vyhledávacího řetězce na nástěnce. |
| `tenantsWithStatusProvider` | all_tenants_provider.dart | Seznam tenantů obohacený o stav (hasAdminProfile, activeUsersCount, pendingInvitationsCount, apartmentCount, latestActivityAt, moduleActiveCount, moduleTotalCount). Závisí na `allTenantsProvider` a dalších dotazech (profiles, invitations, apartments, tenant_modules). |
| `allTenantsProvider` | all_tenants_provider.dart | Načte všechny tenanty: `tenants` select **id, name** (+ v _parseTenant se parsují i další pole, pokud by select byl rozšířen – aktuálně select má jen id, name; zbytek z map bude null). Limit 500, deleted_at IS NULL. |
| `tenantDetailProvider` | tenant_detail_provider.dart | Detail jednoho tenanta: select **id, name, notes, billing_info, price_per_apartment, currency, discount_percentage, stripe_customer_id, trial_ends_at, paid_until**. **Nemá** `acquired_by`, `managed_by`. |
| `tenantProfilesProvider` | tenant_detail_provider.dart | Seznam profilů (id, name, role) pro daného tenanta. |
| `dashboard_mrr_provider` | dashboard_mrr_provider.dart | MRR po tenantech (výpočet z tenant_modules, modulů, cen). |
| `billing_overview_provider` | billing_overview_provider.dart | Přehled fakturace. |
| `auditLogListProvider`, `auditLogTenantFilterProvider`, `auditLogActorNamesProvider` | audit_log_provider.dart | Audit log z tabulky **audit_logs** (jiná než support_interventions). |
| `tenantActiveModuleIdsProvider` | tenant_detail_provider.dart | Množina ID zapnutých modulů pro tenanta. |
| `onboarding_wizard_provider` | onboarding_wizard_provider.dart | Stav kroku a dat importu v průvodci. |

### 1.3 Služby a repozitáře

| Služba / repozitář | Účel |
|--------------------|------|
| **SuperAdminService** | createModule, updateModule, deleteModule, toggleModule, updateTenantModuleTrial. Žádná práce s tenants.acquired_by/managed_by ani support_interventions / agency_management_settlements. |
| **AuditLogRepository** (audit_log_repository.dart, _web, _mobile, _shared) | Načítání z **audit_logs** (fetchLogs, fetchActorNames). Oddělené od **support_interventions**. |
| **OnboardingDbService**, **MasterExcelParser**, **OnboardingExportService** | Import/export dat pro onboarding. |

### 1.4 Auth a převtělení (Magic Login)

- **AuthNotifier.impersonateTenant(tenantId)** – nastaví `_selectedTenantId`, `isImpersonating = true`, načte z `tenants` sloupce `is_active` a `paid_until`, `notifyListeners()`.
- **AuthNotifier.stopImpersonating()** – vymaže `_selectedTenantId`, `isImpersonating = false`.
- **Volání impersonateTenant:**  
  - V **super_admin_dashboard.dart** (akce „Vstoupit“ z karty – např. dlouhý klik nebo menu).  
  - V **tenant_detail_screen.dart** – `_onImpersonate` (tlačítko „Přihlásit se jako klient“).  
  - V **tenant_command_modal.dart** – `_onLoginAs` („Přihlásit se“).  
- Po impersonate: invalidace providerů (adminTasksProvider, adminReservationsProvider, apartmentsProvider, …), `context.go('/admin')`.
- V **admin_layout.dart**: pruh **„Převtělení – [název agentury]“** s tlačítkem **„Zpět do velína“** → `stopImpersonating()` + `context.go('/super-admin')`.

**Důležité:** Při zahájení ani ukončení převtělení se **nezapisuje** nic do tabulky `support_interventions`. Žádný audit „kdo, kdy, u koho, výkaz práce“.

---

## 2. Zhodnocení: jak blueprint zapadá do existujícího kódu

| Bod blueprintu | Stav v kódu | Co je potřeba |
|-----------------|-------------|----------------|
| **1. Přiřazování Lovce a Farmáře** | DB sloupce `tenants.acquired_by` a `tenants.managed_by` existují. V Dartu **neexistují**: modely `TenantRow`, `TenantDetailRow` je nemají, selecty je nečtou, v UI není výběr. | **Rozšířit:** modely a selecty o `acquired_by`, `managed_by`; v detailu tenanta (TenantDetailScreen) přidat sekci „Lovec / Farmář“ a dropdowny (nebo výběr z „HQ personálu“ – profily s role super_admin / account_manager). |
| **2. Přihlásit se jako klient (Magic Login)** | **Plně hotové:** impersonateTenant, stopImpersonating, banner, přesměrování. | **Pouze rozšíření:** doplnit zápis do `support_interventions` (start při impersonate, end + work_report při stop) a případně dialog pro „výkaz práce“ při ukončení. |
| **3. Auditní výkazy práce (support_interventions)** | Tabulka v DB existuje. V aplikaci **žádný** kód: žádný repozitář, žádný provider, žádné volání. | **Zelená louka:** nový repozitář (nebo služba) pro INSERT/UPDATE záznamů, provider pro seznam zásahů, propojení s impersonateTenant/stopImpersonating. |
| **4. Měsíční zúčtování odměn (agency_management_settlements)** | Tabulka v DB existuje. V aplikaci **žádný** kód. | **Zelená louka:** repozitář, providery (seznam vyúčtování podle období/tenanta), nová obrazovka/sekce v HQ pro zadání a schválení provizí (Super-Admin vidí výkazy práce + formulář Lovce/Farmáře). |

**Role account_manager:** V kódu se zatím všude kontroluje pouze `role == 'super_admin'`. RLS v DB už umožňuje Account Managerovi vidět jen své záznamy v `support_interventions` a `agency_management_settlements`. Aby Account Manager v aplikaci „viděl své agentury“ a mohl používat Magic Login, bude potřeba:  
- v seznamu tenantů (dashboard) filtrovat podle `managed_by` / `acquired_by` = aktuální profil (pokud role == account_manager),  
- router a přístup k `/super-admin` povolit i pro `account_manager` (ne jen super_admin).

---

## 3. Co budeme muset upravit vs. stavět na zelené louce

### Upravit (rozšíření stávajícího)

- **all_tenants_provider.dart:** Rozšířit select tenantů (v `tenantsWithStatusProvider` / dotazech, které načítají tenant row) o sloupce `acquired_by`, `managed_by`. Rozšířit model **TenantRow** o `String? acquiredBy`, `String? managedBy` (a volitelně jména z profiles pro zobrazení).
- **tenant_detail_provider.dart:** Do selectu v **tenantDetailProvider** přidat `acquired_by`, `managed_by`. Model **TenantDetailRow** rozšířit o tato pole. Přidat provider pro „HQ personál“ (profily s role in (super_admin, account_manager) a tenant_id IS NULL nebo speciální tenant pro HQ), pokud budou Lovce/Farmáře vybírat ze seznamu interních.
- **tenant_detail_screen.dart:** Na záložce Info (nebo nová podsekce) přidat UI pro přiřazení Lovce a Farmáře (dropdown / výběr osoby). Uložení přes update `tenants` set `acquired_by`, `managed_by`.
- **auth_notifier.dart:** Před `impersonateTenant`: volat službu/repozitář pro **INSERT** do `support_interventions` (profile_id = aktuální profil, tenant_id = vybraný tenant, started_at = now(), ended_at = null). Po uložení pokračovat stávající logikou.  
  Před `stopImpersonating`: zobrazit dialog „Výkaz práce“ (nebo uložit prázdný), pak **UPDATE** posledního otevřeného záznamu v `support_interventions` (ended_at = now(), work_report = text). Alternativa: dialog s výkazem práce může být v admin_layout při kliku na „Zpět do velína“.

### Stavět na zelené louce

- **support_interventions:** Repozitář (např. `SupportInterventionsRepository`) – `insertStart(profileId, tenantId)`, `updateEnd(interventionId, endedAt, workReport)`, `getActiveIntervention(profileId)` (pro ukončení), `fetchInterventions({tenantId?, profileId?, from, to})`. Provider např. `supportInterventionsListProvider`.  
  Propojení: při `impersonateTenant` zavolat insert; při `stopImpersonating` zavolat update (a před tím zobrazit dialog pro work_report, nebo ukládat prázdné).
- **agency_management_settlements:** Repozitář (např. `AgencyManagementSettlementsRepository`) – create, update (schválení, zaplacení), list by period / tenant. Providery: `agencyManagementSettlementsForPeriodProvider(period)`, `agencyManagementSettlementsForTenantProvider(tenantId)`.  
  Nová obrazovka/sekce v HQ: „Zúčtování odměn“ – výběr měsíce, seznam tenantů (nebo výkazy práce), formulář pro zadání částky pro Lovce/Farmáře za daný tenant a měsíc, tlačítko Schválit.
- **Role account_manager:** Rozšířit logiku dashboardu (seznam tenantů) a routeru tak, aby account_manager měl přístup na `/super-admin` a viděl jen tenanty, kde `managed_by` nebo `acquired_by` = jeho profile_id. Volitelně stejné tlačítko Magic Login a stejný zápis do support_interventions.

---

## 4. Navrhovaný postupný plán implementace (ADDITIVE, Riverpod)

### Krok 1: Lovec a Farmář – data a UI v detailu tenanta

- Rozšířit **TenantRow** a **TenantDetailRow** o `acquiredBy`, `managedBy` (uuid).
- Rozšířit selecty v `all_tenants_provider` (tam, kde se načítá tenant pro kartu) a v **tenantDetailProvider** o `acquired_by`, `managed_by`.
- Přidat provider pro „HQ personál“ (seznam profilů pro výběr Lovce/Farmáře): např. profily s `role IN ('super_admin', 'account_manager')` a např. `tenant_id IS NULL` (nebo dle vaší konvence pro interní zaměstnance). Alternativa: vlastní tabulka `hq_staff` – podle toho, jak máte interní týmy vedené.
- V **TenantDetailScreen** (záložka Info nebo nová sekce) přidat dva výběry: „Lovec (kdo získal)“ a „Farmář (kdo se stará)“. Uložení: `SupabaseService.client.from('tenants').update({'acquired_by': id, 'managed_by': id}).eq('id', tenantId)`.
- Žádné mazání stávající logiky; pouze rozšíření modelů a UI.

### Krok 2: support_interventions – repozitář a propojení s Magic Login

- Vytvořit **SupportInterventionsRepository** (nebo soubor v `lib/core/repositories/` / `lib/features/super_admin/services/`):  
  - `Future<String?> startIntervention(String profileId, String tenantId)` – INSERT, vrátí id záznamu.  
  - `Future<void> endIntervention(String interventionId, {String? workReport})` – UPDATE ended_at, work_report.  
  - `Future<String?> getActiveInterventionId(String profileId)` – SELECT kde ended_at IS NULL a profile_id = …, limit 1 (pro ukončení při stopImpersonating).
- Při **impersonateTenant**: po úspěšném nastavení stavu zavolat `startIntervention(currentProfileId, tenantId)`. Id aktivního zásahu uložit do paměti (např. v AuthNotifier do nového pole `_activeInterventionId`, nebo vrátit z impersonateTenant a držet v provideru).
- Při **stopImpersonating**: před vymazáním _selectedTenantId zavolat `endIntervention(activeInterventionId, workReport: …)`. Work report lze načíst z jednoduchého dialogu zobrazeného při kliku na „Zpět do velína“ (v admin_layout): dialog s TextField a tlačítky „Ukončit bez poznámky“ / „Ukončit a uložit poznámku“.

### Krok 3: support_interventions – zobrazení v HQ (volitelně hned)

- Provider `supportInterventionsListProvider` (parametry: tenantId?, profileId?, date range) pro Super-Admina a Account Managera.
- V HQ přidat záložku nebo sekci „Výkazy práce“ (seznam zásahů z `support_interventions`) – filtrovat podle tenanta / období. Pouze čtení; úpravy konce a výkazu už při stopImpersonating (Krok 2).

### Krok 4: agency_management_settlements – repozitář a providery

- Vytvořit **AgencyManagementSettlementsRepository**:  
  - `Future<void> createOrUpdateSettlement(...)` – INSERT nebo UPDATE (profile_id, tenant_id, settlement_period, role_type, amount, status).  
  - `Future<List<...>> getSettlementsForPeriod(DateTime firstDayOfMonth)`.  
  - `Future<List<...>> getSettlementsForTenant(String tenantId, DateTime? period)`.
- Providery: např. `agencyManagementSettlementsForPeriodProvider(DateTime period)`, `agencyManagementSettlementsForTenantProvider(tenantId, period)`.

### Krok 5: agency_management_settlements – obrazovka Zúčtování odměn v HQ

- Nová obrazovka (nebo modál) „Zúčtování odměn“: výběr měsíce (settlement_period), seznam tenantů (nebo kombinace s výkazy práce), pro každého tenanta / každého Lovce a Farmáře možnost zadat částku a uložit (status pending → approved). Pouze Super-Admin může zapisovat (RLS to již vynucuje).
- Zobrazit existující záznamy z `agency_management_settlements` a umožnit editaci částky a schválení.

### Krok 6: Role account_manager (rozšíření přístupu)

- V routeru povolit přístup na `/super-admin` i pro `role == 'account_manager'`.
- V provideru, který vrací seznam tenantů pro dashboard (tenantsWithStatusProvider nebo jeho zdroje), přidat filtr: pokud aktuální role je `account_manager`, vracet jen tenanty kde `managed_by = currentProfileId OR acquired_by = currentProfileId`.
- Ověřit, že Magic Login a zápis do `support_interventions` fungují i pro account_manager (RLS to umožňuje).

---

## 5. Rizika a doporučení

- **ADDITIVE:** Všechny změny jsou rozšíření: nové sloupce v modelech, nové selecty, nové tabulky/služby. Neměnit podpis stávajících providerů tak, aby se rozbily existující obrazovky (např. TenantRow rozšířit o nullable pole).
- **Backend:** RLS na `support_interventions` a `agency_management_settlements` již nastaveno; při vývoji v Dartu používat stejného uživatele (Super-Admin / Account Manager) pro testy.
- **Výkaz práce:** Pokud nechcete blokovat ukončení převtělení dialogem, lze ukládat prázdný výkaz a doplnit ho později v sekci „Výkazy práce“ (UPDATE záznamu) – to by vyžadovalo v Krok 3 i možnost editace work_report.

Tím je audit a plán kompletní; implementaci lze provádět po krocích 1–6 v uvedeném pořadí.
