# Návrh: Payout Snapshots (zmražená historie výplat)

## 1. Analýza vzoru `billing_snapshots`

- **Tabulka:** `billing_snapshots` – jeden řádek na **(tenant_id, client_id, billing_period)**.
- **Sloupce:** `id`, `tenant_id`, `client_id`, `billing_period` (date, první den měsíce), `snapshot_data` (jsonb), `locked_at`, `locked_by` (profile admina).
- **Princip:** Při uzamčení měsíce se uloží neměnný JSONB snapshot; historická data se už nepočítají z živých tabulek.
- **RLS:** Admin/worker vidí snapshoty tenanta; majitel jen své (kde client.profile_id = jeho profil). INSERT jen admin.

---

## 2. Návrh SQL migrace pro `payout_snapshots`

Níže je návrh migrace ve stylu `billing_snapshots`: jeden řádek = jeden příjemce (zaměstnanec nebo partner) za jeden měsíc. Uzamčení provede admin při „Uzamknout měsíc výplat“ (nebo po hromadném označení jako vyplaceno).

```sql
-- =============================================================================
-- FalcoNest – Tabulka payout_snapshots pro zmraženou historii výplat
-- =============================================================================
-- PROČ: Historické výplaty nesmí záviset na dynamickém dotazu do task_payouts/
-- task_commissions (hrozí změna historických dat). Při uzamčení měsíce se uloží
-- neměnný snapshot – stejný princip jako billing_snapshots u fakturace.
--
-- Jeden řádek = jeden příjemce (zaměstnanec nebo partner) za jeden měsíc.
-- items_data = uzamčený seznam úkolů, za které dostal zaplaceno (pro PDF a UI).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka payout_snapshots
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payout_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  payout_period date NOT NULL,
  is_employee boolean NOT NULL,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE RESTRICT,
  client_id uuid REFERENCES public.clients(id) ON DELETE RESTRICT,
  recipient_name text NOT NULL,
  total_amount numeric NOT NULL,
  items_data jsonb NOT NULL DEFAULT '[]',
  locked_at timestamp with time zone NOT NULL DEFAULT now(),
  locked_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  CONSTRAINT payout_snapshots_recipient_check CHECK (
    (is_employee = true  AND profile_id IS NOT NULL AND client_id IS NULL)
    OR (is_employee = false AND client_id IS NOT NULL AND profile_id IS NULL)
  )
);

COMMENT ON TABLE public.payout_snapshots IS 'Zmražená historie výplat – jeden řádek na příjemce a měsíc. Čtení pro Historie výplat a PDF export.';
COMMENT ON COLUMN public.payout_snapshots.payout_period IS 'První den měsíce – např. 2026-03-01.';
COMMENT ON COLUMN public.payout_snapshots.is_employee IS 'true = zaměstnanec (profile_id), false = partner (client_id).';
COMMENT ON COLUMN public.payout_snapshots.recipient_name IS 'Jméno příjemce v okamžiku uzamčení (denormalizované).';
COMMENT ON COLUMN public.payout_snapshots.items_data IS 'Pole objektů: [{ "task_id", "task_title", "date", "amount" }, ...].';
COMMENT ON COLUMN public.payout_snapshots.locked_by IS 'Profil (Admin), který uzamčení provedl.';

-- Unikátní index – jeden snapshot na příjemce a měsíc (employee i partner rozlišeni).
CREATE UNIQUE INDEX IF NOT EXISTS idx_payout_snapshots_tenant_period_recipient
  ON public.payout_snapshots (
    tenant_id,
    payout_period,
    COALESCE(profile_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(client_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

CREATE INDEX IF NOT EXISTS idx_payout_snapshots_tenant_period
  ON public.payout_snapshots(tenant_id, payout_period);

-- -----------------------------------------------------------------------------
-- 2. RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.payout_snapshots ENABLE ROW LEVEL SECURITY;

-- SELECT: Admin/Manager/Worker v rámci tenantu; Super Admin vše.
CREATE POLICY "payout_snapshots_select_tenant"
  ON public.payout_snapshots FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- INSERT: Pouze Admin v rámci tenantu; locked_by = aktuální profil.
CREATE POLICY "payout_snapshots_insert_admin"
  ON public.payout_snapshots FOR INSERT
  WITH CHECK (
    (public.is_super_admin() OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    ))
    AND locked_by = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- UPDATE/DELETE: Snapshoty jsou immutable (stejně jako billing_snapshots).
-- Lze později přidat policy pro super_admin při opravě chyb.
```

**Formát `items_data` (JSONB):**

```json
[
  { "task_id": "uuid", "task_title": "Úklid A1", "date": "2026-03-15T00:00:00Z", "amount": 50.00 },
  { "task_id": "uuid", "task_title": "Transfer letiště", "date": "2026-03-18T00:00:00Z", "amount": 30.00 }
]
```

---

## 3. Plán přepisu repozitáře a provideru

### 3.1 Repozitář (`settlement_repository.dart`)

- **Odstranit** (nebo nepoužívat pro Historii): `getPaidSettlementsByMonth` včetně `Future.wait` a dynamických joinů na `task_payouts` / `task_commissions`.
- **Přidat:**
  - **`getPayoutSnapshotsByMonth(tenantId, DateTime month)`**  
    - Dotaz: `from('payout_snapshots').select(...).eq('tenant_id', tenantId).eq('payout_period', firstDayOfMonthStr)`.  
    - Vrátí `List<PayoutGroup>` (nebo DTO), které se z map řádků sestaví: `recipient_name`, `total_amount`, `items_data` → rozparsovat na `PayoutLineItem` a sestavit `PayoutGroup(isEmployee, recipientId, recipientName, totalAmount, payoutIds: [], commissionIds: [], items)`.
  - **`lockPayoutMonth(tenantId, DateTime month, List<PayoutGroup> groups, String lockedByProfileId)`**  
    - Pro každou skupinu z aktuálního stavu „K výplatě“ (nebo z předaných groups) vložit řádek do `payout_snapshots`: `tenant_id`, `payout_period`, `is_employee`, `profile_id`/`client_id`, `recipient_name`, `total_amount`, `items_data` (JSON z `PayoutLineItem`), `locked_by`.  
    - Volá se při akci „Uzamknout měsíc“ (viz níže).

### 3.2 Kdy zapisovat do snapshotů

- **Varianta A:** Při každém „Označit jako vyplaceno“ u skupiny zapisovat/aktualizovat řádek v `payout_snapshots` pro aktuální měsíc (upsert podle tenant_id, payout_period, profile_id/client_id).  
- **Varianta B (doporučeno, jako u Billingu):** Jednou za měsíc admin zvolí **„Uzamknout měsíc výplat“**; v tu chvíli se z aktuálních `task_payouts`/`task_commissions` se statusem `paid` a `updated_at` v daném měsíci načtou data, sestaví se `List<PayoutGroup>` a uloží do `payout_snapshots`.  
- Pro **Historii výplat** se pak vždy čte jen z `payout_snapshots`; pokud pro měsíc žádný snapshot není, zobrazí se prázdný stav („Měsíc nebyl uzamčen“ nebo prázdný seznam).

### 3.3 Provider (`settlements_provider.dart`)

- **`payoutHistoryReportProvider`**  
  - Místo volání `getPaidSettlementsByMonth` (dynamický dotaz) volat **`getPayoutSnapshotsByMonth(tenantId, monthDate)`**.  
  - Provider zůstane `FutureProvider.autoDispose.family<List<PayoutGroup>, PayoutMonthParam>`; pouze zdroj dat = nová metoda z repozitáře čtoucí z `payout_snapshots`.

---

## 4. Plán úpravy UI (odstranění rebuild smyčky)

### 4.1 Příčina smyčky

- V dialogu se používá **`widget.ref`** (ref z rodiče) a v `build` se vytváří **`PayoutMonthParam(year, month)`**.  
- I při správném `==`/`hashCode` může v overlay kontextu dialogu docházet k opakovanému buildu a k dojmu „rebuild smyčky“. PDF funguje, protože export čte data přímo (read/future) bez závislosti na životním cyklu widgetu v overlay.

### 4.2 Řešení: Historie jako přímý obsah (jako Podklady pro fakturaci)

- **Podklady pro fakturaci** nepoužívají vyskakovací dialog pro měsíční přehled – používají **přímý obsah** (`FinanceBillingContent`) v záložce (popř. v dialogu, který jen obaluje tentýž obsah).
- **Navrhovaná úprava:**
  1. **Přidat třetí záložku** na obrazovce Vyúčtování: **„Fronta úkolů“ | „K výplatě“ | „Historie výplat“**.
  2. **Obsah třetí záložky** = jeden widget **`PayoutHistoryContent`** (nový), který je **kopií vzoru** z `FinanceBillingContent`:
     - **ConsumerStatefulWidget** (ne StatefulWidget s `widget.ref`).
     - Stav: `_selectedMonth` (DateTime), v `initState` nastaveno na `DateTime.now()`.
     - V **build**:  
       `final param = PayoutMonthParam(year: _selectedMonth.year, month: _selectedMonth.month);`  
       `final asyncReport = ref.watch(payoutHistoryReportProvider(param));`
     - UI: přepínač měsíce (šipky + text), pod ním **asyncReport.when(loading, error, data)** – loading kolečko, error větev s textem, data = seznam skupin nebo prázdný stav + tlačítko Export PDF.
  3. **Odstranit** vyskakovací dialog pro Historie výplat (tlačítko „Historie výplat“ v záložce „K výplatě“ nahradit přepnutím na třetí záložku, nebo ponechat tlačítko jako přepínač na třetí tab).
  4. Žádné `showDialog` pro Historie výplat – obsah je vždy součástí stromu stejné obrazovky a používá **vlastní** `ref` z ConsumerStatefulWidgetu, takže se odstraní riziko zacyklení kvůli ref z overlay.

### 4.3 Shrnutí UI změn

| Co | Změna |
|----|--------|
| Obrazovka Vyúčtování | DefaultTabController(length: 3), třetí tab = „Historie výplat“. |
| Nový widget | `PayoutHistoryContent` (ConsumerStatefulWidget) – struktura jako `FinanceBillingContent`, param z `_selectedMonth`, `ref.watch(payoutHistoryReportProvider(param))`, when(loading, error, data). |
| Dialog | `SettlementHistoryDialog` a tlačítko „Historie výplat“ odstranit nebo nahradit přepnutím na tab „Historie výplat“. |
| Export PDF | Zůstane v `PayoutHistoryContent` (čte data z provideru pro vybraný měsíc). |

---

## 5. Vytvořená migrace

- **Soubor:** `supabase/migrations/20260317100000_create_payout_snapshots.sql`
- Obsahuje tabulku `payout_snapshots`, unikátní index, komentáře a RLS (SELECT pro tenant, INSERT jen admin, bez UPDATE/DELETE).

## 6. Pořadí implementace

1. **DB:** Migrace `20260317100000_create_payout_snapshots.sql` je připravena – nasadit (`supabase db push` nebo dle CI).
2. **Repo:** Implementovat `getPayoutSnapshotsByMonth` a `lockPayoutMonth`; v provideru pro historii používat jen snapshoty.
3. **Uzamčení měsíce:** V UI (záložka K výplatě nebo Historie) přidat akci „Uzamknout měsíc výplat“, která sestaví skupiny z aktuálních paid záznamů a zavolá `lockPayoutMonth` (nebo nejdřív jen číst ze snapshotů a uzamčení dořešit v další iteraci).
4. **UI:** Třetí záložka + `PayoutHistoryContent`, odstranit dialog pro Historie výplat.

Tím bude Historie výplat číst výhradně z `payout_snapshots`, repozitář bez dynamického Future.wait pro historii a UI bez dialogu v overlay, podle vzoru Podkladů pro fakturaci.
