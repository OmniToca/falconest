# Hloubková analýza modulu Peněženka (Cash Wallet)

**Datum:** 23. 2. 2025  
**Typ:** READ-ONLY AUDIT – fyzická kontrola aktuálního zdrojového kódu (ne staré dokumentace)  
**Zamčený soubor:** `task_assignment_engine.dart` – NEDOTÝKAT

---

## KRITICKÁ KOREKCE

**Obě funkce jsou v kódu implementované.** Následující zjištění vycházejí výhradně z fyzické kontroly souborů `.dart` v repozitáři:

1. **Offline ukládání hotovosti** – repozitář má try-catch, detekuje síťovou chybu a ukládá výběr do `MutationQueueService.enqueueMutation` (mobil).
2. **Extra hotovost / dýško** – dialog má `TextField` pro zadání extra částky, která se sčítá s plánovanou.

---

## 1. Fyzická kontrola Repozitáře (`cash_wallet_repository.dart`)

### 1.1 Try-catch v `recordCashCollection`

**Soubor:** `lib/core/repositories/cash/cash_wallet_repository.dart`  
**Metoda:** `recordCashCollection` (řádky 39–107)

**Zjištění:**

- Ř. **46–89:** Blok `try` – volání Supabase (SELECT/INSERT peněženky, INSERT transakce, UPDATE balance).
- Ř. **90–106:** Blok `catch (e)`:
  - Ř. **91:** Podmínka `if (!kIsWeb && MutationQueueService.isNetworkError(e))`
  - Ř. **94–104:** Volání `MutationQueueService.instance.enqueueMutation` s:
    - `table: 'employee_cash_transactions'`
    - `action: 'OFFLINE_CASH_COLLECTION'`
    - `payload: {tenant_id, profile_id, task_id, amount}`
  - Ř. **105:** `return` – **bez rethrow** (UI nedostane výjimku)
  - Ř. **106:** `rethrow` – pro jiné než síťové chyby

**Závěr:** Offline záchrana dat do fronty je implementovaná. Při síťové chybě na mobilu se výběr uloží do `MutationQueueService` a po návratu sítě ho Sync Engine zpracuje přes `processOfflineCashCollection`.

---

## 2. Fyzická kontrola UI dialogu a Úklidu

### 2.1 Dialog – `TextField` pro Extra hotovost

**Soubor:** `lib/features/worker/utils/cash_collection_dialog.dart`

**Zjištění:**

- Ř. **88:** `final _extraController = TextEditingController();` – controller pro extra částku
- Ř. **96–101:** Metoda `_parseExtra()` – parsuje hodnotu z textu
- Ř. **103–106:** V `_onYes()`: `final extra = _parseExtra() ?? 0; final total = widget.plannedAmount + extra;`
- Ř. **121–126:** Volání `recordCashCollection` s `amount: total` (součet plánované + extra)
- Ř. **169–176:** `TextField` v buildu:
  - `controller: _extraController`
  - `labelText: 'worker.cash_collection_extra_label'.tr()`
  - `hintText: '0'`

**Závěr:** Pole pro extra hotovost / dýško v dialogu existuje. Při potvrzení ANO se posílá `total = plannedAmount + extra`.

### 2.2 Úklid – ikona peněženky v AppBar

**Soubor:** `lib/features/worker/screens/task_types/cleaning_task_screen.dart`

**Zjištění:**

- Ř. **47–61:** V `AppBar.actions` je `IconButton`:
  - `icon: const Icon(Icons.account_balance_wallet_outlined)`
  - `tooltip: 'worker.cash_enter_button_tooltip'.tr()`
  - `onPressed:` volá `maybeShowCashCollectionDialog` s:
    - `forceShowForExtraOnly: true` – dialog se zobrazí i bez plánované částky (jen extra)
    - `completeTaskOnConfirm: false` – úkol se nedokončí, jen zapíše výběr

**Závěr:** Ikona peněženky pro manuální vyvolání dialogu v obrazovce Úklidu existuje. Uklízečka může zadat pouze extra hotovost (dýška), i když úkol nemá `amount_to_collect`.

---

## 3. Shrnutí – kde se dialog používá

| Typ úkolu   | Kde je tlačítko/dialog                            | Podmínka zobrazení                           | `completeTaskOnConfirm` |
|-------------|---------------------------------------------------|----------------------------------------------|--------------------------|
| **Check-in** | Na tlačítku „Dokončit“ v těle obrazovky          | `metadata.amount_to_collect > 0`             | `true`                   |
| **Transfer** | Na tlačítku „Dokončit“ v těle obrazovky          | `metadata.amount_to_collect > 0`             | `true`                   |
| **Cleaning** | Ikona peněženky v **AppBar** (ř. 47–61)          | `forceShowForExtraOnly: true` – vždy viditelné | `false`                  |
| **Check-out**| **Žádné** – pouze tlačítko Dokončit              | N/A                                          | N/A                      |

---

## 4. OFFLINE SPOLEHLIVOST

### 4.1 Průběh při offline potvrzení výběru

1. Uživatel potvrdí ANO → `recordCashCollection` selže na síťové chybě.
2. Catch (ř. 90–105) detekuje `MutationQueueService.isNetworkError(e)` (mobil), enqueue a vrací bez výjimky.
3. Kód pokračuje na `updateStatus(…, 'completed')` → TaskRepositoryMobile zapisuje do Isar lokálně.
4. Po návratu sítě `processQueue` (mutation_queue_service_mobile) zpracuje `OFFLINE_CASH_COLLECTION` → volá `processOfflineCashCollection` → `recordCashCollection` (už online).

**Výsledek:** Peníze se při offline neztratí.

### 4.2 Poznámky

- **Web:** `mutation_queue_service_web.dart` – `isNetworkError` vždy `false` → web nemá offline frontu.
- **Stávající `docs/WORKER_CASH_WALLET_AUDIT.md`:** Obsahuje zastaralý popis (např. „Nepoužívá PendingMutationLocal“). Aktuální implementace používá `MutationQueueService` s akcí `OFFLINE_CASH_COLLECTION`.

---

## 5. ADMIN APP (Web – Kancelář)

- **`finance_dashboard_screen.dart`** – `_showReceiveCashDialog` (ř. 169–222) volá `CashWalletRepository.instance.receiveCashFromWorker` správně.
- **`_FailedCashAlertsSection`** – zobrazuje úkoly s `cash_collection_failed: true`.

---

## 6. DATABÁZE A MODELY

### 6.1 Schéma (dle `database_schema.md`)

| Tabulka                    | Klíčové sloupce                                   |
|----------------------------|---------------------------------------------------|
| `employee_cash_wallets`    | `id`, `tenant_id`, `profile_id`, `balance`         |
| `employee_cash_transactions`| `id`, `wallet_id`, `task_id`, `amount`, `transaction_type` |

- `transaction_type`: `COLLECTED_FROM_GUEST` (výběr) nebo `HANDED_TO_AGENCY` (odevzdání).
- `amount`: kladné = výběr, záporné = odevzdání.

### 6.2 Ukládání celkové částky vs. plánovaná vs. dýško

Repozitář ukládá **jednu celkovou částku** – `total = plannedAmount + extra`. V databázi není rozlišení mezi plánovanou částkou a dýškem; v tabulce je jen sloupec `amount` s celkovou sumou.

- Pro „celkovou vybranou částku“ to stačí – evidence je kompletní.
- Pro budoucí rozšíření (reporty „jen dýška“, „jen plánované“) by bylo nutné přidat např. `planned_amount` a `extra_amount` nebo metadata.

---

## 7. SOUHRN A DOPORUČENÍ

| Oblast              | Stav (ověřeno v kódu)                                                | Poznámka                                                                 |
|---------------------|----------------------------------------------------------------------|--------------------------------------------------------------------------|
| Offline záchrana    | ✅ `recordCashCollection` má try-catch + `MutationQueueService.enqueueMutation` | Ř. 90–105 v cash_wallet_repository.dart                          |
| Extra hotovost      | ✅ `TextField` + `_extraController` v cash_collection_dialog.dart     | Ř. 88, 169–176; total = plannedAmount + extra                            |
| Ikona peněženky (Úklid) | ✅ `Icons.account_balance_wallet_outlined` v AppBar                | cleaning_task_screen.dart ř. 47–61, forceShowForExtraOnly: true           |
| Check-out           | ⚠️ Nemá integraci s peněženkou                                       | Zvážit přidání                                                            |
| WORKER_CASH_WALLET_AUDIT.md | ⚠️ Zastaralý                                                   | Tvrdí, že offline neexistuje – není pravda                                |

### Doporučené další kroky

1. **Check-out:** Zvážit přidání cash collection (ikona v AppBar nebo podmíněný dialog na Dokončit) pro konzistenci s ostatními typy úkolů.
2. **DB rozšíření:** Pokud budou potřeba reporty „jen dýška“ vs. „plánovaná částka“, přidat sloupce nebo metadata.
3. **Dokumentace:** Aktualizovat `WORKER_CASH_WALLET_AUDIT.md` o současnou offline podporu výběru hotovosti.
