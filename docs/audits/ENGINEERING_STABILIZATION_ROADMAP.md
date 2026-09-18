# FalcoNest – Engineering Roadmap: Stabilizace a optimalizace

**Datum:** 2026-07-29  
**Kontext:** TestFlight build je funkčně stabilní (offline sync, LazyIndexedStack, worker flush).  
**Zásada této fáze:** **žádné nové produktové funkce / moduly.** Cíl = 100 % stabilizace, zrychlení, snížení rizika regresí a automatizace release procesu.

**Související dokumenty (nemazat, doplňuje je):**
- `docs/audits/ROADMAP_STABILIZATION.md` – produktový living plán po modulech
- `docs/ai_context/slovnik_modulu.md` / `database_schema.md` – SSOT architektury
- Performance audit (chat 2026-07): IndexedStack, N+1 Realtime, auth cold path
- **`docs/ops/` (2026-09)** – provozní runbooky po security/perf auditu P0–P2 (deploy, Edge, cron, Storage, RLS)

---

## Jak číst priority

| Priorita | Význam | Orientační horizont |
|----------|--------|---------------------|
| **P0 – Kritické / rychlé výhry** | Vysoký dopad, nízké riziko, řeší bolest teď | 1–2 týdny |
| **P1 – Stabilita produkce** | Regrese, observabilita, CI release | 2–4 týdny |
| **P2 – Dluh a výkon** | Refaktory, over-fetch, struktura | 1–2 měsíce |
| **P3 – Polish a dlouhodobé** | UX konzistence, hloubkové testy | průběžně |

U každé položky: **Proč** → **Konkrétní postup** → **Hotovo když**.

---

## P0 – Kritické a rychlé výhry

### P0.1 Dokončit výkonovou vlnu po LazyIndexedStack (bez nových feature)

**Proč:** LazyIndexedStack už brzdí cold start, ale admin stále drží **více Realtime streamů** na `tasks` / `reservations` a široké `select()` – největší zbývající brzda po loginu na Dashboard.

**Postup:**
1. Inventura aktivních stream providerů při tab 0 (Dashboard): `adminDashboardTasksProvider`, `apartmentStatusContextReservationsProvider`, `todayApartmentTasksProvider`, `apartmentsFullListProvider`, `teamFullListProvider`.
2. Sloučit duplicitní Realtime kanály na **jeden canonical stream** + odvozené `Provider.select` / map (bez změny UI kontraktů).
3. V `AdminTasksRepository` / `AdminReservationsRepository` nahradit holé `.select()` za explicitní sloupce pro list/Kanban; JSONB (`metadata`, `media_urls`) lazy v detailu.
4. Zavést `apartmentsLiteProvider` / `teamLiteProvider` (`id`, `name`, …) pro enrich streamů; plný list jen v editorech.
5. Auth cold path: `last_sign_in_at` fire-and-forget; zvážit zkrácení/odstranění pevného 350 ms delay, pokud RLS race už není problém.

**Hotovo když:** Po loginu admina DevTools / Network ukáže výrazně méně paralelních WebSocket/HTTP; Dashboard TTFP subjektivně rychlejší bez změny UX.

---

### P0.2 Napojit `AppLogger` na Crashlytics (nebo Sentry)

**Proč:** `AppLogger` dnes jen `debugPrint` – v release na TestFlight **nevidíte** crash ani soft-fail sync. Firebase Core už v projektu je (`firebase_core`, FCM).

**Postup:**
1. Přidat `firebase_crashlytics` (preferováno – stack už má Firebase) *nebo* Sentry, pokud chcete i web.
2. V `AppLogger.error` / volitelně `FlutterError.onError` + `PlatformDispatcher.instance.onError` forwardovat do Crashlytics.
3. V `main.dart` po `Firebase.initializeApp` zapnout collection; v debug nechat jen console.
4. Ověřit: záměrný test crash + soft `AppLogger.error` v TestFlight → viditelné v konzoli Firebase.
5. Doplnit kontext: `tenant_id`, `profile_id`, `role` jako custom keys (bez PII v message).

**Hotovo když:** Každý `AppLogger.error` a uncaught Flutter error dorazí do Crashlytics s tenant kontextem.

---

### P0.3 Automatický bump build number + checklist TestFlight (dočasná poloviční automatizace)

**Proč:** Plný Fastlane/CI trvá déle; mezitím snižuje lidské chyby u verzí.

**Postup:**
1. Skript `tool/bump_ios_build.sh` (nebo Melos): inkrement `CFBundleVersion` / `pubspec.yaml` `+build`.
2. Dokumentovaný checklist v `docs/checklists/testflight_release.md`: flutter clean → build ipa → upload → whatsnew.
3. GitHub Action **zatím** jen: analyze + test + artefakt `build/web` (volitelně) – bez secrets Apple.

**Hotovo když:** Každý TF upload má unikátní build a checklist bez zapomenutého bump.

---

### P0.4 Unit testy: Smart Merge + mutation queue (minimální síť)

**Proč:** Offline sync je kritická business logika; v `test/` jsou prakticky jen 2 smoke testy. Regrese = „úkol hotový u workera, admin nevidí“.

**Postup:**
1. Extrahovat čisté funkce ze `WorkerSyncService` (merge notes, merge metadata, detekce konfliktu `updated_at`) do `lib/features/worker/utils/worker_sync_merge.dart` (aditivně).
2. Unit testy: lokální completed vs server in_progress; append poznámek; timeout flush nechá pending.
3. Testy `DriftMutationQueueService` s in-memory / mock repo: enqueue → process success → delete; retryable error → keep.
4. CI už běží `flutter test` – stačí přidat soubory.

**Hotovo když:** `flutter test` pokrývá merge pravidla + alespoň 3 scénáře fronty; PR bez zelených testů nejde na main.

---

## P1 – Stabilita produkce a CI/CD

### P1.1 Plná automatizace TestFlight (Fastlane + GitHub Actions)

**Proč:** Ruční Xcode/certifikáty = čas a riziko; po P0.3 přejít na „push tag → TF“.

**Postup:**
1. **Fastlane** v `ios/fastlane/`:
   - `match` (App Store Connect API key + git repo certs) *nebo* `app_store_connect_api_key` + automatic signing.
   - Lane `beta`: `flutter build ipa` → `upload_to_testflight`.
2. Secrets v GitHub: `APP_STORE_CONNECT_API_KEY` (p8), `KEY_ID`, `ISSUER_ID`, `MATCH_PASSWORD` (pokud match), provisioning.
3. Workflow `.github/workflows/ios_testflight.yml`:
   - trigger: `workflow_dispatch` + tag `v*`;
   - macOS runner; Flutter + Ruby/Fastlane;
   - cache CocoaPods;
   - upload bez manuálního Xcode.
4. Android později (Play internal) – stejný pattern, až po iOS.

**Hotovo když:** `gh workflow run` / tag vytvoří nový build na TestFlight bez lokálního Xcode uploadu.

---

### P1.2 Zpřísnit CI (`flutter_check.yml`)

**Proč:** Dnes `--no-fatal-infos --no-fatal-warnings` – warningy se tiše hromadí.

**Postup:**
1. Fáze A: nechat analyze, ale reportovat počet warningů jako artifact.
2. Fáze B: `--fatal-warnings` na kritických paths (`lib/core/offline`, `lib/features/worker/data`).
3. Přidat `dart format --set-exit-if-changed .` (nebo scoped).
4. Volitelně: custom skript „zakázané `Supabase.instance.client.from(` mimo allowlist“ (tenant safety).

**Hotovo když:** Main branch neakceptuje nový kód s analyze warnings v offline/worker vrstvě.

---

### P1.3 Observabilita offline stavů (UX + metrika)

**Proč:** Sync banner a mutation queue screen existují; chybí konzistence napříč flow a telemetrie „kolik pending zůstalo po flush“.

**Postup:**
1. Audit všech míst, kde se mění `syncStatus` / enqueue – jednotný SnackBar / banner klíč (`worker.sync_*`).
2. Po `flushPendingUpdatesBestEffort` (timeout): pokud pending > 0, jasná zpráva „uloženo lokálně, odešle se později“ (i18n).
3. Do Crashlytics/log: `pending_count` při lifecycle flush.
4. Manuální QA checklist: offline complete → airplane → online → admin vidí stav do X s.

**Hotovo když:** Worker nikdy nevidí „ticho“ při pending; QA checklist je v `docs/checklists/`.

---

### P1.4 Auth a startovací sekvence – zpevnění

**Proč:** Sekvenční `main()` + `/auth-loading` + tenant colors sync zpomalují first paint.

**Postup:**
1. Paralelizovat neblokující init (Firebase vs dotenv kde možné); `runApp` dříve s loading shell.
2. `tenantColorsProvider`: theme z Drift okamžitě, `syncFromServer` na pozadí.
3. Sjednotit trojité čtení `tenants` (AuthNotifier + name + announcement + realtime) do jednoho detail provideru.

**Hotovo když:** Time-to-interactive po cold startu změřený (stopky / DevTools) a dokumentovaný baseline → target.

---

## P2 – Architektura, refaktoring, výkon

### P2.1 Rozřezat gigantické soubory (technický dluh #1)

**Proč (měření 2026-07):**
| Soubor | ~řádků | Riziko |
|--------|--------|--------|
| `admin_tasks_screen.dart` | ~4940 | Logika + dialogy + Kanban v UI |
| `admin_tasks_provider.dart` | ~3058 | Mix streamů, generátoru, mutací |
| `admin_layout.dart` | ~1290 | Navigace + omnibox + bannery |

**Postup (aditivní, bez změny chování):**
1. `admin_tasks_screen`: vyjmout dialogy vytvoření/editace do `widgets/task_*_dialog.dart`; Kanban sloupce do vlastních widgetů.
2. `admin_tasks_provider`: oddělit `admin_tasks_stream_provider.dart`, `admin_tasks_actions_notifier.dart`, generator zůstane (pozor: **`task_assignment_engine.dart` je LOCKED** – netýkat se).
3. Každý výřez: smoke test otevření obrazovky + 1 mutace.

**Hotovo když:** Žádný UI screen > ~1500 řádků; reviewable PR < 400 řádků diffu na výřez.

---

### P2.2 Riverpod lifecycle – konzistence keepAlive vs autoDispose

**Proč:** Core streamy správně bez autoDispose (IndexedStack/Lazy); detail family často autoDispose (OK). Riziko: zbytečné `invalidate(adminTasksStreamProvider)` → re-subscribe.

**Postup:**
1. Grep `invalidate(adminTasksStreamProvider)` – nahradit lokálním patch / Realtime, invalidate jen hard refresh.
2. Dokumentovat v `slovnik_modulu.md` tabulku: provider → keepAlive/autoDispose → důvod.
3. Owner portal: ověřit, že LazyIndexedStack + `FutureProvider` bez autoDispose neleakují po odhlášení (`ref.onDispose` / invalidate na logout).

**Hotovo když:** Přepínání tabů neobnovuje Realtime subscription; logout čistí tenant-scoped cache.

---

### P2.3 Supabase over-fetch a limity

**Proč:** `apartmentsFullListProvider` limit 5000, task stream safety 15 000, reservations 500/8000 – škálování agentury = OOM / pomalý parse.

**Postup:**
1. List select column pruning (viz P0.1).
2. Server-side okno místo client filter u Realtime (view / RPC), kde SDK dovolí.
3. Pagination UI tam, kde už existuje (`apartmentsProvider`) – nepřepínat full list bez důvodu.
4. Benchmark: tenant s N byty / M úkoly – dokumentovat max doporučené N.

**Hotovo když:** Payload list endpointů zmenšený o měřitelná %; žádný tichý ořez dat bez UI varování (už máte limitReached flagy – rozšířit).

---

### P2.4 Media upload – sjednotit kompresi

**Proč:** `MediaService` komprimuje přes ImagePicker; `PhotoService` má `flutter_image_compress`. Worker task fotky – ověřit, že všechny cesty procházejí stejnou max velikostí.

**Postup:**
1. Inventura všech upload path (checklist photo, task complete, expense receipt, signature).
2. Jedna politika: max hraná 1200px, quality ~60, JPEG; jednotný helper.
3. Test: 12MP foto → upload < ~300 KB typicky.

**Hotovo když:** Žádný upload raw HEIC/full-res mimo výjimku (podpis PNG).

---

### P2.5 Web vs mobil parity (bez nových modulů)

**Proč:** Mutation queue na webu fail-fast; admin je online-first. Riziko „tiché“ rozdílné chování.

**Postup:**
1. Matice: akce × web × mobil × offline – doplnit do `docs/checklists/platform_parity.md`.
2. Sjednotit empty/error copy (i18n) tam, kde platforma akci nepodporuje.
3. LazyIndexedStack na webu – regresní checklist (už opraven Positioned.fill).

**Hotovo když:** QA má 1 stránku „co funguje offline na webu vs mobilu“.

---

## P3 – UX/UI polish a dlouhodobé

### P3.1 Design system konzistence (existující obrazovky)

**Proč:** Audit `ui_consistency_audit.md` – stovky `Colors.*`, `fontSize` mimo `textTheme`; `AppSpacing` / tenant colors už částečně existují.

**Postup (pouze polish, žádné nové obrazovky):**
1. Worker dashboard + detail: nahradit hardcoded `_primaryBlue` / `Colors.red` za `colorScheme` / `theme_ext`.
2. Admin snackbary: `colorScheme.error` / success token.
3. Padding: preferovat `AppSpacing.*` při každém touchnutí souboru (boy scout).
4. Empty states: sjednotit na `AppEmptyState` kde chybí.
5. Mikro-animace: `AnimatedSwitcher` při přepnutí LazyIndexedStack tabu (fade 150 ms) – volitelné, low risk.

**Hotovo když:** Dotčené obrazovky bez nových hardcoded barev; checklist z `ui_consistency_audit` odškrtnutý po modulech.

---

### P3.2 i18n hygienická vlna

**Proč:** cs/en/es; riziko chybějících klíčů u novějších worker stringů (`overdue`, `syncing_completion`).

**Postup:**
1. Skript porovnání klíčů cs ↔ en ↔ es (CI job fail při missing).
2. Projít `debugPrint` / hardcoded UI stringy v `lib/features/worker` a `admin` (grep `Text\('`).
3. ES kvalita – spot check kritických worker flow.

**Hotovo když:** CI failne na chybějící překladový klíč.

---

### P3.3 Dokumentace a vývojový proces

**Proč:** 90+ MD v `docs/` – těžké najít „co platí teď“.

**Postup:**
1. `docs/audits/README.md` – index: living vs archive; odkaz na tento roadmap.
2. PR template: checklist Drift parity, i18n, `safeFrom`, testy sync pokud se týká offline.
3. Po každém milníku aktualizovat tento soubor (checkboxy níže).

**Hotovo když:** Nový contributor najde za 5 minut „jak releasnout“ a „co netahat“.

---

### P3.4 Integration / golden testy (dlouhodobě)

**Proč:** Unit pokryje merge; E2E sync vyžaduje více setupu.

**Postup:**
1. Po unit suite: 1–2 integration testy s fake Supabase HTTP (mock).
2. Volitelně Patrol/integration_test na „login → worker dashboard → complete“.
3. Nesnažit se o 80 % coverage – cílit **kritické cesty**.

---

### P3.5 Integrace Verifacti (Veri\*Factu / AEAT) – naplánováno

**Proč:** Španělská povinnost Veri\*Factu – FalcoNest má vystavovat / podklady k fakturaci v souladu s AEAT. Místo přímé integrace na AEAT použijeme API **Verifacti** (cloud middleware: JSON → QR + XML registr → odeslání AEAT).

**API (výchozí reference):**
- Dokumentace / ceny + OpenAPI: [verifacti.com/precios](https://www.verifacti.com/precios#/paths/~1verifactu~1declaracion/get)
- Endpoint **`GET /verifactu/declaracion`** – získání **declaración responsable** (odpovědnostní prohlášení producenta SIF / komponenty) – nutný podklad pro compliance a zobrazení v produktu.
- Širší scope později: odesílání faktur (registro), stav registru, webhooks AEAT, správa NIF emisora (tenant / agentura).

**Byznysový kontext:** Cena Verifacti je primárně dle počtu aktivních **NIF** v produkci (typicky 1 NIF = 1 agentura / emitent, pokud fakturujeme „za sebe“; u multi-tenant SaaS = NIF každé agentury, která přes FalcoNest vydává daňové faktury).

**Postup (až po stabilizaci P0–P2):**
1. Účet Verifacti (test NIF zdarma) + Edge Function proxy (API key jen server-side, nikdy ve Flutter).
2. Napojit `GET /verifactu/declaracion` – uložit / zobrazit declaración (admin nastavení / legal stránka).
3. Mapovat FalcoNest billing / invoices → payload Verifactu; QR na PDF podkladech.
4. Webhook / poll stavu AEAT; audit trail v tenant scope (`tenant_id`).
5. RLS + secrets: klíče per tenant NIF v Supabase Vault / Edge secrets.

**Hotovo když:** Tenant s produkčním NIF odešle testovací fakturu přes Verifacti a declaración je dohledatelná v aplikaci.

**Stav:** 📋 backlog (2026-09-13) – ještě neimplementováno.

---

## Doporučené pořadí sprintů (návrh)

```text
Sprint 1 (P0):  Crashlytics + sync unit testy + TF bump checklist
                + start Realtime/select pruning (Dashboard path)

Sprint 2 (P1):  Fastlane TF workflow + CI fatal warnings (scoped)
                + auth/theme cold start + offline UX copy

Sprint 3 (P2):  Split admin_tasks_screen / provider
                + lite apartments/team + media policy unify

Sprint 4 (P3):  Theme/spacing polish worker+admin hotspots
                + i18n key CI + docs index
```

---

## Checklist milníků (odškrtávat)

- [ ] P0.1 Výkon: column pick + méně Realtime kanálů
- [ ] P0.2 Crashlytics / Sentry napojené na `AppLogger`
- [ ] P0.3 TF build bump + release checklist
- [ ] P0.4 Unit testy merge + mutation queue
- [ ] P1.1 GitHub Actions → TestFlight
- [ ] P1.2 Přísnější CI analyze/format
- [ ] P1.3 Offline komunikace + telemetrie pending
- [ ] P1.4 Rychlejší start / auth
- [ ] P2.1 Rozřezání `admin_tasks_*`
- [ ] P2.2 Invalidate / lifecycle audit
- [ ] P2.3 Over-fetch limity
- [ ] P2.4 Jednotná komprese médií
- [ ] P2.5 Platform parity checklist
- [ ] P3.1 UI polish (theme/spacing)
- [ ] P3.2 i18n CI
- [ ] P3.3 Docs index + PR template
- [ ] P3.4 Integration test kritické cesty
- [ ] P3.5 Verifacti / Veri\*Factu API (`GET /verifactu/declaracion` + fakturační tok)

---

## Explicitně mimo scope této fáze

- Nové moduly, nové role, nové billing produkty (výjimka backlogu: **P3.5 Verifacti** – plánováno po stabilizaci)  
- Refaktor / změny v **`task_assignment_engine.dart`** (LOCKED)  
- Přepis admina na plný Drift offline (obří projekt – jen pokud P2.5 ukáže kritickou potřebu)  
- Nativní background upload framework (Workmanager) – až když P0/P1 flush nestačí v produkčních metrikách  

---

## Baseline „hotovo fáze stabilizace“

1. Crashlytics živé, 0 neznámých crashů bez issue.  
2. TestFlight upload z CI.  
3. Unit testy chrání sync merge + frontu.  
4. Admin cold start výrazně lehčí (měřeno).  
5. Žádný nový warning v offline/worker CI gate.  
6. i18n klíče synchronní cs/en/es v CI.

*Dokument aktualizujte při dokončení milníku; produktový plán modulů zůstává v `ROADMAP_STABILIZATION.md`.*
