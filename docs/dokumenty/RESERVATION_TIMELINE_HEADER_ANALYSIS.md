# Architektonická analýza: optimalizace layoutu hlavičky Rezervační Plachty

**Soubor:** `lib/features/admin/admin_reservations_screen.dart`  
**Datum analýzy:** 2025-03-01

---

## 1. Lokalizace widgetů hlavičky Plachty

### 1.1 Přesné umístění

Hlavička Plachty se skládá ze dvou částí na dvou různých úrovních:

| Umístění | Řádky | Popis |
|----------|-------|-------|
| **Nad ReservationTimeline** | 177–185 | Statický nadpis „Vizuální přehled (Plachta)“ a mezera pod ním |
| **Uvnitř ReservationTimeline** | 692–741 | Horní ovládací lišta – date switcher, tlačítko Dnes, legenda stavů |

**Struktura záložky Plachta (Tab 0):**

```
SingleChildScrollView(padding: 24,16,24,24)
└── Column
    ├── Text('admin.reservations_timeline_title'.tr())   ← nadpis (ř. 177)
    ├── SizedBox(height: 12)                               ← mezera
    └── ReservationTimeline(...)
```

**Struktura hlavičky uvnitř ReservationTimeline:**

```
SizedBox(height: 480)
└── Column
    ├── Padding(16,8,16,16)
    │   └── Row
    │       ├── IconButton (←)
    │       ├── SizedBox(8)
    │       ├── Text("22.2. – 31.3.")
    │       ├── SizedBox(8)
    │       ├── IconButton (→)
    │       ├── SizedBox(24)
    │       ├── OutlinedButton("Dnes")
    │       ├── SizedBox(24)
    │       └── Expanded(
    │             child: Wrap(...)                         ← legenda – ZDE je problém
    │           )
    └── Expanded(child: bílý kontejner s mřížkou)
```

### 1.2 Identifikované ovládací prvky

1. **Date switcher / navigace období** (ř. 697–724):
   - `IconButton` (←), `Text` (rozsah období), `IconButton` (→), `OutlinedButton` ("Dnes")
   - Stav: `visibleStartDate` předaný do widgetu, callbacks `onPrevious`, `onNext`, `onToday`

2. **Legenda stavů rezervací** (ř. 725–738):
   - Pět `_ReservationLegendPill`: `new`, `confirmed`, `checked_in`, `checked_out`, `cancelled`
   - Použité klíče: `admin.reservation_status_new`, `admin.reservation_status_confirmed` apod.
   - **Není** samostatný widget typu `ReservationLegend` – legenda je přímo v kódu.

3. **Nadpis nad Plachtou** (ř. 177–183):
   - Statický text „Vizuální přehled (Plachta)“ / „Visual overview (Timeline)“
   - Zabírá řádek + `SizedBox(height: 12)` pod ním.

---

## 2. Strom widgetů hlavičky

### 2.1 Celkový strom (od záložky Plachta)

```
SingleChildScrollView
└── Column(crossAxisAlignment: stretch)
    ├── Text(                                 ← NADBYTEČNÝ nadpis
    │     'admin.reservations_timeline_title'.tr(),
    │     style: titleMedium, fontWeight: w600
    │   )
    ├── SizedBox(height: 12)                  ← ~12px vertikálně
    └── ReservationTimeline(height: 480)
        └── Column
            ├── Padding(16, 8, 16, 16)
            │   └── Row(crossAxisAlignment: center)
            │       ├── [Date switcher – řádek 1 viz níže]
            │       └── Expanded(
            │             child: Wrap(        ← PŘÍČINA vertikálního růstu
            │               spacing: 8,
            │               runSpacing: 8,
            │               children: [
            │                 _ReservationLegendPill × 5
            │               ],
            │             ),
            │           )
            └── Expanded(child: bílý box s mřížkou)
```

### 2.2 Detail hlavičky (řádky 692–741)

```
Padding(fromLTRB: 16, 8, 16, 16)
└── Row(children: [
      IconButton(chevron_left),
      SizedBox(8),
      Text("22.2. – 31.3."),
      SizedBox(8),
      IconButton(chevron_right),
      SizedBox(24),
      OutlinedButton("Dnes"),
      SizedBox(24),
      Expanded(
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          _ReservationLegendPill(new),
          _ReservationLegendPill(confirmed),
          _ReservationLegendPill(checked_in),
          _ReservationLegendPill(checked_out),
          _ReservationLegendPill(cancelled),
        ]),
      ),
    ])
```

### 2.3 _ReservationLegendPill (ř. 786–815)

Samostatná pilulka – `Container` s paddingem, pastelovým pozadím a `Text` s `reservationStatusLabelKey(status).tr()`.

---

## 3. Analýza příčin vertikálního růstu

### 3.1 Wrap v hlavičce ReservationTimeline (ř. 726–738)

- `Wrap` uvnitř `Expanded` způsobuje **zalamování** položek legendy na další řádky při nedostatku místa.
- `runSpacing: 8` přidává svislou mezeru mezi řádky.
- Pět pilulek (Nová, Potvrzená, Ubytováno, Odhlášeno, Zrušeno) se snadno zalomí na 2 řádky na středně úzkých displejích.

### 3.2 Nadbytečný nadpis (ř. 177–185)

- Text „Vizuální přehled (Plachta)“ je redundantní – záložka TabBaru už zobrazuje „Plachta“.
- Spolu s `SizedBox(height: 12)` zabírá cca **28–40 px** vertikálně.

### 3.3 Padding

- `Padding(16, 8, 16, 16)` přidává 8 px nahoře a 16 px dole pod hlavičkou.

---

## 4. Provázání se stavem

| Prvek | Zdroj | Typ | Přesun v build() |
|-------|-------|-----|------------------|
| Date switcher | `visibleStartDate`, `onPrevious/Next/Today` | props, callbacks | Ano – lze přesouvat |
| Legenda | Statická (5 fixních stavů) | konstanta | Ano – není žádný provider |
| Nadpis | i18n klíč | statický text | Lze odstranit nebo přesunout |

Žádné Riverpod providery v hlavičce – vše je řízeno props a callbacks. Redesign layoutu je plně v rukou widgetu `ReservationTimeline` a nadřazeného `Column`u.

---

## 5. Návrh redesignu – „zploštění“ hlavičky

### 5.1 Cíl

- Jeden kompaktní řádek: date switcher vlevo + legenda vpravo (horizontální scroll).
- Žádné zalamování legendy do dalších řádků.
- Snížení nadbytečného vertikálního prostoru (nadpis, mezery).

### 5.2 Návrh struktury hlavičky uvnitř ReservationTimeline

**Nahradit `Expanded(child: Wrap(...))` za horizontálně scrollovatelný blok:**

```
Row(children: [
  // Levé křídlo: navigace data (bez změny)
  Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(←),
    Text("22.2. – 31.3."),
    IconButton(→),
    SizedBox(24),
    OutlinedButton("Dnes"),
  ]),
  SizedBox(width: 24),
  // Pravé křídlo: legenda scrolluje horizontálně
  Expanded(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReservationLegendPill(...),
          SizedBox(width: 8),
          _ReservationLegendPill(...),
          ... (všech 5 pilulek),
        ],
      ),
    ),
  ),
])
```

**Změna:** `Wrap` → `SingleChildScrollView(scrollDirection: Axis.horizontal)` + `Row(mainAxisSize: MainAxisSize.min)` s pilulkami oddělenými `SizedBox(width: 8)`.

### 5.3 Návrh pro nadpis „Vizuální přehled (Plachta)“

**Možnost A – odstranit:**
- Záložka TabBaru už říká „Plachta“, nadpis je nadbytečný.
- Odstranit `Text` i `SizedBox(height: 12)` → úspora ~28–40 px.

**Možnost B – přesunout do hlavičky:**
- Pokud má nadpis zůstat (např. kvůli konzistenci s jinými záložkami), přesunout ho do jedné řádky s date switcherem, například:
  - Vlevo: nadpis jako menší text, pak date switcher.
  - Nebo zcela vypustit.

**Doporučení:** Možnost A – odstranit nadpis a `SizedBox(height: 12)`, aby Plachta byla co nejkompaktnější.

### 5.4 Zmenšení mezer

- `Padding(16, 8, 16, 16)` → možné snížit na např. `Padding(16, 4, 16, 8)`.
- `SizedBox(width: 24)` mezi date switcherem a legendou – ponechat pro přehlednost.

---

## 6. Shrnutí – strom před / po

### PŘED (aktuální)

```
Column [záložka Plachta]
├── Text("Vizuální přehled (Plachta)")        ← nadbytečný
├── SizedBox(12)
└── ReservationTimeline
    └── Column
        ├── Padding(16,8,16,16)
        │   └── Row
        │       ├── [date nav + Dnes]
        │       └── Expanded(
        │             Wrap(runSpacing: 8)     ← zalamování
        │             └── 5× _ReservationLegendPill
        │           )
        └── Expanded(mřížka)
```

### PO (navrhovaná struktura)

```
Column [záložka Plachta]
└── ReservationTimeline                       ← bez nadpisu a SizedBox
    └── Column
        ├── Padding(16, 4, 16, 8)             ← zmenšený padding
        │   └── Row
        │       ├── Row [date nav + Dnes]
        │       ├── SizedBox(24)
        │       └── Expanded(
        │             SingleChildScrollView(horizontal)
        │             └── Row [5× pill + SizedBox(8)]
        └── Expanded(mřížka)
```

---

## 7. Rizika a omezení

- **Odstranění nadpisu** může ovlivnit UX – záložka „Plachta“ by měla být dostatečně zřetelná.
- `ReservationTimeline` má pevnou výšku `_timelineHeight = 480` – zmenšení hlavičky uvolní více místa pro mřížku pouze při zachování stávající výšky; pokud je Plachta v `SingleChildScrollView` uvnitř `TabBarView`, uvolněný prostor půjde do scrollu nebo do mřížky.
- Legenda rezervací je specifická pro Plachtu – není sdílený widget jako `TaskLegend`. Refaktor na `ReservationLegend(scrollHorizontally: true)` by byl konzistentní s Plánovacím kalendářem, ale není nutný pro samotný redesign.
