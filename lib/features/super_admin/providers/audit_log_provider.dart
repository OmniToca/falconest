import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/super_admin/services/audit_log_repository.dart';

/// Filtr tenanta pro audit log: null = všechny agentury (globální pohled),
/// jinak pouze záznamy daného tenanta. Super_admin může přepínat v UI.
final auditLogTenantFilterProvider = StateProvider<String?>((ref) => null);

/// Načte záznamy z audit_logs pro Super Admina.
///
/// Respektuje [auditLogTenantFilterProvider]: při null zobrazí všechny záznamy (RLS
/// umožní super_admin vše), při vybraném tenant_id pouze jeho záznamy. Data se berou
/// z Supabase; řazení od nejnovějších.
final auditLogListProvider = FutureProvider<List<AuditLogEntry>>((ref) async {
  final tenantId = ref.watch(auditLogTenantFilterProvider);
  return AuditLogRepository.fetchLogs(tenantId: tenantId);
});

/// Načte mapu user_id → zobrazované jméno (Actor) pro záznamy z audit logu.
///
/// Závisí na [auditLogListProvider]: po načtení logů vybere unikátní user_id a dohledá
/// v tabulce profiles first_name + last_name (nebo name). UI pak zobrazí „Jan Novák“
/// místo UUID. Párování je nutné, protože audit_logs obsahuje pouze user_id.
final auditLogActorNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final list = await ref.watch(auditLogListProvider.future);
  final ids = list
      .map((e) => e.userId)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();
  return AuditLogRepository.fetchActorNames(ids);
});
