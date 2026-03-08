# Audit modulu Personál (Zaměstnanci / Team) – FalcoNest

**Datum auditu:** 3. 3. 2025  
**Rozsah:** modul Personál (Admin) – načítání seznamu, CRUD, mazání, kaskáda na úkoly a finance, detail člena, i18n.

---

## 1. KAPACITA A VÝKON (50+ zaměstnanců)

### Jak se aktuálně načítá seznam personálu?

- **Zdroj:** `adminTeamProvider` v `lib/features/admin/providers/admin_team_provider.dart`.
- **Typ:** Jeden **FutureProvider&lt;List&lt;TeamMember&gt;&gt;** – načítá **všechny** záznamy najednou.
- **Dotaz:** Jeden SELECT na tabulku **`profiles`**:
  - `.eq('tenant_id', tenantId)`
  - `.isFilter('deleted_at', null)`
  - `.neq('role', 'super_admin')`
  - `.order('status')`
  - **Žádný `.limit()` ani `.range()`** – načítají se všichni členové tenanta (aktivní i pending) v jednom kroku.

### Vyhledávání

- **Pouze na klientu.** V `admin_team_screen.dart` metoda **`_computeFiltered()`** filtruje již načtený seznam podle textu z vyhledávacího pole (jméno, role – včetně přeložených názvů rolí). Do Supabase se při psaní neposílá žádný dotaz.

### Srovnání s moduly Klienti a Apartmány

- U **Klientů** i **Apartmánů** byl zaveden stránkovaný provider (limit 50, offset) a server-side vyhledávání (ilike).  
- Modul **Personál** je stále v původním stavu: **žádný limit**, **žádná paginace**, **žádné server-side vyhledávání**. Při 50+ zaměstnancích hrozí zbytečně velký první load a vyšší paměťová stopa.

**Shrnutí bodu 1:** Seznam personálu **není připraven na škálování**. Chybí limit v dotazu, paginace a server-side vyhledávání. Doporučuje se sjednotit přístup s moduly Klienti a Apartmány (např. PaginatedTeamNotifier + teamFullListProvider pro dropdowny).

---

## 2. CRUD A OCHRANA DAT (Kritické závislosti)

### Mazání člena (Soft Delete) / Odebrání přístupu

- **Ano.** V seznamu je u každé karty akce **Smazat**; po potvrzení v dialogu **`_DeleteConfirmDialog`** se volá **`_doDelete()`**, která:
  - **Pending (pozvánka):** u záznamu v **`profiles`** nastaví **`deleted_at`**; u **`invitations`** buď `deleted_at` (pokud sloupec existuje), nebo fyzický DELETE.
  - **Aktivní člen:** u **`profiles`** nastaví **`deleted_at`** a **`tenant_id = null`** (konzistence s vyloučením z tenanta).
  - Zapisuje záznam do **Enterprise Audit Logu** (SOFT_DELETE, tabulka profiles).
  - Následně volá **`_unassignTasksForMember(ref, member.id, fromDate: DateTime.now())`** – odpojí člena pouze od **budoucích** nedokončených úkolů.

### Kaskáda na úkoly

- **Co se děje:** `_unassignTasksForMember` vybere úkoly, kde `assigned_to = memberId` NEBO `assigned_user_ids` obsahuje memberId, **stav není Hotovo/Completed**, a **due_date >= fromDate** (zde od „teď“). U těchto úkolů provede **UPDATE**: `assigned_to = null`, `assigned_user_id = null`.
- **Problém 1 – sloupec:** V DB existuje **`assigned_user_ids`** (pole UUID), nikoli `assigned_user_id`. Update tedy **nemaže** spolupracovníka z pole `assigned_user_ids` – u sdílených úkolů zůstane bývalý člen v poli a úkol zůstane částečně přiřazen „smazanému“ profilu.
- **Problém 2 – minulé úkoly:** Odpojení se volá pouze s `fromDate: DateTime.now()`. **Minulé a dnešní nedokončené úkoly** zůstávají s `assigned_to = memberId`. V UI se pak u těchto úkolů bere jméno z `nameByProfileId` (adminTeamProvider); smazaný člen v seznamu už není → **jméno bude chybět** (null / prázdné). Aplikace by měla všude používat fallback (např. „Odstraněný člen“ / zkrácené UUID), jinak hrozí prázdný label nebo chyba.
- **Shrnutí:** Kaskáda na úkoly je **částečná**: pouze budoucí nedokončené se odpojí a navíc **assigned_user_ids** se při mazání člena nečistí.

### Peníze (Peněženka, Settlements)

- **Peněženka (employee_cash_wallets):** Řádky mají **`profile_id`** (FK na profiles). Při **soft delete** se řádek v `profiles` nemazání fyzicky, takže FK zůstává platná. `CashWalletRepository.fetchWalletsForTenant` dělá JOIN na `profiles(name, first_name, last_name)`. Po soft delete (tenant_id=null, deleted_at vyplněn) záleží na RLS: pokud tenant neuvidí „cizí“ profil, join může vrátit prázdné jméno – v kódu je fallback **`workerName = '—'`**, takže **pád by neměl nastat**, ale peněženka odstraněného zaměstnance zůstane v DB a může se zobrazit s „—“.
- **Settlements / task_payouts:** Tabulka **task_payouts** má **`profile_id` REFERENCES profiles(id) ON DELETE RESTRICT****. Fyzický DELETE profilu by DB zakázala; při **soft delete** řádek profilu zůstává, takže **žádná DB kaskáda** ani RESTRICT se nespustí. V aplikaci se u výplat jména typicky berou z mapy odvozené od **adminTeamProvider** (nebo obdobně). Smazaný člen v týmu už v mapě není → u jeho výplat může UI zobrazit prázdné jméno nebo fallback. Nutné ověřit, že všude existuje **null-safe fallback** (např. „Odstraněný zaměstnanec“ / ID), aby nedošlo k null reference v modulu Vyúčtování.
- **Shrnutí:** Z hlediska DB **nedojde** k pádu kvůli RESTRICT ani CASCADE. Riziko je v **UI**: pokud se někde předpokládá, že každé `profile_id` z payoutů/wallet má záznam v aktuálním seznamu týmu a bere se bez fallbacku, může dojít k prázdnému zobrazení nebo chybě. Doporučuje se explicitní fallback pro neexistující/odstraněný profil všude, kde se zobrazuje jméno.

### Detail / Profil zaměstnance

- **„Detail“ = dialog pro úpravu** (**`_EditMemberDialog`**). Není samostatná obrazovka „Profil zaměstnance“.
- **Obsah:** Dvě záložky – **Základní informace** (jméno, příjmení, e-mail, úvazek, datum nástupu/odchodu, systémová role, pracovní pozice, preferované oblasti) a **druhá záložka** (doplňující nastavení). Na **kartě člena** v seznamu je ještě **`_MemberCardExtra`**: kapacita (vytížení tento týden / příští týden), počet aktivních úkolů, nepřítomnosti.
- **Chybí v „detailu“ (edit dialogu):**
  - **Historie úkolů** – seznam úkolů přiřazených tomuto zaměstnanci (minulé i budoucí), s možností přejít na úpravu úkolu. Obdoba záložky Úkoly u klienta/bytu.
  - **Peníze / Peněženka** – přehled nevybrané hotovosti (balance) a odkaz na výběr nebo na modul Peněženky.
  - **Vyplacené částky (Settlements)** – přehled schválených výplat a provizí vázaných na tohoto zaměstnance (obdoba záložky Finance u klienta).

**Shrnutí bodu 2:**  
- **Soft delete je implementovaný** (profiles + invitations), včetně audit logu.  
- **Kaskáda na úkoly:** pouze budoucí nedokončené se odpojují; **assigned_user_ids** se při mazání neaktualizuje (použit nesprávný název sloupce `assigned_user_id`). Minulé úkoly zůstávají přiřazené smazanému profilu – v UI musí být fallback pro chybějící jméno.  
- **Finance:** DB nevytváří pád; nutné ověřit fallbacky u zobrazení jmen v Peněženkách a Vyúčtování.  
- **Detail:** Chybí záložky Úkoly, Peněženka a Finance (vyplacené částky).

---

## 3. i18n (Lokalizace)

### Kde jsou hardcoded české texty?

- **admin_team_provider.dart:**
  - **`print('--- CHYBA PARSOVÁNÍ ČLENA TÝMU: $e');`** (v cyklu parsování profilů).
  - **`print('--- CHYBA NAČÍTÁNÍ TÝMU: $e');`** (v catch bloku provideru).
- **admin_team_screen.dart:**
  - **`print('--- CHYBA MAZÁNÍ ČLENA TÝMU: $e');`** (v catch po _doDelete).
  - **`throw PostgrestException(message: 'Profil nebyl vytvořen', code: '500', details: 'internal');`** (v _AddMemberDialog při prázdném profileId po insertu).
  - **`print('--- CHYBA UKLÁDÁNÍ (Tým): $e');`** (při přidání člena).
  - **`print('--- CHYBA ÚPRAVY ČLENA TÝMU: $e');`** (v catch po úpravě člena).

Ostatní UI (tlačítka, labely, prázdné stavy, validace) používá **`.tr()`** a klíče z překladů. Chybové hlášky zobrazené uživateli (SnackBar) jsou buď obecné (`common.error_with_message`), nebo již lokalizované (např. `admin.team_validation_roles_required`). Problém jsou **výjimky a printy** – české řetězce a absence i18n klíčů pro „Profil nebyl vytvořen“.

**Shrnutí bodu 3:**  
- **Většina UI je na i18n.**  
- **Hardcoded:** české **print** zprávy v provideru a v obrazovce; jedna **PostgrestException** s českým `message: 'Profil nebyl vytvořen'`. Doporučuje se nahradit klíči (např. `admin.team_error_profile_not_created`), printy odstranit nebo obalit `kDebugMode` a případně sjednotit jazyk logování.

---

## Doporučení: nejkritičtější vylepšení

### 1. Kaskáda při mazání člena a odpojení úkolů

- **Opravit update v `_unassignTasksForMember`:** Neměnit neexistující sloupec `assigned_user_id`, ale **aktualizovat `assigned_user_ids`** – odstranit dané `memberId` z pole (např. `array_remove` nebo načíst, odfiltrovat, uložit). Tím se u budoucích úkolů opraví i spolupracovníci.
- **Rozšířit rozsah odpojení (volitelně):** Zvážit odpojení **všech** nedokončených úkolů (včetně minulých), nejen od `fromDate: DateTime.now()`, aby v reportech a historii nebyl „sirotčí“ přiřazenec. Alternativně ponechat minulé přiřazené a **v celé aplikaci** (úkoly, výplaty, peněženky) **sjednotit fallback** pro neexistující/odstraněný profil (např. `admin.team_removed_member` nebo zkrácené UUID).

### 2. Finance a null-safety

- **Audit zobrazení jmen:** V modulu Peněženka (wallet list, detail transakcí) a v modulu Vyúčtování (Settlements, task_payouts, task_commissions) ověřit, že u každého `profile_id` je při chybějícím záznamu v týmu použit **jednoznačný fallback** (např. „Odstraněný zaměstnanec“ / ID), nikdy ne přímý přístup k null. Tím se předejde pádům při odebrání zaměstnance.

### 3. Kapacita a konzistence s ostatními moduly

- **Stránkování a server-side vyhledávání:** Zavést stejný vzor jako u Klientů a Apartmánů – např. **PaginatedTeamNotifier** (limit 50, offset, search query s ilike na name/email), **teamFullListProvider** (až 500 záznamů pro dropdowny a jiné moduly). Vyhledávací pole napojit na `search()` s debounce; seznam na nekonečný scroll s `loadMore()`. Tím se modul Personál připraví na 50+ zaměstnanců a sjednotí s ostatními B2B obrazovkami.

### 4. Detail zaměstnance (kontext)

- Do **`_EditMemberDialog`** (nebo do budoucí obrazovky „Profil zaměstnance“) doplnit záložky:
  - **Úkoly** – seznam úkolů přiřazených tomuto členovi (provider typu `tasksForTeamMemberProvider(profileId)`), s rozlišením aktivní / historie a tlačítkem „Zobrazit historii“, obdobně jako u klienta/bytu.
  - **Peněženka / Finance** – souhrn nevybrané hotovosti a přehled vyplacených částek (nebo odkaz na modul Vyúčtování filtrovaný na tohoto zaměstnance).  
Tím bude mít manažer kontext bez přepínání mezi moduly.

### 5. i18n

- **Chybové hlášky:** Zavést klíč např. `admin.team_error_profile_not_created` a používat ho místo `throw PostgrestException(message: 'Profil nebyl vytvořen', ...)`; v catch bloku při zobrazení uživateli volat `.tr()`.
- **Printy:** Odstranit nebo obalit do `if (kDebugMode) { ... }` a případně převést na anglické zprávy pro konzistenci logování.

---

**Konec reportu.**  
Pro implementaci doporučení dává smysl pořadí: nejdříve bod 1 (oprava kaskády a assigned_user_ids), pak bod 2 (audit fallbacků v finance), potom bod 3 (paginace a vyhledávání), bod 4 (záložky v detailu) a bod 5 (i18n).
