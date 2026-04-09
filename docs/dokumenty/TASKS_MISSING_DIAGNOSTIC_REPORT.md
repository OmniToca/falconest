# Diagnostika: zmizelé úkoly v Reportech a Financích

## KROK 1: Analýza filtrů v kódu

### Reporty (`reports_provider.dart` – `reportsDataProvider`)

Dotaz na úkoly pro Reporty používá **přesně tyto podmínky**:

| Filtr | Hodnota | Poznámka |
|------|--------|----------|
| `tenant_id` | z `authNotifierProvider.tenantIdForData` | Pokud je null nebo prázdný, provider vrátí prázdný souhrn (žádné úkoly). |
| `status` | **přesně** `'completed'` | `.eq('status', 'completed')` – žádná jiná hodnota (např. `done`, `hotovo`, `dokončeno`) neprojde. |
| `deleted_at` | `IS NULL` | Soft-deleted úkoly se neberou. |
| `completed_at` | `>= startOfMonth` a `< startOfNextMonth` | Zařazení do měsíce jen podle `completed_at`. |
| limit | 2000 | | 

**Reporty nefiltrují** podle `invoiced_at` – zahrnují i vyfakturované úkoly.

**Skryté riziko:**  
Jinde v kódu (např. `settlements_provider.dart`) se uvádí, že DB může obsahovat i hodnoty `'done'`, `'hotovo'`, `'dokončeno'`. Reporty i Finance ale filtrují **pouze** `.eq('status', 'completed')`. Úkoly s jiným textem statusu (např. z jiného klienta nebo staršího importu) v Reportech ani v „K fakturaci“ neuvidíte.

---

### Finance – Podklady pro fakturaci / K fakturaci (`finance_billing_provider.dart` – `billingReportProvider`)

- **Pokud pro daný měsíc existují záznamy v `billing_snapshots`:**  
  Vrátí se **zmražený stav** ze snapshotů. Živé úkoly z tabulky `tasks` se **nenačítají**. Odemykací skript nastavil `invoiced_at = NULL` a promazal `task_payouts`, ale **nezmazal řádky v `billing_snapshots`**. Pokud tedy pro leden/únor/březen snapshoty jsou, aplikace zobrazí stará zmražená data (např. prázdná nebo bez těch úkolů) a živé úkoly z DB se v tomto provideru vůbec nečtou.

- **Pokud pro daný měsíc snapshoty nejsou:**  
  Načítají se úkoly s těmito filtry:

| Filtr | Hodnota |
|------|--------|
| `tenant_id` | z `authNotifierProvider.tenantIdForData` |
| `status` | **přesně** `'completed'` |
| `invoiced_at` | `IS NULL` |
| `deleted_at` | `IS NULL` |
| `completed_at` | v intervalu daného měsíce |
| limit | 2000 |

Žádná další „skrytá“ podmínka (např. na přiřazeného uživatele) tam není. Důležité je: **když existují snapshoty, úkoly z DB se pro ten měsíc v tomto provideru neberou.**

---

### Finance – K fakturaci / K vyplacení v detailu klienta (`clientBillingProvider`)

- Načítají se úkoly buď s `client_id = clientId`, nebo s `apartment_id IN (apartmentIds majitele)`.
- Použité filtry: `tenant_id`, `status = 'completed'`, `deleted_at IS NULL`.
- **Neplatí** filtr na `invoiced_at` – vrací se i vyfakturované úkoly (aby bylo vidět stav „uhrazeno“).
- Žádná další skrytá podmínka na přiřazeného uživatele.

---

## Shrnutí příčin, proč úkoly „chybí“

1. **Reporty + Finance (K fakturaci) vyžadují `status = 'completed'`.**  
   Pokud je v DB `done`, `hotovo`, `dokončeno` nebo jiný text, úkoly se v těchto pohledech neobjeví.

2. **Finance (Podklady pro fakturaci) pro daný měsíc bere data ze `billing_snapshots`.**  
   Pokud pro leden/únor/březen snapshoty existují, aplikace nečte aktuální úkoly z `tasks` a zobrazí jen to, co je ve snapshotu (po odemykání může být prázdné nebo neúplné).

3. **`tenant_id`:**  
   Pokud je `tenantIdForData` prázdný (špatný kontext přihlášení / tenant), Reporty i Finance vrátí prázdné výsledky.

4. **`deleted_at`:**  
   Úkoly s vyplněným `deleted_at` se nikde neukazují.

5. **`completed_at`:**  
   Pro Reporty i pro „K fakturaci“ se měsíc určuje podle `completed_at`. Úkoly s `completed_at` mimo zvolený měsíc nebo s `completed_at = NULL` v daném měsíci nebudou zobrazeny.

---

## KROK 2: Diagnostický SQL (Supabase SQL Editor)

Spusť v **Supabase SQL Editoru** následující dotaz. Vypíše **posledních 50 úkolů** (od 1. 1. 2026) seřazených podle `scheduled_start` sestupně, abys viděl reálný stav v DB (včetně `status` a `completed_at`).

```sql
-- Diagnostika: úkoly od 1.1.2026 – reálný stav v DB
-- Sloupce: id, title, status, scheduled_start, completed_at, invoiced_at, deleted_at
SELECT
  id,
  title,
  status,
  scheduled_start,
  completed_at,
  invoiced_at,
  deleted_at
FROM public.tasks
WHERE scheduled_start >= '2026-01-01'
ORDER BY scheduled_start DESC
LIMIT 50;
```

**Na co se v výsledku podívat:**

- **`status`** – pokud není přesně `'completed'`, Reporty i Finance (K fakturaci) úkol nezobrazí.
- **`completed_at`** – pokud je NULL u dokončených úkolů, nezařadí se do žádného měsíce v Reportech ani v Podkladech pro fakturaci.
- **`invoiced_at`** – po odemykání by měl být NULL; pokud ne, „K fakturaci“ je stále vyfiltruje (pokud se pro daný měsíc berou živá data).
- **`deleted_at`** – pokud není NULL, úkol se v aplikaci nikde neukazuje.

**Volitelně – pouze úkoly tenanta (nahraď `TENANT_UUID`):**

```sql
SELECT
  id,
  title,
  status,
  scheduled_start,
  completed_at,
  invoiced_at,
  deleted_at
FROM public.tasks
WHERE tenant_id = 'TENANT_UUID'
  AND scheduled_start >= '2026-01-01'
ORDER BY scheduled_start DESC
LIMIT 50;
```

**Volitelně – rozložení statusů od 1.1.2026 (případně s `tenant_id`):**

```sql
SELECT status, COUNT(*) AS cnt
FROM public.tasks
WHERE scheduled_start >= '2026-01-01'
  -- AND tenant_id = 'TENANT_UUID'
GROUP BY status
ORDER BY cnt DESC;
```

Tím zjistíš, jestli máš úkoly s jiným než `'completed'` statusem, které by měly být v Reportech/Financích vidět.
