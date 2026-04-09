# Super-Admin modul – finální verifikační audit

**Datum:** 2026-03-05  
**Cíl:** Ověření, že opravy P0–P3 nic nerozbily a že je kód připraven na produkci.  
**Rozsah:** `lib/features/super_admin/`, `app_router.dart`, `auth_notifier.dart`, providery, RLS migrace.

---

## VERIFIKACE OPRAV (P0–P3)

### P0: RLS pro Account Managery

- **Migrace `20260306000000_fix_tenants_rls_for_account_managers.sql`**
  - Syntaxe je v pořádku: `DROP POLICY` + `CREATE POLICY` s podmínkou `is_super_admin() OR id = my_tenant_id() OR (role = 'account_manager' AND (acquired_by = current_profile_id OR managed_by = current_profile_id))`.
  - Subdotazy používají `auth.uid()` a `(SELECT id FROM profiles WHERE auth_id = auth.uid() LIMIT 1)` – žádná konkatenace vstupu, bezpečné.
  - ADDITIVE: přístup super_admin a běžných uživatelů se nemění.
  - **Verdikt:** Prošlo na 100 %.

---

### P1: Route Guard pro Account Managera

- **`app_router.dart` – blok P1 (řádky cca 378–398)**
  - Guard běží pouze když `isLoggedIn && role == 'account_manager' && location.startsWith('/super-admin/tenant/')`.
  - `tenantId` se bere z regexu; pokud je prázdný, guard se neprovede (není null reference na `match?.group(1)`).
  - `ref.read(tenantsWithStatusProvider.future)` se **awaituje** – redirect počká na dokončení provideru. Žádné použití `.value` ani předčasný přístup k nedokončenému stavu.
  - Při výjimce (síť, chyba provideru) se vrací `'/super-admin?access_denied=tenant'` – bezpečné chování.
  - **Možné chování:** Při prvním otevření URL `/super-admin/tenant/xxx` (např. záložka) může redirect trvat déle, dokud se nenačte `tenantsWithStatusProvider`. Není to chyba, jen latence před rozhodnutím.
  - **Verdikt:** Prošlo na 100 %.

---

### P2: autoDispose u providerů

- **`tenantDetailProvider`** (`tenant_detail_provider.dart`)
  - Definice: `FutureProvider.autoDispose.family<TenantDetailRow?, String>` – správně.
  - Komentář k P2 auditu je přítomný.
  - **Verdikt:** Prošlo na 100 %.

- **`monthlyAgencySettlementsProvider`** (`agency_settlements_provider.dart`)
  - Definice: `FutureProvider.autoDispose.family<List<TenantSettlementCard>, DateTime>` – správně.
  - Komentář k P2 auditu je přítomný.
  - **Verdikt:** Prošlo na 100 %.

---

### P2: Validátor částky (provize)

- **`agency_settlements_screen.dart` – `_RoleRow`**
  - Pole částky je `TextFormField` s `validator`: prázdný vstup → chybová hláška; neplatné číslo nebo záporné → stejná hláška (`super_admin.settlements_amount_invalid`).
  - Tlačítko „Schválit“ volá `formKey.currentState?.validate() ?? true` a teprve při úspěchu `onApprove()`. Při platném čísle ≥ 0 validátor vrátí `null`, `validate()` vrátí `true`, schválení se provede.
  - V `_approve()` zůstává záloha kontrola `num.tryParse` + SnackBar – dvojitá ochrana.
  - **Verdikt:** Validátor neblokuje platný vstup; P3 prošlo na 100 %.

---

### P2: Logování chyb u Magic Loginu

- **`auth_notifier.dart`**
  - V `impersonateTenant`: v `catch` po `startIntervention` je `debugPrint('Chyba při zápisu auditu převtělení (startIntervention): $e');` a `debugPrint('Stack: $st');`.
  - V `stopImpersonating`: v `catch` po `endIntervention` je stejný vzor s `endIntervention` v závorce.
  - **Verdikt:** Prošlo na 100 %.

---

## NOVÁ ZJIŠTĚNÍ (drobnosti a doporučení)

### 1. Možný overflow u názvu agentury v kartě Zúčtování

- **Kde:** `agency_settlements_screen.dart` – `_SettlementCard`, `Text(widget.card.tenantName, ...)` (řádky cca 275–281).
- **Stav:** Text nemá `maxLines` ani `overflow`. V layoutu s `Column(crossAxisAlignment: CrossAxisAlignment.stretch)` může při velmi dlouhém názvu (nebo dlouhém slově bez mezer) teoreticky dojít k overflow.
- **Doporučení:** Přidat např. `maxLines: 1` a `overflow: TextOverflow.ellipsis` pro konzistenci s Nástěnkou a detail tenanta. Nízká priorita.

---

### 2. State management – invalidace při změně Lovce/Farmáře

- **Kde:** `tenant_detail_screen.dart` – po změně trial_ends_at, paid_until nebo Lovce/Farmáře se volá `ref.invalidate(tenantsWithStatusProvider)` (a `tenantDetailProvider(tenantId)`).
- **Stav:** Nástěnka sleduje `tenantsWithStatusProvider`, takže se po uložení v detailu znovu načte seznam agentur. Jde o záměrné obnovení dat po změně, ne zbytečný over-fetch.
- **Závěr:** Žádná závada; chování je v pořádku.

---

### 3. Async stavy (.when) u providerů

- **Kontrolované obrazovky/modály:**
  - **Super Admin Nástěnka:** `tenantsAsync.when(data, loading, error)` – OK.
  - **Zúčtování odměn:** `cardsAsync.when(data, loading, error)` včetně prázdného stavu a retry – OK.
  - **Výkazy práce:** `listAsync.when(data, loading, error)` včetně prázdného stavu a retry – OK.
  - **Audit log:** `logsAsync.when(data, loading, error)` včetně prázdného stavu a retry – OK.
  - **Billing modal:** `overviewAsync.when` (loading, error, data) včetně prázdného stavu (`super_admin.billing_empty`) – OK.
  - **Tenant command modal / detail:** `detailAsync.when`, `modulesAsync.when` atd. – loading i error jsou ošetřeny.
- **Závěr:** U asynchronních providerů v Super-Admin modulu jsou stavy data/loading/error konzistentně ošetřeny.

---

### 4. Empty stavy a lokalizace

- **Výkazy práce:** prázdný stav přes `super_admin.work_reports_empty`.tr() – OK.
- **Zúčtování odměn:** prázdný stav přes `super_admin.settlements_empty`.tr() – OK.
- **Audit log:** prázdný stav přes `super_admin.audit_log_empty`.tr() – OK.
- **Billing:** prázdný stav přes `super_admin.billing_empty`.tr() – OK.
- **Závěr:** Nové obrazovky/modály mají empty stavy s lokalizovaným textem.

---

### 5. Overflow u výkazů práce a jinde

- **Work reports:** `_WorkReportRow` používá `Expanded` a u textů (kdo, datum/délka/agentura, poznámka) jsou `maxLines` (1 resp. 2) a `overflow: TextOverflow.ellipsis` – OK.
- **Nástěnka (karta agentury):** název tenanta je v `Expanded` + `Text(..., maxLines: 1, overflow: TextOverflow.ellipsis)` – OK.
- **Detail tenanta (modal header):** název v `Expanded` + `Text(..., overflow: TextOverflow.ellipsis)` – OK.
- **Billing modal:** `row.tenantName` s `overflow: TextOverflow.ellipsis` – OK.
- **Jediné místo bez ochrany:** název agentury v kartě Zúčtování (viz bod 1).

---

### 6. Edge case: formKey.currentState je null

- **Kde:** `agency_settlements_screen.dart` – `if (formKey.currentState?.validate() ?? true) onApprove();`
- **Stav:** Pokud by `formKey.currentState` byl null (např. Form ještě není namountovaný), výraz by vrátil `true` a `onApprove()` by se zavolal. V běžném flow je Form v stromu při tapu na tlačítko.
- **Závěr:** V praxi nepravděpodobné; navíc `_approve()` dále kontroluje `num.tryParse` a záporné hodnoty. Není nutná okamžitá úprava.

---

## Shrnutí

| Oblast | Stav |
|--------|------|
| P0 RLS migrace | Prošlo |
| P1 Route Guard | Prošlo (včetně await na provider, catch, null-safe přístup) |
| P2 autoDispose (oba providery) | Prošlo |
| P2/P3 Validátor částky | Prošlo (neblokuje platný vstup) |
| P2 Logování Magic Login | Prošlo |
| .when(data/loading/error) | Všechny relevantní providery ošetřeny |
| Empty stavy + i18n | Ošetřeny a lokalizované |
| Overflow v UI | Jediné doporučení: název agentury v kartě Zúčtování (maxLines + ellipsis) |

**Závěr:** Předchozí opravy P0–P3 jsou implementované správně a nic zásadního nerozbily. Kód je z hlediska auditu připraven na produkci. Jediné doporučení je drobná úprava zobrazení dlouhého názvu agentury v kartě Zúčtování (overflow), a to jako nízkoprioritní vylepšení UX.
