# READ-ONLY AUDIT: Sjednocení designu _ApartmentCard podle _MemberCard

## Shrnutí rozdílů

| Aspekt | _MemberCard | _ApartmentCard (aktuální) |
|--------|-------------|---------------------------|
| **Root layout** | `Row` (avatar \| obsah \| status+tlačítka) | `Column` (Row + progress bar + owner notes) |
| **Avatar/ikona** | `CircleAvatar` radius 28, fialové pozadí | `Container` 56×56 čtverec, zaoblení 12 |
| **Hlavička** | Jméno + inline badge "Admin" | Jen název bytu |
| **Status** | Pilulka vpravo (orange/green.shade100) | Pilulka vpravo (různé barvy dle stavu) |
| **Metadata** | `_TeamDetailRow` (ikona 16 + text 13) | `_InfoRow` (téměř shodné) |
| **Progress bar** | Uvnitř levého sloupce, 6px, jemné barvy | Pod kartou, 6px, výrazné barvy (červená/oranžová/zelená) |
| **Tlačítka** | `IconButton` s `backgroundColor: shade50` v pravém sloupci | Jediné velké červené `IconButton` vedle statusu |

---

## 1. AVATAR / IKONA

### Jak to dělá _MemberCard
- **Widget:** `CircleAvatar`
- **Parametry:** `radius: 28`, `backgroundColor: Colors.purple.shade100`
- **Obsah:** `Text(_initialsFromName(member.name))` – iniciály, `fontSize: 18`, `fontWeight: w600`, `color: Colors.purple.shade800`

### Jak napasovat ikonu apartmánu
- **Řešení:** `CircleAvatar` se stejným rozměrem a barvou, uvnitř `Icon` místo `Text`
- **Parametry:** `radius: 28`, `backgroundColor: Colors.purple.shade100`
- **Obsah:** `Icon(Icons.apartment, size: 28, color: Colors.purple.shade800)` (alternativně `Icons.domain`)
- Čtvercový `Container` 56×56 s `borderRadius: 12` se zruší – bude jednotný kruhový avatar jako u Personálu.

---

## 2. HLAVIČKA A STATUS

### Jak to dělá _MemberCard
- **Levá část (Expanded):** `Row` s `Text(member.name)` – tučně, 18px
  - Pokud `member.role == 'admin'`: `SizedBox(8)` + malý `Container` (badge „Admin“) s `padding: 6,2`, `borderRadius: 6`, `Colors.blue.shade100/800`
- Pod ním: `SizedBox(height: 4)` + `Text(_roleSubtitle)` – šedý, 14px

- **Pravá část:** `Column(crossAxisAlignment: end)` s:
  1. Status pilulka: `Container` s `padding: 12,6`, `borderRadius: 12`, `color: orange/green.shade100`, text `fontSize: 12`, `fontWeight: w600`
  2. `SizedBox(height: 8)`
  3. `IconButton`(y)

### Aplikace na _ApartmentCard
- **Levá část:** `Row` s `Text(apartment.name)` – tučně, 18px
  - Volitelně: pokud má byt výjimku v časech (check-in/out ≠ 15:00/10:00), malý badge (např. `Colors.orange.shade100`) podobně jako „Admin“
- Pod ním: `SizedBox(height: 4)` + nic (u bytu není role)

- **Pravá část:** Zachovat `_buildStatusBadge(status)`, ale doladit parametry:
  - `padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)` (jako u Member)
  - `borderRadius: 12`
  - Barvy dál z `_statusChipColors` (green/red/blue/orange/grey.shade100)
  - Pod statusem `SizedBox(height: 8)` a pak `IconButton` smazání

---

## 3. TĚLO A METADATA

### Jak to dělá _MemberCard
- `_TeamDetailRow`: `Row(mainAxisSize: min)` → `Icon(16, grey.shade600)` + `SizedBox(6)` + `Flexible(Text(13, grey.shade700))`
- **Mezery:** `SizedBox(6)` před e-mailem, `SizedBox(10)` před blokem smlouvy, `Padding(bottom: 4)` u smlouvy, `SizedBox(4)` před `_MemberCardExtra`

### Plán pro _ApartmentCard
- **Komponenta:** `_InfoRow` v Apartments je funkčně stejná jako `_TeamDetailRow` – lze sloučit nebo jen sjednotit styl (ikona 16, `SizedBox(6)`, `Flexible` text 13).
- **Pořadí řádků:**
  1. `_InfoRow(Icons.location_on_outlined, adresa)`
  2. `_InfoRow(Icons.vpn_key_outlined, keyboxLabel)`
  3. `_InfoRow(Icons.timer_outlined, cleaningLabel)`
  4. Pokud výjimka v časech: `Padding(bottom: 4)` + `Row` s ikonou `Icons.access_time_filled` a textem (jako u Member absence blok) – použít šedý/oranžový styl

- **Mezery:** `SizedBox(4)` po názvu, `SizedBox(6)` mezi bloky (volitelně), `SizedBox(10)` před progress barem, `SizedBox(4)` před progress barem – srovnat s Member pro konzistenci.

---

## 4. PROGRESS BAR A TLAČÍTKA

### Jak to dělá _MemberCard (_buildWorkloadIndicator)
- **Struktura:** `Column` s nadpisem (`Row` s `spaceBetween`), `SizedBox(4)`, pak progress bar
- **Progress bar:** `Container(height: 6)`, `decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: 4)`
- **Vyplň:** `ClipRRect` + `LayoutBuilder` + `Stack` s `Container(width: w)` – barva dle poměru:
  - `< 0.7` → `Colors.green.shade400`
  - `< 0.9` → `Colors.orange.shade400`
  - `≥ 0.9` → `Colors.red.shade500`

### Problém v _ApartmentCard
- Barvy jsou obrácené (nízká obsazenost = červená, vysoká = zelená) – to je správná sémantika pro byznys.
- „Hrubá červená čára“ – pravděpodobně kvůli `Colors.red.shade400` při nízkém poměru.

### Navrhovaná úprava progress baru v Apartments
- **Zachovat:** výšku 6px, šedé pozadí `Colors.grey.shade200`, `borderRadius: 4`
- **Změnit barvy** pro jemnější dojem:
  - `ratio < 0.3` → `Colors.red.shade300` (místo shade400)
  - `ratio < 0.7` → `Colors.orange.shade300`
  - `ratio >= 0.7` → `Colors.green.shade400`
- **Umístění:** Přesunout progress bar do levého sloupce (uvnitř `Expanded`), jako `_MemberCardExtra` – tedy pod metadata, ne jako samostatná spodní sekce karty.

### Tlačítka v _MemberCard
- `IconButton` s `style: IconButton.styleFrom(backgroundColor: Colors.red.shade50)`, ikona `Icons.delete_outline, color: Colors.red.shade700`
- Umístěno v pravém sloupci pod status pilulkou, vedle dalších akcí (link, absence).

### Pro _ApartmentCard
- Zachovat stejný styl: `IconButton.styleFrom(backgroundColor: Colors.red.shade50)`, `Icons.delete_outline, color: Colors.red.shade700`
- Poloha: v pravém sloupci pod statusem – už je tam, ale v novém layoutu bude vizuálně vyváženější, protože vpravo bude jen status + jedno tlačítko, podobně jako u Member s jedinou akcí (absence).

---

## 5. Návrh finální struktury _ApartmentCard

```
AppCard(
  onTap: onEdit,
  padding: 16,
  child: Row(                          // ← ROOT = Row (ne Column)
    crossAxisAlignment: start,
    children: [
      // 1. AVATAR
      CircleAvatar(
        radius: 28,
        backgroundColor: Colors.purple.shade100,
        child: Icon(Icons.apartment, size: 28, color: Colors.purple.shade800),
      ),
      SizedBox(width: 16),

      // 2. STŘEDNÍ OBSAH
      Expanded(
        child: Column(
          crossAxisAlignment: start,
          children: [
            // Hlavička: název + volitelný badge
            Row(children: [Text(name), if (timeException) badge]),
            SizedBox(height: 4),

            // Metadata (_InfoRow / _TeamDetailRow)
            _InfoRow(icon: location, text: adresa),
            _InfoRow(icon: vpn_key, text: keybox),
            _InfoRow(icon: timer, text: cleaning),
            if (timeException) Padding + Row s časem,
            SizedBox(height: 10),

            // Progress bar (jako _MemberCardExtra)
            Row(label + hodnoty),
            SizedBox(height: 4),
            Container(height: 6, progress bar s jemnějšími barvami),
            SizedBox(height: 4),

            // Owner notes (zachovat, styl jako absence blok v Member)
            if (ownerNotes) Padding + Row s warning icon,
          ],
        ),
      ),

      // 3. PRAVÝ SLOUPEC
      Column(
        crossAxisAlignment: end,
        children: [
          _buildStatusBadge(status),   // padding 12,6, borderRadius 12
          SizedBox(height: 8),
          IconButton(delete, styleFrom backgroundColor red.shade50),
        ],
      ),
    ],
  ),
)
```

---

## 6. Checklist implementace

| Krok | Akce |
|------|------|
| 1 | Nahradit `Container` 56×56 za `CircleAvatar` (radius 28) s `Icon(Icons.apartment)` |
| 2 | Změnit root z `Column` na `Row` |
| 3 | Sjednotit hlavičku: název v `Row`, volitelný badge pro výjimku časů |
| 4 | Zkontrolovat, že `_InfoRow` odpovídá `_TeamDetailRow` (ikona 16, mezera 6, text 13) |
| 5 | Přesunout progress bar do levého sloupce (pod metadata) |
| 6 | Zmírnit barvy progress baru (shade300 místo shade400 pro červenou/oranžovou) |
| 7 | Sjednotit `_buildStatusBadge` padding na 12,6 a borderRadius 12 |
| 8 | IconButton smazání ponechat v pravém sloupci se `styleFrom(backgroundColor: red.shade50)` |
| 9 | Owner notes stylovat jako absence blok (Padding, Row, ikona, Flexible text) |
