# Offline-First Compliance Audit – FalcoNest

**Datum auditu:** 2025-02-28  
**Oblast:** lib/features/worker, lib/features/tasks, lib/features/finance, lib/core/database

---

## 1. lib/features/worker/

### 1.1 Supabase Direct Calls (offline riziko)

| Soubor | Řádky | Pattern | Kontext |
|--------|-------|---------|---------|
| `data/services/worker_sync_service_mobile.dart` | 47-50, 80-84, 91-95, 102-106, 127-129, 162-164 | `.from(...).select()` | Pull tasks, apartments, reservations, clients, tenants, templates ze Supabase – **OK** (sync service) |
| `data/services/worker_sync_service_mobile.dart` | 327-330, 378-380 | `.from(...).update()` | Upload pending tasks/reservations – **OK** (push sync) |
| `providers/worker_absences_provider.dart` | 20-22 | `.from('staff_absences').select()` | **PROBLÉM**: Přímý Supabase select – absence se offline nenačtou |
| `widgets/add_absence_dialog.dart` | 167-168 | `.from('staff_absences').insert()`, `.from('tasks').insert()` | **OK**: Try-first Supabase, při chybě fallback do MutationQueueService (181-189) |
| `widgets/issue_reporter_dialog.dart` | 146 | `.from('tasks').insert()` | **PROBLÉM**: Přímý Supabase insert bez offline fallbacku – komentář říká „bypass MutationQueue pro zachycení chyby“ |

### 1.2 Isar / lokální DB použití

| Soubor | Řádky | Pattern | Kontext |
|--------|-------|---------|---------|
| `data/services/worker_sync_service_mobile.dart` | 146-283, 304-419 | `isar.writeTxn`, `isar.taskLocals`, `isar.apartmentLocals`, `isar.reservationLocals`, `isar.clientLocals`, `isar.messageTemplateLocals`, `isar.tenantLocals` | Sync service zapisuje stažená data do Isar – **OK** |
| `screens/worker_dashboard_screen.dart` | 69-71 | `ref.watch(workerTasksProvider)`, `ref.watch(workerSyncStateProvider)` | Data z provideru (TaskRepository → Isar na mobilu) |
| `screens/worker_task_detail_screen.dart` | 25 | `ref.watch(workerTaskDetailProvider(taskId))` | Detail z TaskRepository (Isar) |
| `screens/worker_wallet_screen.dart` | 24-25 | `ref.watch(myCashWalletProvider)`, `ref.watch(myCashTransactionsProvider)` | **PROBLÉM**: Finance providery čtou Supabase stream, ne Isar |
| `screens/task_types/*_task_screen.dart` | 21-31 | `ref.watch(workerTaskDetailProvider(taskId))` | Všechny task screens čtou z Isar přes TaskRepository |

### 1.3 PendingMutationLocal / MutationQueueService

| Soubor | Řádky | Pattern | Kontext |
|--------|-------|---------|---------|
| `widgets/add_absence_dialog.dart` | 181-189 | `MutationQueueService.instance.enqueueMutation` | Fallback při síťové chybě – **OK** |
| `utils/cash_collection_dialog.dart` | 122-127 | `CashWalletRepository.instance.recordCashCollection()` | Repository má interní offline fallback (viz CashWalletRepository) |
| `widgets/add_company_expense_dialog.dart` | 139 | `CashWalletRepository.instance.recordCompanyExpense()` | Repository má interní offline fallback |

### 1.4 Screens await remote before UI update?

| Screen | Await remote? | Poznámka |
|--------|---------------|----------|
| `WorkerDashboardScreen` | N/A (read) | Čte z Isar přes workerTasksProvider – **OK** |
| `WorkerTaskDetailScreen` | N/A | Čte z Isar – **OK** |
| `WorkerWalletScreen` | N/A | Čte Supabase stream – offline prázdné/chyba |
| `CheckinTaskScreen` | Ano | `maybeShowCashCollectionDialog` → `recordCashCollection` (try-first, offline → queue) |
| `TransferTaskScreen` | Ano | Stejné jako Check-in |
| `CleaningTaskScreen` | Ano | Stejné |
| `AddAbsenceDialog` | Ano | Try Supabase, catch → enqueue – **OK** |
| `IssueReporterDialog` | Ano | **PROBLÉM**: Awaituje Supabase insert, žádný offline fallback |

---

## 2. lib/features/tasks/

### 2.1 Supabase Direct Calls

| Soubor | Řádky | Pattern | Kontext |
|--------|-------|---------|---------|
| *Žádný přímý Supabase v tasks/* | – | – | Tasks feature na mobilu používá pouze Isar |

### 2.2 Isar použití

| Soubor | Řádky | Pattern | Kontext |
|--------|-------|---------|---------|
| `providers/task_detail_provider_mobile.dart` | 22-23, 63-64, 82-83 | `isar.taskLocals.getSync()`, `isar.apartmentLocals`, `isar.taskLocals.put()` | Čtení i zápis detailu úkolu v Isar – **OK** |

**Poznámka:** `task_detail_provider.dart` je podmíněný export – na mobilu se používá `task_detail_provider_mobile.dart` (Isar), na webu `task_detail_provider_web.dart` (Supabase).

---

## 3. lib/features/finance/ (a finance-related)

*Poznámka: Samostatná složka `lib/features/finance/` neexistuje. Finance logika je v `lib/features/admin/providers/finance_cash_provider.dart` a `lib/core/repositories/cash/`.*

### 3.1 Supabase Direct Calls

| Soubor | Řádky | Pattern | Kontext |
|--------|-------|---------|---------|
| `admin/providers/finance_cash_provider.dart` | 28-29, 64-66 | `CashWalletRepository.watchWalletsRaw()` | Interně Supabase `.stream()` – **PROBLÉM** pro worker offline |
| `admin/providers/finance_cash_provider.dart` | 105-107, 126-128 | `watchTransactionsRawForWallet()` | Supabase stream – **PROBLÉM** offline |
| `admin/providers/finance_cash_provider.dart` | 154-158 | `.from('tasks').select()` | Admin: načtení úkolů pro failed cash – OK (admin je online) |
| `admin/providers/finance_cash_provider.dart` | 222-226, 297-299 | `.from('tasks').select()` | Admin – OK |
| `admin/providers/finance_cash_provider.dart` | 314-316 | `.from('tasks').update()` | Admin: resolve failed collection – OK |
| `admin/providers/finance_cash_provider.dart` | 151-158 | `SupabaseService.client.from('tasks').select()` | `_enrichTransactions` – **PROBLÉM**: Worker Wallet screen volá provider, který při enrichi volá Supabase |

### 3.2 Worker-consumed finance

| Provider | Zdroj dat | Offline? |
|----------|-----------|----------|
| `myCashWalletProvider` | `CashWalletRepository.watchWalletsRaw()` → Supabase stream | **NE** – offline prázdné |
| `myCashTransactionsProvider` | `watchTransactionsRawForWallet()` → Supabase stream + `_enrichTransactions` (Supabase select tasks) | **NE** – offline prázdné |

---

## 4. lib/core/database/

### 4.1 Isar

| Soubor | Pattern | Kontext |
|--------|---------|---------|
| `isar_service.dart` | Schema (TaskLocal, ApartmentLocal, ReservationLocal, atd.) | **OK** – obsahuje PendingMutationLocal |
| `models/pending_mutation_local.dart` | `PendingMutationLocal` | Fronta offline mutací |
| `models/task_local.dart` | `TaskLocal` | Lokální model úkolu |

### 4.2 PendingMutationLocal queue

| Soubor | Řádky | Pattern | Kontext |
|--------|-------|---------|---------|
| `offline/mutation_queue_service_mobile.dart` | 34-40 | `PendingMutationLocal()`, `isar.pendingMutationLocals.put()` | Zápis do fronty |
| `offline/mutation_queue_service_mobile.dart` | 60-70, 112, 137-138 | `isar.pendingMutationLocals.filter().findAll()`, `delete()` | Čtení a mazání po odeslání |
| `offline/offline_cash_collection_processor.dart` | 34 | `CashWalletRepository.recordCashCollection` | Zpracování OFFLINE_CASH_COLLECTION z fronty – **OK** |
| `offline/offline_company_expense_processor.dart` | 31 | `CashWalletRepository.recordCompanyExpense` | Zpracování OFFLINE_COMPANY_EXPENSE – **OK** |

---

## 5. CashWalletRepository – shrnutí

| Metoda | Supabase direct? | Offline fallback? |
|--------|------------------|-------------------|
| `recordCashCollection` | Ano (lines 54-93) | Ano – catch → enqueueMutation OFFLINE_CASH_COLLECTION |
| `recordCompanyExpense` | Ano (lines 147-184) | Ano – catch → enqueueMutation OFFLINE_COMPANY_EXPENSE |
| `receiveCashFromWorker` | Ano | **NE** – admin only, předpokládá online |
| `watchWalletsRaw` | Supabase `.stream()` | **NE** – žádná Isar alternativa |
| `watchTransactionsRaw` | Supabase `.stream()` | **NE** |
| `watchTransactionsRawForWallet` | Supabase `.stream()` | **NE** |
| `fetchWalletsForTenant` | Supabase select | **NE** – admin only |

---

## 6. expected_amount v CashCollectionDialog / recordCashCollection

| Místo | Řádky | Kontext |
|-------|-------|---------|
| `cash_collection_dialog.dart` | 36-39, 126 | `plannedAmount` z `detail.metadata['amount_to_collect']` → předáno jako `expectedAmount` do `recordCashCollection` – **OK** |
| `cash_wallet_repository.dart` | 83 | `if (expectedAmount != null && expectedAmount > 0) 'expected_amount': expectedAmount` – ukládá se do transakce – **OK** |
| `offline_cash_collection_processor.dart` | 28-31, 38 | Čte `expected_amount` z payloadu fronty a předává do `recordCashCollection` – **OK** |
| `MutationQueueService` payload | 114-115 | CashWalletRepository při enqueue předává `expected_amount` v payload – **OK** |

**Shrnutí:** `expected_amount` je v offline flow správně předávané a ukládané.

---

## 7. Read-only task locking

| Místo | Kontext |
|-------|---------|
| `admin/admin_tasks_screen.dart` | `isReadOnly = _normalizeToSystemStatus(task.status) == 'completed'` – blokace editace dokončených úkolů |
| `admin/admin_reservation_forms.dart` | `isReadOnly` pro checked_out rezervace |
| `owner/owner_planning_calendar_screen.dart` | Read-only kalendář |

**Poznámka:** „Read-only task locking“ není v Worker UI implementováno – worker může dokončovat a měnit úkoly. Locking je v Admin pro dokončené úkoly. Žádná speciální Isar nebo offline logika pro locking nebyla nalezena v worker/tasks/finance/core.

---

## 8. Task completion flow

| Krok | Implementace | Offline? |
|------|--------------|----------|
| Start úkolu | `TaskRepositoryMobile.updateTaskStatus` → Isar put, syncStatus=pending | **ANO** |
| Dokončení bez fotek | Isar put, syncStatus=pending, WorkerSyncService push | **ANO** |
| Dokončení s fotkami | **PROBLÉM**: TaskRepositoryMobile (179-218) volá Supabase přímo – `mediaUrls != null` branch | **NE** – vyžaduje síť |
| Cash collection před dokončením | CashWalletRepository.recordCashCollection – try Supabase, catch → queue | **ANO** |
| Reservation status (checked_in/out) | Isar ReservationLocal put, syncStatus=pending | **ANO** |

---

## 9. Prioritní problémy (offline-first gaps)

1. **IssueReporterDialog** – přímý Supabase insert bez offline fallbacku.
2. **Worker Absences** – `worker_absences_provider` čte ze Supabase; absence se offline nenačtou.
3. **Worker Wallet screen** – `myCashWalletProvider`, `myCashTransactionsProvider` používají Supabase stream; offline prázdné/chyba.
4. **Task completion s fotkami** – při `mediaUrls.isNotEmpty` TaskRepositoryMobile volá Supabase přímo místo Isar + sync.
5. **_enrichTransactions** – při zobrazení transakcí na Worker Wallet screen se volá Supabase select na tasks; offline selže.

---

## 10. Doporučení

1. **IssueReporterDialog**: Přidat offline fallback – při `MutationQueueService.isNetworkError(e)` ukládat payload do fronty a zobrazit snackbar „Záznam uložen do fronty“.
2. **worker_absences_provider**: Na mobilu číst z Isar (StaffAbsenceLocal, pokud existuje) nebo cache; případně akceptovat prázdný seznam offline.
3. **Worker Wallet**: Zvážit Isar cache pro employee_cash_wallets a employee_cash_transactions (sync při online) nebo explicitní offline stav UI.
4. **Task completion s fotkami**: Při offline ukládat cesty k lokálním souborům, při sync nahrát a aktualizovat metadata.
5. **_enrichTransactions**: Při offline používat lokální data (např. TaskLocal) místo Supabase select.
