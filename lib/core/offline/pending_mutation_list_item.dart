import 'package:falconest/core/database/drift/repositories/drift_pending_mutation_repository.dart';

/// Jedna položka lokální fronty mutací pro UI a služby (bez závislosti na Drift entitě).
///
/// PROČ: [MutationQueueServiceInterface] a worker obrazovka potřebují stabilní DTO;
/// mapujeme z [PendingMutationRow], aby webová no-op implementace nemusela importovat SQLite.
class PendingMutationListItem {
  const PendingMutationListItem({
    required this.id,
    required this.tableName,
    required this.actionType,
    required this.createdAt,
    this.recordId,
    this.payload,
  });

  final int id;
  final String tableName;
  final String actionType;
  final DateTime createdAt;
  final String? recordId;
  final Map<String, dynamic>? payload;

  /// Vytvoří DTO z řádku repozitáře (parsování payloadu přes existující getter).
  factory PendingMutationListItem.fromRow(PendingMutationRow row) {
    return PendingMutationListItem(
      id: row.id,
      tableName: row.tableName,
      actionType: row.actionType,
      createdAt: row.createdAt,
      recordId: row.recordId,
      payload: row.payload,
    );
  }

  /// tenant_id z payloadu (Supabase řádky, OFFLINE akce) – pro filtr worker UI v rámci multi-tenant.
  ///
  /// PROČ: Worker má vždy jeden aktivní tenant; položky bez tenant_id v payloadu považujeme
  /// za relevantní (typicky obsahují jiný identifikátor vázaný na stejný účet).
  String? get tenantIdFromPayload {
    final raw = payload?['tenant_id'];
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }
}
