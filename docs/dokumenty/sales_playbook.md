# FalcoNest Sales Playbook – Trénink obchodníků a ambasadorů

**Pro koho:** Obchodníci, ambasadoři, rodina a přátelé, kteří chtějí FalcoNest s nadšením prodávat  
**Základ:** 100 % podloženo reálným kódem (viz [v1_product_audit.md](./v1_product_audit.md))  
**Jazyk:** Česky, čtivě, lidsky

---

## 1. Čtyři hrdinové FalcoNestu (Persony a jejich proměna)

Každá role v systému má svůj starý svět plný bolesti – a nový svět, kde FalcoNest zvedá tíhu z jejich ramen.

---

### Hrdina 1: Majitel agentury (Admin)

**Dnešní noční můra:**  
Excel, hromady papírů, WhatsApp plný „kde jsou klíče?“ a „už je to uklizený?“ Několik oken otevřených najednou, nervozita, jestli něco neprošvihnul. Neustálé telefony od majitelů. Nejasno, kolik reálně vydělává a kde jsou peníze v pohybu.

**FalcoNest realita:**  

Na **Nástěnce** vidí na první pohled: kolik má bytů, kolik je dnes příjezdů a odjezdů, trendy oproti včerejšku. Žádné listování v tabulkách. Rychlé akce ho vedou rovnou na Rezervace nebo Úkoly, když se něco děje.

Modul **Finance** mu dává přehled o zaměstnanecké pokladně – kdo má v terénu vybranou hotovost, kdo už odevzdal. A **Billing modal** (při přístupu Super Admina) ukazuje MRR a fakturaci napříč agenturami.

**Proměna:** Z chaosu plného obav na klidný pohled z výšky – vidí zisk, rizika i příležitosti na jednom místě.

---

### Hrdina 2: Dispečer (Admin – člověk, co to reálně řídí)

**Dnešní noční můra:**  
Excel s rezervacemi, druhý Excel s úkoly. Přepisování datumů z jedné tabulky do druhé. Zapomenuté úklidy, dvojité rezervace, zoufalé hovory: „Máte uklidit byt 3 před příjezdem v 15:00?“ Neví, kdo je kde a co už je hotové.

**FalcoNest realita:**  

V **Kanbanu rezervací** má Nové → Potvrzené → Ubytováno → Odhlášeno. Rezervace, které majitel potvrdil a předal, vidí hned. Žádné přepisování z mailů nebo WhatsApp.

**Task Automator** – když přijde nová potvrzená rezervace, dispečer spustí generování úkolů. Systém mu sám navrhne úklid, transfer, check-in, check-out podle dat rezervace a nastavení služeb. Dispečer jen schválí a přiřadí personálu.

**Plánovací kalendář** – týdenní mřížka s úkoly a rezervacemi. **Drag & Drop**: přetažením přiřadí úkol jinému pracovníkovi nebo jiný čas. Vidí kolize, back-to-back úklidy, všechno na jednom místě.

**Proměna:** Z rutiny kopírování a strachu, že něco ztratí, na řízení jedním pohledem. Rezervace → úkoly → personál – vše propojené.

---

### Hrdina 3: Pracovník v terénu (Worker – uklízečka, údržbář)

**Dnešní noční můra:**  
Papír se seznamem adres. Telefon bez signálu ve sklepě. Neví, kde přesně je další byt, musí volat dispečing. Ztráta klíčů, zapomenutý kód od schránky. Po uklidu další hovor: „Už jsi to odklikl?“ Nemůže, protože netuší, jak to systému říct.

**FalcoNest realita:**  

Na hlavní obrazovce „Moje práce“ vidí úkoly rozdělené na **Dnes | Zítra | Později**. Žádné papíry. Každá karta má čas, byt, adresu a tlačítko **Navigace** – jedno kliknutí a otevře se Google Maps.

**Offline-first:** Data jsou uložená přímo v telefonu (Isar databáze). Když ztratí signál v podzemí, v horách nebo na zapadlé adrese, seznam úkolů funguje dál. Může označit „Probíhá“ nebo „Hotovo“ i bez sítě. Po návratu signálu se vše samo synchronizuje.

V detailu úkolu má adresu, schránku na klíče, poznámky majitele. Vše na jednom místě. Žádné hledání v diáři nebo v notýsku.

**Proměna:** Z improvizace a stresu na klidnou práci podle seznamu, který vždy funguje – i v tom nejhorším signálu.

---

### Hrdina 4: Majitel apartmánu (Owner – zákazník agentury)

**Dnešní noční můra:**  
Platí agentuře provizi, ale neví, co se reálně děje. „Je byt uklizený?“ „Kdo tam teď bydlí?“ „Kolik mám tento měsíc obsazeno?“ Neustálé dotazy mailem nebo telefonem. Pocit, že platí za něco, co neovlivní ani nekontroluje.

**FalcoNest realita:**  

**Property Cards** – každý byt jako přehledná karta. Na ní **teploměr obsazenosti**: „Obsazenost tento měsíc: 18 z 30 dní“ s barevným pruhem (zelená = skvěle, oranžová = solidně, červená = málo). Hned vidí, jak mu byt jede.

Pod teploměrem **3 nejbližší rezervace** – datum a jméno hosta. Žádné listování v mailech.

**Detail bytu** – přístup ke schránce, kódy, časy check-in/check-out, poznámky. Vše na jednom místě, včetně kopírování do schránky.

**Kanban rezervací** – může sám přidat rezervaci a jedním kliknutím **„Potvrdit a předat agentuře“** ji předat. Žádné emaily, žádné přeposílání.

**Read-only Kanban úkolů a kalendář** – vidí, že agentura pracuje (Zadáno → Probíhá → Hotovo), ale nemusí volat. Má přehled, aniž by obtěžoval.

**Proměna:** Z pocitu „platím a nic nevidím“ na klid a důvěru – vše je transparentní a pod kontrolou.

---

## 2. Magický workflow – Jeden den s aplikací

Příběh jednoho rezervačního dne od majitele po uklízečku – krok za krokem, tak jak to v systému reálně funguje.

---

**Krok 1: Majitel zadá rezervaci a předá ji agentuře**

Majitel má novou rezervaci od hosta. Otevře Klientský portál, sekci Rezervace, klikne na „Nová rezervace“. Vyplní byt, datumy OD–DO, jméno hosta, počet osob, služby. Pak klikne na **„Potvrdit a předat agentuře“** (Handoff).

Rezervace se přesune ze sloupce „Nové“ do „Potvrzené“ a je vidět v Admin rozhraní. Žádný e-mail, žádné přeposílání.

---

**Krok 2: Dispečer ji vidí a vygeneruje úkoly**

Dispečer otevře Admin, Rezervace. Nová potvrzená rezervace je v Kanbanu. Spustí **Task Automator** – generování úkolů z rezervací.

Systém podle nastavení služeb a typů (úklid, transfer, check-in, check-out) vytvoří návrhy úkolů. Dispečer je schválí, přiřadí personálu v **Plánovacím kalendáři** – třeba přetažením úkolu na konkrétního uklízeče a čas.

Úkoly jsou v databázi, přiřazené pracovníkovi.

---

**Krok 3: Uklízečka to vidí v mobilu – i bez signálu**

Uklízečka otevře mobilní aplikaci „Moje práce“. Úkoly jsou seskupeny: **Dnes | Zítra | Později**. Vidí nový úklid – čas, adresu, byt.

Přijede na místo. Ve sklepě nebo v údolí bez signálu. **Offline-first** – data jsou v lokální Isar databázi v telefonu. Seznam se načetl už dříve. Může normálně pracovat.

Po dokončení úklidu klikne na úkol, změní stav na **„Hotovo“**. Změna se uloží lokálně; po obnovení signálu se odešle na server (Timestamp Merging řeší případné konflikty).

---

**Krok 4: Stav se propíše dál**

Dispečer vidí v Admin Kanbanu úkol přesunutý do „Hotovo“. Majitel vidí na své Property Card změnu statusu – místo „Probíhá úklid“ je **„Čistý“**. A pokud je to v den příjezdu hosta, teploměr obsazenosti ho už počítá – majitel má živý přehled.

Jeden rezervační den. Žádné telefony navíc. Všechno v jednom systému.

---

## 3. Tři neprůstřelné argumenty pro obchodníky

Jak prodat technologii jazykem, kterému zákazník rozumí.

---

### Argument 1: Žádné výpadky v terénu

**Obchodní věta:**  
„Vaši uklízečky a údržbáři pracují často v místech se špatným signálem – sklep, horské údolí, zapadlé objekty. U běžných aplikací by museli čekat na načtení, nebo by vůbec nic neviděli. U nás mají všechna data uložená přímo v telefonu. Seznam úkolů, adresy, kódy od schránek – vše funguje i bez internetu. Odkliknou hotovo, a když se znovu připojí, vše se samo odešle. Žádné ztracené úkoly, žádné přerušení práce.“

**Technický základ:** Isar lokální databáze, offline-first architektura, Timestamp Merging pro řešení konfliktů při synchronizaci. (viz `TaskRepositoryMobile`, `IsarService`, `task_repository_mobile.dart`)

---

### Argument 2: Bezpečí jako v bance

**Obchodní věta:**  
„Každá agentura vidí jen svoje data. Majitel bytu vidí jen svoje byty. Žádná agentura nemůže náhodou ani úmyslně nahlédnout k druhé. Databáze používá Row Level Security – pravidla na úrovni řádků. Je to jako trezor: i kdyby někdo měl přístup k systému, uvidí jen to, co mu patří. Vaši klienti i vy můžete být v klidu.“

**Technický základ:** RLS politiky na tabulkách tenants, apartments, reservations, tasks, profiles. Izolace přes `tenant_id` a `apartment_owners`. (viz `docs/RLS_DART_COMPATIBILITY.md`, migrace RLS)

---

### Argument 3: Připraveno na růst

**Obchodní věta:**  
„Systém je navržen pro více agentur a tisíc uživatelů. Multi-tenant architektura to zvládne. A co je důležité – aplikace už dnes běží ve třech jazycích: česky, anglicky a španělsky. Přidání dalšího trhu (např. Německo, Itálie) znamená v podstatě nový překlad, ne přepisování aplikace. Jste připraveni expandovat, aniž byste museli měnit systém.“

**Technický základ:** i18n přes `easy_localization`, JSON soubory `cs.json`, `en.json`, `es.json`. Multi-tenant databáze s `tenant_id` na všech relevantních tabulkách.

---

## 4. Rychlá taháková kartička

| Kdo | Hlavní bolest | FalcoNest řešení v jedné větě |
|-----|---------------|------------------------------|
| Majitel agentury | Chaos, nevidím zisk | Nástěnka KPI, Finance, Billing – vše na jednom místě |
| Dispečer | Excel, zapomenuté úklidy | Kanban rezervací + Task Automator + Plánovací kalendář s Drag&Drop |
| Uklízečka | Papíry, žádný signál | Moje práce: Dnes/Zítra/Později, navigace, offline databáze Isar |
| Majitel bytu | Nevidím, co se děje | Property Cards s teploměrem, 3 rezervace, handoff jedním kliknutím |

---

## 5. Závěr

FalcoNest není jen software. Je to nový způsob, jak spolu agentury, personál a majitelé bytů pracují – bez zbytečných hovorů, bez ztracených informací, s přehledem a důvěrou.

Každá zmíněná funkce v tomto playbooku existuje v kódu. Obchodník může mluvit s jistotou – slibuje jen to, co aplikace skutečně umí.

---

*Založeno na [v1_product_audit.md](./v1_product_audit.md). Verze 1.0, únor 2025.*
