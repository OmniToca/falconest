# Analýza: „Modul je již aktivní“ – UI ukazuje modul jako neaktivní, aktivace selže

**Problém:** V administraci jsou moduly (Fakturace, Automatizace) zobrazeny jako neaktivní a nabízejí spuštění zkušební verze. Po kliknutí na aktivaci uživatel dostane chybu „Modul je již aktivní.“ Databáze má záznam a brání duplicitě; aplikace modul buď nevidí, nebo ho při „odemčení“ ignoruje.

**Scope:** Pouze analýza. Návrh oprav až po odsouhlasení.

---

## 1. Databáze a RLS (`tenant_modules`)

### Hodnoty sloupce `status`

- V **20250225_tenant_modules_and_modules.sql**: `status text NOT NULL DEFAULT 'active'`. Komentář: *„active = zapnuto, cancelled = zrušeno (pro budoucí rozšíření)“*.
- V kódu se při aktivaci trialu posílá **`status: 'active'`** (premium_upsell_dialog, INSERT do `tenant_modules`).
- **Závěr:** Schéma ani komentáře neobsahují hodnotu `trialing`. Stav „zkušební“ je vyjádřen sloupci **`is_trial`** a **`trial_ends_at`**, ne hodnotou `status`. Očekávané hodnoty: **`active`**, **`cancelled`** (a případně budoucí rozšíření).

### RLS pro SELECT (admin / super_admin)

- **20250226:**  
  - `tenant_modules_super_admin_full` – FOR ALL, `is_super_admin()` → Super Admin vidí vše.  
  - `tenant_modules_select_own_tenant` – FOR SELECT, `tenant_id = (SELECT tenant_id FROM public.profiles WHERE **id** = auth.uid() LIMIT 1)`.  
  - **Chyba:** V `profiles` je uživatel identifikován **`auth_id = auth.uid()`**, ne `id = auth.uid()`. Sloupec `id` je UUID profilu, `auth.uid()` je UUID z `auth.users`. Tato podmínka proto pro běžné uživatele **nikdy nesedí** – policy sama o sobě nikomu nepovolí řádky.

- **20250306_unified_profiles_ghost_strategy.sql:**  
  - V DO bloku: pokud existuje nějaká policy na `tenant_modules` s názvem obsahujícím `tenant`, vytvoří se **`tenant_modules_select`**:  
    `USING (public.is_super_admin() OR tenant_id = public.my_tenant_id())`.  
  - **`my_tenant_id()`** vrací `tenant_id` z `profiles WHERE auth_id = auth.uid()` – to je správně.
- **Výsledek:** Pro běžného admina je jediná funkční SELECT policy **`tenant_modules_select`** (s `my_tenant_id()`). Super Admin má navíc plný přístup přes `tenant_modules_super_admin_full`.  
- **Riziko:** Pokud by z nějakého důvodu `my_tenant_id()` vracel NULL (např. chybějící nebo nekonzistentní profil), admin by neviděl žádné řádky. Pro „ráno to fungovalo“ je ale pravděpodobnější příčina na straně aplikace (viz bod 2 a 3).

---

## 2. Načítání ve Flutteru (provider)

- **Provider:** Aktivní moduly pro tenanta načítá **`lib/features/admin/providers/module_provider.dart`**:
  - **`activeModuleKeysProvider`** → volá **`_fetchActiveModuleKeysForTenant(tenantId)`**
  - **`tenantActiveModuleIdsProvider`** → volá **`_fetchActiveModuleIdsForTenant(tenantId)`**

- **Dotaz:**  
  - `.from('tenant_modules')`  
  - `.select('module_id, modules(key), valid_until, trial_ends_at')` resp. bez joinu jen potřebné sloupce  
  - **`.eq('tenant_id', tenantId)`**  
  - **`.isFilter('deleted_at', null)`**  
  - **Žádný filtr na `status`** – tedy **žádné `.eq('status', 'active')`**. Stav `trialing` vs `active` v sloupci `status` tedy na výsledek dotazu nemá vliv.

- **Důležitá logika po načtení:**  
  Pro každý řádek se volá **`_isModuleValidNow(map['valid_until'], map['trial_ends_at'], now)`**:
  - `valid_until != null && valid_until.isBefore(now)` → modul se **nezapočítá** (vyřadí se z množiny aktivních).
  - `trial_ends_at != null && trial_ends_at.isBefore(now)` → modul se **nezapočítá**.

- **Závěr:**  
  Provider **nezahazuje** moduly kvůli hodnotě `status` (např. `trialing`). **Zahazuje** je však, pokud **`trial_ends_at`** nebo **`valid_until`** jsou v minulosti. V takovém případě řádek v DB zůstává (a stále má např. `status = 'active'`), ale v aplikaci se neobjeví v `activeModuleKeysProvider` / `tenantActiveModuleIdsProvider`, takže UI modul zobrazí jako neaktivní. Při opětovné aktivaci pak INSERT narazí na UNIQUE (tenant_id, module_id) → 23505 → „Modul je již aktivní.“

---

## 3. Logika „odemčení“ v UI (Flutter)

- **Kde se rozhoduje, zda je modul odemčen:**  
  - **`isModuleActive(ref, moduleKey)`** v `module_provider.dart`:  
    - Super Admin → vždy `true`.  
    - Ostatní → `ref.read(activeModuleKeysProvider).valueOrNull?.contains(moduleKey) ?? false`.
  - **Sidebar (admin_layout.dart):**  
    - `activeKeys = activeModuleKeysProvider.valueOrNull ?? {}`  
    - `tenantHasModule = activeKeys.contains(module.key)`  
    - `isActive = isSuperAdmin || tenantHasModule`  
  - Tj. „odemčeno“ = modul je v množině vrácené z **`_fetchActiveModuleKeysForTenant`**, která závisí na **deleted_at** a na **valid_until / trial_ends_at** (viz výše).

- **Zohlednění stavů:**  
  Aplikace **nerozlišuje** hodnoty `status` (active / trialing / cancelled). Rozhoduje pouze:
  - řádek existuje a `deleted_at IS NULL`,
  - a **v kódu** platí `_isModuleValidNow` (tj. `valid_until` a `trial_ends_at` nejsou v minulosti).  
  Jakmile je **trial_ends_at** (nebo **valid_until**) v minulosti, modul je v UI považován za **neaktivní**, i když v DB záznam s `status = 'active'` zůstává.

---

## Shrnutí příčiny

- **Proč aplikace „ignoruje“ modul, který v databázi existuje:**  
  Protože **neignoruje existenci řádku**, ale **vyřadí ho až v aplikaci** podle data platnosti.

1. **Žádný tvrdý filtr na `status`** – provider nefiltruje podle `status`, takže `trialing` vs `active` není příčina.
2. **Filtr podle času v kódu** – modul se do „aktivních“ dostane jen pokud projde **`_isModuleValidNow(valid_until, trial_ends_at, now)`**. Pokud je **trial_ends_at** (nebo **valid_until**) v minulosti, modul se z výsledku vyhodí a v UI se zobrazí jako zamčený.
3. **Řádek v DB zůstává** – takže při pokusu o znovuaktivaci (INSERT) dojde k porušení UNIQUE (tenant_id, module_id) → 23505 → hláška „Modul je již aktivní.“

**Nejpravděpodobnější scénář:**  
Moduly (Fakturace, Automatizace) byly aktivované se 14denním triálem. Po uplynutí **trial_ends_at** (např. přes noc) je aplikace přestala považovat za aktivní a zobrazuje je jako neaktivní s nabídkou „Aktivovat zkušební verzi“. Při kliknutí INSERT narazí na existující záznam → „Modul je již aktivní.“

**Vedlejší zjištění (RLS):**  
Policy **`tenant_modules_select_own_tenant`** používá `profiles.id = auth.uid()` místo `profiles.auth_id = auth.uid()` a je tedy pro běžné uživatele nefunkční. Čtení pro adminy zajišťuje až **`tenant_modules_select`** s `my_tenant_id()`. Pokud by někdy nebyl vytvořen nebo byl odstraněn, mohlo by dojít k tomu, že admin neuvidí žádné moduly; pro aktuální příznak (modul ráno fungoval, pak ne) je ale hlavní vysvětlení vypršení **trial_ends_at** / **valid_until** a následné vyřazení modulu v kódu provideru.

---

## Doporučený směr opravy (až po odsouhlasení)

- **Krátkodobě:**  
  - Po vypršení trialu modul buď **nepovažovat za „neaktivní“ z hlediska zámku** (např. zobrazovat jako aktivní, ale s bannerem „Trial vypršel – prodlužte“),  
  - nebo při zobrazení „Aktivovat trial“ nejdříve zkontrolovat, zda už řádek v `tenant_modules` existuje (např. SELECT bez filtru na datum), a pokud ano, **nevolat INSERT**, ale např. **UPDATE** (prodloužení trialu) nebo zobrazit jinou hlášku / CTA.
- **Konzistence:**  
  - Jednoznačně definovat, kdy je modul „aktivní“ (zda stačí existující řádek s `deleted_at IS NULL`, nebo zda platnost po vypršení trialu/valid_until má modul skrýt nebo jen „degradovat“).  
  - Případně upravit RLS a opravit **tenant_modules_select_own_tenant** na `auth_id = auth.uid()` pro konzistenci s ostatními politikami.
