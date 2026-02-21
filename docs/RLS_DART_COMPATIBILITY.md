# RLS a kompatibilita s Flutter (Dart) kódem

Tento dokument popisuje, jak jsou migrace RLS sladěné s aplikací:
- `20250218_rls_multi_tenant.sql` – zapnutí RLS
- `20250219_rls_profiles_login_fix.sql` – rozdělení SELECT na profiles
- **`20250220_rls_is_super_admin_no_recursion.sql`** – odstranění rekurze: `is_super_admin()` čte z tabulky `app_super_admins`, ne z `profiles`.

## 1. Přihlášení a načtení profilu

**Co SQL dělá (po opravě 20250219):**  
Na `profiles` jsou **dvě** SELECT policy:
- **profiles_select_own:** `id = auth.uid()` – čtení vlastního řádku (bez volání `is_super_admin()`).
- **profiles_select_super_admin:** `is_super_admin()` – Super Admin vidí všechny.

Čtení vlastního profilu tedy závisí jen na `auth.uid()`. V `auth_notifier.dart` v `_loadRoleAndNotify()`:

```dart
.from('profiles').select('role, tenant_id').eq('id', user.id).maybeSingle()
```

**Dart úpravy (kvůli RLS / race condition):**  
- Na začátku `_loadRoleAndNotify()` je **prodleva 350 ms**, aby Supabase klient stihl nastavit JWT do dalších requestů (jinak může první dotaz odjet s prázdným `auth` a RLS vrátí 0 řádků).  
- **5 pokusů** s prodlevou (první opakování po 500 ms, další po 1 s).  
- Chybová hláška při null odpovědi zmiňuje RLS a možné pozdní nastavení JWT.

---

## 2. Super Admin a `tenant_id = NULL`

**Co SQL dělá:**  
Funkce `is_super_admin()` čte z `profiles` s **SECURITY DEFINER**, takže nevyvolá RLS (žádná rekurze).  
Pro Super Admina s `tenant_id = NULL` pak všechny policy na `tenants`, `apartments`, `reservations`, `tasks` projdou díky `is_super_admin() = true` – nemusí mít vyplněný `tenant_id`.

**Co už máš v Dartu:**  
- `AppAuthState.tenantId` je **nullable** (`String?`).  
- Parsování v `_loadRoleAndNotify` při `tenant_id == null` nenastavuje chybu.  
- Router posílá Super Admina na `/super-admin`, ne na čekárnu.  
- Providery používají `tenantIdForData` a při null vracejí prázdný seznam (bez volání API).

**Doporučení:** Žádná změna. Kód je s RLS a null `tenant_id` u Super Admina sladěný.

---

## 3. Filtrování na klientovi (tenantIdForData)

Aplikace už v dotazech používá **`.eq('tenant_id', tenantIdForData)`** (tasks, apartments, …).  
S RLS:

- **Běžný uživatel:** DB mu stejně vrátí jen řádky jeho tenanta; filtr v aplikaci je redundantní, ale neškodí.  
- **Super Admin:** DB mu může vrátit všechna data; **aplikace musí filtrovat** podle vybrané agentury (`_selectedTenantId`), aby v UI viděl jen jednu agenturu.

**Doporučení:** Zachovat současné chování – provádět filtry na klientovi podle `tenantIdForData`. Po zapnutí RLS se nic nemění z pohledu UI.

---

## 4. Tabulky mimo tuto migraci

RLS v této migraci zapínáme jen pro: **profiles, tenants, apartments, reservations, tasks**.

- **invitations**, **staff_absences**: Pokud na ně máš nebo přidáš RLS, používej stejný vzor: `is_super_admin() OR (tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid()))`.  
- **user_roles** (migrace `20250216_user_roles.sql`): Policies tam čtou `(SELECT role FROM public.profiles WHERE id = auth.uid())`. Po zapnutí RLS na `profiles` to stále funguje, protože čtení **vlastního** profilu je povolené. Pro sjednocení můžeš v policies pro super_admin větvu použít `public.is_super_admin()` místo přímého SELECT z `profiles`.

---

## 5. Možné kolize a co zkontrolovat

| Místo | Riziko | Stav |
|-------|--------|------|
| Login – čtení `profiles` po přihlášení | RLS by mohl zablokovat čtení vlastního profilu | ✅ Policy povoluje `id = auth.uid()` |
| Super Admin bez vybrané agentury | Načítání „všech“ dat bez filtru | ✅ Providery vracejí `[]` při null `tenantIdForData` |
| `tenant_id = null` v odpovědi | Pád nebo chybný redirect | ✅ Null je ošetřen v auth a routeru |
| Rekurze při kontrole role v RLS | Zacyklení při čtení `profiles` v policy | ✅ `is_super_admin()` je SECURITY DEFINER |

Žádná úprava Dart kódu kvůli této RLS migraci není nutná. Doporučený postup:

1. Spustit `20250218_rls_multi_tenant.sql` v Supabase (SQL Editor nebo migrace).  
2. Otestovat přihlášení jako **Super Admin** (tenant_id NULL) → očekávaně přesměrování na `/super-admin`.  
3. Otestovat přihlášení jako **Admin** s vyplněným tenant_id → přístup k datům své agentury.  
4. Otestovat převtělení Super Admina do agentury → zobrazení pouze dat vybrané agentury (díky `tenantIdForData`).
