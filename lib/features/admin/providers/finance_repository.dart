import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář pro operace modulu Fakturace – označování úkolů jako vyfakturované.
class FinanceRepository {
  FinanceRepository._();
  static final FinanceRepository instance = FinanceRepository._();

  /// Označí dané úkoly jako vyfakturované – nastaví invoiced_at = now().
  ///
  /// PROČ: Soft-archivace. Úkoly s invoiced_at != null se již nezobrazují
  /// na Nástěnce/Plachtě ani v podkladech pro fakturaci. Fakturace je idempotentní
  /// – opakované volání na stejná ID nic nepokazí.
  Future<void> invoiceTasks(String tenantId, List<String> taskIds) async {
    if (tenantId.isEmpty || taskIds.isEmpty) return;
    final ids = taskIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();

    await SupabaseService.safeFrom('tasks', tenantId)
        .update({'invoiced_at': now})
        .inFilter('id', ids);
  }
}
