/// Drift implementace repozitáře pending audit akcí – ekvivalent Isar PendingAuditAction.
///
/// Offline-first: Akce Obnovit/HardDelete z Odpadkového koše se zapisují sem,
/// na pozadí se synchronizují do Supabase (NetworkSyncWatcher, processPendingAuditActions).
library;
import 'package:drift/drift.dart';
import 'package:falconest_drift/app_database.dart';

/// SyncStatus: 0 = synced, 1 = pending (odpovídá enum SyncStatus index).
const int _syncStatusPending = 1;
const int _syncStatusSynced = 0;

class DriftPendingAuditActionRepository {
  DriftPendingAuditActionRepository(this._db);

  final AppDatabase _db;

  /// Přidá pending akci (restore nebo hard_delete).
  Future<void> enqueue({
    required String actionType,
    required String tableName,
    required String recordId,
    String? tenantId,
  }) async {
    await _db.into(_db.pendingAuditActions).insert(
          PendingAuditActionsCompanion.insert(
            actionType: actionType,
            targetTable: tableName,
            recordId: recordId,
            tenantId: Value(tenantId),
            createdAtUtc: DateTime.now().toUtc(),
            syncStatus: const Value(_syncStatusPending),
          ),
        );
  }

  /// Načte všechny pending akce k odeslání.
  Future<List<PendingAuditAction>> getPending() async {
    return (_db.select(_db.pendingAuditActions)
          ..where((t) => t.syncStatus.equals(_syncStatusPending))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAtUtc)]))
        .get();
  }

  /// Označí záznam jako synchronizovaný.
  Future<void> markSynced(PendingAuditAction row) async {
    await (_db.update(_db.pendingAuditActions)
          ..where((t) => t.id.equals(row.id)))
        .write(PendingAuditActionsCompanion(syncStatus: Value(_syncStatusSynced)));
  }
}
