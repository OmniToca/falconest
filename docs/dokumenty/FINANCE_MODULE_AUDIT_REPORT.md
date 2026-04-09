# Hloubkový audit modulu Finance (Pokladna a Fakturace)

**Datum:** 1. 3. 2026  
**Typ:** POUZE ANALÝZA – žádné opravy kódu  
**Zamčený soubor:** `task_assignment_engine.dart` – NEDOTÝKAT  

**Kontext:** B2B SaaS FalcoNest pro 1000+ agentur. Audit před dalším vývojem – identifikace chyb, nedodělků a technologických dluhů. Zvláštní důraz na Zaměstnaneckou pokladnu a generátor PDF (bez hardcoded textů pro zahraniční účetní – např. gestoría ve Španělsku).

---

## 1. ZAMĚSTNANECKÁ POKLADNA (Wallet)

### 1.1 Logika a UI pro transakce

**Souvisící soubory:**
- `lib/features/admin/finance_dashboard_screen.dart` – přehled peněženek
- `lib/features/admin/widgets/wallet_detail_modal.dart` – detail peněženky (modal)
- `lib/features/worker/screens/worker_wallet_screen.dart` – „Moje peněženka“ (pracovník)
- `lib/features/admin/providers/finance_cash_provider.dart` – providery

**Typy transakcí (`transaction_type`):**
| Typ | Význam | Směr `amount` |
|-----|--------|---------------|
| `COLLECTED_FROM_GUEST` | Výběr hotovosti od hosta (Check-in, Transfer) | kladné |
| `HANDED_TO_AGENCY` | Odevzdání agentuře | záporné |
| `COMPANY_EXPENSE` | Firemní výdaj (materiál, nákup) | záporné |

**Zjištění – PŘÍJMY a VÝDAJE:**
- **PŘÍJMY:** Ano – `COLLECTED_FROM_GUEST` při Check-in/Transfer.
- **VÝDAJE:** Ano – `COMPANY_EXPENSE` přes `AddCompanyExpenseDialog` v Worker UI.
- **Vyrovnání:** Ano – `HANDED_TO_AGENCY` přes tlačítko „Převzetí hotovosti“ v Admin (`admin.finance.receive_btn`).

---

### 1.2 Fotografie účtenek u výdajů

**Databáze:**  
Sloupec `receipt_image_url` v `employee_cash_transactions` (dle `database_schema.md`).

**Zadávání (Worker):**  
- `AddCompanyExpenseDialog` – tlačítko „Vyfotit“ (`worker.take_photo`), upload do Supabase Storage (`tenantId/expenses/uuid.jpg`).
- Fotka je volitelná – výdaj lze uložit i bez ní.

**Zobrazení:**
- Admin: `WalletDetailModal` – v `_TransactionTile` thumbnail účtenky, tap → `showReceiptDialog` (InteractiveViewer).
- Worker: `worker_wallet_screen.dart` – `_TransactionTile` s náhledem účtenky a `onReceiptTap`.

**Vazba v DB:**  
`receipt_image_url` je správně uložen a mapován do `BillingExpenseItem.mediaUrls` pro PDF.

**Omezení:**
- Fotky účtenek se nahrávají jen online. Při offline je zobrazeno upozornění (`worker.expense_photo_required_online`) a výdaj se bez fotky neukládá.

---

### 1.3 Výpočet dlužné částky a Vyrovnání

**Balance:**
- `employee_cash_wallets.balance` – aktuální dlužná hotovost.
- Zvýšení při `COLLECTED_FROM_GUEST`, snížení při `HANDED_TO_AGENCY` a `COMPANY_EXPENSE`.

**Funkce Vyrovnání / Převzetí hotovosti:**
- **Admin:**  
  - `FinanceDashboardScreen` – `_WalletCard` s `onReceiveCash` → `_showReceiveCashDialog`.  
  - `WalletDetailModal` – tlačítko „Převzetí hotovosti“ (`admin.finance.receive_btn`) když `balance > 0`.
- Oba dialogy volají `CashWalletRepository.instance.receiveCashFromWorker`, která vytvoří transakci `HANDED_TO_AGENCY` a nuluje balance.
- Dialog pro potvrzení (`admin.finance.receive_confirm_title`) je implementovaný.

**Zjištění:** Klíčová funkce pro vyrovnání existuje a je dostupná jak z přehledu, tak z detailu peněženky.

---

## 2. PODKLADY PRO FAKTURACI A PDF

### 2.1 Logika `billing_pdf_service.dart` a `billing_export_service.dart`

**BillingPdfService:**
- Generuje PDF s úkoly, výdaji a miniaturami fotek.
- Foty úkolů z `BillingTaskItem.mediaUrls`, foty výdajů z `BillingExpenseItem.mediaUrls`.
- Obrázky stahuje přes `networkImage`; selhání jedné fotky nezhodí celý export.
- Executive Summary nahoře, pak rozpis služeb, na konci výdaje s účtenkami.

**BillingExportService:**
- Export do Excelu (.xlsx).
- Sloupce: Klient, Rezervace, Úkol, Naplánováno, Dokončeno, Plátce, Cena, Měna.
- Pro každou skupinu: úkoly, řádek „Uhraveno hosty“, výdaje, řádek „CELKEM“ / „K ÚHRADĚ“.

---

### 2.2 Company expenses včetně účtenek

- **Načítání:** `finance_billing_provider` – `employee_cash_transactions` s `transaction_type = 'COMPANY_EXPENSE'`, `.not('apartment_id', 'is', null)`.
- `receipt_image_url` → `BillingExpenseItem.mediaUrls` (1 URL na výdaj).
- **PDF:** `_expenseToPdfWidgets` vykresluje miniatury 200×150 px pro každou URL.
- **Excel:** výdaje jsou v exportu, ale **bez obrázků** (Excel nepodporuje vložení fotky v tomto formátu).

**Důležité omezení:**  
Firemní výdaje **bez `apartment_id`** se do podkladů **nezapočítávají** – dotaz je filtruje.

---

## 3. KRITICKÁ KONTROLA i18n

### 3.1 BillingPdfService – hardcoded texty

| Řádek | Text | Kontext |
|-------|------|---------|
| 102 | `'Report služeb za $monthStr'` | Hlavička PDF |
| 104 | `'Klient: $clientName'` | Label klienta |
| 176-179 | `'Host: $guestName'` / `'Rezervace: $shortId'` | Základ bloku rezervace |
| 237 | `'Samostatné služby (Mimo rezervace)'` | Nadpis sekce |
| 306 | `'Plán: $scheduledStr  |  Dokončeno: $completedStr'` | Časová řádka u úkolu |
| 323 | `'${...} €'` | Symbol měny u ceny úkolu |
| 372 | `'Datum: $dateStr'` | Label u výdaje |
| 373 | `'${...} €'` | Symbol měny u výdaje |
| 302, 304 | `'—'` | Fallback pro chybějící datum |
| 28-29 | `externalDisplayName = 'Externí'` | Výchozí hodnota parametru |
| 110-118 | `'Celková rekapitulace'`, `'Rozpis poskytnutých služeb'`, ... | Fallbacky pro `footerLabels` (používají se, pokud volající nepředá mapu) |
| 161 | `'Majitel – faktura'`, `'Host – hotovost'`, `'Klient – faktura'`, `'Plátce'` | Fallbacky pro `payerLabels` / `payerPrefix` |
| 436 | `'klient'` | Fallback v `_sanitizeFileName` při prázdném názvu |

**Poznámka:** `FinanceBillingDialog` předává `footerLabels` a `payerLabels` z i18n. Přesto v PDF zůstávají tyto stringy natvrdo:
- `'Report služeb za …'`, `'Klient: …'`, `'Host: …'`, `'Rezervace: …'`
- `'Samostatné služby (Mimo rezervace)'`
- `'Plán: …  |  Dokončeno: …'`
- `'Datum: …'`
- symbol `€` (měna by měla být podle tenanta)

---

### 3.2 BillingExportService – hardcoded texty

| Řádek | Text | Kontext |
|-------|------|---------|
| 62-70 | `'Klient'`, `'Rezervace'`, `'Úkol'`, `'Naplánováno'`, `'Dokončeno'`, `'Plátce'`, `'Cena'`, `'Měna'` | Hlavičky sloupců |
| 157-158 | `'CELKEM'`, `'K ÚHRADĚ'` | Řádek celkové částky |
| 181-184 | `'Excel.encode() vrátil prázdný soubor'` | Chybová hláška |
| 23, 39 | `'fakturace_komplet_'`, `'fakturace_'` | Prefixy názvů souborů |
| 19 | `externalDisplayName = 'Externí'` | Výchozí hodnota parametru |
| 213 | `'klient'` | Fallback v `_sanitizeFileName` |
| 183-190 | `'owner'`, `'guest'`, `'client'` | Hodnoty plátce – vrací `_excelPayer` bez překladu |

---

### 3.3 finance_billing_screen – předávání labelů

- `_onClientExportPdf` předává `footerLabels` a `payerLabels` z i18n (ř. 67-84).
- Pro Excel se předává jen `paid_by_guests` a `paid_by_guests_detail`.
- Sloupce Excelu, `CELKEM`, `K ÚHRADĚ` a názvy souborů **nejsou** lokalizované.

---

### 3.4 Formátování data v PDF a Excelu

- Používá se `DateFormat('dd.MM.yyyy')` / `DateFormat('dd.MM.yyyy HH:mm')`.
- Formát je pevný (evropský), bez respektu k `context.locale` – v PDF službě není BuildContext.

---

## 4. IDENTIFIKACE CHYB A NEDODĚLKŮ

### 4.1 Kritické chyby (blokující pro zahraniční účetní)

| ID | Popis | Soubor(y) |
|----|-------|-----------|
| C1 | PDF: „Report služeb za“, „Klient:“, „Host:“, „Rezervace:“, „Samostatné služby (Mimo rezervace)“ hardcoded | `billing_pdf_service.dart` |
| C2 | PDF: „Plán:“, „Dokončeno:“, „Datum:“ hardcoded | `billing_pdf_service.dart` |
| C3 | PDF: symbol měny `€` hardcoded – měna by měla vycházet z tenanta | `billing_pdf_service.dart` |
| C4 | Excel: hlavičky sloupců (Klient, Rezervace, Úkol, …) hardcoded | `billing_export_service.dart` |
| C5 | Excel: „CELKEM“, „K ÚHRADĚ“ hardcoded | `billing_export_service.dart` |
| C6 | Excel: plátce `owner`/`guest`/`client` bez překladu | `billing_export_service.dart` |

---

### 4.2 Vysoká priorita

| ID | Popis | Soubor(y) |
|----|-------|-----------|
| H1 | Firemní výdaje bez `apartment_id` se nezapočítávají do fakturačních podkladů | `finance_billing_provider.dart` (ř. 485) |
| H2 | Názvy souborů `fakturace_komplet_`, `fakturace_` – český prefix | `billing_export_service.dart` |
| H3 | Fallback `'klient'` v `_sanitizeFileName` | `billing_pdf_service.dart`, `billing_export_service.dart` |
| H4 | Formát data v PDF/Excel pevný (dd.MM.yyyy) – bez lokalizace | oba exportní servery |

---

### 4.3 Střední priorita

| ID | Popis | Soubor(y) |
|----|-------|-----------|
| M1 | Fotka účtenky při offline – výdaj se neuloží; chybí offline fronta pro média | `add_company_expense_dialog.dart` |
| M2 | Symbol `€` hardcoded v UI (AddCompanyExpenseDialog, FinanceDashboardScreen, WalletDetailModal) | několik souborů |
| M3 | Excel neobsahuje sloupce pro URL účtenek – nelze ověřit fotky v tabulce | `billing_export_service.dart` |

---

### 4.4 Nízká priorita / vylepšení

| ID | Popis |
|----|-------|
| L1 | Chybová hláška v Excelu v češtině: `'Excel.encode() vrátil prázdný soubor'` |
| L2 | Volitelně: multi-receipt (více fotografií na jeden výdaj) – DB má jen `receipt_image_url` (1 URL) |
| L3 | Volitelně: možnost výběru galerie místo jen kamery u účtenky |

---

### 4.5 Shrnutí – chybějící i18n klíče pro PDF/Excel

Pro plnou lokalizaci PDF a Excelu je nutné doplnit např. tyto klíče (nebo ekvivalentní):

```
billing.pdf_report_title          // "Report služeb za" / "Services report for"
billing.pdf_client_label          // "Klient:" / "Client:"
billing.pdf_host_label            // "Host:" / "Guest:"
billing.pdf_reservation_label     // "Rezervace:" / "Reservation:"
billing.pdf_standalone_services    // "Samostatné služby (Mimo rezervace)"
billing.pdf_scheduled_label       // "Plán:" / "Scheduled:"
billing.pdf_completed_label       // "Dokončeno:" / "Completed:"
billing.pdf_date_label            // "Datum:" / "Date:"
billing.excel_col_client          // "Klient"
billing.excel_col_reservation     // "Rezervace"
billing.excel_col_task            // "Úkol"
billing.excel_col_scheduled       // "Naplánováno"
billing.excel_col_completed       // "Dokončeno"
billing.excel_col_payer           // "Plátce"
billing.excel_col_price           // "Cena"
billing.excel_col_currency        // "Měna"
billing.excel_row_total           // "CELKEM"
billing.excel_row_amount_due      // "K ÚHRADĚ"
billing.file_prefix_bulk          // "fakturace_komplet" / "billing_complete"
billing.file_prefix_client        // "fakturace" / "billing"
billing.fallback_client_name      // "klient" / "client"
```

Symbol měny by měl být odvozován z `tenant_currency_provider` / `currency_service`, ne hardcoded.

---

## 5. ARCHITEKTURA – dodržení pravidel

| Pravidlo | Stav |
|----------|------|
| i18n – žádné hardcoded texty v UI | Částečně porušeno – viz sekce 3 |
| i18n – PDF/Excel | Výrazně porušeno – viz sekce 3 |
| Multi-tenant (tenant_id, RLS) | Splněno |
| Offline-first | Splněno u výběru hotovosti; fotky účtenek jen online |
| Riverpod state management | Splněno |
| České komentáře | Splněno (kde bylo kontrolováno) |

---

## 6. DOPORUČENÝ AKČNÍ PLÁN

1. **Fáze 1 (kritické):** Odstranit hardcoded stringy v `billing_pdf_service.dart` – všechny texty přes parametry z i18n.
2. **Fáze 2 (kritické):** Odstranit hardcoded stringy v `billing_export_service.dart` – sloupce a řádky přes `labels` mapu.
3. **Fáze 3 (vysoká):** Řešit výdaje bez `apartment_id` – např. přiřazení do skupiny `external` nebo dedikovaná logika.
4. **Fáze 4 (střední):** Symbol měny odvozovat z tenanta v PDF/Excel i v UI.
5. **Fáze 5 (střední):** Lokalizovaný formát data pro exporty (např. předat `DateFormat` z volajícího s locale).

---

*Konec auditního reportu.*
