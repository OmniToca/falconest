# FalcoNest – Komplexní prodejní a marketingový dokument

> **Pro koho:** NotebookLM, obchodní prezentace, audio podcast, sales deck  
> **Jazyk:** Čeština  
> **Cíl:** Property manažeři 10–20 apartmánů, Costa Blanca / Torrevieja, Španělsko  
> **Zdroj:** 100 % podloženo reálným kódem aplikace FalcoNest

---

## 1. THE HOOK – Problém (Noční můra property managera)

Představte si typický den **Anny**, která spravuje 15 apartmánů u moře na Costa Blance. Má 4 terénní pracovníky: dvě uklízečky, jednoho řidiče na transfery a jednoho handymana. A každé ráno začíná stejně:

**Ranní chaos:**  
WhatsApp skupina bují zprávami. „Kde je klíč od Casa Sol?“ „Host přijíždí ve 14:00, kdo to zvládne?“ „V apartmánu 7 teče záchod – kdo to hlásil?“ Odpovědi se topí v dlouhých vláknách, diskuze o tom, kdo co řekl, zmizí za pár hodin. **Ztracené účtenky:** Uklízečka koupila v Mercadoně mop za 12 eur. Kde je ta účtenka? V kapse? Vypraná v pračce? Příští měsíc Anna neví, jestli 12 eur strhnout majiteli bytu, nebo to bylo „na agenturu“. **Zapomenuté úklidy:** Rezervace se změnila včera večer – odjezd o den dříve. Kdo to věděl? Úklid se neplánoval. Host přijede do nedouklideného bytu. **Offline pracovníci:** Řidič je na letišti v Alicante, signál minimální. Nemůže potvrdit výběr hotovosti. Nemůže nahlásit závadu. Vrací se do kanceláře až večer – a pak teprve vše zapište. **Nedělní Excel:** A pak ta nejhorší část. Nedělní odpoledne. Anna sedí před Excel tabulkou a skládá puzzle: Které úkoly patří kterému majiteli? Kolik vybrali hosté v hotovosti? Které výdaje strhnout z účtu bytu? Co poslat účetní (gestoría) pro Modelo 303? Hodiny práce, riziko chyby, stres.

**To je realita tisíců malých property manažerů.** WhatsApp + Excel. Žádná systémová paměť. Žádná auditní stopa. Žádný klid.

---

## 2. THE SOLUTION – FalcoNest Value Proposition

**FalcoNest není rezervační systém.** Neprodáváme booking engine. Nepodřezáváme vám provize z rezervací.

**FalcoNest je operační štít.**  
Jednotný systém, který nahradí chaos WhatsApp skupin, ztracených účtenek a nedělního Excelu. Zaměřený na **operativu**: kdo co udělá, kdy to udělá, kolik to stálo a co z toho fakturovat.

### Tři pilíře hodnoty:

| Pilíř | Co to znamená |
|-------|----------------|
| **Extrémní jednoduchost** | Uklízečka nepotřebuje školení. Stiskne „Start“, udělá práci, stiskne „Hotovo“. Dispečer vidí vše na jedné nástěnce. |
| **Nulové provize** | Žádné procenta z rezervací. Placíte paušál za byt. Vaše marže zůstává vaše. |
| **Operační klid** | Vše je zaznamenáno. Každý úkol, každá transakce, každá fotka. Když účetní nebo majitel položí otázku, máte odpověď za sekundy. |

---

## 3. THE „WOW“ FEATURES – Co FalcoNest reálně umí

*Vše níže je implementováno v kódu. Žádné sliby – jen funkce, které existují.*

### 3.1 Jednoklíkové iCal automatizace

**Problém:** Rezervace přicházejí z Airbnb, Booking, Smoobu, direct. Manuální přepis = chyby a ztracený čas.

**Řešení:** U každého apartmánu zadáte **jeden odkaz** na iCal feed (`.ics`). FalcoNest stáhne události, vyparsuje příjezdy a odjezdy a **automaticky vytvoří rezervace**. Duplicity se filtrují přes `external_uid` – žádné dvojité záznamy. Rezervace se objeví v Kanbanu a v Plachtě. Odkaz jednou nastavíte, sync proběhne na vyžádání nebo naplánovaně.

**Benefit:** Z pěti minut práce na rezervaci na **nulu**. Rezervace jsou v systému dřív, než stihnete otevřít další platformu.

---

### 3.2 „Hloupě jednoduchá“ mobilní aplikace pro pracovníky

**Problém:** Terénní pracovníci nejsou IT specialisté. Potřebují něco, co pochopí za 30 sekund.

**Řešení:** Worker App s **offline-first** architekturou. Úkoly se stáhnou do telefonu. Pracovník vidí „Dnes / Zítra / Později“. Otevře úkol, stiskne **Start**, udělá práci, stiskne **Hotovo**. I když je v suterénu bez signálu – vše se uloží lokálně a **po obnovení spojení se automaticky synchronizuje**. Fronta mutací (`DriftMutationQueueService`) zaručuje, že žádný záznam nezmizí.

**Benefit:** Žádné „zapomněl jsem to zapsat“. Žádné tlačení na pracovníky, aby „něco nahráli“. Systém to zvládne sám.

---

### 3.3 Vizuelle důkaz – fotografie ke každému úkolu

**Problém:** Host tvrdí, že apartmán byl špinavý. Majitel tvrdí, že uklízečka něco rozbila. Kdo má pravdu?

**Řešení:** **Camera integrace** na úrovni dokončení úkolu. Pracovník může přiložit fotky ke kontrole stavu, k dokončení úklidu nebo k hlášení závady. Fotky se ukládají do Supabase Storage (`falconest_media/tasks/`) a jsou **automaticky včleněny do PDF fakturačních podkladů**. Každý úkol s fotkou = důkaz.

**Benefit:** Nezpochybnitelná dokumentace. Méně sporů. Více důvěry od majitelů a hostů.

---

### 3.4 Hlasové hlášení závad (Voice-to-Task)

**Problém:** Uklízečka našla prasklou dlažku. Měla by psát popis? V jakém jazyce? Česky, španělsky?

**Řešení:** **Mikrofon v dialogu hlášení závady.** Pracovník namluví problém v libovolném jazyce (např. česky). Text se přepíše lokálně (speech-to-text). Při synchronizaci jde payload do Edge Function `process-issue-ai`, která pomocí AI **přeloží popis do španělštiny** a vytvoří profesionální nadpis. Pokud AI selže (výpadek API), úkol se **nikdy neztratí** – uloží se se surovým textem a fallback nadpisem.

**Benefit:** Hlášení závad za 10 sekund. Žádné psaní. Žádné ztracené reporty.

---

### 3.5 Firemní výdaje: fotka účtenky = záznam

**Problém:** Pracovník koupil v Mercadoně materiál. Účtenka skončí v koši nebo v pračce. Příští měsíc nikdo neví, kolik a kam to zařadit.

**Řešení:** V **Worker Wallet** je tlačítko „Přidat firemní výdaj“. Pracovník vyfotí účtenku, zadá částku, volitelně vybere apartmán (pro stržení nákladů ve faktuře majitele). Záznam jde i **offline** do fronty a odešle se při obnovení sítě. Fotka účtenky se ukládá do Storage (`tenant_id/expenses/uuid.jpg`) a je **součástí PDF fakturačních podkladů**.

**Benefit:** Žádné ztracené účtenky. Každý výdaj má fotodokumentaci. Majitel vidí, co se utratilo za jeho byt.

---

### 3.6 Zaměstnanecká pokladna a výběr hotovosti

**Problém:** Řidič vybere od hosta 200 eur za transfer. Kde jsou? Odevzdal je? Kolik měl vybrat?

**Řešení:** **Employee Cash Wallets** – každý pracovník má „kapsu“. Při Check-in nebo Transferu systému víte očekávanou částku (`expected_amount` z metadata úkolu). Pracovník při dokončení potvrdí, kolik vybral (včetně spropitného či nedoplatku). Transakce typu `COLLECTED_FROM_GUEST` se zapíše. Dispečer vidí, kdo má u sebe kolik hotovosti. Při odevzdání v kanceláři: `HANDED_TO_AGENCY` – balance se vynuluje.

**Benefit:** Plná kontrola hotovosti. Žádné „zapomněl jsem odevzdat“. Auditní stopa pro účetní.

---

### 3.7 Šablony zpráv a upozornění na transfery

**Problém:** Host potřebuje instrukce 48h před letem, 24h před letem, při přistání. Kdo má čas to posílat ručně?

**Řešení:** **Message Templates** s placeholdery (`{guest_name}`, `{flight_number}`). Edge Function `template-reminders` běží v blocích 7:00, 11:00, 15:00, 19:00 (Madrid time) – žádné noční buzení. Vyhodnotí transfer úkoly a pošle FCM push pracovníkovi: „Čas na zprávu: [host], let v 14:30.“ Pracovník otevře šablonu, doplní a odešle přes WhatsApp link.

**Benefit:** Automatizovaná komunikace. Host je informovaný. Pracovník nesměřuje ručně.

---

### 3.8 Plánovací kalendář a Drag & Drop

**Problém:** Kolize úkolů, přetažení na jiný den, vizuální přehled týdne.

**Řešení:** **Planning Calendar** – týdenní mřížka s 15minutovými sloty. Rezervace a úkoly se zobrazují vizuálně. **Drag & Drop** pro přesunutí úkolu na jiný čas nebo den. Detekce kolizí. Vyhledávání.

**Benefit:** Jeden pohled na celý týden. Žádné překrývání. Rychlé přeplánování při nemoci nebo změně letu.

---

### 3.9 Klientská zóna pro majitele (Owner Portal)

**Problém:** Majitel chce vidět své apartmány, rezervace a **fakturační podklady** bez toho, aby musel volat agenturu.

**Řešení:** **Owner Portal** – majitel se přihlásí a vidí pouze své byty, rezervace, úkoly a **Billing**. Kdykoliv může stáhnout PDF vyúčtování za uzamčený měsíc. PDF je vygenerováno on-demand z `billing_snapshots` – zmražená data, žádné „live“ změny.

**Benefit:** Majitel má vlastní přehled. Méně dotazů na agenturu. Profesionální dojem.

---

## 4. THE END-OF-MONTH MAGIC – Deal Closer (Podklady pro fakturaci)

*Toto je funkce, která prodává.*

**Problém:** Konec měsíce. Manažer sedí nad Excel tabulkou. Musí sestavit přehled: které úkoly fakturovat kterému majiteli, kolik vybrali hosté v hotovosti, které firemní výdaje strhnout z účtu bytu. Pak to poslat gestorii pro DPH (Modelo 303). Hodiny práce. Chyby. Stres.

**Řešení:** Modul **finance_export** (Podklady pro fakturaci).

1. Manažer otevře **Finance → Podklady pro fakturaci**.
2. Vybere měsíc.
3. Vidí **seskupení podle klienta (majitele)** – každý majitel má svůj expansion panel s úkoly, cenami a výdaji.
4. Jedno kliknutí: **PDF export**. Systém vygeneruje profesionální PDF report s:
   - Rozdělením úkolů podle rezervací
   - Typem plátce (majitel / host)
   - Firemními výdaji s fotkami účtenek
   - Souhrnem: obrat, co vybrali hosté, výdaje k proplacení, **finální částka k úhradě majiteli**
5. **Excel export** pro další zpracování v účetním softwaru.

PDF obsahuje **fotodokumentaci** – miniatury fotek z úkolů a výdajů. Účetní (gestoría) má vše na jednom místě. Připraveno pro Modelo 303 a fakturaci majitelům.

**Benefit:** Nedělní odpoledne místo hodin v Excelu = **minuty**. Jedno tlačítko. Žádné chyby. Žádný stres.

---

## 5. PRICING & FUTURE VISION

### Transparentní cenění

- **Základní paušál:** `price_per_apartment × počet bytů` – např. **10 EUR / byt / měsíc** (konkrétní cena dle nastavení tenanta).
- **Žádné provize z rezervací.** Vaše marže z Airbnb, Booking, direct zůstává 100 % vaše.
- **Žádné licence na uživatele.** Uklízečka, řidič, handyman – všichni v ceně. Jedna smlouva = jedna agentura.
- **Moduly:** Plánovací kalendář, Chytrá automatizace úkolů, Podklady pro fakturaci (29 EUR/měsíc fixed) – vše volitelné. Trial 14 dní na vybrané moduly.

### Budoucí prémiové moduly (teaser)

- **AI ověření fotografií** – automatická kontrola, zda úklid splňuje standard (např. rozpoznání čistoty povrchů).
- **AI OCR účtenek** – nafotíte účtenku, systém sám vytáhne částku, datum a položky. Žádné ruční zadávání.
- **Integrace chytrých zámků** – dálkové odemykání pro check-in.
- **Skladový modul** – evidence materiálu a spotřeby.

---

## Shrnutí pro 60sekundový pitch

> *„FalcoNest je operační štít pro property managery na Costa Blance. Nahrazuje WhatsApp a Excel jedním systémem: rezervace z iCal odkazu, úkoly v mobilu s offline režimem, fotky ke každému úkolu, firemní výdaje s fotkou účtenky a na konci měsíce jedno tlačítko – PDF pro gestorii. Paušál za byt, nulové provize. Zkuste 14 dní zdarma.“*

---

*Dokument vznikl analýzou kódu FalcoNest. Všechny popsané funkce existují v aplikaci.*
