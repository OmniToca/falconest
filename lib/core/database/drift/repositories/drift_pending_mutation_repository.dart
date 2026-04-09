import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:falconest_drift/app_database.dart' as db;

/// Řádek mutace z fronty – nezávislý DTO pro použití mimo Drift.
///
/// PROČ: Aby budoucí DriftMutationQueueService nemusel importovat Drift modely.
/// [payloadJson] je uložený string – volající použije jsonDecode pro Map.
class PendingMutationRow {
  const PendingMutationRow({
    required this.id,
    required this.tableName,
    required this.actionType,
    required this.payloadJson,
    this.recordId,
    required this.createdAt,
  });

  final int id;
  final String tableName;
  final String actionType;
  final String payloadJson;
  final String? recordId;
  final DateTime createdAt;

  /// Parsuje payloadJson na Map. PROČ: SQLite ukládá JSON jako text,
  /// processQueue potřebuje Map pro Supabase operace a procesory.
  Map<String, dynamic>? get payload =>
      (jsonDecode(payloadJson) as Map?)?.cast<String, dynamic>();
}

/// Drift implementace repozitáře fronty pending mutací – ekvivalent Isar PendingMutationLocal.
///
/// Paralelní implementace pro fázi přechodu. Metody odpovídají použití v MutationQueueService:
/// enqueueMutation, processQueue (getAll + delete), getPendingCount.
///
/// payloadJson se ukládá jako text – při čtení parsujeme přes jsonDecode.
class DriftPendingMutationRepository {
  DriftPendingMutationRepository(this._db);

  final db.AppDatabase _db;

  /// Přidá mutaci do fronty. Volá se při offline operaci (SocketException, timeout).
  ///
  /// PROČ JSON: SQLite nemá typ pro Map – payload serializujeme do textu.
  /// Při processQueue se znovu dekóduje.
  Future<void> enqueue({
    required String table,
    required String action,
    required Map<String, dynamic> payload,
    String? recordId,
  }) async {
    await _db.into(_db.pendingMutations).insert(
          db.PendingMutationsCompanion.insert(
            targetTable: table,
            actionType: action,
            payloadJson: jsonEncode(payload),
            recordId: Value(recordId),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// Načte všechny mutace seřazené podle [createdAt].
  /// PROČ: processQueue musí odesílat v pořadí vytvoření (FIFO).
  Future<List<PendingMutationRow>> getAllOrderedByCreatedAt() async {
    final rows = await (_db.select(_db.pendingMutations)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map((r) => _toRow(r)).toList();
  }

  PendingMutationRow _toRow(db.PendingMutation r) {
    return PendingMutationRow(
      id: r.id,
      tableName: r.targetTable,
      actionType: r.actionType,
      payloadJson: r.payloadJson,
      recordId: r.recordId,
      createdAt: r.createdAt,
    );
  }

  /// Smaže mutaci po úspěšném odeslání.
  Future<void> deleteById(int id) async {
    await (_db.delete(_db.pendingMutations)..where((t) => t.id.equals(id)))
        .go();
  }

  /// Počet záznamů ve frontě. PROČ: SyncStatusIcon – uživatel vidí, kolik změn čeká.
  ///
  /// Fronta obvykle obsahuje jen desítky záznamů – načtení délky je dostatečné.
  Future<int> getCount() async {
    final rows = await _db.select(_db.pendingMutations).get();
    return rows.length;
  }

  /// Reaktivní stream počtu mutací pro živé aktualizace UI.
  Stream<int> watchCount() {
    return _db.select(_db.pendingMutations).watch().map((rows) => rows.length);
  }

  /// Stream celé fronty v pořadí vytvoření – Drift při změně tabulky znovu vyemituje seznam.
  ///
  /// PROČ: Obrazovka worker fronty potřebuje okamžitou aktualizaci po processQueue / enqueue
  /// bez ruční invalidace provideru.
  Stream<List<PendingMutationRow>> watchAllOrderedByCreatedAt() {
    final query = _db.select(_db.pendingMutations)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toRow).toList());
  }
}
