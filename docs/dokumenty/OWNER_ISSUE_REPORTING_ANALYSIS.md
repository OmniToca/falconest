# Nahlášení závady majitelem (Owner Issue Reporting) – Analýza a návrh architektury

**Datum:** 2026-03-09  
**Účel:** Příprava na implementaci funkce „Nahlášení závady“ v Klientské zóně – pouze analýza, bez kódu.

---

## 1. STAV DATABÁZE

### 1.1 Tabulka `tasks` – co máme k dispozici

Systém **nepoužívá** samostatnou tabulku `issues` ani `maintenance_requests`. Vše běží přes jednotnou tabulku **`public.tasks`**.

**Sloupce relevantní pro „závadu od majitele“ (z migrací a Flutter modelu):**

| Sloupec | Typ | Poznámka |
|--------|-----|----------|
| `id` | uuid | PK |
| `tenant_id` | uuid | FK na tenants – agentura |
| `apartment_id` | uuid (nullable) | Byt, ke kterému se úkol vztahuje |
| `title` | text | Název úkolu |
| `description` | text | Popis (např. „Bliká žárovka“) |
| `status` | text | Stav: např. pending, in_progress, completed, draft |
| `task_type` | text | Typ úkolu – v kódu např. cleaning, check_in, check_out, **maintenance** (viz task_categories seed) |
| `due_date` | timestamptz | Termín |
| `scheduled_start` | timestamptz | Naplánovaný začátek |
| `assigned_to` | uuid | Přiřazený pracovník (profiles.id) |
| `assigned_user_ids` | uuid[] | Další přiřazení |
| **`created_by`** | **uuid (nullable)** | **FK na profiles.id – kdo úkol vytvořil (audit)** |
| `reservation_id` | uuid (nullable) | Rezervace (u závad typicky null) |
| `service_id` | uuid (nullable) | Služba z katalogu (u závad null) |
| `client_id` | uuid (nullable) | Pro externí úkoly |
| `custom_title` / `custom_location` | text | Pro úkoly bez bytu |
| `metadata` | jsonb | Volná data pro UI |
| **`media_urls`** | **text[]** | **Fotky – již používáno pro „hlášení závad“ (komentář v migraci)** |
| `reference_number` | text | Lidsky čitelný identifikátor |
| `deleted_at` | timestamptz | Soft delete |
| `updated_at` | timestamptz | Poslední změna |
| `started_at` / `completed_at` | timestamptz | Čas zahájení/dokončení |
| `invoiced_at` | timestamptz | Vyfakturováno (archivace) |
| `unassigned_info` | jsonb | Při odebrání přiřazení |

**Závěr stavu DB:**

- **Ano**, máme **`task_type`** – v seedu `task_categories` existuje kategorie **`maintenance`** (Údržba).
- **Ano**, máme **`status`** – životní cyklus úkolu (pending → in_progress → completed atd.).
- **Ano**, máme **`created_by`** – přímo odpovídá „kdo úkol zadal“ (můžeme rozlišit úkol zadaný majitelem vs. agenturou).
- **Ano**, máme **`media_urls`** – vhodné pro fotodokumentaci závady.

Pro „nahlášení závady majitelem“ tedy **nepotřebujeme novou tabulku**. Stačí používat `tasks` s:

- `task_type` = kategorie údržby (např. `maintenance` nebo dedikovaný kód např. `owner_issue`, pokud chcete v UI oddělit „závady od majitele“ od ostatní údržby),
- `created_by` = `profiles.id` majitele,
- `apartment_id` = byt majitele (kontrola přes `apartment_owners`).

---

## 2. SOUČASNÉ ŘEŠENÍ – tvorba a správa úkolů

### 2.1 Kdo úkoly vytváří

- **Admin/Manager (agentura):** Ručně v administraci, z rezervací (automaticky úklid, check-in/out), z externích klientů (CRM).
- **Majitel (property_owner):** Už dnes může **vkládat** úkoly – ale pouze v kontextu rezervací (např. při vytvoření rezervace v Klientském portálu; v aktuálním kódu se automatické generování úkolu při rezervaci již neprovádí). Samostatné „nahlášení závady“ jako vlastní flow v UI **zatím není**.

### 2.2 RLS – kdo co vidí

**Obecné policies (tenant):**

- **tasks_select / tasks_insert / tasks_update / tasks_delete:**  
  Podmínka: `tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())` (nebo super_admin).  
  → **Admin a Worker** vidí a spravují **všechny** úkoly své agentury.

**Speciální policies pro majitele** (`20260223_fix_owner_select_rls.sql`):

- **tasks_property_owner_select_own_apartments:**  
  Majitel smí **číst** úkoly pouze u bytů, které má v `apartment_owners` (vazba `apartment_id` → `apartment_owners.apartment_id` a `owner_id` = jeho `profiles.id`).
- **tasks_property_owner_insert_own_apartments:**  
  Majitel smí **vkládat** úkoly pouze pro byty, které má v `apartment_owners`.

**Důležité:**

- Pro majitele **neexistuje** policy **tasks_update** ani **tasks_delete**.  
  → Majitel **nemůže** měnit stav úkolu (Nové → Řeší se → Vyřešeno) – to dává smysl, stav mění pouze agentura.
- Majitel dnes vidí **všechny** úkoly u svých bytů (úklidy, check-in/out, údržbu atd.). V `owner_tasks_provider` se pouze filtrují návrhy (draft/pending) v kódu.  
  → Pro „Nahlášení závady“ typicky chceme, aby majitel viděl **jen své nahlášené závady** (a jejich stav), ne kompletní plán úklidů.

### 2.3 Jak se úkoly načítají v aplikaci

- **Admin:** `AdminTasksRepository` / `admin_tasks_provider` – stream nebo future, filtr podle `tenant_id`, `deleted_at` a `invoiced_at`.
- **Majitel:** `owner_tasks_provider` – načte úkoly přes `.inFilter('apartment_id', ownedApartmentIds)` (RLS pak stejně omezí na byty z `apartment_owners`), bez JOINu na jména personálu, s odfiltrováním draft statusů.

Shrnutí: **Tvorba úkolů** je na straně agentury (admin/rezervace/externí klient); **majitel má právo INSERT a SELECT** jen pro své byty, ale dnes vidí všechny typy úkolů u těchto bytů a nemá dedikované UI pro „jen mé nahlášené závady“.

---

## 3. NÁVRH ŘEŠENÍ (Architektura)

Cíl:

- Majitel může **vytvořit** „úkol-závadu“ (titul, popis, volitelně foto).
- Majitel vidí **pouze své nahlášené závady** a jejich **stav** (Nové → Řeší se → Vyřešeno).
- Agentura (tenant) vidí tyto úkoly ve svém dashboardu a **může měnit stav** (přiřadit, „řeší se“, „vyřešeno“).

Doporučený směr: **využít stávající tabulku `tasks`** a upravit RLS + Flutter tak, aby:

- „Závada od majitele“ = úkol s např. `task_type` = `maintenance` (nebo nový kód `owner_issue`) a `created_by` = profil majitele.
- Majitel v Klientské zóně vidí jen úkoly, kde **on je tvůrce** (`created_by` = jeho `profiles.id`), případně ještě filtrováno podle `task_type`, aby se v jednom místě zobrazovaly jen závady.

### 3.1 Databáze

- **Žádná nová tabulka.**  
  Pouze případně:
  - Zvážit novou **kategorii v `task_categories`** (např. `owner_issue`), pokud chcete v administraci oddělit „závady od majitele“ od ostatní údržby (reporty, filtry). Jinak stačí `maintenance`.
- **Sloupce:**  
  - `task_type` = `maintenance` (nebo `owner_issue`).  
  - `created_by` = `profiles.id` majitele při vytvoření z Klientského portálu.  
  - `apartment_id` = byt majitele (kontrola přes `apartment_owners`).  
  - `title` / `description` / `media_urls` podle potřeby.
- **Stav:**  
  Stávající `status` (např. `pending` = Nové, `in_progress` = Řeší se, `completed` = Vyřešeno). Názvy pro majitele lze mapovat v i18n.

### 3.2 RLS – návrh změn

Současný stav:

- Majitel: SELECT na všechny úkoly u svých bytů; INSERT pro své byty; **bez UPDATE**.

Pro „jen mé nahlášené závady“ máte dvě varianty:

**Varianta A – Rozšířit podmínku SELECT pro majitele (doporučeno)**  
- **Nechat** stávající `tasks_property_owner_select_own_apartments` pro zpětnou kompatibilitu (např. stávající obrazovka „Úkoly“ může dál ukazovat všechny úkoly u bytů, pokud to chcete).  
- **Přidat** novou policy např. `tasks_property_owner_select_own_created` s podmínkou:  
  `role = 'property_owner'` **a** `created_by IN (SELECT id FROM profiles WHERE auth_id = auth.uid())`.  
  Aplikace pak pro záložku „Moje nahlášené závady“ bude dotazovat s tím, že efektivně uvidí jen řádky splňující tuto novou policy (např. voláním pouze pro úkoly kde `created_by = current_profile_id`).  
  **Případně** místo druhé policy pouze **v aplikaci** filtrovat: stejný SELECT jako dnes, ale filtr `created_by == profileId` a `task_type == 'maintenance'` (nebo `owner_issue`).  
  → Minimální změna RLS: žádná nová policy, jen INSERT s `created_by` a v klientu filtr.

**Varianta B – Omezit majitele jen na „vlastní“ úkoly**  
- Upravit `tasks_property_owner_select_own_apartments` tak, aby majitel viděl **jen** úkoly, kde `created_by = (SELECT id FROM profiles WHERE auth_id = auth.uid())`.  
  → Majitel by pak **neviděl** úkoly vytvořené agenturou (úklidy, check-in) u svých bytů. To by měnilo chování stávající obrazovky „Úkoly“ (ta by pak zobrazovala jen závady).  
  Pokud chcete zachovat současné chování (majitel vidí i úkoly od agentury u svých bytů) a zároveň mít sekci „Moje nahlášené závady“, je vhodnější **Varianta A** (filtr v aplikaci nebo nová policy jen pro nový endpoint/view).

**INSERT:**  
Stávající `tasks_property_owner_insert_own_apartments` stačí. Při vložení z Klientského portálu nastavit:

- `tenant_id` = tenant bytu (z `apartments.tenant_id`),
- `apartment_id` = vybraný byt,
- `created_by` = aktuální `profiles.id` majitele,
- `task_type` = `maintenance` (nebo `owner_issue`),
- `status` = např. `pending`.

**UPDATE/DELETE:**  
Pro majitele **nepřidávat** UPDATE/DELETE na `tasks` – stav mění pouze agentura.

### 3.3 Flutter – návrh krok za krokem

1. **Klientský portál (majitel)**  
   - **Nová záložka / sekce:** např. „Nahlášené závady“ (nebo rozšíření stávajícího menu).  
   - **Seznam:**  
     - Provider (např. `ownerReportedIssuesProvider`) načte z `tasks` pouze úkoly kde `apartment_id IN (vlastněné byty)` **a** `created_by == currentUser.profileId` **a** volitelně `task_type == 'maintenance'` (nebo `owner_issue`).  
     - Zobrazit stav: Nové / Řeší se / Vyřešeno (mapování `status` → i18n).  
   - **Formulář „Nahlásit závadu“:**  
     - Výběr bytu (pouze byty z `ownerApartmentsProvider`),  
     - název (title), popis (description), volitelně fotky (`media_urls` – upload do Storage, uložit URL do úkolu).  
     - Při ukládání: INSERT do `tasks` s `created_by`, `task_type`, `apartment_id`, `tenant_id` z bytu; `status = 'pending'`.  
   - **Žádná editace stavu** – majitel pouze čte stav.

2. **Administrace (agentura)**  
   - **Stávající úkoly:** Úkoly s `task_type = maintenance` (nebo `owner_issue`) a `created_by` vyplněný (a ne z jejich týmu) lze zobrazit jako „Závady od majitelů“ (filtr / štítek).  
   - **Změna stavu:** Stávající UI pro změnu `status` a přiřazení (`assigned_to`) – bez změn v DB.  
   - Volitelně: v detailu úkolu zobrazit „Nahlášeno majitelem“ (join na `profiles` přes `created_by`) a nepřiřazovat jméno personálu majiteli v Klientském portálu (již tak je).

3. **Bezpečnost**  
   - Na backendu (RLS) již platí: majitel INSERT jen pro své byty; SELECT jen úkoly u svých bytů (příp. jen vlastní při použití filtru `created_by`).  
   - V aplikaci vždy filtrovat `apartment_id` na seznam vlastněných bytů a u „Moje závady“ i `created_by = profileId`.

### 3.4 Shrnutí návrhu

| Oblast | Návrh |
|--------|--------|
| **DB** | Žádná nová tabulka. Použít `tasks` + `task_type` (maintenance / owner_issue) + `created_by` (profil majitele). |
| **RLS** | INSERT beze změny. SELECT buď ponechat a filtrovat v aplikaci podle `created_by` + `task_type`, nebo přidat užší policy jen pro „vlastní“ úkoly, pokud chcete omezit majitele pouze na ně. UPDATE/DELETE pro majitele nepřidávat. |
| **Flutter** | Nová sekce „Nahlášené závady“: provider na úkoly s `created_by == profileId` (a vlastněné byty), formulář INSERT s byt + title + description + volitelně foto; zobrazení stavu read-only. Admin bez změn logiky, jen využití stávajícího úkolu a případně filtr „závady od majitelů“. |

Tím bude majitel moci závadu vytvořit, vidět jen své nahlášené závady a jejich stav a agentura je uvidí v dashboardu a bude moci na ně reagovat (stav, přiřazení).
