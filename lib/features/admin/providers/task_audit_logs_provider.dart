import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/super_admin/services/audit_log_repository.dart';

/// Auditní záznamy pro konkrétní úkol (`audit_logs`: table_name = tasks, record_id = task id).
///
/// PROČ: Dispečer v detailu úkolu vidí kdo a kdy měnil stav (bez nových tabulek v DB).
final taskAuditLogsProvider =
    FutureProvider.family<List<AuditLogEntry>, String>((ref, taskId) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty || taskId.trim().isEmpty) {
    return [];
  }
  return AuditLogRepository.fetchLogsForRecord(
    tenantId: tenantId,
    tableName: 'tasks',
    recordId: taskId.trim(),
  );
});
