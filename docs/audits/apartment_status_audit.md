# Audit: výpočet „Stavu apartmánu“ (FalcoNest)

**Datum analýzy:** podle aktuálního stavu repozitáře.  
**Cíl:** popsat přesnou byznys logiku, root cause hlášeného bugu a doporučený směr opravy (bez implementačního kódu).

---

## 1. Kde je logika?

| Místo | Role |
|--------|------|
| **`lib/features/admin/providers/apartment_status_provider.dart`** | **Jediný zdroj pravdy** pro dynamický stav zobrazený na Nástěnce i v seznamu Apartmánů. |
| Funkce **`getApartmentStatusForToday`** | Čistá funkce: `(rezervace, úkoly, apartmentId) → i18n klíč` – používá ji **`admin_dashboard_screen.dart`** pro součty „flotily“ (Uklizeno / K úklidu / Obsazeno). |
| **`apartmentStatusProvider`** | `Provider.autoDispose.family<String, String>` – stejná logika jako `getApartmentStatusForToday`, napojená na `adminReservationsProvider` + `adminTasksStreamProvider`. |
| **`lib/features/admin/admin_apartments_screen.dart`** | U položky bytu: `ref.watch(apartmentStatusProvider(apartment.id))` → badge ve stejném výpočtu jako nástěnka. |

**Související (nejsou hlavní výpočet „dnes“):**

- **`lib/features/admin/providers/apartments_provider.dart`** – model **`ApartmentRow.status`** je **statický sloupec z tabulky `apartments`** (fallback při parsování `'Uklizeno'`). UI seznamu apartmánů pro **dynamický** štítek ale používá **`apartmentStatusProvider`**, ne tento sloupec.
- **`lib/features/owner/providers/owner_apartments_provider.dart`** – vlastní enum **`OwnerApartmentStatus`** a **`_computeStatus`** pro **klientskou zónu majitele** (jiný kontext, jiná pravidla).

---

## 2. Současná pravidla (přesné podmínky)

Vstupy: seznam **`ReservationRow`** (filtrováno podle `apartmentId`), seznam **`TaskRow`** (úkoly pro tenanta; uvnitř funkce se filtruje `apartmentId`).

### Krok A – Obsazeno (`apartments.status.occupied`)

- Projdou se rezervace daného bytu (`status != 'cancelled'`).
- Pro každou se volá **`_isTodayWithinReservation(checkIn, checkOut)`**:
  - `checkIn` / `checkOut` jsou **řetězce ve formátu DD.MM.YYYY** (odpovídají zobrazení z `ReservationRow`, kde `start_date`/`end_date` z DB jdou přes `_formatIsoToDisplay`).
  - **Dnešní kalendářní den** musí ležet v intervalu **[startDay, endDay]** včetně (den příjezdu až den odjezdu).

**Důsledek:** „Obsazeno“ = host dnes **bydlí** (včetně dne příjezdu i dne odjezdu podle stejného intervalu).

### Krok B – K úklidu (`apartments.status.to_clean`)

- Pouze pokud Krok A nenašel obsazení.
- Funkce **`_hasOpenCleaningTask(tasks, apartmentId)`** vrátí `true`, pokud existuje úkol:
  - stejný `apartmentId`,
  - typ vypadá jako úklid: `cleaning` / obsahuje `cleaning` / `úklid`,
  - status **není** dokončený (`_isCompletedStatus`: `completed`, `done`, `hotovo`, `dokončeno`),
  - status **není** návrh (`draft`, `návrh`, `navrh`),
  - a **čas úkolu** (`scheduledStart ?? dueDate`) **není po konci dnešního dne** (`endOfToday` = dnes 23:59:59.999) – tj. úkoly **čistě v budoucnu** se **ignorují**.

### Krok C – Uklizeno / volno (`apartments.status.clean`)

- Pokud A ani B neplatí → vrátí se **`apartments.status.clean`**.

**Časové okno:** Logika je explicitně **„pro dnešek“** – komentáře v souboru mluví o „dnešním“ stavu; u úklidu se navíc **záměrně** nepočítají úkoly naplánované až **za hranicí dnešního dne**.

**Historie rezervací:** Po skončení pobytu se rezervace **nepoužívá** k odvození „ještě neuklizeno po hostech“. Rezervace vstupuje jen do „dnes uvnitř intervalu“ (obsazeno). Minulé / budoucí pobyty mimo dnešek se pro stav **nevyhodnocují**.

---

## 3. Root cause (proč „Uklizeno“, když úklid až 23. 3.)

**Přímá příčina:** V **`_hasOpenCleaningTask`** (řádky cca 60–62 v `apartment_status_provider.dart`) platí:

- Pokud je jediný otevřený úklid **naplánován na budoucí datum** (např. 23. 3.) → splnění podmínky `taskDate.isAfter(endOfToday)` → úkol se **přeskočí** → funkce vrátí `false`.
- Krok A už neplatí (hosté po **checkoutu** dnes **nejsou** v intervalu pobytu, pokud je „dnes“ až den po odjezdu – záleží na tom, jak je v systému nastaven `end_date` oproti „dnu odjezdu“; typicky po odjezdu už **není** obsazeno).
- Pak Krok B selže → Krok C → **`apartments.status.clean`** („Uklizeno“).

**Záměr v kódu (komentář):** *„Ignorujeme úkoly v budoucnu – úklid na příští týden neznamená ‚K úklidu‘ dnes.“*  
To je konzistentní s **uživatelským očekáváním v hlášení bugu** v opačné situaci: po odjezdu hostů je byt **fyzicky neuklizen**, i když je úklid v systému až za několik dní – současná logika to **neumí** vyjádřit a špatně interpretuje „budoucí úklid“ jako „dnes žádný otevřený úklid v horizontu do konce dne = uklizeno“.

**Shrnutí:** Chybí pojem **„čeká na úklid po turnoveru“** (checkout proběhl, dokončený úklid za poslední pobyt ještě ne). Současná logika spojuje „K úklidu“ jen s **úkolem úklidu, který je zároveň „aktuální“ časově do dneška**, ne s **stav pobytu vs. dokončení úklidu vůči rezervaci**.

---

## 4. Doporučená architektura pro spolehlivý stav (datový model)

Cíl: stav odvodit z **konkurenčních faktů**: pobyt vs. úklid vůči **konkrétní rezervaci** / turnoveru, ne jen z „máme dnes nehotový úklid s due dnes“.

**Tabulky / vazby (již typicky v systému):**

| Entita | Význam pro výpočet |
|--------|---------------------|
| **`reservations`** | `apartment_id`, `start_date`, `end_date`, `status` – určit **poslední ukončený pobyt** / **checkout** a zda **dnes** ještě probíhá pobyt. |
| **`tasks`** | `apartment_id`, `task_type` (cleaning), `status`, `scheduled_start`, **`completed_at`**, ideálně **`reservation_id`** – spojit úklid s pobytem. |
| Volitelně **`apartments`** | `standard_cleaning_duration`, ruční stav jen pokud chcete hybrid s dispečinkem. |

**Logická osa opravy (koncept):**

1. **Obsazeno:** beze změny smyslu – dnes je v intervalu pobytu (případně upřesnit hranice dne odjezdu vs. čas checkoutu, pokud má být „obsazeno“ jen do okamžiku odjezdu).
2. **K úklidu:** kromě stávajícího „otevřený úklid s termínem do konce dne“ přidat např.:
   - existuje **rezervace**, která **skončila** (checkout před „teď“ nebo před dneškem podle definice), a **neexistuje** dokončený úklid **navázaný na tuto rezervaci** (nebo po `end_date` není `completed` úklid pro daný byt v daném turnoveru), **nebo**
   - jednodušší heuristika: „poslední `end_date` &lt; dnešek“ a „žádný `cleaning` s `completed_at` po tomto datu“ – podle přesné definice „den odjezdu“ v DB.
3. **Uklizeno:** pobyt neprobíhá a **turnover je uzavřený** dokončeným úklidem, nebo ještě nepřišel host (žádná rezervace, žádný dangling turnover – podle produktu).

**Spolehlivost:** Nejvyšší při **`tasks.reservation_id`** (nebo ekvivalent) – porovnání „úklid po rezervaci X“ vs. „rezervace X skončila“. Bez vazby na rezervaci zůstane heuristika **poslední checkout vs. poslední dokončený úklid** podle času u daného `apartment_id` (náchylnější k okrajovým případům).

---

## 5. Potvrzení předchozích úprav Nástěnky (předchozí úkol)

Následující změny jsou **v kódu přítomny** (ref. `lib/features/admin/admin_dashboard_screen.dart`):

| Požadavek | Stav |
|-----------|------|
| **Legenda donut grafu** – překlady místo surového klíče `admin.dashboard.chart_category_...` | **Opraveno:** funkce **`_taskTypeToCategoryKey`** vrací klíče ve tvaru **`admin.dashboard_chart_category_*`** (jedna úroveň pod `admin` v JSON), konzistentně s `cs.json` / `en.json`. |
| **Karta „Dnešní externí služby“** – vycentrování prázdného stavu (ikona auta) | **Opraveno:** widget **`_ExternalTasksSection`** používá **`LayoutBuilder`** + **`Center`** / **`Expanded`** pro prázdný obsah (u konečné výšky vedle „Rychlé akce“ přes `IntrinsicHeight`). |

---

*Tento dokument je výhradně diagnostický; neobsahuje implementační kód opravy.*
