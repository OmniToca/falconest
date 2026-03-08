# Audit architektury: Offline-First mobilní aplikace FalcoNest

**Datum auditu:** 2025-02-28  
**Zadavatel:** Senior Architect  
**Kontext:** Podezření, že nedávné úpravy (zamykání úkolů, finance, dýška) narušily OFFLINE-FIRST chování pro pracovníky v terénu.

**Legenda:**
- **PASS** – funguje offline (data z Isar / lokální DB / PendingMutation queue)
- **FAIL** – přímé volání Supabase, při chybějícím připojení selže nebo prázdné UI

---

## 1. ČTENÍ DAT (Reads)

### 1.1 Worker obrazovky – zdroj dat

| Obrazovka | Provider | Zdroj dat | PASS / FAIL |
|-----------|----------|-----------|-------------|
| **WorkerDashboardScreen** | `workerTasksProvider` | `TaskRepositoryMobile` → Isar `taskLocals` | ✅ **PASS** |
| **WorkerTaskDetailScreen** | `workerTaskDetailProvider` | `TaskDetailProviderMobile` → Isar `taskLocals.getSync()` | ✅ **PASS** |
| **CheckinTaskScreen** | `workerTaskDetailProvider` | Isar | ✅ **PASS** |
| **CheckoutTaskScreen** | `workerTaskDetailProvider` | Isar | ✅ **PASS** |
| **TransferTaskScreen** | `workerTaskDetailProvider`, `messageTemplatesForWorkerProvider` | Isar `taskLocals`, Isar `messageTemplateLocals` | ✅ **PASS** |
| **CleaningTaskScreen** | `workerTaskDetailProvider` | Isar | ✅ **PASS** |
| **DefaultTaskScreen** | `workerTaskDetailProvider` | Isar | ✅ **PASS** |
| **MaintenanceTaskScreen** | `workerTaskDetailProvider` | Isar | ✅ **PASS** |
| **MaterialTaskScreen** | `workerTaskDetailProvider` | Isar | ✅ **PASS** |
| **IssueTaskScreen** | `workerTaskDetailProvider` | Isar | ✅ **PASS** |
| **WorkerWalletScreen** | `myCashWalletProvider`, `myCashTransactionsProvider` | `CashWalletRepository.watchWalletsRaw()` + `watchTransactionsRawForWallet()` → **Supabase `.stream()`** | ❌ **FAIL** |
| **WorkerAbsencesScreen** | `workerAbsencesProvider` | `SupabaseService.client.from('staff_absences').select()` | ❌ **FAIL** |

### 1.2 Detailní analýza FAIL položek

#### WorkerWalletScreen (FAIL)
- `myCashWalletProvider` (ř. 56–82, finance_cash_provider.dart): `CashWalletRepository.watchWalletsRaw()` → Supabase `.stream(primaryKey: ['id']).inFilter('tenant_id', [tenantId])`
- `myCashTransactionsProvider` (ř. 89–110): `watchTransactionsRawForWallet()` → Supabase stream
- Navíc `_enrichTransactions()` (ř. 138–180): při každé změně streamu volá `SupabaseService.client.from('tasks').select('id, apartments(name), reservations(guest_name)')` – další online závislost
- **Důsledek:** Bez internetu je obrazovka peněženky prázdná (null/empty), pracovník nevidí svůj zůstatek ani historii výběrů

#### WorkerAbsencesScreen (FAIL)
- `worker_absences_provider.dart` (ř. 20–22): přímý `SupabaseService.client.from('staff_absences').select(...).eq('profile_id', profileId)`
- **Důsledek:** Absence (dovolené, nemoci) se offline nenačtou

### 1.3 Sdílené providery (tasks / finance)

| Provider | Použití | Zdroj | PASS / FAIL |
|----------|---------|-------|-------------|
| `workerTasksProvider` | Dashboard, stats | `TaskRepositoryMobile` → Isar | ✅ **PASS** |
| `workerTaskDetailProvider` | Všechny task screens | `TaskDetailProviderMobile` → Isar | ✅ **PASS** |
| `weeklyStatsProvider` | Dashboard statistiky | `workerTasksProvider` (Isar) | ✅ **PASS** |
| `myCashWalletProvider` | Worker Wallet | Supabase stream | ❌ **FAIL** |
| `myCashTransactionsProvider` | Worker Wallet | Supabase stream + `_enrichTransactions` (Supabase select) | ❌ **FAIL** |

---

## 2. ZÁPIS DAT (Writes / Mutations)

### 2.1 Akce pracovníka – offline podpora

| Akce | Místo | Mechanismus | PASS / FAIL |
|------|-------|-------------|-------------|
| **Dokončení úkolu (bez fotek)** | `TaskRepositoryMobile.updateTaskStatus` | Isar `putSync()`, `syncStatus = pending`, WorkerSyncService push po připojení | ✅ **PASS** |
| **Dokončení úkolu (s fotkami)** | `TaskRepositoryMobile.updateTaskStatus` (ř. 178–218) | **Přímý Supabase** `.update(updates)` – vyžaduje síť pro upload URL | ❌ **FAIL** |
| **Výběr hotovosti od hosta (Check-in/Transfer)** | `CashCollectionDialog` → `recordCashCollection` | Try Supabase, catch → `MutationQueueService.enqueueMutation(OFFLINE_CASH_COLLECTION)` | ✅ **PASS** |
| **Přidání firemního výdaje** | `AddCompanyExpenseDialog` → `recordCompanyExpense` | Try Supabase, catch → `MutationQueueService.enqueueMutation(OFFLINE_COMPANY_EXPENSE)` | ✅ **PASS** |
| **Přidání absence** | `AddAbsenceDialog` | Try Supabase insert, catch → `MutationQueueService.enqueueMutation` | ✅ **PASS** |
| **Nahlášení problému (Issue Reporter)** | `IssueReporterDialog` (ř. 147) | **Přímý** `SupabaseService.client.from('tasks').insert(payload)` – žádný offline fallback | ❌ **FAIL** |
| **Změna stavu rezervace (checked_in/out)** | `TaskRepositoryMobile._applyReservationStatusOnComplete` | Isar `reservationLocals.putSync()`, `syncStatus = pending` | ✅ **PASS** |

### 2.2 Čekání na Supabase před aktualizací UI

| Akce | Await Supabase před UI update? | Poznámka |
|------|-------------------------------|----------|
| Dokončení úkolu (bez fotek) | **Ne** – Isar putSync synchronně | UI reaguje okamžitě |
| Dokončení úkolu (s fotkami) | **Ano** – await Supabase update | Bez sítě nekonečný loading / timeout |
| Výběr hotovosti | **Ne** – při offline se vrací z `recordCashCollection` bez výjimky po enqueue | UI zavře dialog, snackbar „uloženo“ |
| Firemní výdaj | **Ne** – stejný fallback | ✅ |
| Absence | **Ne** – catch → enqueue | ✅ |
| Issue Reporter | **Ano** – await Supabase insert | Bez sítě chyba, záznam se ztratí |

---

## 3. NEDÁVNÉ ZMĚNY

### 3.1 expected_amount při výběru peněz

| Místo | Soubor | Kontrola online-only závislosti | PASS / FAIL |
|-------|--------|----------------------------------|-------------|
| `CashCollectionDialog` | `cash_collection_dialog.dart` | `plannedAmount` z `detail.metadata['amount_to_collect']` → předává se do `recordCashCollection` | ✅ **PASS** |
| `recordCashCollection` | `cash_wallet_repository.dart` | Ukládá `expected_amount` do transakce; při offline předává v payloadu do fronty | ✅ **PASS** |
| `OfflineCashCollectionProcessor` | `offline_cash_collection_processor.dart` | Čte `expected_amount` z payloadu, předává do `recordCashCollection` | ✅ **PASS** |
| `MutationQueueService` payload | `cash_wallet_repository.dart` (ř. 114–115) | `if (expectedAmount != null && expectedAmount > 0) 'expected_amount': expectedAmount` v payloadu | ✅ **PASS** |

**Závěr:** `expected_amount` je v offline flow plně podporován. Žádná nová online-only závislost.

### 3.2 Read-only zamykání úkolů

| Místo | Kontext |
|-------|---------|
| `admin_tasks_screen.dart` | `isReadOnly = _normalizeToSystemStatus(task.status) == 'completed'` – blokace editace dokončených úkolů v Admin UI |
| Worker UI | Žádná speciální logika pro locking – worker může dokončovat a měnit úkoly jako dříve |
| Isar / offline | Žádná změna – locking je čistě prezentační v Admin, ne v datové vrstvě |

**Závěr:** Read-only locking je implementován pouze v Admin (online prostředí). Worker flow neovlivněn, offline-first beze změny.

---

## 4. Shrnutí – úniky online logiky

### 4.1 FAIL – kritické (Worker UI závislé na internetu)

| # | Komponenta | Problém |
|---|------------|---------|
| 1 | **WorkerWalletScreen** | Peněženka a transakce čtené ze Supabase streamu; offline prázdné |
| 2 | **_enrichTransactions** | Volání `tasks.select()` při zobrazení transakcí – offline selže |
| 3 | **WorkerAbsencesScreen** | Absence čtené přímým Supabase select – offline prázdné |
| 4 | **IssueReporterDialog** | Přímý Supabase insert bez fallbacku do MutationQueue |
| 5 | **Dokončení úkolu s fotkami** | `TaskRepositoryMobile` při `mediaUrls != null` volá Supabase přímo – vyžaduje síť |

### 4.2 PASS – správně offline-first

| Komponenta | Mechanismus |
|------------|-------------|
| Dashboard, seznam úkolů | Isar `taskLocals` přes TaskRepositoryMobile |
| Detail úkolu (všechny typy) | Isar `taskLocals.getSync()` |
| Dokončení bez fotek | Isar put + syncStatus pending |
| Výběr hotovosti | Try Supabase → catch → PendingMutation (OFFLINE_CASH_COLLECTION) |
| Firemní výdaj | Try Supabase → catch → PendingMutation (OFFLINE_COMPANY_EXPENSE) |
| Přidání absence | Try Supabase → catch → enqueue |
| expected_amount | Plně v payloadu a offline procesoru |
| Šablony zpráv (TransferTaskScreen) | Isar `messageTemplateLocals` |

---

## 5. Doporučení (pro budoucí implementaci)

1. **Worker Wallet:** Zvážit Isar cache pro `employee_cash_wallets` a `employee_cash_transactions` (sync při online), nebo explicitní offline stav UI s informací „Připojte se pro zobrazení peněženky“.
2. **Worker Absences:** Na mobilu číst z Isar (StaffAbsenceLocal), pokud existuje schema, nebo akceptovat prázdný seznam s hláškou offline.
3. **IssueReporterDialog:** Přidat offline fallback – při `MutationQueueService.isNetworkError(e)` ukládat payload do fronty (např. OFFLINE_ISSUE_TASK).
4. **Dokončení s fotkami:** Ukládat lokální cesty do Isar, při sync nahrát soubory a aktualizovat `media_urls`; nepoužívat přímý Supabase update.
5. **_enrichTransactions:** Při offline používat `TaskLocal` z Isar místo Supabase select pro apartment/reservation kontext.
