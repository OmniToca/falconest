/// Sdílené modely a pomocné metody pro AuditLogRepository.
///
/// Bez importu Isaru – používají web i mobilní implementace.
library;
import 'package:falconest/core/services/supabase_service.dart';

/// Jeden záznam z tabulky audit_logs – pro zobrazení v modulu Odpadkový koš.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    this.tenantId,
    this.userId,
    required this.actionType,
    this.tableName,
    this.recordId,
    this.details,
    required this.createdAt,
  });

  final String id;
  final String? tenantId;
  final String? userId;
  final String actionType;
  final String? tableName;
  final String? recordId;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  static AuditLogEntry? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final createdAtRaw = map['created_at'];
    DateTime createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now().toUtc();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now().toUtc();
    }
    final detailsRaw = map['details'];
    Map<String, dynamic>? details;
    if (detailsRaw is Map<String, dynamic>) {
      details = detailsRaw;
    } else if (detailsRaw is Map) {
      details = Map<String, dynamic>.from(detailsRaw);
    }
    return AuditLogEntry(
      id: id,
      tenantId: map['tenant_id']?.toString(),
      userId: map['user_id']?.toString(),
      actionType: map['action_type'] as String? ?? '',
      tableName: map['table_name'] as String?,
      recordId: map['record_id'] as String?,
      details: details,
      createdAt: createdAt,
    );
  }
}

abstract class AuditActionType {
  static const String softDelete = 'SOFT_DELETE';
  static const String softDeleteCascade = 'SOFT_DELETE_CASCADE';
}

const Set<String> kSoftDeleteTables = {'apartments', 'tasks', 'profiles', 'reservations'};

bool canRestoreAuditEntry(AuditLogEntry entry) {
  if (entry.tableName == null || entry.recordId == null) return false;
  if (entry.actionType != AuditActionType.softDelete &&
      entry.actionType != AuditActionType.softDeleteCascade) {
    return false;
  }
  return kSoftDeleteTables.contains(entry.tableName);
}

bool canHardDeleteAuditEntry(AuditLogEntry entry) {
  if (entry.tableName == null || entry.recordId == null) return false;
  return kSoftDeleteTables.contains(entry.tableName);
}

Future<void> applyRestoreToSupabase(String tableName, String recordId) async {
  await SupabaseService.client.from(tableName).update({'deleted_at': null}).eq('id', recordId);
}

Future<void> applyHardDeleteToSupabase(String tableName, String recordId) async {
  await SupabaseService.client.from(tableName).delete().eq('id', recordId);
}
