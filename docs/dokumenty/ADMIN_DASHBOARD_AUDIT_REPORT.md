# Audit a návrhy vylepšení – Admin Dashboard (Nástěnka) FalcoNest

**Datum:** Březen 2026  
**Rozsah:** Analýza současného stavu, návrhy nových widgetů z dostupných dat, optimalizace výkonu.

---

## 1. ANALÝZA SOUČASNÉHO STAVU

### 1.1 Vizuální struktura Dashboardu

| Sekce | Popis |
|-------|--------|
| **Hlavička** | Uvítání (Dobré ráno/odpoledne/večer), jméno admina, dnešní datum. |
| **Action Strip** | Varovný pruh: Návrhy ke schválení, Problémy z terénu, Nevybraná hotovost (počet zaměstnanců + celková částka). Při nulách: zelený pruh „Vše je vyřešeno“. Klik vede na záložku Úkoly nebo Finance. |
| **Dnešní plán** | Scrollovací seznam dnešních úkolů (čas, název, byt, přiřazený). Odvozeno z úkolů s `due_date` v rozsahu dneška. |
| **Stav apartmánů** | Tři bloky: Uklizeno / K úklidu / Obsazeno. Počty z rezervací + úkolů (getApartmentStatusForToday). |
| **Dnešní tým** | Avatary pracovníků s úkoly na dnešek; badge s počtem úkolů; ikona peněženky u těch s nevybranou hotovostí. |
| **Manažerský přehled** | Čárový graf „Vývoj rezervací (14 dní)“ (příjezdy check-in); prstencový graf „Skladba dnešních úkolů“ (Úklidy, Transfery, Příjezdy, …). |
| **Rychlé akce** | Tlačítka: Přidat úkol, Generovat návrhy, Finance (peněženka). |
| **Dnešní externí služby** | Úkoly bez `apartment_id` (transfery, služby u klienta) na dnešek. |

### 1.2 Datové zdroje (providery)

| Zdroj | Typ | Co načítá | Použití na Nástěnce |
|-------|-----|-----------|----------------------|
| **adminTasksStreamProvider** | Stream (Realtime) | Všechny aktivní úkoly tenanta (`deleted_at` a `invoiced_at` null), **limit 500**, řazení `scheduled_start DESC`. | Dnešní plán, externí služby, stav apartmánů, Action Strip (pending/problem), skladba úkolů, dnešní tým. |
| **adminReservationsProvider** | Stream (Realtime) | Rezervace bytů tenanta, **limit 500**, `start_date DESC`. | Stav apartmánů (obsazeno / k úklidu), graf „Vývoj rezervací (14 dní)“. |
| **apartmentsProvider** | Future | Seznam apartmánů tenanta. | Filtry rezervací a úkolů, mapy jmen bytů. |
| **adminTeamProvider** | Future | Členové týmu (profily tenanta). | Jména v plánu a v „Dnešní tým“, mapování `profile_id` → jméno. |
| **dashboardSummaryProvider** | Provider (derived) | Agregace z úkolů, peněženek a rezervací. | Action Strip (počty + hotovost), grafy (tasksComposition, reservationsTrend). |
| **employeeCashWalletsProvider** | Stream (Realtime) | Peněženky zaměstnanců (balance). | Action Strip (nevybraná hotovost), ikona 💰 u pracovníků v „Dnešní tým“. |
| **currentUserProfileProvider** | Future | Profil přihlášeného. | Hlavička (jméno). |

### 1.3 Shrnutí datových toků

- **Úkoly:** Jeden Realtime stream na celý tenant, max 500 záznamů. Na klientovi se z nich filtrují „dnešní“, „pending“, „problem“, skladba podle typu atd.
- **Rezervace:** Jeden stream přes `apartment_id IN (…)`, max 500 záznamů. Na klientovi se počítají příjezdy po dnech (14 dní) a stav bytů.
- **Apartmány a tým:** Načtení jednou (Future), bez Realtime.
- **Hotovost:** Realtime stream peněženek, agregace na klientovi (počet s balance > 0, součet).

Dashboard **nevytváří** speciální „dashboardové“ API – vše je odvozeno z těchto šesti zdrojů a z derivovaného `dashboardSummaryProvider`.

---

## 2. NÁVRH NA DOPLNĚNÍ (NOVÉ WIDGETY – BUSINESS LOGIKA)

Níže navržené widgety používají **již existující tabulky a vztahy** v Supabase; jde o to, tato data na Nástěnce zobrazit.

### 2.1 Čeká na vyplacení (modul Vyúčtování)

- **Zdroj:** `task_payouts` + `task_commissions` se `status = 'pending'`, agregace podle příjemce (již existuje `groupedPendingPayoutsProvider`).
- **Widget:** Jedna karta typu „Čeká na vyplacení: X příjemců, celkem Y [měna]“ s odkazem na záložku Vyúčtování / K výplatě.
- **Přínos:** Admin vidí na první pohled, kolik peněz čeká na vyplacení personálu a partnerům, bez přepnutí do modulu.

### 2.2 Fronta úkolů ke schválení (Vyúčtování)

- **Zdroj:** `pendingSettlementsProvider` – dokončené úkoly bez záznamu v `task_payouts`.
- **Widget:** Karta „Ke schválení vyúčtování: N úkolů“ s odkazem na záložku Vyúčtování (Fronta úkolů).
- **Přínos:** Připomínka, že je potřeba rozdělit výplaty a provize u dokončených úkolů.

### 2.3 Očekávaný příjem z fakturace (aktuální měsíc)

- **Zdroj:** Úkoly s `invoiced_at IS NULL`, `status = 'completed'`, případně rozšíření o `reservation_services.charged_price` nebo `tasks.metadata` (service_price / amount_to_collect). Agregace za aktuální měsíc (podle `completed_at` nebo `scheduled_start`).
- **Alternativa:** Pokud existuje nebo doplníte view/snapshot „nevyfakturované úkoly za měsíc“, použít ten.
- **Widget:** Karta „Očekávaný příjem tento měsíc: X [měna]“ (odkaz na Podklady pro fakturaci).
- **Přínos:** Rychlý odhad cash flow z dokončených, ale ještě nevyfakturovaných služeb.

### 2.4 Kritické / zpožděné úkoly

- **Zdroj:** `tasks`: (např. `status = 'problem'` nebo `due_date` / `scheduled_start` v minulosti a status jiný než completed/cancelled). Filtrovat na tenant, `deleted_at` a `invoiced_at` null.
- **Widget:** Karta „Kritické / zpožděné: N úkolů“ s odkazem na Úkoly (přednastavený filtr).
- **Přínos:** Problémy a přetáhnuté úkoly vidět hned na Nástěnce; dnes je „problem“ v Action Stripu, zpoždění (overdue) tam není.

### 2.5 Nejaktivnější pracovník (tento týden / měsíc)

- **Zdroj:** `tasks`: úkoly se `status = 'completed'`, `completed_at` v daném období, seskupení podle `assigned_to` (nebo více přiřazených), počet dokončených úkolů.
- **Widget:** Malá karta „Nejvíce dokončených tento týden: [Jméno] (N úkolů)“.
- **Přínos:** Motivační a informační prvek pro manažera; data už v `tasks` jsou.

**Doporučení pořadí implementace:**  
Nejprve (2.1) a (2.2) – přímé propojení s modulem Vyúčtování a minimální nová logika. Poté (2.4) – zpožděné úkoly. Následně (2.3) a (2.5) podle priority byznesu (cash flow vs. motivace týmu).

---

## 3. NÁVRH NA ÚPRAVU A OPTIMALIZACI VÝKONU

### 3.1 Rizika při ~1000 uživatelích a ~5000 úkolech

- **Úkoly:** `watchTasksRaw` má **limit 500**. Při 5000 úkolech tenant vidí jen posledních 500 (řazení `scheduled_start DESC`). Starší úkoly (např. minulý měsíc) se na Nástěnku ani do streamu nedostanou. Dnešní plán a „dnešní“ metriky mohou být neúplné, pokud je většina úkolů mimo tento výřez.
- **Rezervace:** Stejný princip – limit 500. Graf „14 dní“ a stav bytů jsou počítány jen z těchto 500 rezervací. Při velkém počtu bytů a rezervací může být výřez nedostatečný.
- **Načítání najednou:** Dashboard čeká na **všechny čtyři** providery (tasks, reservations, apartments, team). Žádné postupné renderování; při pomalé síti nebo velkém tenantovi je první malba blokovaná dokud nejsou všechna data.
- **dashboardSummaryProvider:** Projíždí **všechny** úkoly a rezervace z providerů (až 500 + 500) v paměti – několik průchodů (pending, problem, dnešní skladba, 14 dní rezervací). Při 500+500 je to stále v řádu milisekund, ale při odstranění limitu nebo růstu objemu by mohlo narůst.
- **Žádná cache / TTL:** Při každé návštěvě Nástěnky a při každém Realtime eventu se znovu počítají agregace. Není oddělený „dashboardový“ endpoint s krátkým TTL.

### 3.2 Doporučené optimalizace

1. **Dashboard-specifický stream úkolů (časové okno)**  
   Pro Nástěnku nepotřebujeme všech 500 úkolů. Stačí např. úkoly od „dnes − 1 den“ do „dnes + 14 dní“ (nebo podobné okno).  
   - Zavedení např. `adminTasksStreamForDashboardProvider`, který volá novou metodu repozitáře s filtrem `scheduled_start` / `due_date` v tomto rozsahu a rozumným limitem (např. 200).  
   - Hlavní `adminTasksStreamProvider` pro záložku Úkoly ponechat (eventuálně s vyšším limitem nebo stránkováním), aby kalendář a seznam úkolů měly kompletní data.

2. **Agregace rezervací pro graf na backendu**  
   Graf „Vývoj rezervací (14 dní)“ potřebuje jen 14 čísel (počet příjezdů po dnech).  
   - Varianta A: Supabase RPC (např. `get_reservations_trend(tenant_id, date_from, date_to)`) vrací přímo pole 14 hodnot.  
   - Varianta B: Zachovat stream rezervací pro „stav bytů“, ale pro graf použít samostatný lehký dotaz (aggregate COUNT GROUP BY den) nebo RPC.  
   Sníží se objem dat přenášených do klienta a množství výpočtů v `dashboardSummaryProvider`.

3. **Lazy / postupné načítání sekcí**  
   - Hlavička + Action Strip (závislé na `dashboardSummaryProvider` + úkoly + peněženky) mohou zůstat „nad foldem“.  
   - Sekce „Manažerský přehled“ (grafy) a „Dnešní externí služby“ mohou být v samostatných widgetech s vlastním `when(loading: …, data: …)`.  
   - Např. nejdřív zobrazit hlavičku, Action Strip a tři sloupce (plán, byty, tým) hned jak máme úkoly + rezervace + apartmány + tým; grafy načíst hned poté bez blokování první malby.  
   Dnes se čeká na všechno – rozdělení pomůže vnímané rychlosti.

4. **Zachovat a zviditelnit limity**  
   - V repozitářích je limit 500 u úkolů a rezervací – v dokumentaci a v kódu explicitně uvádět, že Dashboard a streamy jsou navržené na „posledních N záznamů“.  
   - Pro úplné historické přehledy používat jiné cesty (Reporty, exporty, filtrované obrazovky se stránkováním).

5. **Možná cache pro Dashboard Summary**  
   - `dashboardSummaryProvider` je čistý Provider přepočítávající se při každé změně úkolů/rezervací/peněženek.  
   - Pokud by se v budoucnu přidaly těžší výpočty, lze zvážit krátkou TTL cache (např. 30 s) pro „počty“ (pending, problem, hotovost), zatímco Realtime by invalidoval cache při změně.  
   Pro současný rozsah dat to není nutné.

### 3.3 Shrnutí optimalizací

| Problém | Návrh řešení |
|--------|----------------|
| Limit 500 úkolů může ořezat „dnešní“ úkoly | Dashboardový stream s časovým oknem (např. −1 až +14 dní) a menším limitem. |
| Graf rezervací tahá až 500 rezervací | RPC nebo agregovaný dotaz vrací jen 14 čísel. |
| Čekání na všechna data před první malbou | Lazy sekce – nejdřív hlavička + Strip + operativa, grafy a externí služby až poté. |
| Budoucí růst agregací | Volitelně TTL cache pro dashboard summary. |

---

## 4. SOUHRN

- **Současný stav:** Dashboard je postaven na čtyřech hlavních datech (úkoly, rezervace, apartmány, tým) a dvou streamech (peněženky, dashboard summary). Všechny úkoly a rezervace jsou omezeny limitem 500; filtrace a agregace probíhají na klientovi.
- **Nové widgety:** Největší přínos s minimem nových tabulek přináší widgety z modulu Vyúčtování (čeká na vyplacení, fronta ke schválení), dále kritické/zpožděné úkoly, volitelně očekávaný příjem z fakturace a nejaktivnější pracovník.
- **Výkon:** Při 1000 uživatelích a 5000 úkolech je hlavní riziko limit 500 (neúplný výřez) a blokující načtení všech dat před vykreslením. Doporučuje se dashboardový stream s časovým oknem, agregace trendu rezervací na backendu a postupné zobrazení sekcí.

Po schválení priorit lze jednotlivé body z této zprávy rozpracovat do konkrétních úkolů (úpravy providerů, nové RPC, změny UI).
