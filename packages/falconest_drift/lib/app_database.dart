import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

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
  TextColumn get status => text()();
  TextColumn get photoUrl => text().nullable()();

  DateTimeColumn get localUpdatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdated => dateTime()();

  TextColumn get metadataJson => text().nullable()();
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
class Reservations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get status => text().withDefault(const Constant('new'))();
  TextColumn get guestName => text().nullable()();
  TextColumn get guestPhone => text().nullable()();
  TextColumn get referenceNumber => text().nullable()();
  DateTimeColumn get localUpdatedAt => dateTime()();
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
class MessageTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supabaseId => text().nullable()();
  TextColumn get tenantId => text()();
  TextColumn get key => text().withDefault(const Constant(''))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get channel => text().nullable()();
  TextColumn get languageCode => text().nullable()();
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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

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
        },
      );

  /// Otevře SQLite databázi. NativeDatabase.createInBackground pro neblokující inicializaci.
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'falconest_drift.sqlite'));

      final cachebase = (await getTemporaryDirectory()).path;
      sqlite3.tempDirectory = cachebase;

      return NativeDatabase.createInBackground(file);
    });
  }
}
