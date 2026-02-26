# FalcoNest – Hloubkový audit mobilní aplikace pro personál (Worker Flow)

**Datum:** 23. února 2025  
**Typ:** Read-only UX a byznysová analýza  
**Zaměření:** Výhradně mobilní aplikace pro personál v terénu (úklid, údržba, řidiči, check-in agenti).

---

## 1. DENNÍ RUTINA (Flow)

### 1.1 Co vidí pracovník při otevření aplikace

**WorkerDashboardScreen** – hlavní obrazovka „Moje práce“:

- **Seznam úkolů** přiřazených aktuálně přihlášenému uživateli
- **Řazení:** Dnes → Zítra → Později (podle `scheduled_start`)
- **Uvnitř každé skupiny:** úkoly seřazené podle plánovaného času (nejdříve první)

### 1.2 Které úkoly se zobrazují

- **Zahrnuty:** pouze stavy `assigned` a `in_progress`
- **Vynechány:** `pending`, `draft`, `nový`, `new` (návrhy) a `completed`, `done`, `dokončeno`, `hotovo` (dokončené)

Pracovník tedy vidí **všechny budoucí a právě probíhající úkoly** (dnes, zítra i později). Minulé dokončené úkoly v dashboardu nejsou.

### 1.3 Další prvky na hlavní obrazovce

- **Banner offline:** oranžový pruh „Offline režim“, když není připojení
- **Banner chyby syncu:** červený pruh při selhání synchronizace na pozadí
- **Pull-to-refresh:** ruční obnovení dat
- **Tlačítko Refresh:** v AppBar
- **Navigační drawer:** Vizitka (jméno, e-mail, role), Moje nepřítomnost, Změna PINu, Odhlášení

### 1.4 Stavy úkolu a přechody

Dvoufázový flow:

1. **Zahájit** → stav `in_progress` (+ uložení `startedAt`)
2. **Dokončit** → stav `completed` (+ uložení `completedAt`)

Na kartě úkolu je **status indikátor** (tečka): modrá = probíhá, oranžová = assigned.

---

## 2. SPECIALIZOVANÉ OBRAZOVKY ÚKOLŮ

### 2.1 Úklid (CleaningTaskScreen)

**Zobrazení:**
- Název úkolu / apartmán
- Adresa (bez navigace na mapu)
- Popis
- Custom note z metadat (pokud existuje)

**Akce:**
- Zahájit práci → Dokončit
- Žádné fotky
- Žádné odškrtávání místností
- Žádná evidence prací

**Poznámka:** Finance (amount_to_collect, collection_breakdown) jsou záměrně skryty – uklízečka je nevidí.

### 2.2 Check-in (CheckinTaskScreen)

**Zobrazení:**
- Název / apartmán (část před/za dvojtečkou)
- Datum a čas
- Adresa + **tlačítko Navigovat** (Google Maps)
- Popis
- Custom note (instrukce k předání klíčů)
- **Banner částky k vybrání** (amount_to_collect) – pokud > 0
- **Rozpad platby** (collection_breakdown) – položky typu úklid, check-in, transfer

**Akce:**
- Zahájit → Dokončit
- Při Dokončit, pokud existuje `amount_to_collect` > 0:
  - Dialog **Výběr hotovosti**
  - 3 možnosti: **ANO** (vybral), **NE** (nevybral – `cash_collection_failed`), **Zrušit**

### 2.3 Check-out (CheckoutTaskScreen)

**Zobrazení:**
- Stejná struktura jako Check-in
- Custom note (na co si dát pozor při kontrole)
- **Informační karta auditu** – očekávaná částka, rozpad (účtenka)
- Žádný výběr hotovosti – jen informace

**Akce:**
- Zahájit → Dokončit
- Bez cash collection dialogu – check-out slouží spíše jako informace o očekávaném auditu

### 2.4 Transfer (TransferTaskScreen)

**Zobrazení:**
- Název, čas, adresa + Navigovat
- Karta „Instrukce / Informace o letu“ (description + custom_note – např. číslo letu, jméno klienta)
- **Banner částky k vybrání** – pokud `amount_to_collect` > 0

**Akce:**
- Zahájit → Dokončit
- Při Dokončit, pokud `amount_to_collect` > 0: stejný cash collection dialog jako u Check-inu

### 2.5 Údržba (MaintenanceTaskScreen)

**Zobrazení:**
- Název, čas, adresa + Navigovat
- Popis problému (custom_note nebo description)

**Akce:**
- Zahájit → **Závada vyřešena**
- Žádné zadávání materiálu
- Žádné fotky
- Jen potvrzení dokončení

### 2.6 Materiál (MaterialTaskScreen)

**Zobrazení:**
- Seznam materiálu k doplnění (custom_note nebo description)

**Akce:**
- Zahájit → **Materiál doplněn**
- Žádné zadávání nakoupených položek
- Jen odškrtnutí, že materiál byl doplněn

### 2.7 Závada (IssueTaskScreen)

Úkol typu „Závada“ vytvořený z Adminu (např. rozbitá TV).

**Zobrazení:**
- Popis problému (custom_note)

**Akce:**
- Zahájit → **Závada vyřešena**
- Bez možnosti nahlásit nový problém – pracovník jen označí existující úkol jako vyřešený

### 2.8 Výchozí (DefaultTaskScreen)

Pro typy mimo výše uvedené.

**Zobrazení:**
- Název, adresa, popis, custom_note

**Akce:**
- Zahájit → Dokončit

### 2.9 Moje nepřítomnost (WorkerAbsencesScreen)

Obrazovka dostupná z Drawer menu – **Moje nepřítomnost**.

**Zobrazení:**
- Seznam vlastních nepřítomností (dovolená, nemoc) z tabulky `staff_absences`
- Filtrováno podle `profile_id` a `tenant_id` přihlášeného uživatele
- Karta: datum od–do, důvod (Dovolená / Nemoc / Jiné nebo volný text)

**Akce:**
- FAB „Přidat nepřítomnost“ – otevře dialog
- Dialog: výběr data Od, Do, dropdown Důvod (Dovolená, Nemoc, Jiné)
- Při offline: zápis do `MutationQueueService`, odeslání po obnovení sítě

---

## 3. ŘEŠENÍ PROBLÉMŮ A KOMUNIKACE

### 3.1 Tlačítko „Nahlásit problém“

V mobilní aplikaci **neexistuje** tlačítko „Nahlásit problém“ ani podobná akce.

- **Issue** je typ úkolu vytvořeného v Adminu – pracovník ho pouze vyřeší, nepoužívá ho k hlášení nových problémů.
- Při výskytu problému (rozbitá TV, host nedorazil, poškození apod.) **nemá pracovník v aplikaci žádný způsob**, jak to nahlásit.

### 3.2 Kontakt na hosta

**Pracovník v mobilní aplikaci nevidí:**
- Jméno hosta
- Telefon hosta
- E-mail hosta

Data rezervace (guest_name, guest_phone) se při syncu stahují do Isaru, ale **nejsou mapována do WorkerTaskDetail** ani zobrazena v UI. Pracovník nemůže hosta volat přímo z aplikace.

### 3.3 Co pracovník vidí místo toho

- Název úkolu (často ve formě „Check-in: Petr Sokol“ apod.)
- Custom notes (instrukce, poznámky z Adminu)
- Adresa bytu, čas

---

## 4. BÍLÁ MÍSTA V MOBILNÍ APLIKACI (UX díry)

### 4.1 Skrytá data – keybox a ownerNotes

- **WorkerTaskDetail** obsahuje `keybox` a `ownerNotes` – data jsou načtena z apartmánu.
- **Žádná obrazovka je nezobrazuje.**

Uklízečka/check-in agent typicky potřebuje kód od keyboxu – ten v UI **není nikde vidět**.

### 4.2 Chybějící navigace u Úklidu

- **CleaningTaskScreen** nemá tlačítko Navigovat – adresa je jen text.
- Ostatní typy (Check-in, Check-out, Transfer, Údržba, Materiál) mají Navigovat do map.

### 4.3 Žádné potvrzovací dialogy

- Zahájit práci – **žádné** potvrzení.
- Dokončit úkol – **žádné** potvrzení (kromě cash collection, kde je to záměrné).
- Riziko omylem stisknout Dokončit místo Zahájit.

### 4.4 Stav „assigned“ bez „Přijmout“

- Úkoly se zobrazují ve stavu assigned.
- Není vidět explicitní krok „Přijmout úkol“ – pracovník rovnou může zahájit.
- To může být záměrné (úkoly jsou předpřipravené), ale není jasné, zda někdy bylo „Přijmout“ plánováno.

### 4.5 Dokončené úkoly

- Po Dokončit se pracovník vrátí na dashboard – dokončený úkol zmizí.
- Není historie ani „Moje dokončené úkoly“.

### 4.6 Offline a sync chyby

- Při offline práci je banner, ale není jasné, kdy se data synchronizují.
- Chyba syncu zobrazí červený banner – po tapu se zpráva skryje, ale opětovný sync se nespustí automaticky.

### 4.7 Fotky u úkolů

- Úkol má pole `photoUrl` (např. z Supabase Storage).
- Žádná obrazovka **neunáší fotky** – pracovník nemůže fotit ani prohlížet fotky k úkolu.

### 4.8 Rozlišení typů v routing

- `Issue` vs `Maintenance` – oba mají podobný účel (popis problému).
- Issue má červené pozadí, Maintenance oranžové.
- Oba končí „Závada vyřešena“ / „Vyřešeno“.

---

## 5. SHRNUTÍ – CO MOBILNÍ APP PRO PERSONÁL UMÍ A CO NE

| Oblast | Stav |
|--------|------|
| Seznam úkolů (Dnes/Zítra/Později) | ✅ |
| Zahájení a dokončení | ✅ |
| Check-in / Check-out / Transfer cash flow | ✅ |
| Navigace do map (kromě Úklidu) | Částečně |
| Offline režim | ✅ |
| Time tracking (startedAt, completedAt) | ✅ |
| Keybox / kód od schránky | ❌ (data jsou, ale nejsou zobrazena) |
| Poznámky majitele | ❌ (data jsou, ale nejsou zobrazena) |
| Kontakt na hosta | ❌ |
| Nahlášení problému | ❌ |
| Fotky u úkolu | ❌ |
| Odškrtávání místností u úklidu | ❌ |
| Zadání materiálu u údržby | ❌ |
| Potvrzovací dialogy u dokončení | ❌ |

### Závěr

Mobilní aplikace pro personál je **MVP pro základní flow** – zobrazení úkolů, zahájení, dokončení, výběr hotovosti u Check-inu a Transferu, navigace do map. Offline-first a time tracking jsou funkční.

Pro každodenní nasazení uklízečkám a check-in agentům ale chybí klíčové prvky:
1. **Keybox / kód** – data existují, UI je nezobrazuje.
2. **Kontakt na hosta** – telefon pro call/SMS.
3. **Nahlášení problému** – způsob, jak upozornit na závadu nebo nestandardní situaci.
4. **Navigace u Úklidu** – stejně jako u ostatních typů.

Bez těchto prvků je nutné spoléhat se na externí kanály (telefon, WhatsApp, papír), což snižuje hodnotu aplikace v terénu.

---

*Report vznikl jako read-only analýza codebase. Žádný kód nebyl měněn.*
