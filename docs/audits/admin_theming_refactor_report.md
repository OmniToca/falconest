# Admin Theming Refactor - Produkcni Report

**Datum:** 2026-04-02  
**Status:** ✅ Hotovo  
**Scope:** Centralizace hardcoded barev v admin widgetech

---

## 1. Cíl

Nahradit vsechny hardcoded barvy v admin widgetech za centralizovane theme tokeny z `lib/core/theme/`.

**Problem:** Nastenka (dashboard) vypadala nejednotne, barvy nebyly spravovatelne z jednoho mista.  
**Reseni:** Centralizace barev pres `context.colors` a `context.customColors`.

---

## 2. Scope (co bylo zmeneno)

### FAZE 1: Audit
- Identifikovany hardcoded barvy v 7 admin widgetech
- Hlavni zdroj problemu: `lib/features/admin/widgets/`
- Hlavni screeny (dashboard, apartments, automations) byly uz prevazne theme-driven

### FAZE 2: Rozsireni custom_colors.dart
Pridany nove semanticke barvy:
- `success`, `successSubtle`
- `warning`, `warningSubtle`
- `info`, `infoSubtle`
- `groupTypeBlue`, `groupTypePurple`
- `modalBarrier`

### FAZE 3: Refactor widgetu
Refaktorovany tyto soubory:
1. `lib/features/admin/widgets/wallet_detail_modal.dart`
2. `lib/features/admin/widgets/payout_history_content.dart`
3. `lib/features/admin/widgets/settlement_split_dialog.dart`
4. `lib/features/admin/widgets/client_form_dialog.dart`
5. `lib/features/admin/widgets/ad_hoc_message_dialog.dart`
6. `lib/features/admin/widgets/reservation_service_row_widget.dart`
7. `lib/features/admin/widgets/task_metadata_section.dart`

### FAZE 4: Validace
- `flutter analyze lib` ✅ bez chyb
- Smoke test ✅ 4/4 testy prosly
- Manualni vizualni kontrola (light/dark mode)

---

## 3. Mapovani barev (transformace)

| Stara barva | Nova barva | Ucel |
|-------------|-----------|------|
| `Colors.black54` | `context.customColors.modalBarrier` | Modal overlay |
| `Colors.white` | `context.colors.surface` | Panel background |
| `Colors.red.shade700` | `context.colors.error` | Error state |
| `Colors.green.shade700` | `context.customColors.success` | Success state |
| `Colors.orange.shade700` | `context.customColors.warning` | Warning state |
| `Colors.blue.shade700` | `context.customColors.groupTypeBlue` | Category type |
| `Colors.purple.shade700` | `context.customColors.groupTypePurple` | Category type |
| `Colors.grey.shade*` | `context.colors.onSurface*` | Text/border |

---

## 4. Vyhody

✅ **Jednotna nastenka** - vsechny widgety pouzivaji stejny theme system  
✅ **Centralizovane barvy** - zmena v jednom miste (`custom_colors.dart`)  
✅ **Automaticka podpora light/dark mode** - barvy reaguji na prepnuti rezimu  
✅ **Semanticke barvy** - citelny a udrzovatelny kod  
✅ **Aditivni vyvoj** - bez destruktivniho mazani funkcniho kodu  
✅ **Bez regresi** - smoke test + manualni QA potvrzuji funkcnost  

---

## 5. Technicke detaily

### Centralni zdroj barev
- `lib/core/theme/custom_colors.dart` - semanticke custom barvy
- `lib/core/theme/theme_ext.dart` - extensions na BuildContext
- `lib/core/theme/app_theme.dart` - registrace ThemeData

### Pristup v kodu
```dart
// Stare (hardcoded)
Container(color: Colors.red.shade700)

// Nove (theme-driven)
Container(color: context.colors.error)
Container(color: context.customColors.success)
```

---

## 6. Omezeni smoke testu

- Smoke test overuje stabilitu renderu na urovni Material shellu a regresni pady po refactoru.
- Nejde o plny integracni test vsech admin provideru (Supabase/Firebase init flow zustava mimo tento test scope).

