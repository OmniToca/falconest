# Audit – Zaměstnanecká pokladna v mobilní aplikaci (Worker flow)

**Datum:** Únor 2025  
**Typ:** READ-ONLY analýza – žádný vývoj, inventarizace pro UX návrh  
**Cíl:** Zjistit výchozí stav pro edge-case „uklízečka dostane neplánovanou hotovost od hostů“

---

## 1. Datová vrstva a offline

### 1.1 Zrcadlení tabulek v Isaru

| Tabulka | V Isaru? | Zdroj dat |
|---------|----------|-----------|
| `employee_cash_wallets` | ❌ Ne | Supabase (online) |
| `employee_cash_transactions` | ❌ Ne | Supabase (online) |

**Zdroj:**  
`docs/OFFLINE_AUDIT_REPORT.md` výslovně uvádí: *„staff_absences, employee_cash_wallets – ze Supabase“*.  
V `IsarService.init()` jsou registrovány pouze: `ApartmentLocal`, `TaskLocal`, `ReservationLocal`, `PendingAuditAction`, `PendingMutationLocal`. Žádná lokální kolekce pro finance.

### 1.2 Jak se ukládá plánovaný výběr hotovosti (Cash Collection)

**Cesta:**  
`maybeShowCashCollectionDialog` → při potvrzení „Ano“ → `CashWalletRepository.instance.recordCashCollection()`

**Implementace `recordCashCollection`** (`lib/core/repositories/cash/cash_wallet_repository.dart`):

- Volá **přímo Supabase** (`SupabaseService.client.from(...)`):
  - `SELECT` z `employee_cash_wallets` (hledání peněženky)
  - `INSERT` do `employee_cash_wallets` (pokud neexistuje)
  - `INSERT` do `employee_cash_transactions` (COLLECTED_FROM_GUEST)
  - `UPDATE` na `employee_cash_wallets` (zvýšení balance)
- **Nepoužívá** `PendingMutationLocal` ani žádnou offline frontu.

**Dokumentace repozitáře:**  
*„Všechny operace jdou přímo do Supabase – při offline režimu na mobilu volání selže.“*

**Důsledek:**  
Při offline výběru hotovosti záznam neprojde – výjimka se vyhodí, úkol se dokončí (status jde do Isaru přes `WorkerTaskStatusNotifier`), ale cash transakce se nezapíše. Pracovník nemá jak vybrání zaznamenat bez signálu.

---

## 2. Co vidí pracovník v UI

### 2.1 Stav peněženky (balance – kolik dluží agentuře)

**Worker v mobilní aplikaci svůj stav peněženky nevidí.**

- Worker dashboard (`WorkerDashboardScreen`) – seznam úkolů, pull-to-refresh, offline banner. Žádná sekce „Má peněženku“ ani „Dlužím agentuře“.
- Drawer (`_WorkerDrawer`) – položky: „Změnit PIN“, „Odhlásit se“. Žádná položka Finance.
- Žádný provider ani obrazovka, která by pracovníkovi zobrazovala vlastní wallet balance.

### 2.2 Finance modul z pohledu Workera

**Finance modul existuje pouze v Admin části aplikace.**

- `FinanceDashboardScreen` je v `lib/features/admin/`, přístupný adminům přes menu.
- Worker nemá přístup k route `/admin/*`.
- Worker route: `/worker`, `/worker/task/:id`. Žádná `/worker/finance` ani podobná.

**Závěr:** Pracovník v Worker flow nemá žádné tlačítko ani obrazovku pro modul Finance (peněženku).

---

## 3. Prostor pro „extra hotovost“ (neplánovaný výběr)

### 3.1 Kde se `CashCollectionDialog` zobrazuje

Dialog se volá **pouze** v:

- `CheckinTaskScreen` – při dokončení úkolu
- `TransferTaskScreen` – při dokončení transferu

**CleaningTaskScreen** dialog nevolá – úklid explicitně ignoruje finance metadata (`_buildCleaningMetadata` používá jen `custom_note`, `amount_to_collect` a `collection_breakdown` záměrně ignoruje).

### 3.2 Vazba na `amount_to_collect`

`maybeShowCashCollectionDialog`:

```dart
final amountRaw = meta['amount_to_collect'];
// ...
if (amount == null || amount <= 0) return null;  // dialog se vůbec nezobrazí
```

- Dialog se **nezobrazí**, pokud `amount_to_collect` není v metadatech nebo je ≤ 0.
- Částka je **fixní** – bere se z `metadata['amount_to_collect']`, uživatel ji nemůže měnit.
- UI: pouze tři akce – „Ano, vybral jsem hotovost“, „Nevybral jsem“, „Zrušit“. Žádné vstupní pole pro částku.

### 3.3 Zda lze snadno přidat neplánovanou částku

**Stávající dialog je striktně vázaný na předem daný `amount_to_collect`.**

- Nelze zadat vlastní částku.
- Nelze přičíst dodatečnou sumu k plánované.
- Pro scénář „uklízečka na bytě, úkol bez výběru, hosté dají 100 EUR“ aktuálně **není žádná možnost** – úklid dialog vůbec neukazuje a jiný vstup pro extra hotovost neexistuje.

**Pro podporu extra hotovosti bude potřeba:**

- buď rozšířit stávající dialog o možnost „Přidat jinou částku“ (volitelný vstup),
- nebo zavést nový vstupní bod (např. tlačítko „Zadat hotovost“ na dashboardu nebo v draweru),
- plus odpovídající logika pro zápis do `employee_cash_transactions` (ideálně s offline podporou).

---

## 4. Shrnutí – výchozí stav

| Oblast | Stav | Poznámka |
|--------|------|----------|
| **employee_cash_wallets v Isaru** | ❌ Ne | Pouze Supabase |
| **employee_cash_transactions v Isaru** | ❌ Ne | Pouze Supabase |
| **Cash collection – offline** | ❌ Ne | Přímý zápis do Supabase |
| **Cash collection – PendingMutationLocal** | ❌ Nepoužívá | Žádná fronta |
| **Worker vidí svůj balance** | ❌ Ne | Není žádné UI |
| **Worker má Finance modul** | ❌ Ne | Jen Admin |
| **CashCollectionDialog – extra částka** | ❌ Ne | Pouze fixní amount_to_collect |
| **Úklid – cash dialog** | ❌ Ne | Cleaning metadata ignorují amount_to_collect |

**Pro edge-case „uklízečka dostane 100 EUR navíc“:**  
Aktuálně není žádná cesta, jak tuto částku v Worker aplikaci zaznamenat – ani plánovanou (úklid dialog neukazuje), ani neplánovanou (není vstup pro vlastní částku).
