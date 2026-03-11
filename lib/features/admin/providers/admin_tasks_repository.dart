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
  /// OMEZENÍ: Bez časového okna, limit 500. Pro záložku Úkoly preferuj [watchTasksRawForMonth].
  Stream<List<Map<String, dynamic>>> watchTasksRaw(String tenantId) {
    if (tenantId.isEmpty) return Stream.value([]);

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
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

    // Frontend Firewall: safeFrom vnutí .eq('tenant_id', tenantId) / .inFilter('tenant_id', [tenantId])
    // – při převtělení Super Admina nelze zapomenout na filtr.
    final safeTasks = SupabaseService.safeFrom('tasks', tenantId);
    final stream = resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => safeTasks
          .stream(primaryKey: ['id'])
          .order('scheduled_start', ascending: false)
          .limit(500)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksRaw',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final res = await safeTasks
            .select()
            .isFilter('deleted_at', null)
            .isFilter('invoiced_at', null)
            .order('scheduled_start', ascending: false)
            .limit(500);
        final list = (res as List).cast<Map<String, dynamic>>();
        return filterAndSort(list);
      },
    );
  }

  /// Realtime stream úkolů pro daného tenanta omezený na jeden měsíc.
  ///
  /// PROČ: Výkon – limit 500 se aplikuje jen na vybraný měsíc (odstranění „slepoty do minulosti“).
  /// [month] – libovolný den v měsíci; použije se první a poslední den měsíce (UTC).
  Stream<List<Map<String, dynamic>>> watchTasksRawForMonth(String tenantId, DateTime month) {
    if (tenantId.isEmpty) return Stream.value([]);

    final start = DateTime.utc(month.year, month.month, 1);
    final end = DateTime.utc(month.year, month.month + 1, 1);
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    bool isInMonth(Map<String, dynamic> r) {
      final s = r['scheduled_start'] ?? r['due_date'];
      if (s == null) return false;
      final dt = DateTime.tryParse(s.toString());
      if (dt == null) return false;
      return !dt.isBefore(start) && dt.isBefore(end);
    }

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final filtered = rows
          .where((r) => r['deleted_at'] == null && isInMonth(r))
          .toList();
      filtered.sort((a, b) {
        final aVal = a['due_date'] ?? a['scheduled_start'] ?? '';
        final bVal = b['due_date'] ?? b['scheduled_start'] ?? '';
        return aVal.toString().compareTo(bVal.toString());
      });
      return filtered;
    }

    final safeTasks = SupabaseService.safeFrom('tasks', tenantId);
    final stream = resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => safeTasks
          .stream(primaryKey: ['id'])
          .order('scheduled_start', ascending: false)
          .limit(500)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksRawForMonth',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final res = await safeTasks
            .select()
            .isFilter('deleted_at', null)
            .gte('scheduled_start', startIso)
            .lt('scheduled_start', endIso)
            .order('scheduled_start', ascending: false)
            .limit(500);
        final list = (res as List).cast<Map<String, dynamic>>();
        return filterAndSort(list);
      },
    );
  }

  /// Realtime stream úkolů pouze pro Nástěnku – B2B měsíční výhled.
  ///
  /// PROČ: Dashboard zobrazuje Očekávaný příjem za aktuální + příští měsíc; provider předává
  /// [from] = 1. den aktuálního měsíce, [to] = poslední den příštího měsíce 23:59. Limit 1500.
  /// Filtry: tenant_id, deleted_at IS NULL, invoiced_at IS NULL, scheduled_start v [from, to].
  /// [from] a [to] – provider předává UTC.
  Stream<List<Map<String, dynamic>>> watchTasksForDashboard(
    String tenantId, {
    required DateTime from,
    required DateTime to,
  }) {
    if (tenantId.isEmpty) return Stream.value([]);

    final fromUtc = from.isUtc ? from : from.toUtc();
    final toUtc = to.isUtc ? to : to.toUtc();
    final fromIso = fromUtc.toIso8601String();
    final toIso = toUtc.toIso8601String();

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final filtered = rows
          .where((r) {
            if (r['deleted_at'] != null || r['invoiced_at'] != null) return false;
            final s = r['scheduled_start'] ?? r['due_date'];
            if (s == null) return false;
            final dt = DateTime.tryParse(s.toString());
            if (dt == null) return true;
            return !dt.isBefore(fromUtc) && !dt.isAfter(toUtc);
          })
          .toList();
      filtered.sort((a, b) {
        final aVal = a['due_date'] ?? a['scheduled_start'] ?? '';
        final bVal = b['due_date'] ?? b['scheduled_start'] ?? '';
        return aVal.toString().compareTo(bVal.toString());
      });
      return filtered;
    }

    final safeTasks = SupabaseService.safeFrom('tasks', tenantId);
    final stream = resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => safeTasks
          .stream(primaryKey: ['id'])
          .order('scheduled_start', ascending: false)
          .limit(1500)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksForDashboard',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final res = await safeTasks
            .select()
            .isFilter('deleted_at', null)
            .isFilter('invoiced_at', null)
            .gte('scheduled_start', fromIso)
            .lte('scheduled_start', toIso)
            .order('scheduled_start', ascending: false)
            .limit(1500);
        final list = (res as List).cast<Map<String, dynamic>>();
        return filterAndSort(list);
      },
    );
  }

  /// Načte všechny úkoly navázané na danou rezervaci – BEZ časového/měsíčního filtru.
  ///
  /// PROČ: V detailu rezervace (Související úkoly) musí být vidět check-in i check-out úkoly;
  /// check-out může spadat do dalšího měsíce a [watchTasksRawForMonth] by je nepřinesl.
  /// Vrací pouze úkoly s reservation_id == [reservationId], seřazené podle scheduled_start.
  static Future<List<Map<String, dynamic>>> fetchTasksForReservation(String tenantId, String reservationId) async {
    if (tenantId.isEmpty || reservationId.isEmpty) return [];
    try {
      final res = await SupabaseService.safeFrom('tasks', tenantId)
          .select()
          .eq('reservation_id', reservationId)
          .isFilter('deleted_at', null)
          .order('scheduled_start', ascending: true);
      final list = (res as List).cast<Map<String, dynamic>>();
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Načte jeden úkol podle ID – BEZ filtru deleted_at/invoiced_at.
  ///
  /// PROČ: Peněženka zobrazuje transakce vázané na úkoly (včetně dokončených/archivovaných).
  /// Admin stream tyto úkoly vyřazuje. Tato metoda umožňuje otevřít detail z transakce.
  static Future<Map<String, dynamic>?> fetchTaskById(String tenantId, String taskId) async {
    if (tenantId.isEmpty || taskId.isEmpty) return null;
    try {
      final res = await SupabaseService.safeFrom('tasks', tenantId)
          .select()
          .eq('id', taskId)
          .maybeSingle();
      return res != null ? Map<String, dynamic>.from(res as Map) : null;
    } catch (_) {
      return null;
    }
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
