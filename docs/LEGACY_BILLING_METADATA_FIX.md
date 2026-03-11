# Jednorázová oprava legacy metadat u úkolů (fakturace)

Tento dokument obsahuje SQL dotazy pro ruční opravu historických úkolů v Supabase – doplnění nebo přepsání `metadata` (service_price, amount_to_collect, payer_type), aby se na obrazovce „Podklady pro fakturaci“ zobrazovaly správné ceny a plátci.

---

## Kam SQL vložit v Supabase

1. Otevřete **Supabase Dashboard** → váš projekt
2. V levém menu zvolte **SQL Editor**
3. Klikněte na **New query**
4. Zkopírujte příslušný SQL kód (nejdřív SELECT pro kontrolu, pak UPDATE pro úpravu)
5. Klikněte **Run** (nebo Ctrl/Cmd + Enter)

> **Poznámka:** U multi-tenant aplikace může RLS omezit výběr jen na váš tenant. Pokud běžíte jako super_admin nebo service_role, uvidíte všechna data. Pro běžného tenanta bude RLS platit automaticky.

---

## 1. SELECT – vypsat dokončené úkoly za březen 2026

Tento dotaz vrátí úkoly s lidsky čitelnými názvy apartmánů a klientů. Slouží k identifikaci, který úkol patří ke kterému bytu/klientovi a co má v `metadata`.

```sql
-- Dokončené úkoly za březen 2026 s názvy apartmánů a klientů
SELECT
  t.id AS task_id,
  t.title AS task_title,
  COALESCE(a.name, '(externí)') AS apartment_name,
  COALESCE(c_direct.name, c_owner.name, '(bez klienta)') AS client_name,
  t.metadata,
  t.completed_at::date AS completed_date
FROM tasks t
LEFT JOIN apartments a
  ON t.apartment_id = a.id AND (a.deleted_at IS NULL)
LEFT JOIN clients c_direct
  ON t.client_id = c_direct.id AND (c_direct.deleted_at IS NULL)
LEFT JOIN apartment_owners ao
  ON t.apartment_id = ao.apartment_id AND (ao.deleted_at IS NULL)
LEFT JOIN clients c_owner
  ON ao.owner_id = c_owner.profile_id AND (c_owner.deleted_at IS NULL)
WHERE t.status = 'completed'
  AND t.completed_at >= '2026-03-01'::timestamptz
  AND t.completed_at < '2026-04-01'::timestamptz
  AND (t.deleted_at IS NULL)
ORDER BY client_name, apartment_name, t.completed_at;
```

**Význam sloupců:**
- `task_id` – UUID úkolu (potřebné pro UPDATE)
- `task_title` – název úkolu
- `apartment_name` – název apartmánu (u externích úkolů „(externí)“)
- `client_name` – jméno klienta/majitele
- `metadata` – aktuální JSONB obsah (service_price, amount_to_collect, payer_type, …)
- `completed_date` – datum dokončení

---

## 2. UPDATE – bezpečná aktualizace metadata (merge, bez mazání existujících klíčů)

Operátor `||` u JSONB **sloučí** objekty: nové klíče se přidají, existující se přepíší. Ostatní klíče (např. `requires_photo`, `flight_number`) zůstanou zachovány.

### Příklad A: Host platí hotovost (45 EUR)

```sql
-- DOPLŇTE task_id z výsledku SELECT dotazu výše
UPDATE tasks
SET metadata = metadata || '{"payer_type": "guest", "amount_to_collect": 45}'::jsonb
WHERE id = 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
  AND status = 'completed';
```

### Příklad B: Majitel platí (70 EUR na faktuře)

```sql
UPDATE tasks
SET metadata = metadata || '{"payer_type": "owner", "service_price": 70}'::jsonb
WHERE id = 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
  AND status = 'completed';
```

### Příklad C: Kombinace (majitel + cena + ponechat amount_to_collect)

```sql
UPDATE tasks
SET metadata = metadata || '{"payer_type": "owner", "service_price": 70}'::jsonb
WHERE id = 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
  AND status = 'completed';
```

> **Tip:** Pokud chcete `amount_to_collect` odstranit (platí majitel), použijte `-` operátor:
> ```sql
> SET metadata = (metadata - 'amount_to_collect') || '{"payer_type": "owner", "service_price": 70}'::jsonb
> ```

---

## 3. Kontrola po UPDATE

Po úpravě spusťte znovu SELECT s konkrétním `task_id`:

```sql
SELECT id, title, metadata
FROM tasks
WHERE id = 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX';
```

---

## Bezpečnostní doporučení

1. **Vždy nejdřív SELECT** – ověřte, že vybíráte správné úkoly.
2. **UPDATE po jednom** – pro větší jistotu upravujte úkoly jeden po druhém (podle `task_id`).
3. **Záloha** – před hromadnými změnami si můžete exportovat data:
   ```sql
   -- Export pro zálohu (spusťte a stáhněte výsledek)
   SELECT id, metadata FROM tasks WHERE status = 'completed' AND completed_at >= '2026-03-01' AND completed_at < '2026-04-01';
   ```
