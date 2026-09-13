import 'package:drift/drift.dart';

import 'connection.dart';

part 'app_database.g.dart';

/// Tabulka úkolů – ekvivalent Isar TaskLocal.
///
/// Offline-first: Ukládá úkoly synchronizované z Supabase i nové lokální záznamy.
/// [localUpdatedAt] se používá pro Timestamp Merging při řešení konfliktů.
/// Sloupce odpovídají Isar modelu TaskLocal pro snadnou paralelní migraci.
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get apartmentSupabaseId => text().nullable()();
  TextColumn get clientSupabaseId => text().nullable()();
  TextColumn get customLocation => text().nullable()();
  TextColumn get customTitle => text().nullable()();
  TextColumn get reservationSupabaseId => text().nullable()();
  TextColumn get assignedUserSupabaseId => text().nullable()();
  /// Další přiřazení pracovníci (JSON pole UUID) – pro sdílení úkolu.
  TextColumn get assignedUserIdsJson => text().nullable()();
  TextColumn get referenceNumber => text().nullable()();

  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get taskType => text().withDefault(const Constant('Jiné'))();

  DateTimeColumn get scheduledStart => dateTime()();
  /// Termín splnění z `tasks.due_date` (na serveru text) – po sync parsováno do UTC; null pokud server neposlal nebo nejde parsovat.
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text()();
  TextColumn get photoUrl => text().nullable()();

  DateTimeColumn get localUpdatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdated => dateTime()();

  TextColumn get metadataJson => text().nullable()();
  /// JSON z `tasks.title_i18n` (jsonb) – uložené překlady názvu pro exporty; prázdné řádky = null.
  TextColumn get titleI18nJson => text().nullable()();
  /// JSON z `tasks.unassigned_info` (jsonb) jako text – pro offline kontext nepřiřazeného úkolu.
  TextColumn get unassignedInfo => text().nullable()();
  /// UUID služby z `tasks.service_id` – text kvůli jednoduchosti v SQLite.
  TextColumn get serviceId => text().nullable()();
  /// JSON pole URL fotek (Supabase `tasks.media_urls` typu text[]) – serializace jako JSON string.
  /// Přidáno ve Fázi 2: offline náhled fotek u úkolu (requires_photo, závady, dokumentace).
  TextColumn get mediaUrlsJson => text().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get invoicedAt => dateTime().nullable()();
}

/// Tabulka bytů – ekvivalent Isar ApartmentLocal.
///
/// Offline-first: Data se synchronizují ze Supabase. Slouží pro zobrazení jména bytu
/// a adresy u úkolů (např. Worker dashboard). [syncStatus]: 0=synced, 1=pending.
class Apartments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get address => text().nullable()();
  TextColumn get keybox => text().nullable()();
  TextColumn get code => text().nullable()();
  TextColumn get ownerNotes => text().nullable()();
  /// Standardní čas příjezdu hosta (např. „15:00“) – z `apartments.check_in_time`.
  TextColumn get checkInTime => text().nullable()();
  /// Standardní čas odjezdu (check-out) – z `apartments.check_out_time`.
  TextColumn get checkOutTime => text().nullable()();
  /// UUID zóny (např. parkování) – z `apartments.zone_id`, text pro jednoduchost v SQLite.
  TextColumn get zoneId => text().nullable()();
  /// Instrukce k parkování pro offline zobrazení – z `apartments.parking_instructions`.
  TextColumn get parkingInstructions => text().nullable()();
  /// Příznak investičního modulu – z `apartments.investment_tracking_enabled`.
  BoolColumn get investmentTrackingEnabled => boolean().withDefault(const Constant(false))();
  /// `short_term` | `long_term` – z `apartments.rental_mode`.
  TextColumn get rentalMode => text().withDefault(const Constant('short_term'))();
  /// Platnost smlouvy od (nullable) – z `apartments.lease_start_date`.
  DateTimeColumn get leaseStartDate => dateTime().nullable()();
  /// Platnost smlouvy do – z `apartments.lease_end_date`.
  DateTimeColumn get leaseEndDate => dateTime().nullable()();
  /// Měsíční nájem (dlouhodobý) – z `apartments.rent_amount`.
  RealColumn get rentAmount => real().withDefault(const Constant(0))();
  /// Den splatnosti 1–31 – z `apartments.rent_due_day`.
  IntColumn get rentDueDay => integer().withDefault(const Constant(1))();
  /// `notification` | `task` – z `apartments.rent_collection_mode`.
  TextColumn get rentCollectionMode => text().withDefault(const Constant('notification'))();
  /// Odpovědný pracovník (profiles.id) – z `apartments.rent_task_assignee_id`.
  TextColumn get rentTaskAssigneeId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  DateTimeColumn get localUpdatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get lastUpdated => dateTime()();
}

/// Tabulka klientů – ekvivalent Isar ClientLocal.
///
/// Minimální subset pro Worker: externí úkoly (transfer bez rezervace) mají tasks.client_id.
/// Pro offline zobrazení jména klienta řidiči ukládáme klienty sem.
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get phone => text().nullable()();
}

/// Tabulka rezervací – ekvivalent Isar ReservationLocal.
///
/// Minimální subset pro Worker: offline-first update statusu při Check-in. [guestName],
/// [guestPhone] pro zobrazení check-in agentům. [syncStatus]: 0=synced, 1=pending.
/// [lastSyncedAt]: serverové `updated_at` známé po posledním syncu – Timestamp Merging při pushi.
class Reservations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get status => text().withDefault(const Constant('new'))();
  TextColumn get guestName => text().nullable()();
  TextColumn get guestPhone => text().nullable()();
  TextColumn get referenceNumber => text().nullable()();
  /// Speciální požadavky hosta – z `reservations.special_requests`.
  TextColumn get specialRequests => text().nullable()();
  /// Preferovaný jazyk hosta (např. šablony SMS) – z `reservations.guest_language`.
  TextColumn get guestLanguage => text().nullable()();
  /// Začátek pobytu – z `reservations.start_date` (PostgreSQL date → UTC půlnoc).
  DateTimeColumn get startDate => dateTime().nullable()();
  /// Konec pobytu – z `reservations.end_date`.
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get localUpdatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdated => dateTime()();
}

/// Tabulka tenantů – ekvivalent Isar TenantLocal.
///
/// Nastavení tenanta (agentury): Worker UI potřebuje měnu pro formátování hotovosti
/// offline. Sync stáhne tenants (id, currency) při stažení úkolů.
class Tenants extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supabaseId => text()();
  TextColumn get currency => text().nullable()();
}

/// Tabulka šablon zpráv – ekvivalent Isar MessageTemplateLocal.
///
/// tenant_message_templates ze Supabase. Řidiči používají šablony v terénu offline.
/// Full Replace při sync – Worker jen čte. [syncStatus]: 0=synced, 1=pending.
/// Texty šablon jsou v [translationsJson] (stejný JSON jako Supabase jsonb); legacy sloupce
/// body/language_code byly odstraněny – viz migrace schématu v4.
class MessageTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get key => text().withDefault(const Constant(''))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get channel => text().nullable()();
  TextColumn get emailSubject => text().nullable()();
  TextColumn get translationsJson => text().nullable()();
  TextColumn get triggerContext => text().nullable()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

/// Tabulka pending audit akcí – ekvivalent Isar PendingAuditAction.
///
/// Akce „Obnovit“ nebo „Trvalé odstranění“ z audit logu. Offline-first: zápis sem,
/// na pozadí sync do Supabase. targetTable = tableName (rezervované v Drift).
class PendingAuditActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get actionType => text()();
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get tenantId => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

/// Tabulka fronty offline mutací – ekvivalent Isar PendingMutationLocal.
///
/// Univerzální fronta pro operace (INSERT, UPDATE, DELETE) na Supabase tabulky.
/// KRITICKÉ: Tato tabulka obsahuje neodeslaná data – nikdy ji nesmazat bez záchrany.
class PendingMutations extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Název cílové tabulky (např. tasks, cash_wallets). Používáme targetTable,
  /// protože tableName je rezervované v Drift Table base class.
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get actionType => text()();
  TextColumn get payloadJson => text()();
  TextColumn get recordId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Lokální instance checklistu k úkolu – odpovídá `task_checklists` v Supabase.
///
/// PROČ: Worker ukládá offline jen instance, ne šablony. [supabaseId] = UUID řádku na serveru;
/// [taskId] = UUID úkolu (`tasks.id`). [syncStatus]: 0 = synchronizováno, 1 = čeká na odeslání.
class TaskChecklists extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get taskId => text()();
  TextColumn get templateId => text().nullable()();

  DateTimeColumn get localUpdatedAt => dateTime()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

/// Lokální položky instance checklistu – odpovídá `task_checklist_items` v Supabase.
///
/// PROČ: Odškrtávání a fotografie u bodů; [taskChecklistId] = UUID rodiče z `task_checklists`.
class TaskChecklistItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get taskChecklistId => text()();

  TextColumn get title => text().withDefault(const Constant(''))();
  BoolColumn get isPhotoRequired => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get completedBy => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  /// Lokální cesta nebo demo řetězec (stub) – na Supabase neposíláme; server drží jen [photoUrl] z úložiště.
  ///
  /// PROČ: Worker v terénu může mít offline náhled / simulaci přiložení bez okamžitého uploadu.
  TextColumn get localPhotoPath => text().nullable()();

  DateTimeColumn get localUpdatedAt => dateTime()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

/// Lokální kopie `task_payouts` pro Worker „Moje výdělky“ (offline-first).
///
/// PROČ: UI nesmí volat Supabase přímo; sync worker stáhne řádky pro `profile_id` přihlášeného.
/// [supabaseId] = UUID záznamu na serveru; částky v měně tenanta (bez přepočtu).
class TaskPayouts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get supabaseId => text()();
  TextColumn get tenantId => text()();
  TextColumn get taskId => text()();
  TextColumn get profileId => text()();

  RealColumn get amount => real()();
  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Lokální kopie `task_commissions` řádků, kde příjemcem je zaměstnanec (`profile_id`).
///
/// PROČ: Worker výdělky slučují výplaty i provize; `client_id` držíme pro budoucí admin náhledy.
class TaskCommissions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get supabaseId => text()();
  TextColumn get tenantId => text()();
  TextColumn get taskId => text()();
  TextColumn get profileId => text().nullable()();
  TextColumn get clientId => text().nullable()();

  RealColumn get amount => real()();
  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Lokální kopie `staff_absences` pro Worker „Moje nepřítomnost“ (offline-first).
///
/// PROČ: [supabaseId] je UUID řádku na serveru; při prvním zápisu z mobilu ho generuje klient
/// a posílá v INSERT mutaci – Drift a Supabase zůstanou sladěné.
@DataClassName('DriftStaffAbsence')
class StaffAbsences extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get supabaseId => text()();
  TextColumn get tenantId => text()();
  TextColumn get profileId => text()();
  TextColumn get invitationId => text().nullable()();

  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get reason => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Lokální kopie `employee_cash_wallets` pro Worker „Peněženka“ (offline-first).
///
/// PROČ: [supabaseId] je UUID peněženky na serveru; měna tenanta se denormalizuje z [Tenants]
/// při synci kvůli zobrazení bez dalšího dotazu (sloupec v Supabase tabulce není).
@DataClassName('DriftEmployeeCashWallet')
class EmployeeCashWallets extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get supabaseId => text()();
  TextColumn get tenantId => text()();
  TextColumn get profileId => text()();

  RealColumn get balance => real()();
  /// ISO měna z lokálního [Tenants.currency] (např. CZK) – v PostgreSQL u peněženky není.
  TextColumn get currencyCode => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
}

/// Lokální kopie `employee_cash_transactions` – historie pohybů na peněžence workera.
///
/// PROČ: Worker UI čte výhradně SQLite; [profileId] denormalizujeme kvůli mazání při full replace synci.
@DataClassName('DriftEmployeeCashTransaction')
class EmployeeCashTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get supabaseId => text()();
  TextColumn get tenantId => text()();
  TextColumn get walletId => text()();
  TextColumn get profileId => text()();

  RealColumn get amount => real()();
  TextColumn get transactionType => text()();

  /// Odpovídá `note` na serveru (popis / poznámka k výdaji).
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  TextColumn get taskId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get receiptImageUrl => text().nullable()();
  RealColumn get expectedAmount => real().nullable()();
  TextColumn get apartmentId => text().nullable()();
  TextColumn get clientId => text().nullable()();

  BoolColumn get isShortfallResolved => boolean().withDefault(const Constant(false))();
  TextColumn get shortfallResolutionType => text().nullable()();
  TextColumn get shortfallResolutionNote => text().nullable()();
}

/// Lokální cache řádku `profiles` pro přihlášeného uživatele (drawer, dialogy).
///
/// PROČ: [id] je vždy `auth.users.id` (Supabase Auth UUID), ne `profiles.id` – podle něj
/// filtrujeme jediný řádek cache na zařízení. Sloupec [profileDisplayName] drží `profiles.name`
/// pro případy bez first/last. [avatarUrl] je nullable (v aktuální DB nemusí existovat).
@DataClassName('DriftUserProfileCache')
class UserProfilesCache extends Table {
  /// `auth.users.id` – shoda s dotazem `.eq('auth_id', user.id)` na serveru.
  @override
  Set<Column> get primaryKey => {id};

  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  /// Hodnota sloupce `name` v `profiles` (zobrazení, když chybí křestní/příjmení).
  TextColumn get profileDisplayName => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get role => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Lokální kopie `tenant_ui_preferences` – brandové barvy agentury (offline-first).
///
/// PROČ: Parita se Supabase (`database_schema.md`); [id] = UUID řádku na serveru nebo nově
/// vygenerovaný při prvním lokálním zápisu před úspěšným upsertem. [updatedAt] v UTC pro Timestamp Merging.
@DataClassName('TenantUiPreference')
class TenantUiPreferences extends Table {
  @override
  Set<Column> get primaryKey => {id};

  /// Shodné s `tenant_ui_preferences.id` (UUID).
  TextColumn get id => text()();

  TextColumn get tenantId => text()();

  TextColumn get primaryColor => text().nullable()();

  TextColumn get secondaryColor => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {tenantId},
      ];
}

/// Drift (SQLite) databáze – paralelní implementace pro 100 % offline stabilitu.
///
/// PROČ DRIFT: Isar 3.x na starších iOS vykazuje fatální chyby ("Collection id is invalid").
/// SQLite je průmyslový standard s garantovanou stabilitou na všech platformách.
///
/// PARALELNÍ IMPLEMENTACE: Tento modul existuje vedle Isar. Původní Isar kód zůstává nedotčen.
@DriftDatabase(tables: [
  Tasks,
  PendingMutations,
  Apartments,
  Clients,
  Reservations,
  Tenants,
  MessageTemplates,
  PendingAuditActions,
  TaskChecklists,
  TaskChecklistItems,
  TaskPayouts,
  TaskCommissions,
  StaffAbsences,
  EmployeeCashWallets,
  EmployeeCashTransactions,
  UserProfilesCache,
  TenantUiPreferences,
])
class AppDatabase extends _$AppDatabase {
  /// [executor] lze injektovat v testech; produkce používá platformový výběr z [connection.dart].
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? openFalcoNestDriftConnection());

  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(apartments);
            await migrator.createTable(clients);
            await migrator.createTable(reservations);
            await migrator.createTable(tenants);
            await migrator.createTable(messageTemplates);
            await migrator.createTable(pendingAuditActions);
          }
          if (from < 3) {
            await migrator.addColumn(tasks, tasks.assignedUserIdsJson);
          }
          // PROČ v4: zarovnání s Supabase – odstranění legacy body/language_code, přidání
          // email_subject + translations_json (testovací data nepotřebujeme zachovat).
          if (from < 4) {
            await migrator.dropColumn(messageTemplates, 'body');
            await migrator.dropColumn(messageTemplates, 'language_code');
            await migrator.addColumn(messageTemplates, messageTemplates.emailSubject);
            await migrator.addColumn(messageTemplates, messageTemplates.translationsJson);
          }
          // PROČ v5: Dynamic Checklists – pouze instance (task_checklists, task_checklist_items).
          if (from < 5) {
            await migrator.createTable(taskChecklists);
            await migrator.createTable(taskChecklistItems);
          }
          // PROČ v6: Fáze 2 – plnohodnotný offline worker (fotky úkolu, požadavky rezervace, časy bytu).
          if (from < 6) {
            await migrator.addColumn(tasks, tasks.mediaUrlsJson);
            await migrator.addColumn(reservations, reservations.specialRequests);
            await migrator.addColumn(apartments, apartments.checkInTime);
            await migrator.addColumn(apartments, apartments.checkOutTime);
            await migrator.addColumn(apartments, apartments.zoneId);
          }
          // PROČ v7: kritická provozní data pro workera v terénu (parita se worker sync selecty).
          if (from < 7) {
            await migrator.addColumn(tasks, tasks.dueDate);
            await migrator.addColumn(tasks, tasks.unassignedInfo);
            await migrator.addColumn(tasks, tasks.serviceId);
            await migrator.addColumn(apartments, apartments.parkingInstructions);
            await migrator.addColumn(reservations, reservations.guestLanguage);
            await migrator.addColumn(reservations, reservations.startDate);
            await migrator.addColumn(reservations, reservations.endDate);
          }
          // PROČ v8: lokální indikace / stub fotky u položek checklistu bez závislosti na Storage URL.
          if (from < 8) {
            await migrator.addColumn(taskChecklistItems, taskChecklistItems.localPhotoPath);
          }
          // PROČ v9: výplaty a provize workera pro obrazovku „Moje výdělky“ bez online dotazu.
          if (from < 9) {
            await migrator.createTable(taskPayouts);
            await migrator.createTable(taskCommissions);
          }
          // PROČ v10: nepřítomnosti workera – čtení bez online Supabase dotazu.
          if (from < 10) {
            await migrator.createTable(staffAbsences);
          }
          // PROČ v11: hotovostní peněženka workera – čtení a okamžitý zápis offline.
          if (from < 11) {
            await migrator.createTable(employeeCashWallets);
            await migrator.createTable(employeeCashTransactions);
          }
          // PROČ v12: vizitka uživatele v draweru bez online dotazu na profiles.
          if (from < 12) {
            await migrator.createTable(userProfilesCache);
          }
          // PROČ v13: nastavení barev UI tenanta – lokální pravda před syncem se Supabase.
          if (from < 13) {
            await migrator.createTable(tenantUiPreferences);
          }
          // PROČ v14: Timestamp Merging u pushi rezervací – porovnání s Supabase updated_at.
          if (from < 14) {
            await migrator.addColumn(reservations, reservations.lastSyncedAt);
          }
          // PROČ v15: parita se Supabase – sloupce is_owner_block / agency_collects_payment odstraněny.
          if (from < 15) {
            await migrator.dropColumn(reservations, 'is_owner_block');
          }
          // PROČ v16: příznak investičního sledování u bytu (Supabase apartments.investment_tracking_enabled).
          if (from < 16) {
            await migrator.addColumn(apartments, apartments.investmentTrackingEnabled);
          }
          // PROČ v17: režim pronájmu STR vs. dlouhodobý + volitelná platnost smlouvy (Supabase).
          if (from < 17) {
            await migrator.addColumn(apartments, apartments.rentalMode);
            await migrator.addColumn(apartments, apartments.leaseStartDate);
            await migrator.addColumn(apartments, apartments.leaseEndDate);
          }
          // PROČ v18: automatizace nájmu u dlouhodobých bytů (částka, splatnost, režim, assignee).
          if (from < 18) {
            await migrator.addColumn(apartments, apartments.rentAmount);
            await migrator.addColumn(apartments, apartments.rentDueDay);
            await migrator.addColumn(apartments, apartments.rentCollectionMode);
            await migrator.addColumn(apartments, apartments.rentTaskAssigneeId);
          }
          // PROČ v19: parita s Supabase `tasks.title_i18n` (JSONB překlady názvu úkolu).
          if (from < 19) {
            await migrator.addColumn(tasks, tasks.titleI18nJson);
          }
        },
      );
}
