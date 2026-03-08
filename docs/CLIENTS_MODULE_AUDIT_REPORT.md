# Audit modulu Klienti (Adresář klientů / Externí agentury) – FalcoNest

**Datum auditu:** 3. 3. 2025  
**Rozsah:** modul Klienti (Admin) – načítání, CRUD, detail klienta, i18n.

---

## 1. KAPACITA A VÝKON (1000+ klientů)

### Jak je aktuálně řešen výpis klientů?

- **Zdroj dat:** `clientsProvider` v `lib/features/admin/providers/clients_provider.dart`.
- **Dotaz:** Jeden **neomezený** SELECT na tabulku `clients`:
  - `eq('tenant_id', tenantId)`
  - `isFilter('deleted_at', null)`
  - `order('name')`
  - **Žádný `.limit()`** – načítají se **všichni** klienti tenanta najednou.

### Stránkování a vyhledávání

- **Stránkování:** **Neexistuje.** Celý seznam se stáhne při otevření obrazovky Klienti a drží se v paměti (FutureProvider vrací `List<ClientModel>`).
- **Vyhledávání:** Pouze **na klientu** (v UI). V `admin_clients_screen.dart` metoda `_computeFiltered()` filtruje již načtený seznam podle textu z `TextField` (jméno, email, telefon). Do Supabase se při psaní neposílá žádný dotaz.

### Rizika při 1000+ klientech

| Aspekt | Stav | Riziko |
|--------|------|--------|
| Počet řádků v jednom requestu | Všichni klienti | Velký payload, pomalý první load, vyšší paměť na zařízení. |
| Realtime / invalidace | Při změně se invaliduje celý `clientsProvider` | Znovu se stáhnou všichni klienti. |
| Dropdowny (např. „Doporučující agentura“, výběr klienta u úkolu) | Berou data z `clientsProvider` | Stejný plný seznam; s 1000+ položkami může být dropdown nepohodlný. |

**Shrnutí bodu 1:** Výpis klientů **není připraven na 1000+ záznamů**. Chybí **pagination** (např. cursor/offset na backendu), **server-side vyhledávání** (fulltext nebo filtr `ilike` na `name`/`email`/`phone`) a **limit** v základním dotazu. Při růstu dat hrozí pomalé načítání a vyšší spotřeba paměti.

---

## 2. CRUD A DATA (Detail klienta, mazání, historie)

### Co v detailu klienta lze dělat a vidět?

Detail je realizován v **`ClientDetailDialog`** (`client_detail_dialog.dart`). Taby se mění podle **`client_type`**:

| Typ klienta | Taby v detailu |
|-------------|-----------------|
| **owner** (Majitel) | Přehled, Apartmány, Rezervace, Úkoly |
| **agency** (Agentura) | Přehled, Adresář (adresy pro transfery), Doporučení klienti, Úkoly |
| **external** (Externí) | Přehled, Úkoly |

**Přehled:** e-mail, telefon, typ klienta; u majitele navíc stav portálu (čeká na aktivaci / aktivní, zvací odkaz, poslední přihlášení) a počet apartmánů; u externího – doporučující agentura.

**Apartmány (majitel):** Seznam bytů z `apartmentsForProfileProvider(client.profileId!)`, tlačítko „Přidat apartmán“, klik na řádek → úprava bytu.

**Rezervace (majitel):** `clientReservationsProvider(client.id)` – rezervace přes byty přiřazené majiteli; přidání / úprava rezervace.

**Úkoly:** `clientTasksProvider(client.id)` – u majitele úkoly na jeho bytech, u externího/agentury úkoly s `client_id`; přidání / úprava úkolu.

**Adresář (agentura):** Adresy z `clientAddressesProvider(client.id)`, přidání / soft delete adresy.

**Doporučení klienti (agentura):** Externí klienti s `agency_id` = tato agentura.

### Mazání klienta (Soft Delete)

- **Ano.** V obrazovce seznamu je u každé karty ikona koše; po potvrzení v dialogu se volá **`softDeleteClientProvider`**, který nastaví `deleted_at` v tabulce `clients`.
- **Archivace:** Není oddělená od „smazání“. Jediný stav je „aktivní“ (deleted_at IS NULL) vs „smazaný“. Není zde koncept „archivovaný“ (např. neaktivní, ale zobrazený v archivu).
- V **detailu klienta** tlačítko pro smazání **není** – smazat lze jen ze seznamu (karta → koš).

### Historie a propojení s moduly

| Oblast | V detailu klienta |
|--------|-------------------|
| **Apartmány (majitel)** | Ano – záložka Apartmány, počet v Přehledu. |
| **Rezervace** | Ano – záložka Rezervace (majitel). |
| **Úkoly** | Ano – záložka Úkoly. |
| **Settlements / výplaty / faktury** | **Ne.** V modulu Klienti ani v detailu klienta není záložka ani odkaz na vyplacení, faktury nebo souhrn plateb vázaných na klienta (např. úkoly s `client_id` a jejich vyplacení v rámci Settlements). |

**Shrnutí bodu 2:**  
- CRUD je pokryt (vytvoření, úprava, **soft delete** ze seznamu).  
- **Archivace** jako samostatný stav chybí.  
- V detailu **chybí propojení na modul Settlements** (faktury, výplaty vázané na klienta).  
- V detailu chybí možnost klienta přímo smazat (soft delete) – pouze ze seznamu.

---

## 3. i18n (Lokalizace)

### UI – obrazovka a dialogy

- **admin_clients_screen.dart**, **client_detail_dialog.dart**, **client_form_dialog.dart** používají **`.tr()`** a klíče z `assets/translations` (např. `clients.title`, `clients.tab_owners`, `clients.delete_confirm`, `clients.portal_pending` atd.).  
- Tlačítka, labely, prázdné stavy, potvrzení mazání – **vše je napojeno na i18n klíče.**  
- Pro mazání se používá i klíč z jiného modulu: `admin.apartments_delete` (titulek dialogu a tlačítko „Smazat“) – funkčně OK, ideálně mít vlastní `clients.delete` pro konzistenci.

### Hardcoded české texty

- **clients_provider.dart:** Všechny výjimky pro programátora jsou **česky** a neprocházejí i18n:
  - `'Žádný tenant v kontextu – nelze přidat klienta.'`
  - `'Klient musí patřit aktuálnímu tenantovi.'`
  - `'Klient bez ID nelze aktualizovat.'`
  - `'Žádný tenant v kontextu.'`
  - `'Nelze smazat klienta bez ID.'`
- **client_repository.dart:** Stejně **české StateError** zprávy:
  - `'Tenant ID je povinný pro přidání adresy.'`
  - `'Client ID je povinný pro přidání adresy.'`
  - `'Label (název) adresy nesmí být prázdný.'`
  - `'Adresa nesmí být prázdná.'`
  - `'Tenant ID je povinný pro smazání adresy.'`
  - `'Nelze smazat adresu bez ID.'`
- **client_detail_dialog.dart:** V `_taskStatusKey()` jsou v kódu české varianty statusů (`'návrh'`, `'nový'`, `'zadáno'`, `'probíhá'`, `'hotovo'`, `'dokončeno'`, `'problém'`) – slouží k mapování z DB na i18n klíč; pokud backend může vracet i české hodnoty, je to záměr, ale jsou to hardcoded stringy v kódu.
- **Komentáře v kódu** jsou česky (dle pravidel projektu) – to se do i18n neřeší.

**Shrnutí bodu 3:**  
- **UI je z ~100 % napojené na lokalizační klíče** (cs/en/es).  
- **Výjimky (StateError)** v `clients_provider.dart` a `client_repository.dart` jsou **natvrdo česky** – při zobrazení uživateli (např. v SnackBaru po chybě) by měly jít přes `.tr()`.  
- Drobně: opakované použití `admin.apartments_delete` v modulu Klienti; v detailu chybí vlastní klíč pro „Smazat klienta“.

---

## Doporučení pro B2B SaaS standard

### Akutní (výkon a škálovatelnost)

1. **Pagination na seznamu klientů**  
   - Na backendu (Supabase) zavést stránkování: např. `.range(from, to)` nebo cursor-based (např. `created_at` + `id`) s rozumným limitem (50–100 na stránku).  
   - V UI: buď „Načíst další“, nebo stránkovací ovládání.

2. **Server-side vyhledávání**  
   - Při vyhledávání (TextField) neposílat celý seznam, ale dotaz s filtrem: např. `.or('name.ilike.%query%,email.ilike.%query%,phone.ilike.%query%')` a opět s limitem/pagination.  
   - Případně fulltext na `name`/`email`/`phone` (PostgreSQL), pokud bude potřeba.

3. **Limit v základním dotazu**  
   - Alespoň dočasně přidat `.limit(500)` (nebo podobně) do `clientsProvider`, aby náhodný velký tenant nenačetl desetitisíce řádků najednou. Po zavedení pagination limit upravit podle velikosti stránky.

### CRUD a detail klienta

4. **Settlements / finance v detailu klienta**  
   - Přidat záložku (nebo sekci) „Vyplacení / Faktury“ nebo „Finance“ pro klienta: seznam vyplacení nebo úkolů s výplatami vázaných na `client_id` (z modulu Settlements), aby dispečer viděl historii plateb u externího klienta/agentury.

5. **Soft delete z detailu**  
   - V detailu klienta umožnit akci „Smazat klienta“ (s potvrzením), která volá `softDeleteClientProvider` a zavře dialog – konzistentní s mazáním ze seznamu.

6. **Archivace (volitelně)**  
   - Zvážit stav „archivovaný“ (např. `archived_at` nebo příznak) oddělený od soft delete: archivovaní klienti se v defaultním seznamu neukazují, ale jsou dostupní v „Archivu“ a záznamy (úkoly, rezervace) zůstávají vázané.

### i18n

7. **Převést StateError zprávy na i18n**  
   - V `clients_provider.dart` a `client_repository.dart` nemít české stringy v `throw StateError(...)`. Buď používat kódy a v UI mapovat na klíče (např. `clients.error_no_tenant`), nebo před throw sestavit zprávu z `'clients.error_*'.tr()` a tu předat dál (např. do SnackBaru).  
   - Přidat odpovídající klíče do `cs.json` / `en.json` / `es.json`.

8. **Vlastní klíče pro mazání v modulu Klienti**  
   - Např. `clients.delete` (tlačítko) a `clients.delete_confirm` (již existuje) – titulek dialogu mazání používat `clients.delete` místo `admin.apartments_delete`.

---

**Konec reportu.**  
Pro implementaci změn lze postupovat po bodech (nejdřív pagination + vyhledávání + limit, potom Settlements v detailu a i18n u výjimek).
