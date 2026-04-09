# Analýza: Nákup modulu po vypršení trialu („Koupit plnou verzi“)

**Záměr:** Po vypršení zkušební doby umožnit uživateli kliknout na „Koupit plnou verzi“. Bez Stripe – vlastní fakturační modul a interní zpracování (požadavek do vyúčtování / notifikace Super Adminovi).

**Scope:** Pouze analýza. Implementace až po odsouhlasení.

---

## 1. Existující fakturační infrastruktura

### Tabulky v databázi

| Tabulka | Účel |
|--------|------|
| **invoices** | Hlavičky faktur – `tenant_id`, `stripe_invoice_id`, `amount_due`, `amount_paid`, `currency`, `status`, `invoice_pdf_url`, `paid_at`. Stripe-oriented; **žádné řádkové položky**, žádná vazba na moduly ani na „žádosti“. |
| **billing_snapshots** | Zmražená měsíční vyúčtování **majitelů bytů** (klientů agentury). Unikátní podle `(tenant_id, client_id, billing_period)`. `snapshot_data` (JSONB) obsahuje `items` (úkoly s cenami), `total_to_invoice`, `expenses`, `final_to_invoice`, `monthly_management_fee`. Slouží k „Podkladům pro fakturaci“ – uzamčení měsíce → snapshot úkolů a součtů. |
| **billing_shortfall_transfers** | Nedoplatky převedené na fakturu majitele (shortfall po hostech). |
| **tenant_modules** | Které moduly má tenant zapnuté; `is_trial`, `trial_ends_at`, `valid_until`, `stripe_subscription_id` (připraveno pro Stripe, aktuálně nevyužito). |
| **modules** | Katalog modulů – `key`, `name`, `price_eur`, `pricing_type`, `parent_module_key`. Cena je v EUR. |

**Žádná tabulka** typu `purchase_requests`, `subscription_requests` ani `billing_items` (řádkové položky k fakturám) v současnosti **neexistuje**.

### Jak funguje modul „Podklady pro fakturaci“ (Billing)

- **Zdroj dat:** Živá data z **úkolů** (tasks) a **rezervací/služeb** (reservation_services, apartments.monthly_management_fee). Agregace po klientech (majitelích) a měsíci.
- **Uzamčení měsíce:** `BillingActionService.lockBillingMonth()` vytvoří pro každého klienta jeden záznam v **billing_snapshots** (JSONB snapshot úkolů, cen, výdajů). Úkoly se označí `invoiced_at`, takže už nefigurují v dalších „živých“ podkladech.
- **Výstup:** Admin vidí přehled po klientech a měsíci; majitelé si z uzamčených snapshotů generují PDF v Klientské zóně. Fyzické faktury (PDF pro agenturu jako takovou) se v kódu připravují přes jiné cesty (např. billing_overview_provider, MRR po tenantech).
- **Závěr:** Billing je **orientovaný na vyúčtování majitelů bytů a úkolů**, ne na nákup modulů. Řádek „Modul Automatizace 15 EUR/měsíc“ tam jako samostatná položka **není** – moduly se řeší v `tenant_modules` a v Super Admin UI (zapnutí/vypnutí).

---

## 2. Kam zaznamenat nákup modulu a jak informovat

### Požadavek „Koupit modul X za Y EUR/měsíc“

- **Potřeba:** Jedno místo, kde je požadavek evidovaný, aby o něm věděla účetní / Super Admin a mohl ho vyfakturovat nebo schválit.
- **invoices:** Jsou to hlavičky faktur (Stripe), bez řádkových položek. Přidávat tam „žádost o modul“ by znamenalo buď zneužití (jeden řádek = jedna faktura), nebo rozšíření o položky – obojí je odlišný use-case od současného designu.
- **billing_snapshots:** Jsou vázané na **klienta (majitele bytu)** a **billing_period** (měsíc). Slouží vyúčtování služeb agentury majitelům, ne předplatnému modulů za celou agenturu. Přidávat sem „položku modul“ by bylo nekonzistentní (modul je na úrovni tenanta, ne klienta).

**Doporučení:** Zavedení **dedikované tabulky pro žádosti o modul** (např. **module_purchase_requests**), která bude sloužit jako fronta požadavků a podklad pro vyúčtování / schvalování:

- `id`, `tenant_id`, `module_id` (FK na modules), `requested_at`, `requested_by` (profile_id admina, který kliknul), `status` (pending / approved / rejected), `price_eur` (snížení v čase), volitelně `notes`, `resolved_at`, `resolved_by`.
- Super Admin (nebo účetní) uvidí seznam čekajících žádostí, schválí → vytvoří/aktualizuje `tenant_modules` (např. `is_trial: false`, `valid_until`), označí žádost jako `approved` a může ji zanést do svého fakturačního procesu mimo aplikaci (nebo do budoucí rozšíření faktur).

### Notifikační systém

- **Existující vzor:** Trigger **owner_issue_notification_trigger** po INSERT do `tasks` (úkol typu maintenance od majitele) volá **notify_admins_on_owner_issue()**. Ta vloží do **notifications** jeden záznam pro **každého admina a manažera tenantu** (`profile_id`, `tenant_id`, title, message, type `owner_issue`). Funkce je SECURITY DEFINER, aby obešla RLS.
- **notifications:** `tenant_id`, `profile_id`, `title`, `message`, `type`, `is_read`. Každá notifikace je pro konkrétního příjemce (`profile_id`).
- **Super Admin:** Má profil s `role = 'super_admin'` (sync do `app_super_admins` přes auth_id). Může mít `tenant_id` NULL (HQ).
- **Využití:** Po INSERT do **module_purchase_requests** lze stejný vzor použít: **trigger nebo aplikací** vložit do `notifications` záznam pro **každý profil s role = 'super_admin'**, s `tenant_id` = tenanta žadatele, `type` např. `module_purchase_request`, title/message např. „Agentura XY chce koupit modul Z za 15 EUR/měsíc“. Super Admin tak dostane v aplikaci (zvoneček) upozornění a může v sekci „Žádosti o moduly“ žádost vyřídit.

**Shrnutí:**  
- **Kam uložit:** Nová tabulka **module_purchase_requests** (ne rozšiřovat billing_snapshots o položky modulů).  
- **Notifikace:** Ano – po vytvoření žádosti vložit notifikaci pro Super Adminy (trigger nebo kód po úspěšném INSERT), aby o žádosti věděli a mohli ji zpracovat.

---

## 3. Návrh řešení pro tlačítko „Koupit“

### Tok pod kapotou (bez Stripe)

1. **UI (premium_upsell_dialog nebo rozšířený stav):**  
   Když je trial vypršený, vedle nebo místo „Aktivovat trial“ zobrazit tlačítko **„Koupit plnou verzi“** (např. „Modul Automatizace – 15 EUR/měsíc“). Cenu brát z `modules.price_eur` (příp. zobrazení v měně tenanta přes `CurrencyService`).

2. **Po kliknutí „Koupit“:**  
   - **INSERT** do **module_purchase_requests**:  
     `tenant_id`, `module_id`, `requested_at` (now()), `requested_by` (aktuální profile_id), `status = 'pending'`, `price_eur` (z modulu), volitelně `notes`.  
   - **Notifikace:**  
     - **Varianta A (doporučená):** V aplikaci (Flutter) po úspěšném INSERT zavolat službu, která načte všechny profily s `role = 'super_admin'` a pro každý vloží řádek do `notifications` (tenant_id = žadatel, profile_id = daný super_admin, type = `module_purchase_request`, title/message s názvem tenanta a modulu).  
     - **Varianta B:** DB trigger AFTER INSERT na `module_purchase_requests`, který vloží notifikace pro Super Adminy (SELECT id FROM profiles WHERE role = 'super_admin'; INSERT INTO notifications …). SECURITY DEFINER jako u owner_issue.  
   - **Feedback uživateli:** Např. „Žádost byla odeslána. O vyřízení vás budeme kontaktovat.“ (SnackBar + zavření dialogu). **Žádná** automatická aktivace modulu – tu provede až Super Admin po schválení.

3. **Super Admin:**  
   - V notifikacích uvidí „Agentura XY chce koupit modul Z“.  
   - V nové sekci (nebo v Tenant Detail / Moduly) zobrazit seznam **pending** žádostí z `module_purchase_requests`.  
   - Akce „Schválit“: vytvoření/update záznamu v **tenant_modules** (zapnutí modulu, `is_trial: false`, `valid_until` dle obchodní praxe), změna stavu žádosti na `approved`, volitelně `resolved_at` / `resolved_by`.  
   - Akce „Odmítnout“: `status = 'rejected'`, volitelně `notes`.  
   - Fakturace: Super Admin si žádost zapíše do svého vyúčtování (externí faktura, spreadsheet, nebo budoucí rozšíření tabulky `invoices` o řádkové položky).

4. **Konzistence s triálem:**  
   - Tlačítko „Koupit“ se zobrazuje **jen když** už existuje záznam v `tenant_modules` a **trial_ends_at je v minulosti** (stejná podmínka, při které dnes zobrazujete hlášku o vypršení trialu).  
   - Při „Koupit“ **nevolat** INSERT do `tenant_modules` – ten přijde až po schválení žádosti.

### Výhody tohoto návrhu

- **Jedna pravda:** Všechny žádosti o modul jsou v jedné tabulce, s jasným stavem (pending/approved/rejected).  
- **Bez nekonečného trialu:** Žádná automatická aktivace; prodloužení dostane tenant až po schválení a (dle vaší praxe) vyfakturování.  
- **Reuse notifikací:** Stejný vzor jako u owner_issue – Super Admin dostane hned upozornění.  
- **Rozšiřitelnost:** Později lze přidat např. `invoice_id` (FK na invoices), automatické generování položky do faktury, nebo propojení s externím účetním systémem.

### Minimální kroky pro implementaci (až po odsouhlasení)

1. **Migrace:** Vytvořit tabulku **module_purchase_requests** (tenant_id, module_id, requested_at, requested_by, status, price_eur, notes, resolved_at, resolved_by), RLS (tenant vidí své žádosti; Super Admin vše).  
2. **Flutter:** V dialogu po vypršení trialu zobrazit „Koupit plnou verzi“; při kliknutí INSERT do `module_purchase_requests` + odeslání notifikací Super Adminům (nebo trigger).  
3. **Super Admin UI:** Seznam pending žádostí + akce Schválit/Odmítnout (update `tenant_modules` + status žádosti).

Tím bude „Koupit“ plně zapojené do stávajícího ekosystému (moduly, notifikace, tenant_modules) bez Stripe a s jasným místem pro vyúčtování na straně Super Admina.
