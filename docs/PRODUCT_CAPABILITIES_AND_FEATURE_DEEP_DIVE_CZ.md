# FalcoNest – Hloubková analýza produktových schopností a funkcí

**Dokument pro prezentaci profesionálním agenturám správy nemovitostí**

*Generováno na základě hloubkové auditní analýzy codebase. Žádný marketing – pouze technický popis založený na skutečné implementaci.*

---

## 1. Pokročilé CRM a typy klientů

### 1.1 Tři typy klientů (owner, external, agency)

**Jak to funguje v systému:**  
Tabulka `clients` obsahuje sloupec `client_type` s hodnotami `owner`, `external`, `agency`. Každý klient má `tenant_id` (multi-tenant izolace), `name`, `email`, `phone` a volitelný `profile_id` – propojení s přihlašovacím profilem (Klientský portál majitelů). V UI (`admin_clients_screen.dart`) se klienti zobrazují v mřížce s barevnými badges: teal pro majitele, modrá pro externí, fialová pro agentury. U majitele bez `profile_id` se zobrazuje oranžová ikona „Čeká na aktivaci“ – majitel ještě nevyužil odkaz na portál.

**Proč to klient (agentura) miluje:**  
Jeden CRM pohled pro všechny typy zákazníků: majitele bytů (fakturace, portál), externí klienty (jen transfer, bez apartmánu) a partnerské agentury s vlastními adresami. Vše na jednom místě, s vyhledáváním podle jména, emailu a telefonu.

---

### 1.2 Majitel s profile_id a Klientský portál

**Jak to funguje v systému:**  
Klient typu `owner` s vyplněným `profile_id` je propojen s uživatelským účtem v `profiles`. V seznamu klientů (`_CompactOwnerMeta`) se načítá `clientPortalStatusProvider` – stav portálu (pending/active). U aktivních majitelů se zobrazuje počet apartmánů (`ownerApartmentCountsProvider`). Majitelé se záznamem v `apartment_owners` vidí své byty v Klientské zóně (`/owner`).

**Proč to klient (agentura) miluje:**  
Majitel se může přihlásit do portálu a spravovat rezervace, sledovat stav úklidu a stahovat vyúčtování. Agentura vidí, kdo je připojen a kolik bytů má – bez ručního dotazování.

---

### 1.3 Externí klienti a fakturace bez bytu

**Jak to funguje v systému:**  
Klient typu `external` nemusí mít žádný apartmán. Úkoly (`tasks`) mohou mít `apartment_id = NULL` a `client_id` odkazující na klienta v CRM. Sloupec `custom_location` a `custom_title` (např. „Transfer letiště“) doplňují kontext. V modulu fakturace (`billing_action_service.dart`) se skupina `external` zpracovává zvlášť – může mít vlastní display name pro PDF.

**Proč to klient (agentura) miluje:**  
Agentura může fakturovat čistě transferové služby (vyzvednutí na letišti, odvoz) i lidem bez apartmánu. Jednotná evidence v CRM a úkoly v Plachtě.

---

### 1.4 Partnerské agentury a adresář adres

**Jak to funguje v systému:**  
Tabulka `client_addresses` (FK `client_id` → `clients`) umožňuje každému klientovi (zejména typu `agency`) mít více adres. Každá adresa má `label` (např. „Apartmán u moře“, „Kancelář v centru“) a `address` – plná adresa pro řidiče. V Detailu klienta (`ClientDetailDialog`) je záložka Apartmány; u agentur se využívá adresář pro transfery. Model `ClientAddressModel` parsuje data z DB.

**Proč to klient (agentura) miluje:**  
Partnerská agentura může mít více objektů na různých adresách. Řidič má v úkolu přesnou lokaci pro vyzvednutí/odvoz, bez hledání v poznámkách.

---

## 2. Konfigurovatelnost služeb

### 2.1 Tříúrovňový model (Katalog → Byt → Rezervace)

**Jak to funguje v systému:**  
Služby jsou definovány na třech úrovních (viz `database_schema.md`):

1. **tenant_services** – katalog agentury: `name`, `service_type` (cleaning, transfer_in, check_in …), `default_price`, `duration_minutes`, `required_role`, `requires_photo`.
2. **apartment_services** – přiřazení služby k bytu: `custom_price`, `custom_description`, `trigger_type`, `schedule_interval`, `is_mandatory`, `payer_type` (owner/guest), `requires_photo` override.
3. **reservation_services** – výběr pro konkrétní pobyt: `charged_price`, `custom_note`, `flight_number`, `payer_type` override.

Cena se bere v pořadí: `reservation_services.charged_price` → `apartment_services.custom_price` → `tenant_services.default_price`. Plátce stejným způsobem. `apartment_services_repository.dart` ukládá záznamy s `trigger_type`, `is_mandatory`, `payer_type`.

**Proč to klient (agentura) miluje:**  
Flexibilita bez chaosu: základní ceník v katalogu, přepisy pro konkrétní byt (jiná cena úklidu, jiný plátce) a finální přepis u konkrétní rezervace.

---

### 2.2 Typy spouštěčů (trigger_type)

**Jak to funguje v systému:**  
Sloupec `apartment_services.trigger_type` má CHECK constraint: `on_demand`, `before_checkin`, `after_checkout`, `both_ways`, `scheduled`. Pro `scheduled` se používá `schedule_interval` (1_week, 2_weeks, 1_month …). Tyto hodnoty řídí Task Automator – kdy se úkol vytvoří: před check-inem hosta, po odjezdu, obousměrný transfer, nebo pravidelně v intervalu. Model `ApartmentServiceRow` validuje povolené hodnoty.

**Proč to klient (agentura) miluje:**  
Byt může mít „Úklid vždy po odjezdu“ vs. „Transfer jen na vyžádání“. Pravidelná údržba (1x za 2 týdny) bez ručního zakládání úkolů.

---

### 2.3 Povinné služby a plátce

**Jak to funguje v systému:**  
`is_mandatory = true` znamená, že službu nelze v rezervaci odškrtnout – checkbox je zamčený. `payer_type`: `owner` = majitel platí (faktura), `guest` = host platí na místě. Na úrovni rezervace lze `payer_type` přepsat v `reservation_services`. V `owner_reservations_screen.dart` majitel volí plátce u každé služby v rezervaci.

**Proč to klient (agentura) miluje:**  
Standardní úklid může být vždy povinný, transfer volitelný. Jasná fakturace: co jde majiteli, co se vybírá od hosta.

---

### 2.4 Konfigurace služeb v dialogu bytu

**Jak to funguje v systému:**  
V `admin_apartments_screen.dart` se v dialogu editace bytu načítá `apartmentServicesOptionsProvider` (resp. data z `apartment_services_repository.fetchByApartmentId`). Tab „Služby a požadavky“ obsahuje seznam služeb z katalogu s checkboxy (enabled/disabled), přepisy cen, trigger_type, plátce. `saveForApartment` v `apartment_services_repository.dart` maže staré záznamy a vkládá nové.

**Proč to klient (agentura) miluje:**  
Konfigurace služeb přímo u bytu – nepotřebuje přepínat mezi různými obrazovkami.

---

## 3. Zatížení personálu a automatické přiřazení

### 3.1 Load Balancing engine (task_assignment_engine.dart)

**Jak to funguje v systému:**  
Funkce `pickAssigneeWithCollisionAvoidance` bere kandidáty (personál), časové okno úkolu (`taskStart`, `taskEnd`), `deadline` a seznam existujících úkolů. Kontroluje překryvy: `(novýStart < stávajícíKonec) && (novýKonec > stávajícíStart)` → kandidát vyřazen. Ze volných kandidátů vybírá podle tří pravidel:

1. **Ochrana před přetížením:** Denní limit max +2 úkoly nad minimem, týdenní max +3.
2. **Zónová priorita:** `zone_preferences` v profiles (1 = nejraději, 2–5 = dojedu).
3. **Spravedlnost v daný den:** Kdo má méně úkolů, dostane přednost.

Pro flexibilní úkoly (úklid) hledá volný slot po 30min krocích až do deadline; pro „svaté“ úkoly (check-in, transfer) se čas neposouvá.

**Proč to klient (agentura) miluje:**  
Žádný jeden člověk nedostává přemíru úkolů. Místní řidič má přednost před těmi „z druhého konce města“.

---

### 3.2 Pracovní doba a noční klid

**Jak to funguje v systému:**  
Parametr `applyNightRest = true` omezuje úkoly na 07:00–19:00. Pokud by úklid začínal před 7:00, začátek se posune na 7:00. Pokud by přesáhl 19:00, začátek jde na 7:00 následujícího dne. Iterace končí, pokud by posunutý úkol překročil `deadline`.

**Proč to klient (agentura) miluje:**  
Personál nedostává úkoly uprostřed noci a respektuje běžnou pracovní dobu.

---

### 3.3 Nepřítomnosti a vyloučení kandidátů

**Jak to funguje v systému:**  
Před voláním engine se načte `staffAbsencesProvider` (tabulka `staff_absences`). Kandidáti s nepřítomností v daném datu se z `candidates` odeberou. Worker i Admin může přidávat absenci přes `AddAbsenceDialog` / `staff_absences` insert.

**Proč to klient (agentura) miluje:**  
Engine neassignuje úkoly lidem na dovolené nebo nemocné.

---

### 3.4 Přepočet personálu (Recalculate Staff)

**Jak to funguje v systému:**  
V `admin_tasks_screen.dart` tlačítko „Přepočítat personál“ volá `_runRecalculateAssignees`. `AdminTasksNotifier.recalculateAssignees` načte úkoly (batch limit), pro každý znovu spustí engine s aktuálními úkoly a absencí. Výsledky se zobrazí v dialogu s checkboxy – dispečer vybere, které změny potvrdit. Pouze vybrané se zapíší do DB.

**Proč to klient (agentura) miluje:**  
Po změně absencí nebo ruční úpravě plánu lze jedním kliknutím znovu rozložit úkoly spravedlivě.

---

### 3.5 Indikátor zatížení v Personálu

**Jak to funguje v systému:**  
V `admin_team_screen.dart` u každého člena týmu (`_TeamDetailRow`) se zobrazuje `admin.team_workload` s `weeklyHours` z profilu. `_buildWorkloadIndicator` (statická metoda) bere úkoly přiřazené členovi a vizualizuje vytížení – např. počet úkolů v daném období. U člena se také zobrazuje, zda má nastavené `zone_preferences`.

**Proč to klient (agentura) miluje:**  
Na první pohled vidí, kdo je přetížen a kdo má kapacitu – bez ručního počítání.

---

## 4. Pokročilý portál majitele

### 4.1 Přidání vlastní rezervace

**Jak to funguje v systému:**  
Na obrazovce Rezervace (`owner_reservations_screen.dart`) je FAB „Nová rezervace“. Otevře se `_NewReservationForm` – dialog s výběrem apartmánu, datem od/do, jménem hosta, telefonem, časy příjezdu/odjezdu, počtem hostů, speciálními požadavky. Služby bytu se načtou z `ownerApartmentServicesOptionsProvider(apartmentId)` – majitel může zapnout/vypnout služby a nastavit plátce. Při ukládání (`_saveReservation`) se kontroluje expres úklid (< 24 h): zobrazí se varování, uživatel může potvrdit nebo zrušit.

**Proč to klient (agentura) miluje:**  
Majitel může sám přidat přímou rezervaci (např. od známého) – agentura nemusí vše zadávat ručně.

---

### 4.2 Editace pouze ve stavu „new“

**Jak to funguje v systému:**  
V Kanban kartě (`_OwnerKanbanCard`) se `canEdit` nastavuje na `reservation.status == 'new'`. Po předání agentuře (`confirmed`) majitel již nemůže editovat – karta zobrazuje „Spravuje agentura“. Životní cyklus: `new` → `confirmed` → `checked_in` → `checked_out` / `cancelled`.

**Proč to klient (agentura) miluje:**  
Po potvrzení nemůže majitel měnit data, která agentura již plánuje – žádné konflikty.

---

### 4.3 Potvrzení a předání agentuře (Confirm and Hand Over)

**Jak to funguje v systému:**  
V `_NewReservationForm` jsou dvě tlačítka: „Uložit“ a „Potvrdit a předat“. Při `confirmAndHandOver = true` se do update payload přidá `status: 'confirmed'`. Rezervace přechází ze sloupce „Nové“ do „Potvrzené“ v Kanbanu. Agentura ji vidí v Plachtě a může generovat úkoly.

**Proč to klient (agentura) miluje:**  
Majitel explicitně předává rezervaci – agentura má jasný signál „teď se o to postarejte“.

---

### 4.4 Kanban rezervací

**Jak to funguje v systému:**  
`_OwnerReservationsKanbanBoard` má čtyři sloupce: Nové (`new`), Potvrzené (`confirmed`), Checked-in (`checked_in`), Checked-out / Zrušené (`checked_out`, `cancelled`). Data z `ownerReservationsProvider` – Supabase dotaz s JOIN na `apartments(name)`. RLS zajistí, že majitel vidí pouze rezervace u bytů z `apartment_owners`.

**Proč to klient (agentura) miluje:**  
Přehledný vizuální stav všech rezervací – bez nutnosti scrollovat v tabulce.

---

### 4.5 Vyúčtování majitele (billing_snapshots)

**Jak to funguje v systému:**  
Admin uzamkne měsíc v modulu Finance – vytvoří se záznam v `billing_snapshots` s `snapshot_data` (JSONB: úkoly, ceny, náklady, totaly). Majitel v Klientské zóně (`owner_billing_screen.dart`) načte `ownerBillingSnapshotsProvider` – RLS umožňuje jen snapshoty, kde `client_id` odpovídá majiteli (přes `clients.profile_id`). U každého měsíce může stáhnout PDF on-demand pomocí `BillingPdfService.generateAndDownloadPdf`.

**Proč to klient (agentura) miluje:**  
Majitel má kdykoliv přístup k vyúčtování bez nutnosti žádat agenturu o PDF.

---

### 4.6 Plánovací kalendář a stav bytů

**Jak to funguje v systému:**  
`owner_planning_calendar_screen.dart` zobrazuje úkoly majitele podle týdne. `ownerApartmentsProvider` počítá stav bytu z posledního úkolu: `completed` → Čistý, `in_progress` → Probíhá úklid, `pending` → Čeká. Na kartách bytů (`owner_apartments_screen.dart`) se zobrazuje teploměr obsazenosti (dny v měsíci) a nejbližší rezervace.

**Proč to klient (agentura) miluje:**  
Majitel vidí aktuální stav úklidu a obsazenost – nemusí volat agenturu.

---

## 5. Automatizovaná komunikace s hosty

### 5.1 Šablony zpráv (tenant_message_templates)

**Jak to funguje v systému:**  
Tabulka `tenant_message_templates` má: `key` (systémový identifikátor), `name` (lidský název), `body` (text s placeholdery), `channel` (whatsapp_link, sms, email), `language_code`, `trigger_context` (transfer, check_in, check_out). V `communication_templates_screen.dart` agentura vytváří a edituje šablony. `TemplateEditorDialog` umožňuje psát text s placeholdery z `TemplatePlaceholderService.supportedPlaceholders`.

**Proč to klient (agentura) miluje:**  
Jednotné zprávy pro všechny řidiče – žádné překlepy a zapomenuté údaje.

---

### 5.2 Placeholdery v šablonách

**Jak to funguje v systému:**  
`TemplatePlaceholderService` podporuje: `{guest_name}`, `{guest_phone}`, `{flight_number}`, `{address}`, `{keybox}`, `{reference_number}`, `{apartment_name}`, `{owner_notes}`. Metoda `buildContextFromTask` sestaví mapu z `WorkerTaskDetail` a volitelných kontextů (rezervace, byt). `replacePlaceholders` nahradí v textu všechny výskyty. Telefon se hledá v pořadí: `taskDetail.guestPhone` → `clientPhone` → `reservation.guestPhone` → parsování z poznámky (regex `+\d...`).

**Proč to klient (agentura) miluje:**  
Řidič stiskne šablonu a získá hotovou zprávu s jménem hosta, adresou, schránkou na klíče – připravenou na odeslání WhatsApp.

---

### 5.3 Připomenutí šablon (template-reminders) – Edge Function

**Jak to funguje v systému:**  
Edge Function `template-reminders` běží 4× denně (pg_cron: 7:00, 11:00, 15:00, 19:00 Madrid). Pro každý transfer úkol (status=assigned, task_type IN transfer_in/transfer_out/transfer) vyhodnotí časové události: T1 = -48 h, T2 = -24 h, T3 = -1 h před `scheduled_start`. Pokud událost spadá do aktuálního časového okna (směna 4 h), odešle FCM push notifikaci na zařízení přiřazeného řidiče. Tělo notifikace např.: „Let v 14:30 (za 2 dny). Pošlete 1. šablonu (48h).“ Řidič si může připomínky vypnout v `notification_preferences.template_reminders_enabled`.

**Proč to klient (agentura) miluje:**  
Řidič dostane včas připomínku „pošlete zprávu hostovi“ – žádné zapomenuté kontakty před příjezdem.

---

## 6. Podpora platformy a Audit Log (výhoda FalcoNest)

### 6.1 Super Admin a převtělení (impersonace)

**Jak to funguje v systému:**  
Super Admin má v `profiles` roli `super_admin` a `tenant_id = NULL`. `AuthNotifier.impersonateTenant(tenantId)` uloží vybrané `tenantId` do paměti (`_selectedTenantId`). Všechny datové dotazy pak používají `tenantIdForData` – pro Super Admina v režimu převtělení je to vybraná agentura. Do DB se nic nezapisuje. `stopImpersonating()` vymaže výběr. V `super_admin_dashboard.dart` je na kartě agentury tlačítko „Přihlásit se jako“ – po kliknutí `impersonateTenant` a `context.go('/admin')`.

**Proč to klient (agentura) miluje:**  
Podpora FalcoNest se může přihlásit jako agentura a vidět přesně to, co vidí dispečer – diagnostika problému v reálném čase bez screen sharu.

---

### 6.2 Audit Log – sledování všech akcí

**Jak to funguje v systému:**  
Tabulka `audit_logs` má: `tenant_id`, `user_id`, `action_type`, `table_name`, `record_id`, `details` (JSONB), `created_at`. `AuditLogService.logEnterprise` zapisuje při každé mutační akci. `details` obsahuje: `record_name`, `actor_snapshot` (jméno, email v době akce), `previous_state`, `new_state`, `client_info` (Web/iOS/Android), `triggered_by` (manual/cascade/system), `reason`. Typy akcí: `SOFT_DELETE`, `SOFT_DELETE_CASCADE`. `AuditLogRepository.restore` obnoví záznam (`deleted_at = null`); `hardDelete` fyzicky smaže.

**Proč to klient (agentura) miluje:**  
Kompletní historie změn – kdo, kdy a co udělal. Možnost obnovit omylem smazaný byt nebo rezervaci.

---

### 6.3 Filtrování a zobrazení Audit Logu

**Jak to funguje v systému:**  
`AuditLogModal` v `audit_log_screen.dart` zobrazuje seznam záznamů s filtrem podle tenanta. Každý řádek obsahuje: ikonu entity, nadpis (např. název smazaného záznamu), metadata (čas, agentura, kdo akci provedl, zařízení), tlačítka Obnovit / Trvale smazat. `EnterpriseAuditPayload.getRecordName`, `getActorNameFromSnapshot`, `getPreviousState`, `getNewState` parsují `details`. Pro změny s předchozím/novým stavem lze otevřít sub-dialog s diffem.

**Proč to klient (agentura) miluje:**  
Super Admin nebo Admin může rychle najít konkrétní akci a v případě potřeby obnovit data.

---

### 6.4 Kaskádové mazání a reason

**Jak to funguje v systému:**  
Při smazání apartmánu (`admin_apartments_screen.dart`, `_doDelete`) se kaskádově soft-delete provedou všechny rezervace a úkoly tohoto bytu. Každá akce se zapíše s `triggered_by: cascade` a `reason` z i18n (např. „Apartmán byl smazán“). V Audit Logu je vidět, že šlo o kaskádu, ne o přímou akci uživatele.

**Proč to klient (agentura) miluje:**  
Jasné rozlišení mezi úmyslným mazáním a důsledkem jiné akce – důležité pro debugging a compliance.

---

## 7. Další důležité moduly (stručný přehled)

### 7.1 iCal synchronizace

**Jak to funguje v systému:**  
Tabulka `apartment_ical_sources` spojuje byt s URL .ics (Airbnb, Booking, Smoobu). Edge Function `ical-fetch` stahuje kalendáře a zapisuje rezervace s `external_uid` pro idempotenci. Migrace `20260304100000_setup_ical_sync.sql` vytváří potřebné struktury.

**Proč to klient (agentura) miluje:**  
Automatická synchronizace rezervací z bookingových platforem – méně ruční práce.

---

### 7.2 Zaměstnanecká pokladna (Cash Accountability)

**Jak to funguje v systému:**  
`employee_cash_wallets` a `employee_cash_transactions` evidují hotovost vybranou od hostů. Typy: `COLLECTED_FROM_GUEST`, `HANDED_TO_AGENCY`, `COMPANY_EXPENSE`. U firemních výdajů lze připojit `apartment_id` pro stržení nákladů ve faktuře majitele. Worker nahrává fotku účtenky (`receipt_image_url`).

**Proč to klient (agentura) miluje:**  
Přehled o tom, kdo má u sebe kolik hotovosti – žádné „ztracené“ peníze.

---

### 7.3 Push notifikace a preference

**Jak to funguje v systému:**  
`user_devices` ukládá FCM tokeny. `notification_preferences`: `daily_summary_enabled`, `upcoming_task_enabled`, `new_task_assigned_enabled`. Edge Function `daily-task-summary` (cron) rozesílá ranní souhrn úkolů.

**Proč to klient (agentura) miluje:**  
Personál dostává včas upozornění na nové úkoly a blížící se termíny.

---

## Shrnutí

FalcoNest kombinuje **pokročilé CRM** (tři typy klientů, adresář agentur), **flexibilní konfiguraci služeb** (katalog → byt → rezervace), **inteligentní rozložení úkolů** (load balancing, zóny, absences) a **majitelský portál** (rezervace, předání, vyúčtování). Komunikace s hosty je podpořena **šablonami s placeholdery** a **automatickými připomenutími**. Platforma nabízí **Super Admin převtělení** a **Enterprise Audit Log** pro maximální podporu a bezpečnost.

---

*Dokument vytvořen na základě analýzy souborů: database_schema.md, auth_notifier.dart, admin_clients_screen.dart, client_detail_dialog.dart, apartment_service_model.dart, apartment_services_repository.dart, task_assignment_engine.dart, admin_team_screen.dart, owner_reservations_screen.dart, owner_billing_screen.dart, communication_templates_screen.dart, template_placeholder_service.dart, template-reminders/index.ts, audit_log_screen.dart, enterprise_audit_payload.dart, super_admin_dashboard.dart a souvisejících providerů a migrací.*
