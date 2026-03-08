# Diagnostická analýza: Nekonečné načítání a převod na Dialog

## 1. ANALÝZA NEKONEČNÉHO NAČÍTÁNÍ

### 1.1 Chování FutureProvider

`billingReportProvider` je `FutureProvider.family<List<BillingGroup>, BillingMonthParam>`. Stav:
- **loading** – dokud Future neskončí (úspěch ani chyba)
- **error** – po `rethrow` v catch bloku
- **data** – po úspěšném return

**Závěr:** Pokud UI zůstává v loading, Future nikdy neskončí. Chyba by se projevila přechodem do stavu `error`, ne věčným loadingem.

---

### 1.2 Potenciální zdroje zablokování (Future nikdy nedokončí)

| # | Místo | Riziko | Popis |
|---|-------|--------|-------|
| 1 | **Supabase dotazy** | Vysoké | Žádný explicitní timeout. Při síťovém problému, pomalém RLS nebo zamrznutí serveru může request viset neurčitě dlouho. |
| 2 | **`fetchByReservationIds`** | Střední | Volá se uvnitř try. Pokud vnitřní Supabase dotaz nikdy nevrátí, celý provider visí. |
| 3 | **Sekvence 5+ Supabase volání** | Střední | tasks → reservation_services → apartment_services → apartment_owners → clients (2×). Stačí jedno zavěšení. |

---

### 1.3 Potenciální zdroje výjimek (Future dokončí s chybou)

| # | Místo | Riziko | Popis |
|---|-------|--------|-------|
| 1 | **`tasksRes as List`** | Střední | Pokud Supabase vrátí jiný typ (např. `null`), cast hodí. Chyba by byla v `error:` větvi. |
| 2 | **`t['metadata']`** | Nízké | Kontrola `if (meta is Map)`. Pro ne-Map (String, List, null) se blok přeskočí, `chargedPrice = 0.0`. Parsování je safe. |
| 3 | **`firstWhere`** (ř. 305) | Střední | `tasksInMonth.firstWhere((x) => ... == item.taskId)`. Pokud `item.taskId` v `tasksInMonth` chybí (konzistence dat), vyhodí `StateError`. Chyba by šla do `error:`. Teoreticky by měla být vždy shoda, protože `items` vznikají z `tasksInMonth`. |
| 4 | **`(aptRes as List)`** atd. | Nízké | Očekává se List; jiný typ způsobí chybu. |

---

### 1.4 Proč UI neukazuje chybu

Možné scénáře:

1. **Future nikdy nedokončí (nejpravděpodobnější)**  
   Jedno z Supabase volání se nikdy nedokončí → Future zůstává v běhu → Riverpod zůstává v loading → UI nikdy nepřejde do `error:`.

2. **Chyba mimo try/catch**  
   Např. v synchronní části před prvním `await` – ale provider začíná `await` až na Supabase dotazu, předtím je jen `tenantId` check. `ref.watch(authNotifierProvider)` může teoreticky triggerovat rebuild a zrušení předchozího provideru, ale to by spíš vedlo k novému loading než k trvalému zaseknutí.

3. **Provider se stále invaliduje**  
   Např. při časté změně `authNotifierProvider`. Při každé invalidaci se spouští nový Future a ten předchozí se zruší. Pokud invalizace běží opakovaně (např. v smyčce), mohlo by to vypadat jako nekonečné načítání.

---

### 1.5 Doporučená diagnostika

1. **Logování:** Přidat `debugPrint` na začátek provideru (po tenantId check) a před/za každý Supabase dotaz. Zjistit, které volání je poslední před zaseknutím.
2. **Timeout:** Obalit hlavní logiku do `Future.timeout(Duration(seconds: 30))` – při překročení se vyhodí `TimeoutException` a UI přejde do error stavu.
3. **Supabase RLS:** Ověřit oprávnění pro `tasks`, `reservation_services`, `apartment_services`, `apartment_owners`, `clients` pro daného tenanta.
4. **`tenantIdForData`:** U Super Admina ověřit, že je `_selectedTenantId` nastaveno před otevřením fakturace (impersonace).

---

## 2. NÁVRH PŘEVODU NA DIALOG

### 2.1 Současný stav

**finance_dashboard_screen.dart (ř. 55–61):**
```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => const FinanceBillingScreen(),
  ),
);
```

Full-screen obrazovka přes `Navigator.push` a `MaterialPageRoute`.

---

### 2.2 Změny pro dialog

#### A) Nový wrapper místo Scaffold

- Převést `FinanceBillingScreen` na widget, který může být uvnitř `Dialog` nebo `AlertDialog`.
- Odstranit `Scaffold` a nahradit ho `Dialog` / `AlertDialog` s omezenou šířkou.
- Pro větší obsah (měsíční přepínač + seznam skupin) je vhodný vzor jako v `owner_reservations_screen.dart`:

```dart
Dialog(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 600, maxHeight: 900),
    child: ...
  ),
)
```

#### B) Změna názvu a struktury

- Možnosti:
  - Přejmenovat na `FinanceBillingDialog` a upravit wrapper.
  - Nebo ponechat `FinanceBillingScreen` a pouze měnit způsob zobrazení (Scaffold vs. Dialog).

#### C) Úprava v finance_dashboard_screen.dart

```dart
// Před:
Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FinanceBillingScreen()));

// Po:
showDialog<void>(
  context: context,
  builder: (ctx) => const FinanceBillingDialog(),
);
```

`FinanceBillingDialog` by obsahoval:
- `Dialog` (nebo `AlertDialog`) jako kořen
- `ConstrainedBox` pro omezení rozměrů (např. maxWidth: 600, maxHeight: 800)
- Uvnitř: přepínač měsíce, `asyncReport.when(...)`, seznam skupin
- Tlačítko zavření (X nebo „Zavřít“) místo `AppBar.leading`

#### D) Scrollovatelnost

- Obsah zabalit do `SingleChildScrollView` nebo podobného scroll widgetu, aby byl použitelný na malých obrazovkách a v omezeném dialogu.

#### E) Kontext pro Riverpod

- `showDialog` vytváří nový overlay, ale `ProviderScope` je nad ním – `ConsumerStatefulWidget` a `ref.watch(billingReportProvider(param))` zůstanou platné.
- Důležité: před volat `formatTaskAmount` a další metody musí být uvnitř dialogu `ConsumerWidget`/`ConsumerStatefulWidget` s přístupem k `ref`.

---

### 2.3 Odhad změn

| Soubor | Změna |
|--------|-------|
| `finance_billing_screen.dart` | Přejmenovat na `FinanceBillingDialog`, vyměnit `Scaffold` za `Dialog` + `ConstrainedBox`, upravit header (zavření dialogu místo back). |
| `finance_dashboard_screen.dart` | Zaměnit `Navigator.push` za `showDialog`. |
| Importy | Aktualizovat cesty v souborech, které `FinanceBillingScreen` importují (pokud se přejmenuje). |

---

### 2.4 Reference v projektu

- `finance_dashboard_screen.dart` – jediné místo volání (ř. 57).
- Router (`app_router.dart`) neobsahuje routu na FinanceBillingScreen.
- Ostatní dialogy v projektu (ClientDetailDialog, ModuleSubscriptionDialog, owner reservations) ukazují vzory pro `Dialog` + `ConstrainedBox` + `SingleChildScrollView`.
