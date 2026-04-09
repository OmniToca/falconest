# Architektonická analýza: logika vykreslování bloků rezervací v Plachtě (same-day turnover)

**Soubor:** `lib/features/admin/admin_reservations_screen.dart`  
**Související:** `lib/features/admin/admin_reservation_utils.dart`  
**Datum analýzy:** 2025-03-01

---

## 1. Lokalizace vykreslování bloků

### 1.1 Hlavní soubory a místa

| Umístění | Řádky | Popis |
|----------|-------|-------|
| `_ReservationTimelineBlock.build()` | 1103–1127 | Výpočet `left`, `top`, `width` a vykreslení `Positioned` |
| `_ReservationTimelineGrid` | 893–931 | Stack s pozadím, buňkami pro tap a mapou `reservations.map(_ReservationTimelineBlock)` |
| `isCellEmpty()` | 652–666 | Logika „obsazené buňky“ pro skrytí tap overlay – používá **inklusivní** rozsah dat |

### 1.2 Strom vykreslování

```
ReservationTimeline
└── _ReservationTimelineGrid
    └── Stack(clipBehavior: Clip.none)
        ├── _ReservationTimelineGridBackground
        ├── ...[InkWell buňky pro prázdné buňky]   ← pouze kde isCellEmpty == true
        └── ...reservations.map((r) => _ReservationTimelineBlock(...))
```

Každý blok je `Positioned(left: left+3, top: top+3)` s `SizedBox(width: width-6, height: rowHeight-6)`.

---

## 2. Aktuální výpočet pozice a šířky bloku

### 2.1 Zdrojový kód (`_ReservationTimelineBlock`, ř. 1104–1126)

```dart
final checkInDt = parseReservationCheckIn(reservation.checkIn);
final checkOutDt = parseReservationCheckOut(reservation.checkOut);
if (checkInDt == null || checkOutDt == null) return const SizedBox.shrink();
final checkInDate = DateTime(checkInDt.year, checkInDt.month, checkInDt.day);   // pouze datum
final checkOutDate = DateTime(checkOutDt.year, checkOutDt.month, checkOutDt.day); // pouze datum
final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
final daysFromStart = checkInDate.difference(startDateOnly).inDays;
final left = daysFromStart < 0 ? 0.0 : daysFromStart * dayWidth;
final nights = checkOutDate.difference(checkInDate).inDays;  // ← KLÍČOVÝ VZOREC
final width = nights * dayWidth;
// ...
final top = aptIndex * rowHeight;
```

### 2.2 Parsing času (admin_reservation_utils.dart)

- **check-in** bez času → 15:00 (standardní příjezd)
- **check-out** bez času → 10:00 (standardní odjezd)
- `parseReservationCheckOut`: pokud je jen datum (bez času), vrací `DateTime(..., 10, 0)`

### 2.3 Problém: použití pouze kalendářního data

Současný výpočet:

1. Vynechává **čas** (hodinu) – používá jen `checkInDate` a `checkOutDate`.
2. **`nights`** = `checkOutDate.difference(checkInDate).inDays` – počet celých dní mezi daty.
3. **Šířka** = `nights * dayWidth` – celé sloupce dnů.
4. **Začátek** = `daysFromStart * dayWidth` – začátek sloupce check-in dne.

Důsledky:

- Blok rezervace vždy zabírá **celé sloupce** dnů.
- Žádné dělení dne (dopoledne / odpoledne).
- Pokud se konvence dat liší (např. check-out = den po poslední noci), může dojít k **matematickému překryvu**.

---

## 3. Analýza kolizí a same-day turnover

### 3.1 Same-day turnover

- Rez A: check-out 23.2. 10:00  
- Rez B: check-in 23.2. 14:00 (nebo 15:00)

Reálně se nepřekrývají.

### 3.2 Aktuální chování při datových konvencích

**Scénář A – check-out = datum odjezdu (23.2.)**

- Rez A: checkIn 20.2, checkOut 23.2 → `nights = 3`, šířka 3 sloupce (20, 21, 22).
- Rez B: checkIn 23.2, checkOut 26.2 → `nights = 3`, začátek na 23.2.
- Výsledek: bloky vedle sebe, bez překryvu.

**Scénář B – check-out = den po poslední noci (24.2.)**

- Rez A: checkIn 20.2, checkOut 24.2 („odjezd 24.2.“) → `nights = 4`, šířka 4 sloupce (20–23).
- Rez B: checkIn 23.2, checkOut 27.2 → začátek 23.2, šířka 4 sloupce.
- Výsledek: překryv na sloupci 23.2.

**Scénář C – inkluzivní check-out den**

- Rez A: blok má zahrnovat i dopoledne 23.2. → šířka 4 sloupce (20–23).
- Rez B: začíná 23.2. → začátek na 23.2.
- Výsledek: překryv na 23.2.

### 3.3 Funkce `isCellEmpty` (ř. 652–666)

```dart
if (!cellDate.isBefore(checkInDate) && !cellDate.isAfter(checkOutDate)) return false;
```

Buňka je prázdná jen tehdy, když `cellDate` je **před** check-in **nebo** **po** check-out.

Pro check-in 20.2 a check-out 23.2 je 23.2 považován za **obsazený** (inclusive). To ovlivňuje jen zobrazení prázdných buněk pro tap, ne pozici bloků.

### 3.4 Neexistence logiky pro „vertikální stacking“

V kódu není:

- žádné „lane“ / sub-row,
- žádná detekce překryvů,
- žádná úprava `top` při kolizi.

Bloky mají `top = aptIndex * rowHeight`. Při překryvu v `left`/`width` se tedy **vrství přes sebe** (z-order), ne řadí pod sebe.

„Zalamování pod sebe“ může znamenat:

1. Vizuální překryv (jeden blok zakrývá druhý) – odpovídá horizontální kolizi.
2. Nebo záměnu s jiným view (např. Kanban).
3. Nebo layout jiného widgetu (např. ListView místo Stack).

Pro Plachtu je relevantní scénář 1: horizontální překryv kvůli konvencím dat nebo šířce bloku.

---

## 4. Příčina chyby – shrnutí

1. **Bez použití času** se bloky počítají jen po celých dnech.
2. **Různé konvence** (check-out = den odjezdu vs. den po poslední noci) vedou k různému `nights` a šířce.
3. Při inkluzivním chápání check-out dne nebo „check-out = den po“ vzniká **matematická kolize** – oba bloky zaberou sloupec 23.2.
4. Výsledek: překryv bloků nebo pocit „zalamování“.

---

## 5. Návrh opravy – matematika s časem

### 5.1 Cíl

- Bloky se nikdy nepřekrývají.
- Same-day turnover (check-out 10:00, check-in 14:00) se zobrazí vedle sebe v jednom sloupci dne.
- Jeden den (`dayWidth`) odpovídá 24 hodinám; pozice v rámci dne závisí na času.

### 5.2 Fixní časy (fallback při absenci času)

- **check-out:** 10:00  
- **check-in:** 14:00 (nebo 15:00 dle nastavení tenantu)

### 5.3 Nový výpočet `left` a `width`

Místo práce s celými dny použít **zlomky dne** podle času:

```
// Pomocné veličiny (v hodinách od půlnoci)
checkInHour = checkInDt.hour + checkInDt.minute/60
checkOutHour = checkOutDt.hour + checkOutDt.minute/60

// Zlomek dne (0..1) pro začátek a konec bloku v rámci daného dne
fractionOfDayStart = checkInHour / 24
fractionOfDayEnd   = checkOutHour / 24
```

**`left`:**

```
daysFromStart = checkInDate.difference(startDateOnly).inDays
left = daysFromStart * dayWidth + fractionOfDayStart * dayWidth
```

Blok začíná uvnitř sloupce check-in dne podle času příjezdu.

**`width`:**

```
// Celková délka pobytu v „zlomcích dne“
totalStart = daysFromStart + fractionOfDayStart
totalEnd   = (checkOutDate.difference(startDateOnly).inDays) + fractionOfDayEnd
width      = (totalEnd - totalStart) * dayWidth
```

Tedy šířka = rozdíl mezi koncem a začátkem (v jednotkách dne) × `dayWidth`.

### 5.4 Same-day turnover – příklad

- Rez A: check-out 23.2. 10:00  
  - `totalEnd = (index dne 23.2) + 10/24`
- Rez B: check-in 23.2. 14:00  
  - `totalStart = (index dne 23.2) + 14/24`

Rez B začíná přesně tam, kde končí Rez A; bloky jsou vedle sebe bez překryvu.

### 5.5 Implementační poznámky

1. Pokud `checkIn`/`checkOut` nemají čas, použít fixní časy (14:00 / 10:00).
2. Ošetřit `width <= 0` (např. špatná data).
3. Zachovat stávající vizuální úpravy (`+3`, `-6`) pro mezery mezi bloky.
4. Možné rozšíření: brát `check_in_time` a `check_out_time` z `apartments` pro tenant-specific časy.

---

## 6. Alternativa – zjednodušený fix bez zlomků dne

Pokud nechceme hned zavádět zlomky dne, lze:

- **Šířku** spočítat tak, aby blok končil **před** koncem check-out dne:
  - `width = (nights - 1) * dayWidth + fractionCheckOut * dayWidth`
  - např. `fractionCheckOut = 10/24`.
- **Začátek** Rez B posunout na `fractionCheckIn * dayWidth` v rámci check-in dne:
  - např. `fractionCheckIn = 14/24`.

Pro full same-day turnover je ale konzistentnější vzorec z bodu 5.3.

---

## 7. Kontrolní seznam před implementací

- [ ] Přepnout výpočet na `checkInDt`/`checkOutDt` včetně času.
- [ ] Použít fallback 14:00 / 10:00, když čas chybí.
- [ ] Otestovat same-day turnover (check-out 10:00, check-in 14:00).
- [ ] Otestovat multi-day rezervace.
- [ ] Zvážit úpravu `isCellEmpty`, aby odpovídala nové logice (volitelné).
- [ ] Zachovat zpětnou kompatibilitu pro data bez času.
