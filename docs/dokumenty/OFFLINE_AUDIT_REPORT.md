# Hloubkový audit – Aktuální stav Offline-First architektury FalcoNest

**Datum:** Únor 2025  
**Typ:** READ-ONLY analýza – žádný vývoj, pouze inventarizace  
**Rozsah:** `core/`, `core/database/`, `features/*/repositories`, `features/*/providers`

---

## 1. Lokální databáze (Isar)

### 1.1 Jaké tabulky (kolekce) už máme v Isaru

| Kolekce | Soubor | Stav |
|---------|--------|------|
| **TaskLocal** | `core/database/models/task_local.dart` | ✅ Implementováno |
| **ApartmentLocal** | `core/database/models/apartment_local.dart` | ✅ Implementováno |
| **ReservationLocal** | `core/database/models/reservation_local.dart` | ✅ Implementováno |
| **PendingAuditAction** | `core/database/models/pending_audit_action.dart` | ✅ Implementováno |

**Co v Isaru chybí (ale existuje v Supabase):**

- **Profiles** – není lokální kolekce (profil se cachuje v SharedPreferences přes `ProfileCacheService` při startu aplikace)
- **Zones** – žádná lokální kolekce; admin čte přímo ze Supabase
- **Tenants, tenant_modules, tenant_services** – vše ze Supabase
- **apartment_owners** – ze Supabase
- **staff_absences, employee_cash_wallets** – ze Supabase
- **invitations, audit_logs** – ze Supabase (fetch) / PendingAuditAction jen pro restore/hard_delete akce

### 1.2 Sloupce pro offline synchronizaci v modelech

| Model | localUpdatedAt | lastSyncedAt | syncStatus | is_dirty / pending_action |
|-------|----------------|--------------|-------------|---------------------------|
| **TaskLocal** | ✅ | ✅ | ✅ (synced/pending) | ❌ – místo toho `syncStatus` |
| **ApartmentLocal** | ✅ | ✅ | ✅ | ❌ |
| **ReservationLocal** | ✅ | ❌ (jen `lastUpdated`) | ✅ | ❌ |
| **PendingAuditAction** | ❌ (místo toho `createdAtUtc`) | ❌ | ✅ | ❌ |

**Závěr:** Všechny lokální modely mají sloupce pro Timestamp Merging (`localUpdatedAt`, `lastUpdated`) a stav synchronizace (`syncStatus`). `is_dirty` není – místo toho se používá `SyncStatus.pending`.

---

## 2. Čtení dat (Read Path)

### 2.1 Co čte z Isaru (Single Source of Truth na mobilu)

| Komponenta | Zdroj | Scope |
|------------|-------|-------|
| **TaskRepositoryMobile** | Isar (taskLocals, apartmentLocals) | Úkoly přiřazené pracovníkovi |
| **todaysTasksProvider** (mobil) | Isar | Dnešní úkoly (legacy route) |
| **workerTasksProvider** | `getTaskRepository()` → na mobilu Isar | Worker dashboard – seznam úkolů |
| **workerTaskDetailProvider** | `getTaskRepository()` → na mobilu Isar | Detail úkolu v Worker flow |
| **taskDetailProvider** (mobil) | Isar (taskLocals, apartmentLocals) | Legacy TaskDetailScreen (Isar ID) |
| **WorkerSyncService** | Isar | Čtení pending záznamů pro push |
| **AuditLogRepository** (mobil) | Isar (pendingAuditActions) | Restore/hard_delete fronta |

### 2.2 Co čte přímo ze Supabase (obejití Isaru)

| Komponenta | Tabulka | Poznámka |
|------------|---------|----------|
| **admin_tasks_provider** | tasks, apartments, apartment_services | Admin modul – vždy Supabase |
| **admin_reservations_provider** | reservations | Admin modul |
| **apartments_provider** | apartments | Admin modul |
| **planning_calendar_provider** | tasks | Admin plánovací kalendář |
| **owner_* providers** | apartment_owners, apartments, tasks, reservations | Klientský portál – vždy Supabase |
| **admin_team_provider** | profiles, staff_absences | Admin tým |
| **worker_absences_provider** | staff_absences | Worker – Moje nepřítomnost (čte ze Supabase) |
| **zones_provider** | zones | Zóny |
| **tenant_services_provider** | tenant_services | Služby tenanta |
| **finance_*, wallet_*** | reservations, tasks, tenant_wallets, employee_cash_* | Finance moduly |
| **WorkerSyncService.syncTasksFromSupabase** | tasks, apartments, reservations | Stahuje data do Isaru – zdroj pro Worker |
| **AuditLogRepository** | profiles, audit_logs | Fetch logů – Supabase |
| **auth_notifier** | profiles, tenants | Načtení profilu |

**Závěr:** **Pouze Worker flow** (úlohy přiřazené pracovníkovi) čte z Isaru. Admin, Owner portál, Super Admin a všechny ostatní moduly čtou výhradně ze Supabase. Při offline jsou tyto obrazovky nepoužitelné (dotazy selžou na SocketException).

---

## 3. Zápis dat (Write Path) a fronta

### 3.1 Worker – odškrtnutí úkolu / změna stavu

**Co se stane v kódu:**

1. **WorkerTaskStatusNotifier.updateStatus()** → volá `TaskRepositoryMobile.updateTaskStatus()`.
2. **TaskRepositoryMobile**:
   - Najde úkol v Isar podle `tenantId` + `supabaseId`.
   - Aktualizuje `status`, `startedAt`, `completedAt`, `syncStatus = pending`, `localUpdatedAt`, `lastUpdated`.
   - Pro Check-in/Check-out zároveň aktualizuje `ReservationLocal` (status checked_in/checked_out, syncStatus = pending).
3. **WorkerTaskStatusNotifier** poté volá `WorkerSyncService.pushPendingUpdates()` (async, „fire and forget“).

**Offline:** Zápis jde pouze do Isaru (lokální DB). `pushPendingUpdates` při offline selže na Síťové chybě, ale data zůstanou v Isaru se stavem `pending`. Nic se neztratí.

### 3.2 Worker – fronta pending změn

- **Existuje:** Ano – `TaskLocal.syncStatus == pending` a `ReservationLocal.syncStatus == pending`.
- **Odeslání:** `WorkerSyncService.pushPendingUpdates()` a `pushPendingReservationUpdates()`.
- **Kdy se volá:**  
  - Při změně stavu úkolu (v `WorkerTaskStatusNotifier` po úspěšném uložení do Isaru).  
  - Při ručním refreshi (`runSync()` na Worker dashboard).  
  - **Automaticky při návratu sítě:** Ano – `NetworkSyncWatcher` poslouchá `isOfflineProvider` a při přechodu OFFLINE → ONLINE volá `_triggerAutoSync()` → `pushPendingUpdates()`.

### 3.3 Admin – zápis úkolů, rezervací, bytů

| Akce | Zdroj | Offline chování |
|------|-------|------------------|
| Vytvoření/úprava úkolu | `SupabaseService.client.from('tasks').insert/update` | ❌ Selže – SocketException, data se ztratí |
| Vytvoření/úprava rezervace | `SupabaseService.client.from('reservations')` | ❌ Selže |
| Vytvoření/úprava bytu | `SupabaseService.client.from('apartments')` | ❌ Selže |
| Vytvoření zóny | `SupabaseService.client.from('zones')` | ❌ Selže |

**Fronta (PendingMutation):** Neexistuje. Žádná offline fronta pro admin operace. Při offline se volá přímo Supabase a operace selže.

### 3.4 Super Admin – Audit log (restore / hard delete)

- **AuditLogRepository (mobil):**  
  - `restore()` / `hardDelete()` zapisují do `PendingAuditAction` (Isar) s `syncStatus = pending`.  
  - Následně se volá `processPendingAuditActions()` – pokus o odeslání do Supabase.
- **Offline:** Záznam zůstane v `PendingAuditAction` jako pending.
- **Automaticky při návratu sítě:** Ano – `NetworkSyncWatcher._triggerAutoSync()` volá `AuditLogRepository.processPendingAuditActions()`.

---

## 4. Synchronizační engine

### 4.1 Existující služba

**WorkerSyncService** (mobilní implementace v `worker_sync_service_mobile.dart`):

- **syncTasksFromSupabase()** – stáhne úkoly, byty a rezervace ze Supabase a zapíše je do Isaru.
- **pushPendingUpdates()** – odešle pending změny stavů úkolů do Supabase.
- **pushPendingReservationUpdates()** – odešle pending změny stavů rezervací.
- **getPendingSyncCount()** – vrací počet záznamů čekajících na odeslání (pro UI).

### 4.2 Kdy se sync spouští

| Akce | Kdy |
|------|-----|
| **syncTasksFromSupabase** | Při otevření Worker dashboardu (`initState` → `runSync()`), při pull-to-refresh. |
| **pushPendingUpdates** | Po každé změně stavu úkolu v Worker (updateStatus); **při návratu sítě** (NetworkSyncWatcher). |
| **processQueue** (MutationQueue) | **Při návratu sítě** (NetworkSyncWatcher). |
| **processPendingAuditActions** | Při `restore()` / `hardDelete()`; **při návratu sítě** (NetworkSyncWatcher). |

### 4.3 Connectivity Listener – ✅ IMPLEMENTOVÁNO

**NetworkSyncWatcher** (`lib/core/offline/network_sync_watcher.dart`):

- **Umístění:** Obaluje celou aplikaci v `lib/app.dart` (FalcoNestApp).
- **Mechanika:** Poslouchá `isOfflineProvider` (Stream z `Connectivity().onConnectivityChanged`).
- **Trigger:** Při přechodu **OFFLINE → ONLINE** zavolá `_triggerAutoSync()`.
- **_triggerAutoSync()** (pořadí):
  1. **WorkerSyncService.pushPendingUpdates(tenantId)** – odešle pending úkoly a rezervace z Isaru do Supabase.
  2. **AuditLogRepository.processPendingAuditActions()** – odešle pending restore/hard_delete akce.
  3. **MutationQueueService.processQueue()** – odešle univerzální frontu mutací (např. Issue Reporter, offline Cash Collection, Admin úkoly).

- **isOfflineProvider** (`lib/core/providers/connectivity_provider.dart`): Stream z `connectivity_plus`, vrací `true` když `ConnectivityResult.none`.

**Poznámka:** `syncTasksFromSupabase` (stahování dat) se při návratu sítě nevolá automaticky – spouští se jen při otevření dashboardu nebo pull-to-refresh. Odeslání pending změn (upload) je plně automatické.

### 4.4 Audit log – PendingAuditAction

- **processPendingAuditActions()** – projde pending záznamy a pokusí se je odeslat.
- **Kdy se volá:** Při každém `restore()` nebo `hardDelete()` v AuditLogRepository; **při návratu sítě** z NetworkSyncWatcher.

---

## 5. Shrnutí – stav architektury

| Oblast | Stav | Poznámka |
|--------|------|----------|
| **Worker – čtení** | ✅ Offline-first | Isar jako zdroj dat pro úkoly/byty/rezervace |
| **Worker – zápis** | ✅ Offline-first | Zápis do Isaru + pending fronta |
| **Worker – sync** | ✅ Implementováno | NetworkSyncWatcher při návratu sítě volá pushPendingUpdates |
| **Connectivity listener** | ✅ Implementováno | NetworkSyncWatcher + isOfflineProvider |
| **Admin modul** | ❌ Online-only | Všechny providery čtou/zapisují přímo do Supabase |
| **Owner portál** | ❌ Online-only | Přímo Supabase |
| **Super Admin** | ❌ Online-only | Kromě PendingAuditAction |
| **Profil při startu** | ✅ Opraveno | ProfileCacheService – fallback při offline |
| **Audit log restore/delete** | ✅ Implementováno | PendingAuditAction + auto-sync při reconnect |

---

## 5.1 Komponenty – SyncStatusIcon

**Umístění:** `lib/core/widgets/sync_status_icon.dart`

**Účel:** Vizuální indikátor stavu synchronizace v AppBar. Uživatel (uklízečka, řidič) vidí na první pohled, zda jsou data synchronizována, čekají offline, nebo právě probíhá odesílání.

**Stavy:**
- **Synced** (cloud_done, zelená): Online, fronta prázdná, sync neběží
- **Offline & Pending** (cloud_off + badge s počtem, oranžová): Offline s položkami ve frontě (MutationQueueService)
- **Syncing** (cloud_sync, modrá): Právě běží pushPendingUpdates nebo processQueue

**Providery:** `syncStatusProvider` (StreamProvider), `syncInProgressProvider` (StateProvider)

**Integrace:** WorkerDashboardScreen, CleaningTaskScreen (a další Worker task screens dle potřeby)

---

## 6. Doporučené směry pro plánování oprav

1. ~~**Connectivity listener**~~ – ✅ **HOTOVO.** NetworkSyncWatcher poslouchá isOfflineProvider a při OFFLINE→ONLINE volá pushPendingUpdates, processPendingAuditActions, processQueue.
2. **Admin offline** – buď akceptovat online-only, nebo navrhnout rozšíření Isaru o apartments/reservations/tasks pro admin a odpovídající sync engine.
3. **Owner portál** – stejná úvaha jako u Admin (offline vs. rozsah implementace).
4. ~~**Audit pending reconnect**~~ – ✅ **HOTOVO.** processPendingAuditActions je součástí _triggerAutoSync.
