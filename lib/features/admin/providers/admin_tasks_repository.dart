import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/supabase_stream_helper.dart';

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
  /// PROČ resilientSupabaseStream: Chyby WebSocketu (Code 1000) se nikdy nepropagují do Riverpodu.
  ///
  /// OMEZENÍ: Supabase stream podporuje pouze jeden filtr – používáme inFilter(tenant_id).
  /// Filtrování deleted_at a řazení probíhá na straně klienta.
  ///
  /// PROČ hybridní přístup (initial fetch + stream): Supabase Realtime stream nemusí vždy
  /// emitovat úvodní data okamžitě. Bez initial fetch by StreamProvider zůstal v loading.
  Stream<List<Map<String, dynamic>>> watchTasksRaw(String tenantId) {
    if (tenantId.isEmpty) return Stream.value([]);

    List<Map<String, dynamic>> _filterAndSort(List<Map<String, dynamic>> rows) {
      // PROČ: Archivace. Vyfakturované úkoly (invoiced_at != null) schováváme z aktivních pohledů.
      final filtered = rows
          .where((r) => r['deleted_at'] == null && r['invoiced_at'] == null)
          .toList();
      filtered.sort((a, b) {
        final aVal = a['due_date'] ?? a['scheduled_start'] ?? '';
        final bVal = b['due_date'] ?? b['scheduled_start'] ?? '';
        return aVal.toString().compareTo(bVal.toString());
      });
      return filtered;
    }

    final stream = resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => SupabaseService.client
          .from('tasks')
          .stream(primaryKey: ['id'])
          .inFilter('tenant_id', [tenantId])
          .order('scheduled_start', ascending: false)
          .limit(500)
          .map((List<Map<String, dynamic>> rows) => _filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksRaw',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        // PROČ: Archivace. Vyfakturované úkoly (invoiced_at != null) schováváme z aktivních pohledů.
        final res = await SupabaseService.client
            .from('tasks')
            .select()
            .eq('tenant_id', tenantId)
            .isFilter('deleted_at', null)
            .isFilter('invoiced_at', null)
            .order('scheduled_start', ascending: false)
            .limit(500);
        final list = (res as List).cast<Map<String, dynamic>>();
        return _filterAndSort(list);
      },
    );
  }

  /// Emituje nejdřív úvodní data z [initialFetch], pak pokračuje streamem.
  static Stream<T> _streamWithInitialFetch<T>({
    required Stream<T> stream,
    required Future<T> Function() initialFetch,
  }) async* {
    yield await initialFetch();
    yield* stream;
  }
}
