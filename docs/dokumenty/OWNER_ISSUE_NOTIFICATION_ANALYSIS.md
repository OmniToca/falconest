# Upozornění agentury na nové hlášení závady od majitele – analýza a návrh

**Datum:** 2026-03-09  
**Účel:** Zjistit stávající notifikační systém a navrhnout nejčistší způsob notifikace adminů při vložení úkolu typu „závada“ od majitele.

---

## 1. DATABÁZE A BACKEND

### 1.1 Tabulka pro notifikace

- **Tabulka `notifications`** v projektu **existuje a používá se**. Není v aktuálně prohledaných migracích (pravděpodobně starší migrace nebo jiný název souboru), ale z kódu vyplývá struktura:
  - **Sloupce:** `id`, `tenant_id`, `profile_id`, `title`, `message`, `type` (volitelný), `is_read`, `created_at`.
  - **Sémantika:** Jeden záznam = jedna notifikace pro jednoho příjemce (`profile_id`) v rámci agentury (`tenant_id`). Zvoneček v UI čte řádky pro aktuální `profile_id` a zobrazuje nepřečtené (`is_read = false`).
  - **RLS:** Uživatel vidí jen notifikace, kde `profile_id` = jeho profil a kontext tenantu odpovídá JWT (viz `NotificationRepository`).

### 1.2 Jak se notifikace dnes vytvářejí

- **Žádný databázový trigger** na tabulce `tasks` ani na `notifications` v migracích nebyl nalezen.
- **Žádná Supabase Edge Function** negeneruje záznamy do `notifications` při událostech v `tasks`.
- Notifikace se **vytvářejí z Flutter klienta** po úspěšné akci:
  - **AbsenceNotificationService:** po INSERT do `staff_absences` (worker pošle žádost o absenci) načte adminy/managery tenantu (`profiles` kde `tenant_id` a `role IN ('admin','manager')`), pro každého vloží řádek do `notifications` (title, message, type: `'absence'`).
  - **CashWalletRepository._sendAdminNotification:** po výběru hotovosti / firemním výdaji načte adminy tenantu a vloží do `notifications` (title, message, type např. `'finance_shortfall'` nebo `'finance'`).

Shrnutí: **všechny notifikace pro adminy jdou z klienta** – po úspěšném INSERT do jiné tabulky se zavolá služba, která načte `profile_id` adminů/manažerů daného `tenant_id` a provede INSERT do `notifications`.

### 1.3 Související tabulky

- **notification_preferences** – preference uživatele (ranní souhrn, upozornění před úkolem, nový úkol přiřazen). Pro „zvoneček“ není nutné je při vkládání notifikace řešit (zvoneček zobrazuje vše; preference mohou být využity např. pro FCM).
- **user_devices** – FCM tokeny zařízení pro push notifikace (samostatná vrstva oproti in-app zvonečku).

---

## 2. FLUTTER APLIKACE

### 2.1 Zvoneček v UI

- **Kde:** `lib/features/admin/admin_layout.dart` (Top Bar).
- **Provider:** `unreadNotificationsProvider` (StreamProvider) – závisí na `authNotifierProvider.state.profileId`, volá `NotificationRepository.watchUnreadNotifications(profileId)`.
- **Chování:** Stream z Supabase na tabulku `notifications` s filtrem `profile_id`; v UI se zobrazuje počet nepřečtených a po kliknutí dropdown se seznamem (title, message, typ, tlačítko „Přečíst vše“). Po označení přečteno se volá `markAsRead` / `markAllAsRead`.

### 2.2 Push notifikace (FCM)

- **Používáme:** Ano – `PushNotificationService` (Firebase Cloud Messaging), registrace FCM tokenu do `user_devices` po přihlášení (pro uživatele s tenantem).
- **Vztah k zvonečku:** Zvoneček = in-app tabulka `notifications`. Push = doručení na zařízení (FCM). Pro „nová závada od majitele“ stačí zatím **pouze záznam do `notifications`** – admin uvidí položku ve zvonečku. Rozšíření o FCM (odeslání push na zařízení adminů) lze přidat později (např. cron nebo Edge Function čtoucí `notifications` a posílající FCM).

---

## 3. NÁVRH ELEGANTNÍHO ŘEŠENÍ

### 3.1 Dva možné přístupy

| Přístup | Popis | Výhody | Nevýhody |
|--------|--------|--------|----------|
| **A) Klient (Flutter)** | Po úspěšném INSERT do `tasks` v `owner_report_issue_dialog.dart` zavolat službu, která načte adminy tenantu a vloží záznamy do `notifications`. | Konzistentní s absencí a finance notifikacemi; žádná změna DB; rychlá implementace. | Pokud by někdo vložil úkol z jiného klienta nebo SQL, admin by notifikaci nedostal (u nás ale závady vkládá jen náš dialog). |
| **B) Backend (DB trigger)** | Trigger `AFTER INSERT ON tasks` kde `task_type = 'maintenance'` a `created_by IS NOT NULL`: funkce načte adminy z `profiles` a vloží řádky do `notifications`. | Jediné místo pravdy; notifikace vznikne vždy při vložení úkolu-závady bez ohledu na klienta. | Nutnost migrace, testování triggeru, mírně složitější ladění. |

### 3.2 Doporučení: **přístup A (klient)**

- V projektu už **všechny podobné notifikace** (absence, finance) řeší klient po úspěšné akci.
- **Závady** vkládá výhradně náš Flutter dialog (`owner_report_issue_dialog.dart`); jiné vstupy do `tasks` s `task_type = 'maintenance'` a `created_by` od majitele se neočekávají.
- **Konzistence:** Stejný vzor jako `AbsenceNotificationService` – jedna služba „notify admins about X“, volaná po úspěšném INSERT.
- **Žádná změna schématu** – pouze nová služba (nebo rozšíření stávající) a jedno volání z dialogu.

Pokud v budoucnu budete chtít „notifikace vždy při každém INSERTu z jakéhokoli zdroje“, lze doplnit trigger (přístup B) a z klienta volání služby odstranit.

---

## 4. PŘESNÝ POSTUP PRO IMPLEMENTACI (PŘÍSTUP A)

1. **Nová služba (doporučené jméno):**  
   `lib/core/services/owner_issue_notification_service.dart`  
   - Statická metoda např. `notifyAdminsAboutNewOwnerIssue({ required String tenantId, required String taskTitle, String? apartmentName })`.  
   - Logika (stejná jako u absence/finance):
     - Načíst z `profiles` všechny `id` kde `tenant_id = tenantId` a `role IN ('admin', 'manager')` a `deleted_at IS NULL`.
     - Pro každý `profile_id` sestavit payload: `tenant_id`, `profile_id`, `title`, `message`, `type: 'owner_issue'` (nebo `'maintenance_request'`).
     - Jeden hromadný `SupabaseService.client.from('notifications').insert(payloads)`.
   - Title/message: použít i18n klíče (např. `admin.notification_owner_issue_title`, `admin.notification_owner_issue_message`) s parametry (název závady, příp. byt). Stejně jako u absence.

2. **Volání z dialogu:**  
   V `owner_report_issue_dialog.dart` v metodě `_submit()` **po úspěšném** `insert` do `tasks` (a před `Navigator.of(context).pop(true)`):
   - Zavolat `OwnerIssueNotificationService.notifyAdminsAboutNewOwnerIssue(tenantId: tenantId, taskTitle: title, apartmentName: … )`.  
   - `apartmentName` lze dohledat z `widget.apartments` podle `apartmentId` (nebo předat jen `taskTitle` a byt nepovinně).  
   - Volání obalit do try/catch a při chybě **neblokovat** uzavření dialogu (stejně jako u absence – notifikace je „nice to have“).

3. **Překlady:**  
   Do `assets/translations/` (cs, en, es) přidat klíče např. pod `admin`:  
   - `notification_owner_issue_title` (např. „Nová závada od majitele“),  
   - `notification_owner_issue_message` (např. „{title}“ nebo „{title} – byt {apartmentName}“).

4. **Zvoneček a typ notifikace:**  
   Stávající UI v `admin_layout.dart` zobrazuje notifikace podle `type` (např. pro finance se používá speciální zpráva). Pro `owner_issue` stačí zobrazit `title` a `message` stejně jako u ostatních typů; případně v dropdownu přidat ikonu nebo štítek pro „Závada od majitele“ podle `type == 'owner_issue'`.

5. **RLS:**  
   INSERT do `notifications` z klienta musí být povolen pro role, které vkládají úkoly – majitel (property_owner) vkládá úkol a hned potom notifikace. Je potřeba ověřit, že RLS na `notifications` umožňuje INSERT řádků, kde `profile_id` je **jiný** než aktuální uživatel (admin), protože vkládá majitel a `profile_id` v řádcích budou admini.  
   → Pokud RLS vyžaduje `profile_id = auth.uid()` nebo ekvivalent, majitel by nemohl vložit notifikace pro adminy. V tom případě bude nutné:
   - buď **trigger (přístup B)** – notifikace vloží backend pod kontextem vlastníka záznamu (např. service role nebo SECURITY DEFINER funkce, která vloží za majitele),  
   - nebo **RLS policy** umožňující majiteli (property_owner) INSERT do `notifications` s `tenant_id` odpovídajícím jeho bytům a `profile_id` v rámci tohoto tenantu (např. pouze role admin/manager).  
   RLS na `notifications` je nutné v migracích dohledat a podle toho buď upravit policy, nebo zvolit trigger.

---

## 5. RLS NA TABULCE `notifications` (DOPLNĚNÍ)

V prohledaných migracích **nebyla nalezena** definice tabulky `notifications` ani její RLS policy. Před implementací doporučuji v Supabase Dashboard (SQL Editor) nebo v migračních souborech ověřit:

- Existuje-li policy **INSERT** na `notifications` a za jakých podmínek (kdo smí vkládat a s jakým `profile_id`).
- Pokud smí vkládat pouze příjemce sám sebe (`profile_id = current profile`), majitel **nemůže** vložit notifikace pro adminy – pak je **nutné řešení B (trigger)** nebo úprava RLS tak, aby property_owner mohl vložit notifikaci s `profile_id` z téhož tenantu (admin/manager).

---

## 6. SHRNUTÍ

| Bod | Zjištění |
|-----|----------|
| **DB – tabulka** | `notifications` s sloupci `tenant_id`, `profile_id`, `title`, `message`, `type`, `is_read`, `created_at`. |
| **DB – triggery** | Žádný trigger na `tasks` pro vytváření notifikací. |
| **Vytváření notifikací** | Z Flutter klienta po úspěšném INSERT (absence, finance). |
| **UI zvoneček** | Admin layout, `unreadNotificationsProvider` → `NotificationRepository.watchUnreadNotifications(profileId)`. |
| **FCM** | Používá se (PushNotificationService, user_devices). Pro zvoneček stačí záznam do `notifications`. |
| **Doporučení** | **Přístup A (klient):** nová služba `OwnerIssueNotificationService.notifyAdminsAboutNewOwnerIssue(...)` volaná z `owner_report_issue_dialog.dart` po úspěšném INSERT do `tasks`. Před implementací ověřit RLS na `notifications` (kdo smí INSERT a s jakým `profile_id`); při nevyhovující RLS zvolit trigger (přístup B). |

Po odsouhlasení tohoto postupu lze napsat konkrétní kód (služba, volání v dialogu, i18n, případně migrace pro trigger nebo RLS).
