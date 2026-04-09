# Admin Theming Refactor - Manualni QA Template

## Test Metadata

- **Datum testu:**  
- **Tester:**  
- **Branch/commit:**  
- **Platforma:** Web / Android / iOS  
- **Rezim:** Light / Dark  

---

## Vyhodnoceni

- **Light mode:** Pass / Fail
- **Dark mode:** Pass / Fail
- **Regrese nalezeny:** Ano / Ne
- **Poznamky:**  

---

## Checklist - Light Mode

- [ ] Spustit aplikaci (`flutter run`)
- [ ] Otevrit Admin Dashboard
- [ ] KPI karty: konzistentni barvy
- [ ] Komunikace & Automatizace: citelne barvy
- [ ] Health-check: warning/error barvy viditelne

### Admin Apartments
- [ ] `_ApartmentCard`: border + background
- [ ] Filter banner: dostatecny kontrast

### Admin Tasks
- [ ] `_TaskCard`: metadata warning accent
- [ ] `task_metadata_section`: panel background

### Finance Dashboard
- [ ] `wallet_detail_modal`: modal barrier (tmavy overlay)
- [ ] Transaction tiles: info/error barvy
- [ ] `payout_history_content`: group type barvy (blue/purple)

### Admin Automations
- [ ] `settlement_split_dialog`: success/error snackbary
- [ ] `client_form_dialog`: validacni chyby

---

## Checklist - Dark Mode

- [ ] Prepnout `Settings > Theme > Dark`
- [ ] Opakovat vsechny kontroly z Light mode
- [ ] Text je citelny na vsech pozadich
- [ ] Barvy maji dostatecny kontrast
- [ ] Modal barrier je viditelny (neni prilis tmavy)

---

## Defect Log (auditovatelne)

| ID | Soubor/Widget | Rezim | Ocekavani | Realita | Severity | Screenshot | Stav |
|----|---------------|-------|-----------|---------|----------|------------|------|
| 1  |               |       |           |         |          |            | Open/Closed |

---

## Finalni potvrzeni

- [ ] Vsechny widgety vypadaji stejne jako predtim (jen barvy z theme)
- [ ] Light mode je citelny
- [ ] Dark mode je citelny
- [ ] V kodu nejsou viditelne hardcoded barvy v refaktorovanem scope

