# FalcoNest v1.0 – Product Fact Sheet

**Datum auditu:** Únor 2025  
**Zdroj:** Hloubková analýza reálného kódu v main větvi  
**Účel:** Přesný byznysový přehled pro marketing a obchodní tým

---

## 1. Super Admin (Správa platformy)

Super Admin je „velín“ celé platformy – přístupný pouze oprávněným uživatelům s rolí `super_admin`.

### Co Super Admin spravuje

- **Seznam agentur (tenantů)** – přehled všech registrovaných agentur s vyhledáváním (název, obchodní jméno, IČO, kontaktní e-mail)
- **Vytváření nových agentur** – FAB otevře dialog s vytvořením agentury a pozvánkou manažera (jméno, příjmení, e-mail)
- **Převtělení (Impersonace)** – Super Admin se může „převtělit“ do vybrané agentury a vidět její rozhraní tak, jak ho vidí admin; banner s možností návratu do velínu
- **Audit log** – modální okno s přehledem auditních záznamů (změny, mazání, kaskády)
- **Billing modal** – přehled fakturace a MRR (Monthly Recurring Revenue) napříč agenturami
- **Globální nastavení** – SuperAdminSettingsModal (měny, moduly, katalog služeb)

### Detail agentury (TenantDetailScreen)

Otevře se jako modální dialog nebo plná stránka při kliku na kartu agentury:

1. **Tab Info & Fakturace** – firemní údaje (IČO, DIČ, adresa, kontaktní e-mail, telefon), slevy, poznámky
2. **Tab Moduly & Plán** – katalog modulů (dashboard, staff, apartments, reservations, tasks, planning_calendar, finance, warehouse, smart_lock, automation, automatic_tasks), zapínání/zakazování předplatných per agentura, počet apartmánů
3. **Tab Tým & Statistiky** – počet aktivních uživatelů, čekající pozvánky, poslední aktivita, adopce modulů (X/Y Aktivní)

### Stav agentury

- **Aktivní** – má alespoň jednoho manažera/admina v profiles
- **Čeká na manažera** – pouze pozvánka, nikdo se zatím nepřihlásil

---

## 2. Admin (Rozhraní pro agentury – „Dispečink“)

Admin rozhraní slouží manažerům a dispečerům agentur pro správu úklidů, rezervací a personálu.

### Menu moduly (dle katalogu)

| Modul | Obrazovka | Byznysové řešení |
|-------|-----------|------------------|
| **Nástěnka** | AdminDashboardScreen | Přehled KPI – počet bytů, dnešní příjezdy/odjezdy, trendy; rychlé akce na Rezervace a Úkoly; prevence přehlédnutí důležitých událostí |
| **Personál** | AdminTeamScreen | Správa členů týmu, přiřazování bytů majitelům; konec chaosu s tím, kdo co spravuje |
| **Byty** | AdminApartmentsScreen | Správa apartmánů – karty s názvem, adresou, schránkou na klíče, dobou úklidu, **teploměrem obsazenosti** (progress bar X z Y dní v měsíci), statusem (Uklizeno / K úklidu / Obsazeno hosty), poznámkami majitele; prevence overbookingu a přehled vytížení |
| **Rezervace** | AdminReservationsScreen | Kanban board (Nové → Potvrzené → Ubytováno → Odhlášeno), timeline Plachta, vytváření a editace rezervací; jednotný pohled na příjezdy/odjezdy |
| **Úkoly** | AdminTasksScreen | Kanban úkolů (Návrh → Zadáno → Probíhá → Hotovo), generování úkolů z rezervací (Task Automator), přiřazování personálu; **konec chaosu v úklidech** – dispečer vidí, co je hotové a co čeká |
| **Plánovací kalendář** | PlanningCalendarScreen | Týdenní mřížka s úkoly a rezervacemi, drag & drop přiřazení; vizuální plánování a prevence kolizí |
| **Finance** | FinanceDashboardScreen | Zaměstnanecká pokladna – dluhy pracovníků z výběru hotovosti v terénu, potvrzení převzetí v kanceláři; modul finance_export pro export fakturace (Stripe upsell) |

### Další prvky Admin rozhraní

- **Impersonace banner** – při převtělení Super Admina oranžový pruh nahoře
- **System announcement** – modrý banner s oznámením (např. z tenant.announcement)
- **Responzivní layout** – na širokých obrazovkách stálý Sidebar, na úzkých Drawer
- **Modulární menu** – moduly bez předplatného zobrazeny jako zamčené (🔒) s upsell toastem

---

## 3. Owner (Klientský portál – „Budování důvěry“)

Klientský portál je určen majitelům bytů (role `property_owner`). Majitel vidí **pouze data svých bytů** – filtrováno přes tabulku `apartment_owners` a RLS.

### Menu záložky

1. **Moje apartmány** – OwnerApartmentsScreen  
2. **Rezervace** – OwnerReservationsScreen  
3. **Úkoly a údržba** – OwnerTasksScreen  
4. **Plánovací kalendář** – OwnerPlanningCalendarScreen  

### Moje apartmány (Property Cards)

- **Responzivní mřížka** – GridView s přizpůsobením šířky (1–4 sloupce podle obrazovky)
- **Property Card** obsahuje:
  - Hlavičku s barevným gradientem a ikonou apartmánu (80 px)
  - Název bytu, adresu s ikonkou lokace
  - **Teploměr obsazenosti** – „Obsazenost tento měsíc: X z Y dní“ + barevný progress bar (zelená ≥70 %, oranžová 30–70 %, červená &lt;30 %)
  - **3 nejbližší rezervace** – datum OD–DO a jméno hosta (nebo „Žádné nadcházející rezervace“)
  - Status chip (Čistý / Probíhá úklid / Čeká na úklid / Neznámý)
  - Patičku „Zobrazit detail“ s proklikem
- **Detail apartmánu** – read-only dialog (OwnerApartmentDetailScreen): základní info, přístup (schránka, kód), časy check-in/check-out, poznámky majitele, kopírování do schránky

### Rezervace (Owner Kanban)

- Kanban board se sloupci: Nové → Potvrzené → Ubytováno → Odhlášeno
- **Majitel může přidat novou rezervaci** – dialog s výběrem bytu, datum OD/DO, jméno hosta, telefon, počty hostů, speciální požadavky, služby (dle katalogu tenant_services), kdo platí (majitel / host)
- **Handoff proces** – tlačítko „Potvrdit a předat agentuře“ převede rezervaci ze sloupce Nové do Potvrzené a předá ji do správy agentury

### Úkoly a údržba (Read-only Kanban)

- Tři sloupce: Zadáno → Probíhá → Hotovo
- Majitel vidí pouze úkoly u svých bytů; **návrhy (draft) jsou skryty**
- Žádná editace – pouze přehled, že agentura pracuje

### Plánovací kalendář (Read-only)

- Týdenní mřížka (0–24 h), read-only – **žádný Drag&Drop**
- Zobrazuje úkoly pouze pro vlastněné byty
- Jména personálu a návrhy skryty – majitel vidí jen „co se děje“, ne „kdo to dělá“

### Jak to pomáhá agentuře obhájit provizi

- **Transparentnost** – majitel vidí teploměr obsazenosti, nadcházející rezervace a stav úklidů v reálném čase
- **Důvěra** – nemusí volat „jak to vypadá?“ – vše má v portálu
- **Handoff** – majitel zadá rezervaci a jedním kliknutím ji předá agentuře; agentura nemusí řešit papíry ani e-maily

---

## 4. Worker (Mobilní aplikace – „Lidé v terénu“)

Worker aplikace je určena uklízečkám, údržbářům a dalším pracovníkům v terénu (role `worker` nebo přiřazení v `staff`).

### Hlavní obrazovka – Moje práce

- **Seznam úkolů** přiřazených aktuálnímu uživateli, seskupených podle data: **Dnes | Zítra | Později**
- **Pull-to-refresh** – stahuje čerstvá data a spouští synchronizaci
- **Offline banner** – oranžový pruh „Režim offline“ při ztrátě připojení
- **Sync chyba banner** – červený pruh při selhání synchronizace (data jsou v lokální DB, ale backend o nich zatím neví)

### Karta úkolu (na seznamu)

- Čas úkolu, název bytu, typ úkolu (Úklid, Transfer, Check-in/out, Závada, Materiál)
- Adresa s tlačítkem **Navigace** – otevře Google Maps
- Krátký popis (instrukce)
- Vizuální indikátor stavu (žlutá = čeká, modrá = probíhá)

### Detail úkolu (podle typu)

- **CleaningTaskScreen** – úklid
- **CheckinTaskScreen** – předání klíčů / check-in
- **CheckoutTaskScreen** – převzetí klíčů / check-out
- **TransferTaskScreen** – transfer
- **IssueTaskScreen** – závada
- **MaintenanceTaskScreen** – údržba
- **MaterialTaskScreen** – materiál
- **DefaultTaskScreen** – ostatní typy

V detailu pracovník vidí: byt, adresu, schránku na klíče, poznámky majitele, instrukce. Může **změnit stav** (Zadáno → Probíhá → Hotovo); změny se ukládají lokálně a synchronizují na pozadí.

### Technické detaily pro terén (USP)

- **Isar lokální databáze** – úkoly, byty, rezervace a pending audit akce se ukládají lokálně (`TaskLocal`, `ApartmentLocal`, `ReservationLocal`, `PendingAuditAction`)
- **Offline-first** – aplikace čte primárně z Isar; při ztrátě signálu (sklep, horské údolí) pracovník vidí své úkoly a může měnit stavy
- **TaskRepository abstrakce** – `ITaskRepository` má dvě implementace: `TaskRepositoryWeb` (Supabase) pro web, `TaskRepositoryMobile` (Isar) pro mobil; kompilace pro web Isar neobsahuje (64-bit int problém v JS)
- **Timestamp Merging** – konflikty při synchronizaci se řeší přes UTC časová razítka
- **PIN zámek** – volitelný PIN pro odemčení aplikace (bezpečnost při ztrátě telefonu)
- **Connectivity provider** – `isOfflineProvider` sleduje stav sítě pro UI

---

## 5. Technologické výhody (USP)

### Offline-first pro personál

**Proč je to super pro personál ve sklepě bez signálu?**

- Úkoly jsou stažené do telefonu v lokální Isar databázi
- Pracovník vidí seznam, detail, adresu a může měnit stav (Probíhá, Hotovo) bez internetu
- Po obnovení připojení se změny odešlou na backend; pending audit akce se synchronizují
- Žádné „čekám na načtení“ v terénu – data jsou vždy dostupná

### RLS & Multi-tenant

**Proč se agentury a majitelé nemusí bát o svá data?**

- **Row Level Security (RLS)** – každá tabulka (tenants, apartments, reservations, tasks, profiles) má politiky: uživatel vidí pouze řádky své agentury (`tenant_id`) nebo své byty (`apartment_owners`)
- **Super Admin** – výjimka přes `is_super_admin()`; může přistupovat ke všem datům pro podporu
- **Majitel (property_owner)** – vidí pouze rezervace a úkoly u bytů, ke kterým je přiřazen v `apartment_owners`
- **Izolace tenantů** – jedna databáze, logická separace; agentura A nikdy neuvidí data agentury B

### i18n (vícejazyčnost)

**Jak snadno dokážeme aplikaci prodat do zahraničí?**

- Všechny UI texty jsou v JSON souborech: **cs.json**, **en.json**, **es.json**
- Balíček `easy_localization` – přepínání jazyka bez nového buildu
- Přidání nového jazyka = nový JSON soubor + registrace v konfiguraci
- Žádné hardcoded texty – pravidlo v `.cursorrules` vynucuje i18n pro každý nový text

---

## 6. Shrnutí – Co FalcoNest v1.0 reálně umí

| Oblast | Klíčové funkce |
|--------|----------------|
| **Super Admin** | Správa agentur, vytváření + pozvánky, převtělení, audit log, billing modal, detail agentury (fakturace, moduly, tým) |
| **Admin** | Nástěnka KPI, personál, byty (s teploměrem), rezervace Kanban + handoff, úkoly Kanban + Task Automator, plánovací kalendář, zaměstnanecká pokladna |
| **Owner** | Property Cards s teploměrem a 3 rezervacemi, read-only detail bytu, Rezervace Kanban + vytváření + handoff, read-only Kanban úkolů, read-only kalendář |
| **Worker** | Seznam úkolů (Dnes/Zítra/Později), detail podle typu úkolu, změna stavu, navigace na adresu, offline-first (Isar), PIN zámek |
| **Technologie** | Offline-first (Isar na mobilu), RLS multi-tenant, i18n (cs, en, es) |

---

*Tento dokument je založen výhradně na analýze kódu v repozitáři. Žádné funkce nebyly vymyšleny.*
