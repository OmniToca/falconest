# Analýza: Peněženka zaměstnance – částečný výběr a vklad základu (kasírtaška)

**Záměr:** Rozšířit modul „Peněženka zaměstnance“ o (1) částečný výběr hotovosti (admin nevybere vše, např. z 459 EUR jen 359 EUR, zůstane 100 EUR na vracení) a (2) vklad hotovosti na začátek (admin zaměstnanci vloží např. +100 EUR jako základ na vracení/nákupy).

**Scope:** Pouze analýza. Žádný kód.

---

## 1. Jak se aktuálně počítá zůstatek?

### Odpověď: Zůstatek je **ukládaný**, ne počítaný

- **Tabulka:** `employee_cash_wallets`  
  Sloupce: `id`, `tenant_id`, `profile_id`, **`balance`** (numeric NOT NULL DEFAULT 0), `updated_at`.  
  Jeden řádek na (tenant_id, profile_id) – jedna „kapsa“ na zaměstnance.

- **Zůstatek** = hodnota sloupce **`balance`**.  
  Není odvozován z úkolů ani z transakcí. Při každé operaci se balance **přepočítá v kódu** a uloží UPDATE do `employee_cash_wallets`.

- **Ledger (účetní kniha):** Tabulka **`employee_cash_transactions`**  
  Append-only záznamy: `wallet_id`, `task_id` (volitelné), `amount` (kladné = přírůstek, záporné = úbytek), `transaction_type`, `created_by`, `created_at`, `note`, atd.  
  Slouží pro historii a audit; **zůstatek se z ní v aplikaci nepočítá** – vždy se čte/aktualizuje `employee_cash_wallets.balance`.

- **Vazba na úkoly:**  
  Úkoly (tasks) pouze **spouštějí** zápis: když pracovník dokončí úkol s hotovostí (Check-in, Transfer), volá se `CashWalletRepository.recordCashCollection(...)` s `task_id` a částkou. Ta přidá transakci `COLLECTED_FROM_GUEST` a zvýší `balance`.  
  Samotný zůstatek **není** součtem úkolů ani součtem transakcí v DB – je to denormalizovaná hodnota v `employee_cash_wallets`.

**Shrnutí:** Zůstatek = `employee_cash_wallets.balance`. Ledger = `employee_cash_transactions`. Žádná agregace z úkolů.

---

## 2. Co přesně dělá současné tlačítko „Převzít hotovost“?

### Repozitář: `CashWalletRepository.receiveCashFromWorker`

**Volání z UI:**  
- `finance_dashboard_screen.dart` (řádek ~426) a `wallet_detail_modal.dart` (řádek ~557) předávají **`amountToClear: row.balance`** – tedy vždy **celý** aktuální zůstatek.

**Co metoda dělá (kráceno):**

1. **INSERT** do `employee_cash_transactions`:  
   - `tenant_id`, `wallet_id`, `task_id: null`  
   - **`amount`: -amountToClear** (záporná částka)  
   - **`transaction_type`: 'HANDED_TO_AGENCY'**  
   - `created_by`: adminProfileId  

2. **UPDATE** `employee_cash_wallets`:  
   - **`balance = 0`** (vždy nuluje celou kapsu)  
   - `updated_at = now()`

Žádné flagy na úkolech (např. `is_cashed_out`), žádná vazba na konkrétní úkoly – jen jedna záporná transakce a vynulování balance.  
**Shrnutí:** Jedna minusová transakce `HANDED_TO_AGENCY` a nastavení `balance` na 0. Částečný výběr ani vklad základu dnes neexistují.

---

## 3. Návrh architektury pro nové požadavky

### 3.1 Částečný výběr (např. 359 EUR z 459 EUR)

- **Datový model:**  
  **Není potřeba nová tabulka.** Stávající model to umí: jedna transakce `HANDED_TO_AGENCY` s libovolnou (zápornou) částkou a úprava `balance` o tuto částku.

- **Změna v repozitáři:**  
  - `receiveCashFromWorker` už bere `amountToClear`.  
  - Jediná nutná úprava: místo pevného **`balance = 0`** použít **`balance = currentBalance - amountToClear`**.  
  - Na začátku metody načíst aktuální `balance` (SELECT), ověřit `amountToClear <= currentBalance` a `amountToClear > 0`, pak INSERT transakce a UPDATE balance.

- **UI:**  
  - V dialogu potvrzení „Převzít hotovost“ nepředávat jen text s celým zůstatkem, ale **pole pro částku k výběru** (výchozí = celý zůstatek, max = zůstatek).  
  - Např. v `_showReceiveCashDialog` (wallet_detail_modal + finance_dashboard_screen): místo jen `row.balance` zobrazit TextField (nebo podobně) s částkou; validace 0 < amount ≤ row.balance; při potvrzení volat `receiveCashFromWorker(..., amountToClear: enteredAmount)`.

- **Ledger:**  
  - Jeden řádek `HANDED_TO_AGENCY` s `amount = -enteredAmount`.  
  - Historie zůstane konzistentní; zůstatek po operaci = předchozí balance − enteredAmount (např. 459 − 359 = 100).

Žádná vazba na úkoly se nemění – částečný výběr je jen „odebrat X EUR z kapsy“.

---

### 3.2 Vklad hotovosti (základ / kasírtaška)

- **Sémantika:** Admin zaměstnanci „vloží“ hotovost (např. +100 EUR), aby měl na vracení nebo nákupy. Zůstatek peněženky se **zvýší**.

- **Datový model:**  
  **Nová hodnota `transaction_type`** v tabulce `employee_cash_transactions`.  
  Aktuálně CHECK: `('COLLECTED_FROM_GUEST', 'HANDED_TO_AGENCY', 'COMPANY_EXPENSE')`.  
  Přidat např. **`FLOAT_ISSUED`** (vklad základu od agentury) nebo **`CASH_IN`**.  
  Implementace: migrace `ALTER TABLE employee_cash_transactions DROP CONSTRAINT ... ; ADD CONSTRAINT ... CHECK (transaction_type IN (..., 'FLOAT_ISSUED'))`.

- **Repozitář:**  
  Nová metoda např. **`recordFloatIssued`** (nebo `recordCashIn`):  
  - parametry: tenantId, walletId, profileId (příp. jen walletId + tenantId), **amount** (kladné), adminProfileId;  
  - najít/create peněženku (stejná logika jako jinde – pokud peněženka neexistuje, lze ji vytvořit s balance 0 a pak přidat transakci);  
  - **INSERT** do `employee_cash_transactions`: `amount` kladné, `transaction_type = 'FLOAT_ISSUED'`, `task_id = null`, `created_by = adminProfileId`;  
  - **UPDATE** `employee_cash_wallets`: `balance = currentBalance + amount`, `updated_at = now()`.

- **UI:**  
  - V detailu peněženky (a případně na přehledu karet) nové tlačítko typu **„Vložit hotovost“ / „Základ“**.  
  - Dialog: pole pro částku (kladné číslo), volitelně poznámka; potvrzení → volání `recordFloatIssued`.  
  - Po úspěchu invalidace providerů (employeeCashWalletsProvider, walletTransactionsProvider(walletId)) a SnackBar.

Žádná nová tabulka – jen nový typ transakce a jedna nová metoda v repozitáři.

---

### 3.3 Shrnutí návrhu

| Požadavek            | Změna v DB                          | Změna v repozitáři                                      | Změna v UI                                                                 |
|----------------------|-------------------------------------|---------------------------------------------------------|----------------------------------------------------------------------------|
| Částečný výběr       | Žádná                               | `receiveCashFromWorker`: balance = current − amount     | Dialog „Převzít“ s editovatelnou částkou (default = celý zůstatek, max = balance) |
| Vklad základu        | Rozšířit CHECK o `FLOAT_ISSUED`     | Nová metoda `recordFloatIssued` (INSERT + zvýšení balance) | Nové tlačítko „Vložit hotovost“ / „Základ“ + dialog s částkou (a vol. poznámkou) |

- **Úkoly:** Vazba na úkoly zůstává jen u `COLLECTED_FROM_GUEST` (task_id). Částečný výběr ani vklad nejsou vázané na úkol – `task_id` u těchto transakcí null.  
- **Ledger:** Jedna tabulka `employee_cash_transactions` dál stačí; všechny pohyby (výběr od hosta, odevzdání agentuře, firemní výdaj, vklad základu) jsou jeden typ záznamu s různými `transaction_type`.  
- **Konzistence:** Balance vždy odpovídá součtu transakcí dané peněženky (pokud bychom je sečetli); aktuálně se ale balance pouze aktualizuje v kódu při každé operaci – doporučení nechat tak a neměnit na „počítat ze SUM(amount)“ bez důvodu (výkon, race conditions).

Tím je architektura pro částečný výběr a vklad základu definovaná bez nutnosti nových tabulek a s minimálními změnami v DB (jedna nová hodnota v CHECK pro `transaction_type`).
