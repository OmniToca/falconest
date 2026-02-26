import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář pro úkoly v Admin modulu – Realtime stream.
///
/// Slouží pro okamžitou aktualizaci seznamu úkolů bez nutnosti F5.
/// Future metody (select, insert) zůstávají v AdminTasksNotifier.
class AdminTasksRepository {
  AdminTasksRepository._();
  static final AdminTasksRepository instance = AdminTasksRepository._();

  /// Realtime stream úkolů pro daného tenanta.
  ///
  /// PROČ: Realtime stream pro okamžitou aktualizaci UI bez nutnosti F5 (Supabase WebSockets).
  /// Dispečer vidí změny (nové úkoly, přiřazení, status) hned po provedení jiným uživatelem nebo systémem.
  ///
  /// OMEZENÍ: Supabase stream podporuje pouze jeden filtr – používáme inFilter(tenant_id).
  /// Filtrování deleted_at a řazení probíhá na straně klienta.
  Stream<List<Map<String, dynamic>>> watchTasksRaw(String tenantId) {
    if (tenantId.isEmpty) return Stream.value([]);

    return SupabaseService.client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .inFilter('tenant_id', [tenantId])
        .map((List<Map<String, dynamic>> rows) {
          final filtered = rows
              .where((r) => r['deleted_at'] == null)
              .toList();
          filtered.sort((a, b) {
            final aVal = a['due_date'] ?? a['scheduled_start'] ?? '';
            final bVal = b['due_date'] ?? b['scheduled_start'] ?? '';
            return aVal.toString().compareTo(bVal.toString());
          });
          return filtered;
        });
  }
}
