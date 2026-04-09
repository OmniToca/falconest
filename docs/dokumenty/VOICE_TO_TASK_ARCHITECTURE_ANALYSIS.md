# Architektonická analýza: AI Hlasové zadávání úkolů (Voice-to-Task)

**Datum:** 1. března 2025  
**Kontext:** Killer feature pro Worker App – pracovník stiskne mikrofon, namluví problém (např. „V koupelně protéká záchod, je nutná oprava“) a systém vytvoří strukturovaný úkol. Striktní pravidlo: **Offline-first**.

---

## 1. UMÍSTĚNÍ V UI (Worker App)

### 1.1 Aktuální stav

| Komponenta | Umístění | Kontext |
|------------|----------|---------|
| **Worker Dashboard** | `lib/features/worker/screens/worker_dashboard_screen.dart` | Hlavní obrazovka „Moje práce“. AppBar (refresh, sync), Drawer, Column s offline/sync bannery a RefreshIndicator. **Žádný FAB**. |
| **Issue Reporter** | `lib/features/worker/widgets/issue_reporter_dialog.dart` | Otevírá se z **detailu úkolu** – IconButton `report_problem_outlined` v AppBar. Vyžaduje `tenantId` a `apartmentId` z kontextu aktuálního úkolu. |
| **Task detail screens** | `cleaning_task_screen`, `checkin_task_screen`, `checkout_task_screen`, `transfer_task_screen`, `maintenance_task_screen`, `issue_task_screen`, `default_task_screen`, `material_task_screen` | Všechny mají tlačítko pro hlášení závady – předávají `detail.apartmentId`. |

**Klíčové zjištění:** Hlášení závady je v současnosti vázané na kontext apartmánu z otevřeného úkolu. Pracovník musí být v detailu úkolu konkrétního bytu, aby mohl nahlásit problém.

### 1.2 Doporučená umístění mikrofonu

| Varianta | Umístění | UX | Kontext apartment_id |
|----------|----------|-----|----------------------|
| **A) FAB na Dashboardu** | FloatingActionButton v pravém dolním rohu `WorkerDashboardScreen` | Globální přístup odkudkoliv. Po stisku otevře bottom sheet s mikrofonoem. | **Potřeba výběru**: Pracovník vybere byt z dropdownu (seznam apartmánů tenanta) NEBO systém nabídne „Poslední byt“ (z naposledy zobrazeného úkolu v session). |
| **B) Mikrofon v IssueReporterDialog** | Nahradit/doplnit TextField – ikona mikrofonu vedle textového pole | Pracovník může místo psaní stisknout mikrofon a namluvit popis. | Již máme – `apartmentId` z předchozího kontextu (otevřený úkol). |
| **C) Položka v Draweru** | Nová položka „Hlásit závadu“ nebo „Hlasové hlášení“ | Otevře flow: 1) Výběr bytu, 2) Nahrávání hlasu. | Explicitní výběr bytu v prvním kroku. |

**Doporučení pro MVP:**  
- **Varianta B** jako první krok – rozšíření stávajícího `IssueReporterDialog` o tlačítko mikrofonu vedle TextFieldu. Kontext bytu už je, flow je minimálně invazivní.  
- **Varianta A** jako druhá fáze – globální FAB na dashboardu s výběrem „Poslední byt“ nebo explicity vybraný byt.

### 1.3 UX při nahrávání (doporučený design)

```
┌─────────────────────────────────────────┐
│  🎤 Hlasové hlášení závady              │
├─────────────────────────────────────────┤
│  [████████████████████░░░░] Návrat       │  ← Animace pulsujícího mikrofono
│                                         │
│  "V koupelně protéká záchod..."         │  ← Přepis v reálném čase (speech_to_text)
│                                         │
│  [Zrušit]              [Potvrdit]       │
└─────────────────────────────────────────┘
```

- **Bottom sheet** nebo rozšířený dialog s velkým tlačítkem mikrofonu.
- **Live přepis:** `speech_to_text` streamuje `onResult` → Text widget se aktualizuje v reálném čase.
- **Tlačítko Potvrdit:** Odešle přepis dál (offline fronta nebo Edge Function).
- **Indikátor nahrávání:** Pulsující kruh / změna barvy mikrofono při aktivním nahrávání.

---

## 2. OFFLINE-FIRST LOGIKA

### 2.1 Jak funguje ukládání úkolů offline (stávající architektura)

| Komponenta | Soubor | Účel |
|------------|--------|------|
| **MutationQueueService** | `lib/core/offline/mutation_queue_service.dart` (export), `mutation_queue_service_mobile.dart` | Mobilní implementace – deleguje na `DriftMutationQueueService`. Provider vrací instanci. |
| **DriftMutationQueueService** | `lib/core/offline/drift_mutation_queue_service.dart` | Implementace přes Drift (SQLite). `enqueueMutation(table, action, payload)` zapisuje do `pending_mutations`. `processQueue()` prochází frontu a volá specializované processory. |
| **DriftPendingMutationRepository** | `lib/core/database/drift/repositories/drift_pending_mutation_repository.dart` | Repozitář pro tabulku `pending_mutations` – `enqueue`, `getAllOrderedByCreatedAt`, `deleteById`. |
| **Offline Issue Processor** | `lib/core/offline/offline_issue_task_processor.dart` | `processOfflineIssueTask(payload)` – při action `OFFLINE_ISSUE_TASK` provede `SupabaseService.client.from('tasks').insert(payload)`. |
| **NetworkSyncWatcher** | `lib/core/offline/network_sync_watcher.dart` | Poslouchá `isOfflineProvider`. Při přechodu **OFFLINE → ONLINE** volá: `pushPendingUpdates` (úkoly, rezervace), `processPendingAuditActions`, **`mutationQueueServiceProvider.processQueue()`**. |

**Payload pro OFFLINE_ISSUE_TASK** (z `issue_reporter_dialog.dart`):
```dart
{
  'id': uuid,
  'tenant_id': tenantId,
  'apartment_id': apartmentId,
  'reference_number': generateTaskRef(),
  'task_type': 'issue',
  'status': 'pending',
  'title': 'Hlášení závady',
  'description': desc,  // Text z TextField
  'created_by': profileId,
  'due_date': dueIso,
  'scheduled_start': dueIso,
  'local_updated_at': dueIso,
  'metadata': {},
  'media_urls': [],
}
```

Fotky se při offline neukládají – vyžadují upload do Supabase Storage. Hlášení závady offline tedy proběhne bez fotek.

### 2.2 Návrh toku dat pro Voice-to-Task (Offline-first)

```
┌──────────────┐     ┌───────────────────┐     ┌─────────────────────────────┐
│ Stisk        │────▶│ speech_to_text     │────▶│ Syrový text (raw_transcript) │
│ mikrofonu    │     │ (lokálně, offline)  │     │                              │
└──────────────┘     └───────────────────┘     └───────────────┬───────────────┘
                                                               │
                                    ┌──────────────────────────┴──────────────────────────┐
                                    │                                                      │
                                    ▼                                                      ▼
                          ┌─────────────────┐                                    ┌─────────────────┐
                          │ ONLINE          │                                    │ OFFLINE        │
                          │                 │                                    │                 │
                          │ POST Edge Fn    │                                    │ enqueueMutation │
                          │ voice-to-task   │                                    │ action:         │
                          │ {raw_transcript,│                                    │ OFFLINE_VOICE_  │
                          │  apartment_id,  │                                    │ TASK            │
                          │  tenant_id,     │                                    │ payload:        │
                          │  profile_id}    │                                    │ {raw_transcript,│
                          └────────┬────────┘                                    │  apartment_id,  │
                                   │                                             │  tenant_id,     │
                                   ▼                                             │  profile_id}    │
                          ┌─────────────────┐                                    └────────┬────────┘
                          │ Edge Function   │                                             │
                          │ LLM → task      │                                             │
                          │ insert tasks    │                                             │
                          └────────┬────────┘                                             │
                                   │                                                      │
                                   │                                              [Čeká na síť]
                                   │                                                      │
                                   │                                    NetworkSyncWatcher│
                                   │                                    offline → online  │
                                   │                                                      │
                                   │                                    processQueue()    │
                                   │                                    └─────────────────┘
                                   │                                             │
                                   │                                    processOfflineVoiceTask()
                                   │                                    → POST Edge Fn se stejnými parametry
                                   │
                                   ▼
                          ┌─────────────────┐
                          │ tasks.insert()   │
                          │ v Supabase       │
                          └────────┬────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │ Worker Sync     │
                          │ pull tasks      │
                          │ → Drift SQLite  │
                          └─────────────────┘
```

### 2.3 Konkrétní kroky implementace (logika, ne kód)

1. **Lokální přepis:** Balíček `speech_to_text` – `SpeechToText().listen(onResult: ...)`. Funguje offline (on-device mode).
2. **Online větev:** Po dokončení nahrávání a potvrzení – pokud `!isOffline` → volání Edge Function `voice-to-task` s `raw_transcript`, `apartment_id`, `tenant_id`, `profile_id`. Edge Function vrátí vytvořený úkol.
3. **Offline větev:** Pokud `MutationQueueService.isNetworkError(e)` (nebo explicitní `isOffline`) → `enqueueMutation(table: 'tasks', action: 'OFFLINE_VOICE_TASK', payload: {raw_transcript, apartment_id, tenant_id, profile_id, locale, created_at})`.
4. **Nový offline processor:** `processOfflineVoiceTask(payload)` – volá stejnou Edge Function `voice-to-task` s obsahem payloadu. Po úspěchu smaže mutaci z fronty.
5. **ProcessQueue rozšíření:** V `DriftMutationQueueService.processQueue()` přidat `case 'OFFLINE_VOICE_TASK': await processOfflineVoiceTask(payload);`.

**Důležité:** Strukturovaný úkol (title, description, task_type) vzniká až na serveru v LLM. Offline fronta drží pouze syrový přepis – žádná lokální LLM inference (to by vyžadovalo on-device model, což je jiný scope).

---

## 3. EDGE FUNKCE A DATABÁZE

### 3.1 Co musí mobil poslat na server

| Parametr | Typ | Povinný | Účel |
|----------|-----|---------|------|
| `tenant_id` | UUID | Ano | Multi-tenant izolace, RLS. |
| `apartment_id` | UUID | Ano | Úkol je vázaný na byt. Bez bytu nelze správně zařadit úkol. |
| `profile_id` | UUID | Ano | `created_by` – kdo úkol vytvořil. Pro audit. |
| `raw_transcribed_text` | string | Ano | Syrový přepis z speech_to_text. Vstup pro LLM. |
| `locale` | string | Ne | cs/en/es – pro lokalizaci LLM odpovědi a promptů. |
| `media_urls` | string[] | Ne | Pokud pracovník přidal fotky před/during/after nahrávání (volitelné rozšíření). |

### 3.2 Návrh Edge Function `voice-to-task`

**Vstup (POST body):**
```json
{
  "tenant_id": "uuid",
  "apartment_id": "uuid",
  "profile_id": "uuid",
  "raw_transcribed_text": "V koupelně protéká záchod, je nutná oprava.",
  "locale": "cs"
}
```

**LLM prompt (pseudokód):**
- Systémový prompt: „Jsi asistent pro property management. Z přepisu hlasu pracovníka v terénu vytvoř strukturovaný záznam úkolu. Výstup: JSON s title, description, task_type (issue/maintenance/cleaning/other).“
- User prompt: raw_transcribed_text + kontext (apartment_id pro log, tenant pro kontext).
- Parsing odpovědi LLM → `{ title, description, task_type }`.

**Výstup Edge Function:**
```json
{
  "task": {
    "id": "uuid",
    "title": "Oprava protékajícího záchodu",
    "description": "V koupelně protéká záchod. Nutná oprava.",
    "task_type": "issue",
    "reference_number": "TSK-XXX",
    ...
  },
  "error": null
}
```

**Akce na serveru:**
1. Volání LLM API (OpenAI / Anthropic / local).
2. INSERT do `tasks` s vygenerovanými hodnotami.
3. Vrácení vytvořeného záznamu klientovi.

### 3.3 Schéma tabulky `tasks` (relevantní sloupce)

| Sloupec | Typ | Poznámka |
|---------|-----|----------|
| id | uuid | PK, generované |
| tenant_id | uuid | NO |
| apartment_id | uuid | YES (NULL = úkol bez bytu) |
| assigned_to | uuid | YES – NULL = nepřiřazeno (pro hlášení závady typicky NULL, dispečer přiřadí) |
| task_type | text | issue, maintenance, cleaning, … |
| title | text | |
| description | text | |
| status | text | pending / assigned / in_progress / completed |
| scheduled_start | timestamptz | NO – použít např. now() |
| due_date | text | |
| created_by | uuid | profile_id reportéra |
| reference_number | text | generateTaskRef() na serveru |
| metadata | jsonb | {} |
| media_urls | text[] | [] |
| local_updated_at | timestamptz | |
| deleted_at | timestamptz | NULL |
| invoiced_at | timestamptz | NULL |

Žádné nové sloupce nejsou potřeba – Voice-to-Task zapisuje do stávající tabulky `tasks`.

---

## 4. PROPSÁNÍ HOTOVÉHO ÚKOLU ZPĚT DO MOBILU

### 4.1 Aktuální sync flow

| Krok | Komponenta | Činnost |
|------|------------|---------|
| 1 | `WorkerSyncService.syncTasksFromSupabase` | `pushPendingUpdates` (odeslání lokálních změn), pak SELECT z Supabase `tasks` WHERE `tenant_id` = X AND `assigned_to` = workerId AND … |
| 2 | `_clearAndWrite` | Vymazání lokálních dat v Drift a zápis nových (tasks, apartments, reservations, clients). |
| 3 | `workerTasksProvider` | Načítá úkoly z Drift přes `DriftTaskRepository` / `workerTasksProvider`. |
| 4 | `RefreshIndicator` / `runSync()` | Uživatel zatáhne pro refresh nebo `NetworkSyncWatcher` spustí sync při návratu online. |

**Důležité:** Sync stahuje pouze úkoly kde `assigned_to = workerId`. Úkoly typu `issue` vytvořené hlasem typicky nemají `assigned_to` (čekají na přiřazení dispečerem). Do Worker dashboardu se tedy nově vytvořený úkol **nepropíše**, pokud není přiřazen konkrétnímu pracovníkovi.

### 4.2 Možnosti pro Voice-to-Task

| Strategie | Popis | Dopad |
|-----------|-------|-------|
| **A) Přiřadit reportérovi** | Edge Function nastaví `assigned_to = profile_id` (pracovník, který hlásí). | Úkol se objeví v „Moje práce“ po syncu. Pracovník vidí vlastní hlášení jako úkol (např. k doplnění fotek). |
| **B) Nepřiřazeno** | `assigned_to = null` | Úkol jde pouze do Admin plachty. Worker ho neuvidí – konzistentní s ručním hlášením závady. |
| **C) Konfigurovatelné** | Tenant setting „Přiřadit hlasové hlášení reportérovi“ | Flexibilita dle zákazníka. |

**Doporučení:** Pro „killer“ zážitek **Strategie A** – pracovník po nahrání hlasu uvidí úkol u sebe po syncu (pull-to-refresh nebo návrat online). Edge Function by měla nastavit `assigned_to: profile_id`.

### 4.3 Sekvence událostí (celý flow)

```
1. Pracovník v bytu X, otevře úkol ( cleaning / check-in / … )
2. Stiskne "Hlásit závadu" → IssueReporterDialog (apartment_id = X)
3. Stiskne mikrofon → speech_to_text nahrává
4. "V koupelně protéká záchod" → přepis v reálném čase
5. Potvrdí

   [ONLINE]
   → POST voice-to-task { raw_transcript, apartment_id, tenant_id, profile_id }
   → Edge Fn: LLM → INSERT tasks (assigned_to = profile_id)
   → Response: { task: { id, ... } }
   → Lokálně: ref.invalidate(workerTasksProvider) + runSync()
   → Drift se naplní novým úkolem
   → UI: úkol se objeví v seznamu po refresh

   [OFFLINE]
   → enqueueMutation(OFFLINE_VOICE_TASK, { raw_transcript, apartment_id, tenant_id, profile_id })
   → SnackBar "Hlášení bude odesláno po připojení"
   → Pracovník pokračuje v práci

6. Pracovník se vrátí online (Wi‑Fi, mobilní data)
7. NetworkSyncWatcher: processQueue()
8. processOfflineVoiceTask() → POST voice-to-task (stejný payload)
9. Edge Fn vytvoří úkol
10. Při příštím runSync() (refresh / auto) se úkol stáhne do Drift
11. workerTasksProvider zobrazí nový úkol v "Moje práce"
```

---

## 5. SHRNUTÍ A DOPORUČENÍ

| Oblast | Shrnutí |
|--------|---------|
| **UI** | Varianta B (mikrofon v IssueReporterDialog) jako MVP. Později FAB na dashboardu s výběrem bytu. |
| **Přepis** | `speech_to_text` lokálně, offline. |
| **Offline fronta** | Nová akce `OFFLINE_VOICE_TASK`, nový processor `processOfflineVoiceTask`, který volá Edge Function. |
| **Edge Function** | `voice-to-task` – input: raw_transcript, apartment_id, tenant_id, profile_id; LLM → title, description, task_type; INSERT tasks. |
| **Přiřazení** | `assigned_to = profile_id` (reportér) pro okamžitou viditelnost v Worker App. |
| **Sync** | Stávající `WorkerSyncService.syncTasksFromSupabase` + Drift – nový úkol se objeví po syncu. |

**Technické dluhy / rizika:**
- Závislost na LLM API (náklady, latence, dostupnost).
- `speech_to_text` vyžaduje oprávnění mikrofonu a správné nastavení pro offline režim.
- Bez sítě nelze vytvořit strukturovaný úkol – pouze uložit přepis do fronty a zpracovat po připojení.
