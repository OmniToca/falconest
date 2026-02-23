/// Mobilní implementace AuditLogRepository – Isar offline-first.
///
/// Kompiluje se pouze pro dart:io. Používá PendingAuditAction pro offline zápis.
import 'package:isar/isar.dart';
import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/pending_audit_action.dart';
import 'package:falconest/core/database/models/sync_status.dart';
import 'package:falconest/features/super_admin/services/audit_log_shared.dart';
import 'package:falconest/core/services/supabase_service.dart';

class AuditLogRepository {
  AuditLogRepository._();

  static final _client = SupabaseService.client;

  static Future<Map<String, String>> fetchActorNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final ids = userIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};
    try {
      final res = await _client
          .from('profiles')
          .select('auth_id, first_name, last_name, name')
          .inFilter('auth_id', ids);
      final out = <String, String>{};
      for (final e in res) {
        final map = Map<String, dynamic>.from(e as Map);
        final authId = map['auth_id']?.toString().trim();
        if (authId == null || authId.isEmpty) continue;
        final first = (map['first_name']?.toString() ?? '').trim();
        final last = (map['last_name']?.toString() ?? '').trim();
        final name = (map['name']?.toString() ?? '').trim();
        final display = first.isNotEmpty || last.isNotEmpty
            ? '$first $last'.trim()
            : (name.isNotEmpty ? name : authId);
        out[authId] = display;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<List<AuditLogEntry>> fetchLogs({String? tenantId, int limit = 200}) async {
    try {
      dynamic query = _client
          .from('audit_logs')
          .select('id, tenant_id, user_id, action_type, table_name, record_id, details, created_at');
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }
      query = query.order('created_at', ascending: false).limit(limit);
      final res = await query;
      final list = res is List ? res : <dynamic>[];
      final out = <AuditLogEntry>[];
      for (final e in list) {
        final map = e is Map ? Map<String, dynamic>.from(e) : null;
        final entry = AuditLogEntry.fromJson(map);
        if (entry != null) out.add(entry);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static bool canRestore(AuditLogEntry entry) => canRestoreAuditEntry(entry);
  static bool canHardDelete(AuditLogEntry entry) => canHardDeleteAuditEntry(entry);

  static Future<void> restore(AuditLogEntry entry) async {
    final table = entry.tableName;
    final recordId = entry.recordId;
    if (table == null || recordId == null || !kSoftDeleteTables.contains(table)) return;
    try {
      final isar = IsarService.instance;
      final pending = PendingAuditAction()
        ..actionType = 'restore'
        ..tableName = table
        ..recordId = recordId
        ..tenantId = entry.tenantId
        ..createdAtUtc = DateTime.now().toUtc()
        ..syncStatus = SyncStatus.pending;
      await isar.writeTxn(() async => isar.pendingAuditActions.put(pending));
      await processPendingAuditActions();
    } catch (_) {
      await applyRestoreToSupabase(table, recordId);
    }
  }

  static Future<void> hardDelete(AuditLogEntry entry) async {
    final table = entry.tableName;
    final recordId = entry.recordId;
    if (table == null || recordId == null || !kSoftDeleteTables.contains(table)) return;
    try {
      final isar = IsarService.instance;
      final pending = PendingAuditAction()
        ..actionType = 'hard_delete'
        ..tableName = table
        ..recordId = recordId
        ..tenantId = entry.tenantId
        ..createdAtUtc = DateTime.now().toUtc()
        ..syncStatus = SyncStatus.pending;
      await isar.writeTxn(() async => isar.pendingAuditActions.put(pending));
      await processPendingAuditActions();
    } catch (_) {
      await applyHardDeleteToSupabase(table, recordId);
    }
  }

  static Future<void> processPendingAuditActions() async {
    try {
      final isar = IsarService.instance;
      final pending = await isar.pendingAuditActions
          .filter()
          .syncStatusEqualTo(SyncStatus.pending)
          .findAll();
      for (final p in pending) {
        try {
          if (p.actionType == 'restore') {
            await applyRestoreToSupabase(p.tableName, p.recordId);
          } else if (p.actionType == 'hard_delete') {
            await applyHardDeleteToSupabase(p.tableName, p.recordId);
          }
          p.syncStatus = SyncStatus.synced;
          await isar.writeTxn(() async => isar.pendingAuditActions.put(p));
        } catch (_) {}
      }
    } catch (_) {}
  }
}
