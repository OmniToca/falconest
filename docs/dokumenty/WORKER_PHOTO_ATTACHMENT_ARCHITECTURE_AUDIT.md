# Architektonická analýza: Logika přikládání fotografií k úkolům v mobilní aplikaci

**Datum:** 1. 3. 2026  
**Typ:** POUZE ANALÝZA – žádné úpravy kódu  
**Zamčený soubor:** `task_assignment_engine.dart` – NEDOTÝKAT  

**Kontext:** Majitel navrhl UX vylepšení – sekce pro fotky má být viditelná vždy (pracovník může zdokumentovat škodu i u úkolů bez povinné fotky). Dokončení má zůstat zablokované, pokud systém fotku vyžaduje a žádná není přiložena.

---

## 1. AUDIT SOUČASNÉHO STAVU UI A LOGIKY

### 1.1 Rozcestník a obrazovky podle typu úkolu

**Soubor:** `lib/features/worker/screens/worker_task_detail_screen.dart`

Detail úkolu je rozcestník – podle `task_type` se vykresluje jedna z MVP obrazovek:
- `transfer_in` / `transfer_out` → `TransferTaskScreen`
- `check_in` → `CheckinTaskScreen`
- `check_out` → `CheckoutTaskScreen`
- `issue` → `IssueTaskScreen`
- `cleaning` → `CleaningTaskScreen`
- `maintenance` → `MaintenanceTaskScreen`
- `material` → `MaterialTaskScreen`
- ostatní → `DefaultTaskScreen`

Všechny typy (Check-in, Transfer, Cleaning, Maintenance, Default, …) používají sdílenou komponentu **`TaskCompleteWithPhotoSection`**.

---

### 1.2 Podmíněné zobrazení sekce pro fotky

**Soubor:** `lib/features/worker/widgets/task_complete_with_photo_section.dart`  
**Řádky 89–100:**

```dart
if (isInProgress) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (requiresPhoto) ...[        // ← KRITICKÉ: Sekce fotek SE ZOBRAZÍ JEN KDYŽ requires_photo == true
        TaskPhotoUploader(
          onFilesChanged: _onFilesChanged,
          maxPhotos: 3,
          existingUrls: widget.detail.mediaUrls,
        ),
        const SizedBox(height: 16),
      ],
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: canComplete
              ? () => _onCompletePressed(context)
              : () => _showRequiresPhotoSnackBar(context),
          // ...
```

**Zjištění:** `TaskPhotoUploader` je vykreslen pouze pokud `requiresPhoto == true`.  
**Důsledek:** U úkolů bez `requires_photo` se sekce pro přidání fotky vůbec nezobrazí.

---

### 1.3 Validace tlačítka „Dokončit úkol“

**Soubor:** `lib/features/worker/widgets/task_complete_with_photo_section.dart`  
**Řádky 68–73:**

```dart
final requiresPhoto = widget.detail.metadata?['requires_photo'] == true;
final hasPhotos = _photoFiles.isNotEmpty || (widget.detail.mediaUrls.isNotEmpty);
final canComplete = !requiresPhoto || hasPhotos;
```

**Logika:**
- `canComplete = true`, pokud:
  - fotka není povinná **nebo**
  - existuje alespoň jedna fotka (nová nebo již nahraná)
- `canComplete = false` jen když `requiresPhoto == true` a žádná fotka není

**Chování tlačítka (ř. 104–106):**
- `onPressed: canComplete ? () => _onCompletePressed(context) : () => _showRequiresPhotoSnackBar(context)`
- `backgroundColor: canComplete ? _primaryBlue : Colors.grey.shade400`

Když `canComplete == false`:
1. Tlačítko je šedé.
2. Klik otevře SnackBar s textem `worker.requires_photo_snackbar`.

**Závěr:** Validace je správně implementovaná – při povinné fotce bez přiložené fotky není možné úkol dokončit.

---

## 2. DATABÁZE A MODELY

### 2.1 Schéma tabulky `tasks`

**Zdroj:** `database_schema.md`

| Sloupec     | Typ   | Popis                                                   |
|-------------|-------|---------------------------------------------------------|
| metadata    | jsonb | flexibilní data pro UI (např. amount_to_collect, poznámky) |
| media_urls  | text[]| URL fotek v Supabase Storage                            |
| photo_url   | text  | starší pole, volitelné                                  |

V `tasks` není sloupec `requires_photo` ani `is_photo_required`. Hodnota se odvozuje z **`metadata['requires_photo']`**.

### 2.2 Kde se bere `requires_photo`

**Kaskáda podle kontextu úkolu:**

1. **`tenant_services.requires_photo`** – výchozí hodnota z katalogu služeb  
2. **`apartment_services.requires_photo`** – override pro konkrétní byt  
3. **`reservation_services.requires_photo`** – override pro rezervaci  

Při vytváření úkolu se výsledná hodnota zapisuje do `tasks.metadata['requires_photo']` (viz `admin_tasks_provider.dart`, řádky 784–788, 1028–1041).

### 2.3 Mapování v Dart modelu

**Soubor:** `lib/core/repositories/task/task_repository.dart`  
**Třída:** `WorkerTaskDetail`

- `metadata` – `Map<String, dynamic>?` z `tasks.metadata`
- `mediaUrls` – `List<String>` z `tasks.media_urls`
- žádná samostatná property `isPhotoRequired` – používá se `detail.metadata?['requires_photo'] == true`

**Závěr:** Mapování je v pořádku, `requires_photo` se čte z `metadata`.

---

## 3. NÁVRH ŘEŠENÍ (Architektura)

### 3.1 Cílový stav

| Požadavek                     | Současný stav                         | Cílový stav                              |
|------------------------------|----------------------------------------|-----------------------------------------|
| Sekce fotek viditelná vždy   | Zobrazuje se jen při `requires_photo` | Vždy zobrazena při `status == in_progress` |
| Blokace dokončení            | Správně implementována                | Beze změny – zachovat současnou logiku   |
| Offline nahrávání            | Podporováno                           | Zachovat stávající flow                  |

### 3.2 Úprava UI – vždy zobrazit sekci fotek

**Soubor:** `task_complete_with_photo_section.dart`

**Aktuálně:**
```dart
if (requiresPhoto) ...[
  TaskPhotoUploader(...),
  const SizedBox(height: 16),
],
```

**Návrh:**
```dart
// Sekce fotek – vždy viditelná (povinná nebo volitelná dokumentace)
TaskPhotoUploader(
  onFilesChanged: _onFilesChanged,
  maxPhotos: 3,
  existingUrls: widget.detail.mediaUrls,
  isRequired: requiresPhoto,  // nový parametr – viz níže
),
const SizedBox(height: 16),
```

**Poznámka:** Parametr `isRequired` by mohl sloužit k odlišení labelů/hintů (např. „Přidej fotku (povinné)“ vs „Přidej fotku (volitelné)“).

### 3.3 Logika validace (beze změny)

```dart
final canComplete = !requiresPhoto || hasPhotos;
```

Tato logika zůstává stejná:
- `requiresPhoto == false` → dokončit lze vždy
- `requiresPhoto == true` a `hasPhotos == true` → dokončit lze
- `requiresPhoto == true` a `hasPhotos == false` → dokončit nelze (šedé tlačítko + SnackBar)

### 3.4 Možná vylepšení v `TaskPhotoUploader`

- Přidat parametr `isRequired: bool` pro různý text tlačítka/hintu.
- Rozšířit i18n o klíče jako `worker.task_photo_optional` a `worker.task_photo_required`.

---

## 4. OFFLINE NAHRÁVÁNÍ FOTEK

### 4.1 Aktuální flow

**Když upload selže (síťová chyba):**

1. `_onCompletePressed` zachytí výjimku (ř. 210).
2. Kontrola `MutationQueueService.isNetworkError(e)`.
3. Volání `_copyPhotosToPersistentStorage` – zkopírování fotek do `getApplicationDocumentsDirectory/offline_task_photos`.
4. Enqueue do mutation fronty s akcí `OFFLINE_TASK_COMPLETE_WITH_PHOTOS` a `local_photo_paths`.
5. Drift lokálně označí úkol jako dokončený.
6. Při dalším `processQueue` (online): `processOfflineTaskCompleteWithPhotos` nahraje fotky na Supabase Storage a aktualizuje `tasks.media_urls`.

**Zdroj:** `task_complete_with_photo_section.dart` (ř. 210–271), `offline_photo_task_processor.dart`, `drift_task_repository.dart`.

### 4.2 Důsledky pro návrh

- Offline flow je implementované a v pořádku.
- Změna „fotky vždy viditelné“ žádnou úpravu offline logiky nevyžaduje.
- Fotky se ukládají do lokální cache a synchronizují při návratu online.

---

## 5. SOUHRN A DOPORUČENÝ POSTUP

### 5.1 Shrnutí zjištění

| Oblast             | Stav |
|--------------------|------|
| Podmíněné zobrazení| `TaskPhotoUploader` jen při `requires_photo` – **změnit** |
| Validace dokončení | Správná – **zachovat** |
| Databáze           | `metadata['requires_photo']` – **beze změny** |
| Offline upload     | Podporován – **beze změny** |

### 5.2 Doporučené kroky implementace

1. **V `TaskCompleteWithPhotoSection`**
   - Odstranit podmínku `if (requiresPhoto)` kolem `TaskPhotoUploader`.
   - Vykreslovat `TaskPhotoUploader` vždy, když `isInProgress == true`.

2. **Volitelně v `TaskPhotoUploader`**
   - Přidat `isRequired: bool`.
   - Upravit text tlačítka/hintu podle povinnosti (např. přes i18n).

3. **Beze změny**
   - `canComplete = !requiresPhoto || hasPhotos`
   - Offline flow
   - Databázové schéma a mapování v modelech

### 5.3 Rizika a omezení

- Bez dalších úprav nelze rozlišit „povinná“ vs „volitelná“ fotka v UI.
- Změna je čistě UI – bez dopadu na API, databázi ani offline logiku.

---

*Konec auditního reportu.*
