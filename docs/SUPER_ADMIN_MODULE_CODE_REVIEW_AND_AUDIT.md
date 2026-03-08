# Super-Admin (FalcoNest HQ) – Code Review a Audit

**Datum:** 2026-03-05  
**Rozsah:** `lib/features/super_admin/` + související soubory (router, auth, providery).  
**Pravidla:** Žádné automatické opravy – pouze report.

---

## 🔴 KRITICKÉ CHYBY (musíme opravit hned)

### 1. RLS na tabulce `tenants` blokuje Account Managery – prázdný dashboard

**Problém:** Politika `tenants_select` v migraci `20250306_unified_profiles_ghost_strategy.sql` povoluje pouze:

- `public.is_super_admin()` **nebo**
- `id = public.my_tenant_id()`

Funkce `my_tenant_id()` vrací `tenant_id` z profilu přihlášeného uživatele. U **account_manager** je `tenant_id` v profilu typicky **NULL** (HQ, ne přiřazen k jednomu tenantu). Tedy `id = NULL` nikdy neplatí a `is_super_admin()` pro account_managera také ne. **Výsledek:** dotazy na `tenants` vrací **0 řádků** – Account Manager vidí prázdný seznam agentur a nemůže používat HQ modul.

**Kde se to projeví:** `allTenantsProvider` a `tenantsWithStatusProvider` volají Supabase `.from('tenants').select(...)`. RLS se vyhodnotí na serveru dřív než client-side filtr `.or('acquired_by.eq.xxx,managed_by.eq.xxx')` – takže bez úpravy RLS se data nikdy nedostanou do aplikace.

**Řešení:** Přidat novou migraci, která rozšíří `tenants_select` o podmínku pro roli `account_manager`:

- Povolit SELECT pro tenanty, kde `tenants.acquired_by` nebo `tenants.managed_by` je rovno ID profilu aktuálního uživatele, **a** současně je role tohoto uživatele `account_manager`.

Příklad (logika – konkrétní SQL podle vaší konvence):

```sql
-- Rozšíření tenants_select: account_manager vidí jen tenanty, kde je Lovec nebo Farmář
DROP POLICY IF EXISTS "tenants_select" ON public.tenants;
CREATE POLICY "tenants_select" ON public.tenants FOR SELECT
  USING (
    public.is_super_admin()
    OR id = public.my_tenant_id()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'account_manager'
      AND (
        acquired_by = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
        OR managed_by = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      )
    )
  );
```

Bez této změny je modul pro roli **account_manager** v produkci nefunkční (prázdný seznam agentur).

---

### 2. Route guard pro `/super-admin/tenant/:id` u Account Managera (doplnění k RLS)

**Problém:** I po opravě RLS výše: pokud by někdo znal ID cizí agentury a otevřel přímo URL `/super-admin/tenant/<cizí-id>`, záleží čistě na RLS, zda dotaz na tenanta vrátí řádek. **RLS po opravě výše** už omezí výběr jen na „vlastní“ tenanty (super_admin vše, account_manager jen acquired_by/managed_by). Takže po zavedení migrace z bodu 1 by přímý přístup na cizí tenant u account_managera **mělo** RLS zablokovat (dotaz vrátí 0 řádků → `tenantDetailProvider` vrátí null → UI zobrazí „Agentura nenalezena“).

**Doporučení:** Přidat **app-level guard** v routeru: před otevřením obrazovky detailu tenanta pro roli `account_manager` ověřit, že `tenantId` je v seznamu povolených (např. z `tenantsWithStatusProvider` nebo z jednoho providera „my allowed tenant ids“). Tím zajistíte konzistentní chování a srozumitelnou chybovou hlášku místo spoléhání jen na to, že RLS vrátí prázdno. Bez guardu to není nutně „kritická díra“ (RLS chrání data), ale je to **doporučené doplnění** pro jasné RBAC v UI a logu.

**Zařazení:** Pokud považujete „možnost zkusit otevřít cizí tenant a dostat jen prázdný stav“ za přijatelné do doby, než guard doplníte, lze tento bod přesunout do 🟠 VAROVÁNÍ. Pokud chcete striktní „nikdy nezobrazit obrazovku bez předchozí kontroly oprávnění“, nechte v kritických nebo doplňte guard co nejdříve.

---

## 🟠 VAROVÁNÍ (chybějící i18n, try-catch, autoDispose)

### 1. Hardcodované texty (i18n)

- **`tenant_command_modal.dart`**  
  - Řádek cca 593: `subtitle: 'MRR'` – mělo by být z i18n (např. klíč `super_admin.mrr_short` nebo společný `common.mrr`).
  - Hint v poli (např. `hintText: '0'`) – pokud je to čistě placeholder čísla, lze ponechat; pokud se má zobrazovat jako popisek, měl by být z i18n.

- **`super_admin_settings_modal.dart`**  
  - `hintText: 'PLN'`, `hintText: 'zł'`, `hintText: '25'` – měly by být v překladových souborech (např. `super_admin.default_currency_hint`, `super_admin.trial_days_hint`), aby bylo možné lokalizovat a měnit bez změny kódu.

### 2. Chybějící `autoDispose` u providerů

- V `lib/features/super_admin/providers/` (a souvisejících) **nejsou** u FutureProviderů / StateProviderů použity `autoDispose` modifikátory.
- **Dopad:** Instance providerů zůstávají v paměti i po opuštění Super-Admin obrazovky, dokud není celý „scope“ zničen. U obrazovek s parametrem (např. měsíc, tenant ID) to může znamenat hromadění cache.
- **Doporučení:** U providerů, které drží pouze data pro aktuální obrazovku (např. `monthlyAgencySettlementsProvider(month)`, `tenantDetailProvider(tenantId)`), zvážit `autoDispose` (např. `ref.keepAlive()` jen tam, kde potřebujete data držet záměrně). U globálních (seznam všech tenantů pro HQ) může být záměr bez autoDispose pro sdílení cache – pak to zdokumentovat komentářem.

### 3. Magic Login – zápis do `support_interventions`

- **Stav:** V `AuthNotifier.impersonateTenant` je volání `startIntervention` v `try/catch`. Při výjimce se nastaví `_activeInterventionId = null` a převtělení se stejně provede – aplikace nepadá.
- **Varování:** Pokud zápis do `support_interventions` selže (síť, RLS, validace), zásah se neaudituje. Je vhodné alespoň logovat výjimku (např. `debugPrint` nebo logger) a v budoucnu zvážit retry nebo lokální frontu neodeslaných zásahů.

### 4. Ukončení převtělení – `endIntervention`

- **Stav:** V `AuthNotifier.stopImpersonating` je `endIntervention` v `try/catch` – chyba se tiše pohltí.
- **Doporučení:** Stejně jako u startu – logovat selhání, aby bylo možné dohledat problémy s auditem (např. síť při odhlašování).

### 5. Validace provize (Zúčtování odměn)

- **Stav:** V `agency_settlements_screen.dart` se používá `num.tryParse(amountController.text.trim())`; při `null` nebo záporné hodnotě se zobrazí SnackBar s klíčem `super_admin.settlements_amount_invalid`. Písmena nebo prázdný vstup tedy nezpůsobí pád – **OK**.
- **Doporučení:** Uživatelsky může být příjemné přidat také `TextFormField` s `validator` (např. kladné číslo, max. 2 desetinná místa), aby se chyba zobrazila u pole, ne jen přes SnackBar.

---

## 🔵 DOPORUČENÍ PRO REFACTORING (čistota a čitelnost)

### 1. Loading a error stavy

- **Agency Settlements:** Obrazovka používá `AsyncValue` z `monthlyAgencySettlementsProvider` a zobrazuje loading/error – v pořádku.
- **Modály a další obrazovky:** Projít všechny obrazovky, které čtou z async providerů (audit log, výkazy práce, detail tenanta, onboarding, billing), a ověřit, že všude je explicitní zpracování `loading` a `error` (např. indikátor načítání a tlačítko „Zkusit znovu“ nebo přehledná chybová hláška).

### 2. Router – explicitní guard pro Account Managera

- Přidat guard před přechodem na `/super-admin/tenant/:id`: pro roli `account_manager` ověřit, že `tenantId` je v seznamu povolených (např. z providera odvozeného od `tenantsWithStatusProvider`). Při neplatném ID přesměrovat na dashboard nebo zobrazit „Nemáte oprávnění k této agentuře“.

### 3. Komentáře a dokumentace

- Repozitáře (`support_interventions_repository.dart`, `agency_management_settlements_repository.dart`) již obsahují české komentáře vysvětlující PROČ (např. účel `startIntervention`/`endIntervention`, upsert provizí). Tuto úroveň zachovat u všech nových metod v HQ modulu.
- U složitějších providerů (např. slučování Lovce/Farmáře do karet v `monthlyAgencySettlementsProvider`) doplnit krátký komentář nad výpočet (např. „Seskupení řádků podle tenanta a role, jeden řádek = jeden tenant s max. dvěma rolemi“).

### 4. Nepoužívané importy a mrtvý kód

- V rámci auditu byly kontrolovány vybrané soubory; doporučuje se spustit **dart analyze** a **flutter analyze** na celou složku `lib/features/super_admin/` a odstranit nepoužívané importy a mrtvé proměnné. Před mergem do main provést stejnou kontrolu na celý projekt.

### 5. Jednotný přístup k „povoleným tenantům“ pro Account Managera

- Seznam tenantů, ke kterým má account_manager přístup, je odvozen z `tenantsWithStatusProvider` (filtrace podle `acquired_by` / `managed_by`). Zvážit jeden malý provider typu `allowedTenantIdsProvider`, který vrací pouze `Set<String>` nebo `List<String>` ID – použitelné v routeru pro guard i v dalších místech (např. „můžu zobrazit tento tenant?“) bez opakování logiky filtrace.

### 6. RLS a role

- Po přidání podmínky pro `account_manager` do `tenants_select` ověřit v testech (nebo ručně), že:
  - Super-Admin vidí všechny tenanty.
  - Account Manager vidí pouze tenanty, kde je `acquired_by` nebo `managed_by` jeho profil.
  - Ostatní role nemají SELECT na tenanty mimo `my_tenant_id()` (pokud to tak má být).

---

## Shrnutí priorit

| Priorita | Bod | Akce |
|----------|-----|------|
| P0 | RLS `tenants` pro account_managera | Přidat migraci s rozšířením `tenants_select` – bez toho je HQ pro account_managera nefunkční. |
| P1 | Route guard `/super-admin/tenant/:id` | Pro account_managera ověřit povolené tenant ID v routeru (doplněk k RLS). |
| P2 | i18n pro „MRR“, „PLN“, „zł“, „25“ | Přesunout do cs/en (a dalších) slovníků. |
| P2 | autoDispose u vybraných providerů | Zvážit u family providerů (měsíc, tenant ID). |
| P2 | Logování u startIntervention/endIntervention | Při chybě logovat, ne jen tiše pohltit. |
| P3 | Validace pole provize (validator) | Doplnit pro lepší UX vedle SnackBar. |
| P3 | allowedTenantIdsProvider + kontrola mrtvého kódu | Zjednodušení guardu a čistota kódu. |

---

*Report vznikl na základě prozkoumání `lib/features/super_admin/`, `app_router.dart`, `auth_notifier.dart`, `all_tenants_provider.dart` a souvisejících migrací v `supabase/migrations/`.*
