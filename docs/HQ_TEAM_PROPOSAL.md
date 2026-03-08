# Návrh modulu „HQ Tým“ – správa interního týmu FalcoNest (Velín)

**Datum:** 2026-03-06  
**Kontext:** Na Velínu (Super-Admin dashboard) máme správu agentur; chybí správa vlastního interního týmu HQ – obchoďáci (Lovci a Farmáři), účetní, mzdové, podpora a další Super-Admini.  
**Pravidlo:** ADDITIVE DEVELOPMENT – stávající logika a tabulky nesmí být ohroženy.

---

## 1. CO UŽ MÁME (existující tabulky a vazby)

### 1.1 Identita a role HQ

| Zdroj | Popis |
|-------|--------|
| **profiles** | Základní tabulka lidí v systému. Sloupce: `id`, `auth_id`, `email`, `first_name`, `last_name`, `name`, **`role`**, **`tenant_id`** (u HQ = NULL), `status`, `weekly_hours`, `start_date`, `end_date`, … |
| **profiles.role** | Hodnoty dnes: `super_admin`, `account_manager`, `admin`, `manager`, `worker`, … HQ členové jsou právě ti s `role IN ('super_admin', 'account_manager')` a `tenant_id IS NULL`. |
| **app_super_admins** | Whitelist pro RLS funkci `is_super_admin()` – obsahuje `id` = **auth.users(id)** (ne profiles.id). Trigger na `profiles` při změně `role` syncuje tento seznam. Slouží pouze k oprávněním, ne jako „seznam HQ“. |

**Vazba:** HQ tým = podmnožina `profiles` kde `tenant_id IS NULL` a `role` je jedna z HQ rolí. Seznam pro dropdowny (Lovec/Farmář) už načítáme v **hq_staff_provider.dart** z `profiles` s `role IN ('super_admin', 'account_manager')`.

### 1.2 Portfolio (Lovci a Farmáři)

| Zdroj | Popis |
|-------|--------|
| **tenants.acquired_by** | UUID → `profiles(id)`. Lovec – kdo agenturu získal. |
| **tenants.managed_by** | UUID → `profiles(id)`. Farmář – kdo se o agenturu stará. |
| **Indexy** | `idx_tenants_acquired_by`, `idx_tenants_managed_by` už existují. |

V detailu HQ pracovníka stačí dotazy: `tenants WHERE acquired_by = :profileId` a `tenants WHERE managed_by = :profileId` (s RLS: Super-Admin vidí vše, Account Manager jen své).

### 1.3 Odměny Lovců a Farmářů (měsíční provize)

| Zdroj | Popis |
|-------|--------|
| **agency_management_settlements** | Již existující tabulka: `profile_id`, `tenant_id`, `settlement_period` (date), `role_type` ('hunter' \| 'farmer'), `amount`, `status` ('pending' \| 'approved' \| 'paid'), `approved_by`, `approved_at`. UNIQUE(profile_id, tenant_id, settlement_period, role_type). |
| **RLS** | Super-Admin vše; Account Manager vidí jen své řádky (`profile_id` = jeho profil). |

Tato tabulka řeší **schvalování měsíčních provizí** za konkrétní agenturu a období. Neukládá však **smluvní parametry** (fixní plat, typ úvazku, % provize) – ty dnes v DB nejsou.

### 1.4 Zásahy podpory (Magic Login) a výkazy práce

| Zdroj | Popis |
|-------|--------|
| **support_interventions** | `profile_id`, `tenant_id`, `started_at`, `ended_at`, `work_report`. Audit „kdo, u koho, kdy, co řešil“. |
| **Stav v aplikaci** | Tabulka existuje; zápis při impersonate/stop dle auditu zatím chybí (lze doplnit v rámci HQ modulu nebo samostatně). |

### 1.5 Absence a dovolené

| Zdroj | Popis |
|-------|--------|
| **staff_absences** | Sloupce: `id`, **`profile_id`**, **`tenant_id`** (nullable), `start_date`, `end_date`, `reason`, `invitation_id`. FK `profile_id` → profiles(id). |
| **tenant_id** | V produkčním schématu je **nullable** (YES). Pro HQ člena tedy můžeme ukládat řádek s `profile_id` = HQ profil a **`tenant_id` = NULL** – absence nepatří k žádné agentuře. |

**Poznámka:** Je nutné ověřit RLS na `staff_absences`: pokud jsou politiky postavené na `tenant_id` (např. „vidět jen řádky svého tenanta“), musíme přidat podmínku typu „NEBO (tenant_id IS NULL AND profile_id = aktuální profil)“ pro HQ, aby si mohli prohlížet a zadávat své absence. Super-Admin by měl vidět všechny absence včetně těch s `tenant_id IS NULL`.

---

## 2. CO MUSÍME PŘIDAT (SQL migrace a nové tabulky)

### 2.1 Rozšíření rolí HQ (volitelné, podle byznysu)

- **Varianta A:** Ponechat pouze `super_admin` a `account_manager`. Účetní, mzdová, podpora jsou buď `super_admin` (vidí vše), nebo je budeme rozlišovat jen v UI (např. štítek „Účetní“ vedle role).
- **Varianta B:** Zavést nové role v `profiles.role`, např. `hq_sales`, `hq_accounting`, `hq_payroll`, `hq_support`. RLS a menu by pak mohly být jemně odstupňované. Vyžaduje změny v auth notifieru a RLS (kde se dnes kontroluje jen `super_admin` / `account_manager`).

Doporučení: **Fáze 1** držet stávající dvě role; „Obchoďák / Účetní / …“ lze evidovat jako **název pozice** v nové tabulce smluv nebo v rozšíření profilu (viz níže).

### 2.2 Nová tabulka: smlouvy a odměny HQ (`hq_staff_contracts`)

Pro typ úvazku (HPP, IČO), fixní plat, bonus za ulovenou agenturu a % provize ze správy **nemáme** v DB místo. Tabulka `agency_management_settlements` řeší jen konkrétní vyplacené částky za období, ne „smluvní nastavení“.

**Návrh tabulky (additivní migrace):**

```sql
-- hq_staff_contracts: smluvní parametry a odměny pro členy HQ týmu
CREATE TABLE IF NOT EXISTS public.hq_staff_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- Typ úvazku: 'hpp' (pracovní poměr), 'ico' (IČO / DPČ)
  employment_type text NOT NULL DEFAULT 'hpp' CHECK (employment_type IN ('hpp', 'ico')),
  -- Pozice / název role pro zobrazení (Účetní, Mzdová, Obchoďák, Podpora, …)
  position_label text,
  -- Fixní složka (měsíční plat)
  fixed_salary_monthly numeric CHECK (fixed_salary_monthly IS NULL OR fixed_salary_monthly >= 0),
  -- Bonus za každou ulovenou agenturu (jednorázově nebo dle dohody – zde jednorázová částka)
  bonus_per_acquired_agency numeric CHECK (bonus_per_acquired_agency IS NULL OR bonus_per_acquired_agency >= 0),
  -- % provize z MRR (nebo z vybrané metriky) za agentury, které spravuje (Farmář)
  commission_percent_managed numeric CHECK (commission_percent_managed IS NULL OR (commission_percent_managed >= 0 AND commission_percent_managed <= 100)),
  -- Platnost smlouvy
  valid_from date NOT NULL DEFAULT CURRENT_DATE,
  valid_to date,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  CONSTRAINT valid_range CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE INDEX IF NOT EXISTS idx_hq_staff_contracts_profile_id ON public.hq_staff_contracts(profile_id);
CREATE INDEX IF NOT EXISTS idx_hq_staff_contracts_valid ON public.hq_staff_contracts(valid_from, valid_to);

ALTER TABLE public.hq_staff_contracts ENABLE ROW LEVEL SECURITY;
-- RLS: Super-Admin vše; jinak jen vlastní záznamy (profile_id = aktuální profil)
```

- Jeden profil může mít více řádků (historie smluv); aktuální = `valid_from <= CURRENT_DATE AND (valid_to IS NULL OR valid_to >= CURRENT_DATE)`.
- Sloupce `fixed_salary_monthly`, `bonus_per_acquired_agency`, `commission_percent_managed` jsou nullable – podle typu pozice se vyplní jen relevantní.

### 2.3 Rozšíření `tenant_detail_provider` / modelu tenanta

- V **tenant detailu** už dnes načítáme (nebo můžeme doplnit) `acquired_by`, `managed_by` z tabulky `tenants` a zobrazovat je v UI.  
- Pro **detail HQ pracovníka** potřebujeme nové providery: např. `hqStaffAcquiredTenantsProvider(profileId)` a `hqStaffManagedTenantsProvider(profileId)` – dotazy na `tenants` WHERE `acquired_by` / `managed_by` = profileId. Žádná nová tabulka.

### 2.4 Absence pro HQ (`staff_absences` s `tenant_id` = NULL)

- **Žádná nová tabulka.** Použijeme `staff_absences`: pro HQ člena vložíme řádek s `profile_id` = jeho profil a **`tenant_id` = NULL**.
- **Kontrola RLS:** V migraci (nebo v této fázi auditu) ověřit, že politiky na `staff_absences` umožňují:
  - Super-Admin: SELECT/INSERT/UPDATE/DELETE všech řádků (včetně `tenant_id IS NULL`).
  - HQ člen (profile s `tenant_id IS NULL`): SELECT/INSERT/UPDATE/DELETE vlastních řádků kde `tenant_id IS NULL` a `profile_id` = jeho profil.
- Pokud dnes RLS povoluje pouze „řádky kde tenant_id = (můj tenant_id)“ a HQ má `tenant_id NULL`, musíme přidat druhou větev: **OR (tenant_id IS NULL AND profile_id = (můj profile id))** pro čtení a zápis vlastních HQ absencí.

---

## 3. NÁVRH UI (umístění a záložky)

### 3.1 Umístění v menu Velínu (podle screenshotu)

- **Hlavní oblast:** Pod/vedle řádku „Hledat agenturu…“ + „Seřadit“ + „+ Přidat agenturu“.
- **Návrh:** Přidat výrazné tlačítko nebo kartu **„HQ Tým“** (ikona lidí / skupina), která povede na novou obrazovku `/super-admin/hq-team` (nebo jako první sekce na stejném dashboardu – sekce „Váš tým“ nad kartami agentur).
- **Doporučení:** Samostatná route `/super-admin/hq-team` s vlastní obrazovkou **HqTeamScreen** – přehledný seznam členů HQ (karty: jméno, role, pozice, počet agentur acquired/managed, tlačítko „Detail“). Tlačítko „+ Přidat člena HQ“ (pouze pro Super-Admina) otevře flow pozvání / vytvoření profilu s přiřazenou rolí.

### 3.2 Seznam HQ týmu

- Karty (podobně jako u agentur): **Jméno**, **Role** (Super-Admin / Account Manager), **Pozice** (z `hq_staff_contracts.position_label` nebo výchozí „Obchoďák“), **Agentury (Lovec)** / **Agentury (Farmář)** (počty), **Status** (aktivní / ukončený).  
- Akce: **Detail**, případně **Převtělit se** (pouze pokud má přiřazenou agenturu a má roli account_manager – viz stávající logiku).

### 3.3 Detail HQ pracovníka (záložky)

| Záložka | Obsah |
|--------|--------|
| **Profil** | Jméno, e-mail, role (ze `profiles`), pozice (z aktuální smlouvy), typ úvazku (HPP/IČO). Tlačítko „Upravit“ – změna role/pozice (Super-Admin). |
| **Smlouva a odměny** | Data z `hq_staff_contracts`: fixní plat, bonus za ulovenou agenturu, % provize za správu; období platnosti. Historie smluv (tabulka). Tlačítko „Přidat smlouvu“ / „Upravit“. |
| **Portfolio** | Dvě sekce: **Agentury, které přivedl (Lovec)** – seznam z `tenants WHERE acquired_by = profile_id`; **Agentury, které spravuje (Farmář)** – `tenants WHERE managed_by = profile_id`. Každá položka: název agentury, odkaz na detail tenanta (existující TenantDetailModal). |
| **Absence a dovolené** | Seznam z `staff_absences WHERE profile_id = :id AND tenant_id IS NULL`. Přidat / upravit / smazat (kalendář nebo jednoduchý formulář datum–datum, důvod). |
| **Provize (vyúčtování)** | Odkaz na stávající modál / obrazovku zúčtování (`agency_management_settlements`) **filtrovaný na tohoto profile_id** – přehled schválených a vyplacených provizí za měsíce. |

---

## 4. KROKOVÝ PLÁN IMPLEMENTACE

- **Step 1 – Datová vrstva (additivní)**  
  - Migrace: vytvořit tabulku `hq_staff_contracts` (struktura výše), RLS, indexy.  
  - Ověřit / doplnit RLS na `staff_absences` pro řádky s `tenant_id IS NULL` (HQ absence).  
  - Aktualizovat `database_schema.md` o novou tabulku a změny u `staff_absences`, pokud se RLS změní.

- **Step 2 – Providery a služby**  
  - Provider: seznam HQ členů (rozšířit stávající `hqStaffProvider` nebo nový `hqTeamListProvider` s údaji z `profiles` + aktuální smlouva a počty agentur).  
  - Providery: `hqStaffAcquiredTenantsProvider(profileId)`, `hqStaffManagedTenantsProvider(profileId)`.  
  - Repozitář/služba: CRUD pro `hq_staff_contracts`; čtení/ zápis `staff_absences` s `tenant_id = NULL` pro daný `profile_id`.

- **Step 3 – UI: seznam HQ týmu**  
  - Route `/super-admin/hq-team`, obrazovka **HqTeamScreen**: seznam karet (jméno, role, pozice, počty agentur, status).  
  - Tlačítko „+ Přidat člena HQ“ (Super-Admin) → flow pozvání / vytvoření účtu s rolí `super_admin` nebo `account_manager` (stávající mechanismus pozvánek nebo ruční vytvoření v Auth + profil).

- **Step 4 – UI: detail HQ pracovníka**  
  - Route `/super-admin/hq-team/:profileId`, obrazovka **HqStaffDetailScreen** s TabBar: Profil, Smlouva a odměny, Portfolio, Absence, Provize.  
  - Naplnit záložky daty z providerů a repozitářů.  
  - Formuláře: přidat/upravit smlouvu; přidat/upravit absenci (s `tenant_id` = NULL).

- **Step 5 – Integrace s Velínem**  
  - Na dashboardu Super-Admina (podle screenshotu) přidat vstup do „HQ Tým“: tlačítko v AppBar nebo sekce „Váš tým“ nad kartami agentur s odkazem na `/super-admin/hq-team`.  
  - Zajistit, že pouze Super-Admin vidí „Přidat člena HQ“ a plnou správu smluv; Account Manager vidí seznam HQ a vlastní detail (popř. jen vlastní smlouvu a absence).

- **Step 6 – Volitelné rozšíření**  
  - Při zahájení/ukončení Magic Login zapisovat do `support_interventions` (audit výkazů práce).  
  - Rozšíření rolí (`hq_accounting`, `hq_support`, …) a jemnější oprávnění v menu a RLS.

---

## 5. Shrnutí rizik a ADDITIVE DEVELOPMENT

- **Žádné mazání:** Nepřepisujeme stávající tabulky ani role; přidáváme pouze `hq_staff_contracts` a volitelně rozšíříme RLS u `staff_absences`.  
- **Zpětná kompatibilita:** `profiles.role` a `app_super_admins` zůstávají; stávající dropdowny (Lovec/Farmář) dál čerpají z `hq_staff_provider`.  
- **Portfolio:** Využíváme jen existující sloupce `tenants.acquired_by` a `tenants.managed_by`.  
- **Provize:** `agency_management_settlements` zůstává zdrojem pravdy pro vyplacené odměny; `hq_staff_contracts` pouze definuje „podmínky“ (plat, bonus, %), nikoliv konkrétní výplatu.

Tímto plánem lze modul „HQ Tým“ zavést postupně bez narušení stávající správy agentur na Velínu.
