# Architektonická analýza: optimalizace layoutu hlavičky Plánovacího kalendáře

**Soubor:** `lib/features/calendar/screens/planning_calendar_screen.dart`  
**Související:** `lib/widgets/task_legend.dart`  
**Datum analýzy:** 2025-03-01

---

## 1. Lokalizace widgetů hlavičky

### 1.1 Přesné umístění

Hlavička kalendáře se vykresluje v **řádcích 131–235** metody `build` třídy `_PlanningCalendarScreenState`.

Struktura:

| Řádek | Popis | Umístění |
|-------|-------|----------|
| **131–164** | Titulek + vyhledávání | `Padding` → `Row` [Text(title), SizedBox(32), Expanded(TextField)] |
| **166–234** | Navigace data + legenda + dropdown | `Padding` → **Wrap** [Row(date nav + Dnes), Center(TaskLegend), _FilterDropdown] |
| 235 | Oddělovač | `SizedBox(height: 16)` |
| 239–306 | Kalendářová mřížka | `Expanded` → bílý kontejner s `_DayHeaderRow` + `_WeekGridScrollBody` |

### 1.2 Identifikované ovládací prvky

1. **Date switcher / navigace týdne** (ř. 174–215):
   - `IconButton` (chevron_left), `Text` (rozsah týdne), `IconButton` (chevron_right), `OutlinedButton` ("Dnes")
   - Lokální stav: `_weekStart` (setState)

2. **Legenda stavů/typů úkolů** (ř. 216–218):
   - `Center(child: TaskLegend())`
   - Data: `taskCategoriesProvider` (Riverpod)

3. **Dropdown „Všichni“** (ř. 220–231):
   - `_FilterDropdown` uvnitř `dataAsync.when(...)` (planningCalendarDataProvider)
   - Lokální stav: `_selectedFilterId` (setState)

---

## 2. Strom widgetů hlavičky (řádek 2)

```
Padding(padding: 24h)
└── Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: center)
    ├── Row(mainAxisSize: min)                    ← navigace týdne + tlačítko Dnes
    │   ├── IconButton (←)
    │   ├── SizedBox(12)
    │   ├── Text("16.2. – 22.2.")
    │   ├── SizedBox(12)
    │   ├── IconButton (→)
    │   ├── SizedBox(8)
    │   └── OutlinedButton("Dnes")
    │
    ├── Center(child: TaskLegend())               ← legenda
    │   └── [viz TaskLegend strom níže]
    │
    └── dataAsync.when(...) → SizedBox(width: 200, child: _FilterDropdown)
```

### 2.1 TaskLegend – interní strom

Soubor: `lib/widgets/task_legend.dart` (ř. 29–42)

```
Padding(padding: vertical 8)
└── Wrap(alignment: center, spacing: 8, runSpacing: 8)
    ├── _LegendBadge (Nepřiřazeno)
    ├── _LegendBadge (Konflikt)
    ├── _LegendBadge (Úklid)
    ├── _LegendBadge (Příjezd)
    ├── _LegendBadge (Check-in)
    ├── _LegendBadge (... další kategorie z DB)
    └── ...
```

---

## 3. Analýza příčin vertikálního růstu

### 3.1 Wrap v hlavičce (planning_calendar_screen.dart, ř. 168)

- `Wrap` umožňuje zalomení na další řádky při nedostatku místa.
- Tři hlavní děti: `Row` (date nav), `TaskLegend`, `_FilterDropdown`.
- Pokud šířka nestačí, `Wrap` je přeloží pod sebe → 2–3 řádky.
- `runSpacing: 12` přidává svislou mezeru mezi řádky.

### 3.2 Wrap v TaskLegend (task_legend.dart, ř. 31)

- Položky legendy (5–10+ badge) jsou uvnitř `Wrap`.
- Při nedostatku místa se badge přelévají do dalších řádků.
- `runSpacing: 8` přidává svislou mezeru.
- `Padding(vertical: 8)` navyšuje výšku legendy o 16 px.

### 3.3 Center kolem TaskLegend

- `Center` sám o sobě výšku nezvyšuje, ale v kombinaci s `Wrap` uvnitř `TaskLegend` způsobí, že celý obsazený „blok“ legendy zabírá tolik řádků, kolik potřebuje.

### 3.4 Dvojitý efekt

- Hlavičkový `Wrap` může dát 2–3 řádky (date nav | legend | dropdown).
- `TaskLegend` uvnitř může mít další řádky kvůli zalamování badge.
- Celková výška hlavičky může snadno přesáhnout 3 řádky.

---

## 4. Provázání se stavem (Riverpod / setState)

| Prvek | Zdroj dat | Typ | Přesun v rámci build() |
|-------|-----------|-----|-------------------------|
| Date switcher | `_weekStart` | setState | Ano – lze libovolně přesunout |
| Legenda | `taskCategoriesProvider` | Riverpod | Ano – samostatný ConsumerWidget |
| Dropdown | `planningCalendarDataProvider(_weekStart)` | Riverpod | Ano – závisí jen na `_weekStart` |

Všechny prvky jsou nezávislé a stavově oddělené. Vizuální přeskládání v `build` nevyžaduje změny providerů ani stavové logiky.

---

## 5. Návrh redesignu – „zploštění“ hlavičky

### 5.1 Cíl

- Udržet jednu kompaktní řádku (řádek 2).
- Nikdy nezalamovat hlavičku do dalších řádků (pokud možno).
- Zachovat funkčnost: date nav, legenda, dropdown.

### 5.2 Návrh struktury

```
Row(children: [
  // LEVÁ ČÁST: navigace + dropdown na jednom řádku
  Row(mainAxisSize: min, children: [
    IconButton(←),
    Text("16.2. – 22.2."),
    IconButton(→),
    OutlinedButton("Dnes"),
    SizedBox(width: 16),
    SizedBox(width: 200, child: _FilterDropdown),  // nebo užší, např. 160
  ]),
  
  // PRAVÁ ČÁST: horizontálně scrollovatelná legenda
  Expanded(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: min,
        children: [/* _LegendBadge × N */],
      ),
    ),
  ),
])
```

Alternativně – pokud má legenda zůstat vždy viditelná bez scrollu na širokých displejích:

```
Row(children: [
  Row(/* date nav + dropdown */),
  const Spacer(),
  Flexible(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(/* badges */),
    ),
  ),
])
```

### 5.3 Potřebné změny

1. **planning_calendar_screen.dart (ř. 166–234):**
   - Nahradit `Wrap` za jeden `Row`.
   - V levé části sloučit `Row` (date nav + Dnes) a `_FilterDropdown`.
   - V pravé části umístit novou variantu legendy s horizontálním scrollováním.

2. **task_legend.dart:**
   - Přidat parametr, např. `scrollHorizontally: bool` (default `false` pro zpětnou kompatibilitu jinde).
   - Když `scrollHorizontally == true`: místo `Wrap` použít `SingleChildScrollView(horizontal)` + `Row` s badge.
   - Odebrat `runSpacing` – vertikální zalamování zmizí.

3. **Padding:**
   - Snížit `Padding(vertical: 8)` v `TaskLegend`, např. na 4 (nebo 0, pokud hlavička má vlastní vertikální padding).

### 5.4 Zachování responzivity

- Na velmi úzkých displejích lze ponechat jako fallback jednu zalomenou řádku (např. `LayoutBuilder` a při `width < 600` vrátit starý `Wrap`), nebo ponechat horizontální scroll u legendy bez zalomení.
- Date nav + dropdown by měly zůstat na jednom řádku i na telefonech (ikonky jsou malé, dropdown 160–200 px).

---

## 6. Shrnutí – strom před / po

### PŘED (aktuální)

```
Column
├── Padding [titul + search]
├── Padding
│   └── Wrap (spacing 16, runSpacing 12)     ← příčina zalamování
│       ├── Row [date nav + Dnes]
│       ├── Center → TaskLegend
│       │   └── Wrap (runSpacing 8)          ← druhá příčina zalamování
│       │       └── badges...
│       └── _FilterDropdown
├── SizedBox(16)
└── Expanded [kalendář]
```

### PO (navrhovaná struktura)

```
Column
├── Padding [titul + search]
├── Padding
│   └── Row                                  ← jeden řádek
│       ├── Row [date nav + Dnes + _FilterDropdown]
│       └── Expanded(
│             SingleChildScrollView(horizontal)
│             └── Row [badges...]            ← bez zalamování
│           )
├── SizedBox(16)   // případně zmenšit na 8
└── Expanded [kalendář]
```

---

## 7. Rizika a omezení

- **TaskLegend** se používá i jinde (např. admin_tasks_screen) – změna layoutu jen pro plánovací kalendář vyžaduje parametr nebo wrapper.
- Horizontální scroll legendy může být na mobilu méně zjevný – zvážit jemné vizuální odlišení okrajů (např. gradient nebo stín).
- Dropdown šířky 200 px může na úzkých displejích „krást“ místo – lze zúžit na 160 px a zkrátit hint „Všichni“.
