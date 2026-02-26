# FalcoNest – Byznys model, moduly a fakturace

**Pro koho:** NotebookLM, obchodníci, investoři  
**Základ:** 100 % podloženo reálným kódem v main větvi  
**Účel:** Srozumitelný popis monetizace a modulárního SaaS modelu

---

## 1. Základní byznys model (B2B SaaS Multi-tenant)

### Jeden kód, logická izolace dat

FalcoNest běží jako **jedna aplikace** na jedné platformě. Neprodáváme „instalaci na server zákazníka“ – pronajímáme přístup do sdíleného systému.

**Technicky:** Všechna data jsou v **jedné databázi** (Supabase). Oddělení mezi agenturami zajišťuje **Row Level Security (RLS)** a sloupec `tenant_id` u každé relevantní tabulky. Každý dotaz automaticky filtruje pouze řádky patřící přihlášenému tenantu. Agentura A nikdy neuvidí data agentury B.

**Obchodně:** Prodáváme **předplatné agentury (Tenant)**, ne jednotlivé uživatele. Majitel agentury platí paušál za přístup k platformě; počet dispečerů, uklízeček nebo majitelů bytů v rámci jeho agentury na cenu nepřímá.

### Co to znamená pro obchod

- **Jedna smlouva = jedna agentura.** Škálování uvnitř agentury (více bytů, více personálu) je v ceně nebo se řeší moduly (viz níže).
- **Žádné licence per uživatel.** Uklízečka, která používá mobilní aplikaci, není samostatná fakturační položka.
- **Předvídatelný příjem.** MRR (Monthly Recurring Revenue) roste s počtem agentur a jejich vybranými moduly.

---

## 2. Katalog modulů („Zboží na skladě“)

Moduly jsou definované v tabulce `modules` a mapované v kódu přes `ModuleIconMapper`. Každý modul má klíč (`key`), název, cenu, typ cenění (`fixed`, `per_apartment`, `per_user`) a pořadí v menu.

| Modul | Hodnota pro klienta |
|-------|---------------------|
| **dashboard** | Nástěnka s KPI – počet bytů, dnešní příjezdy/odjezdy, trendy; prevence přehlédnutí důležitých událostí |
| **staff** | Správa personálu a přiřazování bytů majitelům; konec chaosu s tím, kdo co spravuje |
| **apartments** | Správa apartmánů včetně teploměru obsazenosti, statusu úklidu a poznámek majitele |
| **reservations** | Kanban rezervací, timeline Plachta, vytváření a editace; jednotný pohled na příjezdy a odjezdy |
| **tasks** | Kanban úkolů, přiřazování personálu; dispečer vidí, co je hotové a co čeká |
| **planning_calendar** | Týdenní mřížka s úkoly a rezervacemi, Drag & Drop; vizuální plánování a prevence kolizí |
| **finance** | Zaměstnanecká pokladna – evidence hotovosti vybrané od hostů, potvrzení převzetí v kanceláři |
| **warehouse** | Skladový modul (zatím bez obrazovky – placeholder) |
| **smart_lock** | Integrace chytrých zámků (zatím bez obrazovky – placeholder) |
| **automation** | Automatizace procesů (zatím bez obrazovky – placeholder) |
| **automatic_tasks** | Chytrá automatizace – generování návrhů úklidů a transferů z rezervací, chytré přerozdělení při nemoci |
| **finance_export** | Podklady pro fakturaci – měsíční přehled služeb u ukončených rezervací, souhrn pro účetního |

### Sub-moduly a závislosti

- **finance_export** je sub-modul k `finance` (`parent_module_key = 'finance'`). Nelze ho aktivovat bez aktivního modulu Finance.
- Moduly `warehouse`, `smart_lock`, `automation` mají v kódu `tabIndex: null` – nemají obrazovku; zobrazí se placeholder „Připravujeme“.

### Startovací balíček nové agentury

Při vytvoření nové agentury dostane **core moduly** zdarma: `dashboard`, `apartments`, `reservations`, `tasks`. Ostatní moduly (staff, planning_calendar, finance, automatic_tasks, finance_export…) jsou buď doplňkové, nebo placené.

---

## 3. Mechanika upsellu (Jak lákáme k nákupu)

### Zamčené moduly v levém menu

Když agentura **nemá** modul zaplacený (není v `tenant_modules`):

- V levém postranním panelu se modul zobrazí **šedě** s ikonou **zámečku** (`Icons.lock_outline`) – viz `_ModuleNavItem` s `isActive: false`.
- Klik na něj vyvolá **oranžový toast** (SnackBar): *„Modul [název] není aktivní. Kontaktujte podporu.“* (`admin.module_locked_toast`)

**Výjimka:** Modul **Finance** – pokud agentura nemá `finance` aktivní, položka se v menu vůbec nezobrazí (filtr `financeActive`). Ostatní moduly zůstávají viditelné jako zamčené.

Agentura tedy vidí, že funkce existuje, ale musí ji aktivovat přes Super Admina nebo (u vybraných modulů) přes self-service trial.

### Ghost režim pro Super Admina

Super Admin vidí **všechny** moduly – i ty, které tenant nemá. Tyto moduly se zobrazí jako „ghost“:

- Oranžová / šedá barva, ikona `visibility_off`
- Tooltip: *„Modul tenant nemá – převtělení zobrazí skutečný stav.“*
- Kliknutím může přejít na obrazovku (vidí ji jako náhled), ale tenant by tam bez aktivace neviděl obsah

### Premium upsell dialog (self-service trial)

U vybraných prémiových funkcí (např. **automatic_tasks**, **finance_export**) se po kliku na zamčenou funkci zobrazí **PremiumUpsellDialog** místo pouhého toastu:

- Titulek a popis hodnoty (např. „Chytrá automatizace úkolů“, „Podklady pro fakturaci“)
- Tlačítko **„Aktivovat 14denní trial“** – zapíše do `tenant_modules` záznam s `is_trial: true`, `trial_ends_at` = +14 dní
- Po aktivaci je modul okamžitě dostupný; po skončení trialu ho Super Admin standardně převede na placené předplatné

Agentura si tedy může modul „vyzkoušet“ bez nutnosti volat podporu.

---

## 4. Role Super Admina (Pán modulů a peněz)

### TenantDetailScreen → Tab „Moduly & Plán“

Super Admin otevře detail agentury (modální dialog nebo stránka `TenantDetailScreen`) a přepne na záložku **„Moduly & Plán“**.

Zde vidí kompletní katalog modulů s přepínači (Switch):

- **Zapnutí modulu** – vloží záznam do `tenant_modules` (tenant_id + module_id, status active)
- **Vypnutí modulu** – soft delete (nastaví `deleted_at`) nebo označí `cancel_at_period_end`
- **Sub-modul** (např. finance_export) – pokud tenant nemá parent (finance), systém nabídne „Zapnout oba“
- **ModuleSubscriptionDialog** – pro aktivní modul lze otevřít dialog a nastavit trial (`is_trial`, `trial_ends_at`), manuální platnost (`valid_until`) pro fakturaci

Veškeré změny se zapisují do **audit logu** (MODULE_ACTIVATED, MODULE_DEACTIVATED, TRIAL_UPDATED).

### Přehled MRR v detailu

Na záložce Moduly & Plán je zobrazen **odhad MRR** pro danou agenturu – suma cen aktivních modulů (moduly v trialu se nezapočítávají). Super Admin tak vidí, kolik agentura reálně „váží“.

---

## 5. Fakturace a tok peněz

### Billing modal (Super Admin)

Ikona účetního listu v AppBar Super Admin dashboardu otevře **SuperAdminBillingModal**.

**Obsah:**

1. **MRR karta** – fialový gradient, velký widget s „Celkové MRR“ v EUR. Součet `netTotalEur` ze všech řádků.
2. **Tabulka agentur** – každý řádek: Agentura | Měsíc | Předplatné a moduly (rozpis položek) | Základ | Sleva | K úhradě | Akce

**Výpočet položek (billingOverviewProvider):**

- **Základní paušál**: `price_per_apartment × počet bytů` (v měně tenanta, převedeno do EUR)
- **Moduly**: suma cen aktivních modulů; u modulů s `is_trial == true` cena = 0 (ale položka se zobrazí se štítkem „Trial“)
- **Gross Total** = základ + moduly
- **Net Total** = Gross × (1 − discount_percentage/100)
- **Tenant v trialu** (`tenants.trial_ends_at` v budoucnosti) → netTotal = 0

**Akce „Označit jako vyfakturované“:** Ikona účetního listu u řádku vygeneruje strukturovaný payload (tenant_id, položky, částky) a vypíše ho do debug konzole – připraveno pro budoucí export do Fakturoid / iDoklad / Stripe. Zobrazí zelený toast.

### Finance modul (pro agenturu)

**Finance** je hlavní modul (zdarma v základu – `price_eur = 0`). Obsahuje:

- **Zaměstnaneckou pokladnu** – přehled „kapes“ pracovníků (`employee_cash_wallets`), kde `balance > 0` znamená dlužnou hotovost vybranou od hostů
- **Potvrzení převzetí** – dispečer může označit, že zaměstnanec odevzdal hotovost v kanceláři → nulování balance
- **Kritické alerty** – úkoly, kde pracovník měl vybrat hotovost, ale nepotvrdil to v systému

### finance_export (placený sub-modul)

Cena: **29 EUR/měsíc** (fixed), `parent_module_key = 'finance'`.

**Jak se uplatňuje upsell:**

- V modulu Finance je tlačítko „Spravovat předplatné a platby“ / „Podklady pro fakturaci“
- Pokud agentura **nemá** `finance_export`: tlačítko má ikonu zámečku a při kliku otevře **PremiumUpsellDialog** s popisem: *„Měsíční přehled služeb u ukončených rezervací – souhrn, co fakturovat majitelům a co bylo vybráno v hotovosti od hostů. Ideální pro předání účetnímu.“*
- Pokud agentura **má** `finance_export`: tlačítko otevře **FinanceBillingScreen**

**FinanceBillingScreen** zobrazuje agregaci `reservation_services` podle plátce (majitel / host), filtrovanou podle vybraného měsíce. Výstup slouží jako podklad pro fakturaci majitelům a pro přehled hotovosti vybrané od hostů.

### Stripe a automatická fakturace

V databázovém schématu existují sloupce `tenant_modules.stripe_subscription_id` a `tenant_modules.stripe_price_id` – připraveno pro budoucí propojení se Stripe. Aktuálně fakturace probíhá **manuálně** přes Billing modal; export do externích systémů je v přípravě.

---

## 6. Shrnutí – Tok peněz

```
┌─────────────────────────────────────────────────────────────────┐
│  AGENTURA (Tenant)                                                │
│  • Platí paušál: price_per_apartment × počet bytů                 │
│  • + moduly (automatic_tasks, finance_export, planning_calendar…)│
│  • Sleva: discount_percentage                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  SUPER ADMIN                                                     │
│  • Billing modal: MRR, rozpis per agentura                        │
│  • Označení vyfakturováno → payload pro Fakturoid/iDoklad         │
│  • Detail agentury: zapínání/vypínání modulů, trial, slevy       │
└─────────────────────────────────────────────────────────────────┘
```

**Pro obchodníka:** Agentura vidí hodnotu (moduly v menu), zkouší trial tam, kde je self-service, a rozšíření řeší přes kontakt s námi (Super Admin zapne modul v Tenant detailu). Fakturace probíhá měsíčně podle Billing modal s možností slev a trial období.

---

*Tento dokument vychází výhradně z reálného kódu. Žádné funkce nebyly vymyšleny.*
