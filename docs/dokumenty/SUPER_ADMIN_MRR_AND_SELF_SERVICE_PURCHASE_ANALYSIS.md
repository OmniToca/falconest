# Analýza: Super Admin MRR přehled a samoobslužný nákup modulu („Koupit plnou verzi“)

**Záměr:** Po vypršení trialu nabídnout v dialogu tlačítko „Koupit plnou verzi“. Po potvrzení modul okamžitě odemknout a automaticky ho započítat do Super Admin přehledu „Fakturace – manuální přehled“ (MRR).

**Scope:** Pouze analýza. Žádný kód.

---

## 1. Výpočet MRR a položek faktury

### Který provider to řídí

- **Obrazovka „Fakturace – manuální přehled“:**  
  `lib/features/super_admin/super_admin_billing_modal.dart`  
  Používá provider **`billingOverviewProvider`** z `lib/features/super_admin/providers/billing_overview_provider.dart`.

- **Celkové MRR na dashboardu (KPI, řazení agentur):**  
  **`dashboardMrrProvider`** z `lib/features/super_admin/providers/dashboard_mrr_provider.dart`.  
  Matematika je sjednocená s `billing_overview_provider` – stejná pravidla platnosti modulu a stejné započítání ceny.

### Jak přesně se počítá cena za moduly

- **Zdroj dat:**  
  Oba providery načtou z **`tenant_modules`** pro každého tenanta:
  - **dashboard_mrr_provider:** `_loadTenantModuleTrial()` → `tenant_id`, `module_id`, `is_trial`, `valid_until`, `trial_ends_at`
  - **billing_overview_provider:** `_loadTenantModuleBillingInfo()` → navíc `cancel_at_period_end` (jen pro štítek „Končí“)

- **Filtr „aktivní modul“:**  
  Řádek se bere v úvahu pouze pokud:
  - `deleted_at IS NULL`
  - **valid_until** je `NULL` nebo v budoucnosti
  - **trial_ends_at** je `NULL` nebo v budoucnosti  

  (Pomocné funkce `_isModuleValidForMrr` / `_isModuleValid`.)

- **Cena modulu:**
  - Pokud **is_trial == true** → cena modulu = **0** (nezapočítá se do MRR, v tabulce se zobrazí se štítkem TRIAL).
  - Pokud **is_trial == false** → cena se započítá podle `modules.price_eur` a `pricing_type` (fixed / per_apartment / per_user).

- **Sloupec `status`** v `tenant_modules` se v těchto providerech **nečte**. Rozhodující jsou pouze `deleted_at`, `valid_until`, `trial_ends_at` a **`is_trial`**.

### Shrnutí: Jaká data musí být v `tenant_modules`, aby se modul zobrazil a započítal do ceny

| Podmínka | Důvod |
|----------|--------|
| `deleted_at IS NULL` | Soft-delete; jinak se řádek ignoruje. |
| `valid_until` NULL nebo v budoucnosti | Jinak modul není „platný“ a nefiguruje v přehledu. |
| `trial_ends_at` NULL nebo v budoucnosti | Stejně – vypršený trial → modul se do výpočtu nebere. |
| **`is_trial == false`** | Jedině tak se cena modulu započítá do MRR a do sloupce „K úhradě“. |

`status` může být cokoli z hlediska MRR; v kódu se při výpočtu nepoužívá. Pro konzistenci se jinde píše `status = 'active'`.

---

## 2. Změna stavu při nákupu (co přesně updatovat)

### Aktuální stav po vypršení trialu

- Záznam v `tenant_modules` **existuje**.
- `trial_ends_at` je v minulosti → modul je z pohledu platnosti **neplatný** (všechny providery ho vyřadí).
- `is_trial` je stále `true` → i kdyby platnost prošla, cena by byla 0.

Důsledek: modul se v sidebaru neukazuje (platnost), v MRR přehledu by byl 0 (trial). Aby se po „Koupit“ modul **odemkl a započítal**, musíme změnit jak **platnost**, tak **příznak trialu**.

### Co přesně musíme v `tenant_modules` updatovat

**Minimálně nutné:**

1. **`is_trial = false`**  
   Aby se cena modulu započítala do MRR a do fakturační tabulky („K úhradě“).

2. **Obnovit platnost modulu**  
   Platnost se určuje podle `valid_until` a `trial_ends_at` – obě musí být NULL nebo v budoucnosti. Po vypršení trialu je `trial_ends_at` v minulosti, takže modul je neplatný a neukazuje se v sidebaru ani v přehledu.  
   **Možnosti:**
   - **`valid_until`** nastavit na konec placeného období (např. konec následujícího měsíce nebo +1 měsíc od teď).  
   - **`trial_ends_at`** nastavit na **NULL** (už to není trial), aby na platnost stačil jen `valid_until`.

**Doporučený UPDATE (koncepčně):**

```text
UPDATE tenant_modules
SET
  is_trial       = false,
  trial_ends_at   = NULL,
  valid_until     = <konec prvního placeného období, např. konec následujícího měsíce>,
  status         = 'active',
  deleted_at     = NULL
WHERE tenant_id  = ? AND module_id = ?;
```

- **`status = 'active'`** a **`deleted_at = NULL`** – konzistence s ostatním kódem (insert/update jinde to tak nastavují).
- **`valid_until`** – podle obchodní praxe (měsíční předplatné → např. konec dalšího měsíce; lze později vázat na fakturační cyklus).

**Stačí jen `status = 'active', is_trial = false`?**  
**Ne.** Bez posunu `valid_until` (nebo změny `trial_ends_at`) zůstane `trial_ends_at` v minulosti a modul zůstane „neplatný“ – nebude se zobrazovat v sidebaru a v přehledu bude vyřazen. Proto je nutné nastavit buď `valid_until` do budoucna, nebo `trial_ends_at = NULL` a mít `valid_until` v budoucnosti.

---

## 3. Notifikace / audit

### Audit (audit_logs)

- **Současný stav:**  
  Záznamy do **`audit_logs`** se píší přes **`AuditLogService.log()`** (popř. `logEnterprise()`).  
  V `premium_upsell_dialog.dart` se už teď loguje:
  - **MODULE_ACTIVATED** (nový modul s triálem),
  - **MODULE_REACTIVATED** (znovu zapnutí při běžícím trialu).

- **Doporučení:**  
  Při samoobslužném nákupu („Koupit plnou verzi“) zapsat **nový typ akce**, např. **MODULE_PURCHASED**, s `tableName: 'tenant_modules'` a v `details` např. `module`, `price`, `valid_until`, `self_service: true`.  
  Super Admin pak v Audit logu uvidí, kdo a kdy modul koupil.  
  V `audit_log_display_helpers.dart` bude potřeba doplnit překlad/interpretaci pro `MODULE_PURCHASED` (stejný vzor jako u ostatních akcí).

### Notifikace (notifications)

- **Současný stav:**  
  Tabulka **`notifications`** se používá pro zvoněk (zvoneček) – např. trigger při „owner issue“ vkládá notifikace adminům tenantu. Pro Super Adminy by šlo vložit notifikace při důležitých událostech (např. žádost o modul – viz `MODULE_PURCHASE_REQUEST_ANALYSIS.md`).

- **Doporučení:**  
  Při **samoobslužném nákupu** (okamžitý odemk bez schvalování) je audit_log primární stopa.  
  **Volitelně** lze přidat zápis do **notifications** pro všechny Super Adminy (např. typ `module_self_service_purchase`, text „Agentura XY si koupila modul Z“), aby měli okamžitou viditelnost bez prohlížení Audit logu.  
  Implementačně stejný vzor jako u jiných „notify Super Admin“ (SELECT profily s `role = 'super_admin'`, INSERT do `notifications` s `tenant_id` = tenanta, který koupil).

**Shrnutí:**  
- **Audit:** ano – nový action type (např. MODULE_PURCHASED) do `audit_logs` + zobrazení v Audit logu.  
- **Notifikace:** volitelné, ale vhodné pro rychlé upozornění Super Admina.

---

## 4. Přesný postup při kliknutí na „Koupit“

1. **UI**  
   V `premium_upsell_dialog.dart`: když existuje záznam v `tenant_modules` a `trial_ends_at` je v minulosti, zobrazit tlačítko „Koupit plnou verzi“ (místo nebo vedle hlášky o vypršení trialu). Cenu brát z `modules.price_eur`.

2. **Po potvrzení (jedna transakce / jeden flow)**  
   - **UPDATE `tenant_modules`** (viz výše):  
     `is_trial = false`, `trial_ends_at = NULL`, `valid_until = <konec období>`, `status = 'active'`, `deleted_at = NULL`  
     pro daný `tenant_id` a `module_id`.  
   - **Audit:**  
     `AuditLogService.log(..., actionType: 'MODULE_PURCHASED', tableName: 'tenant_modules', details: { module, price, valid_until, self_service: true })`.  
   - **Volitelně:**  
     INSERT do `notifications` pro Super Adminy (typ např. `module_self_service_purchase`).  
   - **Invalidace providerů:**  
     `activeModuleKeysProvider`, `tenantActiveModuleIdsProvider(tenantId)`, a u Super Admina i `dashboardMrrProvider`, `billingOverviewProvider`, aby se MRR a přehled hned přepočítaly.  
   - **Feedback uživateli:**  
     Zavřít dialog, SnackBar že modul byl odemčen / zakoupen.

3. **Výsledek**  
   Modul je hned vidět v sidebaru (platnost + aktivní záznam), v „Fakturace – manuální přehled“ se objeví jako placená položka a započítá se do MRR. Super Admin má stopu v Audit logu a případně notifikaci.

---

## 5. Shrnutí pod kapotou

| Otázka | Odpověď |
|--------|--------|
| Kdo krmí „Fakturace – manuální přehled“? | **billingOverviewProvider** (super_admin_billing_modal.dart). |
| Kdo počítá celkové MRR? | **dashboardMrrProvider** (stejná logika jako billing overview). |
| Používá se u modulů `status`? | Ne – MRR ani billing overview ho nečtou. |
| Co rozhoduje o započtení ceny? | Modul musí být „platný“ (valid_until / trial_ends_at) a **is_trial == false**. |
| Co updatovat při „Koupit“? | **is_trial = false**, **trial_ends_at = NULL**, **valid_until** = konec placeného období, **status = 'active'**, **deleted_at = NULL**. |
| Audit / notifikace? | **Audit:** nový typ MODULE_PURCHASED do audit_logs. **Notifikace:** volitelně pro Super Adminy. |

Tím je cesta k samoobslužnému nákupu a okamžitému propisu do MRR přehledu jednoznačně daná bez psaní kódu.
