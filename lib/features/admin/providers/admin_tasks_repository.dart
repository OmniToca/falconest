import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/utils/supabase_stream_helper.dart';

/// Repozitář pro úkoly v Admin modulu – Realtime stream.
///
/// Slouží pro okamžitou aktualizaci seznamu úkolů bez nutnosti F5.
/// Future metody (select, insert) zůstávají v AdminTasksNotifier.
class AdminTasksRepository {
  AdminTasksRepository._();
  static final AdminTasksRepository instance = AdminTasksRepository._();

  /// Spodní hranice pro zobrazení **dokončených** úkolů v hlavním admin seznamu (UTC).
  ///
  /// PROČ: Bez časového řezu by dispečink musel stahovat celou historii (tisíce řádků) –
  /// nahrazujeme dřívější tichý `limit(500)`. Neúplné úkoly (`completed_at == null`) bereme
  /// vždy celé. Dokončené jen od min(začátek běžícího měsíce, 30 dní zpět) – dispečer vidí
  /// operativu i čerstvě uzavřené zakázky, ale ne roky starý archiv.
  static DateTime _adminTaskListCompletedVisibilityCutoffUtc() {
    final now = DateTime.now().toUtc();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final monthStart = DateTime.utc(now.year, now.month, 1);
    return thirtyDaysAgo.isBefore(monthStart) ? thirtyDaysAgo : monthStart;
  }

  /// PostgREST `or` pro větev „ještě ne hotovo“ / „hotovo v okně“.
  static String _orOpenOrRecentCompleted(DateTime cutoffUtc) {
    final iso = cutoffUtc.toIso8601String();
    return 'completed_at.is.null,completed_at.gte."$iso"';
  }

  static DateTime? _parseDateTimeField(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    return null;
  }

  /// Strop řádků pro Supabase `.stream()` – **ne** náhrada business logiky.
  ///
  /// PROČ: Realtime klient povoluje jen **jeden** stream filtr (u nás už obsazený `tenant_id`
  /// přes [SafeTenantTable.stream]). Nelze současně poslat `or(completed_at…)` na úrovni
  /// subscription. Výběr podle data dokončení řeší [initialFetch] (PostgREST) a [filterAndSort]
  /// v `.map()`. Tento limit je výhradně pojistka proti OOM při interním `_getPostgrestData`
  /// po reconnectu – hodnotu držíme vysoko, aby velcí klienti neztráceli data jako u 500.
  static const int _streamPostgrestSafetyLimit = 15000;

  /// Úzká projekce sloupců pro admin seznamy / Realtime initialFetch (P1 výkon).
  ///
  /// PROČ: `select()` tahá i `geo_location`, `search_vector`, velké JSON – zbytečný egress.
  /// `metadata` + `media_urls` zůstávají (Kanban cash/tagy, počet fotek). Detail úkolu
  /// dál používá plný `select()` přes [fetchTaskById].
  ///
  /// Při chybějícím sloupci na produkci (migrace ještě neběžela) [fetchTaskMapsWithFallback]
  /// spadne na `select(*)`, aby Nástěnka/Úkoly nespadly na červené chybové obrazovce.
  static const String taskListSelectColumns =
      'id, tenant_id, apartment_id, client_id, reservation_id, service_id, '
      'reference_number, title, description, status, task_type, '
      'due_date, scheduled_start, assigned_to, assigned_user_ids, '
      'custom_title, custom_location, metadata, media_urls, '
      'deleted_at, invoiced_at, unassigned_info, created_by, created_at, '
      'started_at, completed_at';

  static bool _isMissingColumnError(Object e) {
    if (e is PostgrestException) {
      return e.code == '42703' ||
          e.message.contains('column') ||
          e.message.contains('does not exist');
    }
    final s = e.toString();
    return s.contains('42703') ||
        s.contains('column') ||
        s.contains('does not exist');
  }

  static List<Map<String, dynamic>> _asTaskMapList(dynamic res) {
    final out = <Map<String, dynamic>>[];
    if (res is! List) return out;
    for (final raw in res) {
      if (raw is Map) out.add(Map<String, dynamic>.from(raw));
    }
    return out;
  }

  /// SELECT s úzkou projekcí; při chybějícím sloupci v DB → `select(*)`.
  static Future<List<Map<String, dynamic>>> fetchTaskMapsWithFallback(
    Future<dynamic> Function(String columns) runQuery,
  ) async {
    try {
      return _asTaskMapList(await runQuery(taskListSelectColumns));
    } catch (e, st) {
      if (!_isMissingColumnError(e)) rethrow;
      AppLogger.error(
        'AdminTasksRepository: úzký select selhal (chybějící sloupec) – fallback select(*)',
        e,
        st,
      );
      return _asTaskMapList(await runQuery('*'));
    }
  }

  /// Realtime stream úkolů pro daného tenanta.
  ///
  /// PROČ: Úvodní [initialFetch] používá časové okno v SQL (`or` na completed_at). Streamová
  /// větev kvůli omezení SDK filtruje v `.map()` a má jen technický strop řádků (viz [_streamPostgrestSafetyLimit]).
  Stream<List<Map<String, dynamic>>> watchTasksRaw(String tenantId) {
    if (tenantId.isEmpty) return Stream.value([]);

    final cutoffUtc = _adminTaskListCompletedVisibilityCutoffUtc();
    final orCompleted = _orOpenOrRecentCompleted(cutoffUtc);

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final filtered = rows.where((r) {
        if (r['deleted_at'] != null || r['invoiced_at'] != null) return false;
        final completedAt = _parseDateTimeField(r['completed_at']);
        if (completedAt == null) return true;
        return !completedAt.isBefore(cutoffUtc);
      }).toList();
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
          .limit(_streamPostgrestSafetyLimit)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksRaw',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final list = await fetchTaskMapsWithFallback(
            (cols) => safeTasks
                .select(cols)
            .isFilter('deleted_at', null)
            .isFilter('invoiced_at', null)
            .or(orCompleted)
            .order('scheduled_start', ascending: false),
            );
        return filterAndSort(list);
      },
    );
  }

  /// Realtime stream úkolů pro daného tenanta omezený na jeden měsíc.
  ///
  /// PROČ: [initialFetch] omezuje `scheduled_start` v DB. Stream má stejný řez přes `.map()`
  /// a technický strop kvůli Realtime API (viz [_streamPostgrestSafetyLimit]).
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
          .limit(_streamPostgrestSafetyLimit)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksRawForMonth',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final list = await fetchTaskMapsWithFallback(
            (cols) => safeTasks
                .select(cols)
            .isFilter('deleted_at', null)
            .gte('scheduled_start', startIso)
            .lt('scheduled_start', endIso)
            .order('scheduled_start', ascending: false),
            );
        return filterAndSort(list);
      },
    );
  }

  /// Kanonické ops okno: dnes −7 dní → konec příštího měsíce (UTC hranice z lokálního kalendáře).
  ///
  /// PROČ (P1): Nástěnka (aktuální + příští měsíc) a vytížení personálu (−7/+14) sdílejí jeden
  /// Realtime kanál místo dvou plných dumpů až 15k řádků. Derived providery filtrují v paměti.
  static (DateTime fromUtc, DateTime toUtc) opsWindowBoundsUtc() {
    final now = DateTime.now();
    final fromLocal =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final nextMonth =
        now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
    final toLocal = DateTime(nextMonth.year, nextMonth.month + 1, 0, 23, 59, 59, 999);
    return (fromLocal.toUtc(), toLocal.toUtc());
  }

  /// Jeden Realtime stream pro Nástěnku + vytížení týmu (viz [opsWindowBoundsUtc]).
  Stream<List<Map<String, dynamic>>> watchTasksRawForOpsWindow(String tenantId) {
    if (tenantId.isEmpty) return Stream.value([]);

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final (fromUtc, toUtc) = opsWindowBoundsUtc();
      final filtered = rows.where((r) {
        if (r['deleted_at'] != null || r['invoiced_at'] != null) return false;
        final s = r['scheduled_start'] ?? r['due_date'];
        if (s == null) return false;
        final dt = DateTime.tryParse(s.toString());
        if (dt == null) return true;
        final utc = dt.toUtc();
        return !utc.isBefore(fromUtc) && !utc.isAfter(toUtc);
      }).toList();
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
          .limit(_streamPostgrestSafetyLimit)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksRawForOpsWindow',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final (fromUtc, toUtc) = opsWindowBoundsUtc();
        final fromIso = fromUtc.toIso8601String();
        final toIso = toUtc.toIso8601String();
        final list = await fetchTaskMapsWithFallback(
            (cols) => safeTasks
                .select(cols)
            .isFilter('deleted_at', null)
            .isFilter('invoiced_at', null)
            .gte('scheduled_start', fromIso)
            .lte('scheduled_start', toIso)
            .order('scheduled_start', ascending: false),
            );
        return filterAndSort(list);
      },
    );
  }

  /// Realtime stream úkolů pouze pro Nástěnku – B2B měsíční výhled.
  ///
  /// PROČ: [initialFetch] drží `scheduled_start` mezi [from] a [to]. Stream – stejné omezení
  /// v `.map()` + technický strop (_streamPostgrestSafetyLimit).
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
          .limit(_streamPostgrestSafetyLimit)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksForDashboard',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final list = await fetchTaskMapsWithFallback(
            (cols) => safeTasks
                .select(cols)
            .isFilter('deleted_at', null)
            .isFilter('invoiced_at', null)
            .gte('scheduled_start', fromIso)
            .lte('scheduled_start', toIso)
            .order('scheduled_start', ascending: false),
            );
        return filterAndSort(list);
      },
    );
  }

  /// Typ úkolu = úklid (stejná heuristika jako u stavu apartmánu v administraci).
  static bool _isCleaningTaskRow(Map<String, dynamic> r) {
    final t = (r['task_type']?.toString() ?? '').toLowerCase();
    return t == 'cleaning' || t.contains('cleaning') || t.contains('úklid');
  }

  /// Stream úklidových úkolů pro výpočet stavu bytu – **nezávislý na [selectedTaskMonthProvider]**.
  ///
  /// PROČ: Zahrnuje (1) otevřené úklidy se splatností do konce **dnešního** lokálního dne
  /// nebo bez termínu, (2) dokončené úklidy za posledních 400 dní (turnover po checkoutu).
  /// Globální seznam úkolů v UI dál používá [watchTasksRaw] / měsíční řez – ten nesmí řídit stav bytu.
  Stream<List<Map<String, dynamic>>> watchTasksRawForApartmentStatus(String tenantId) {
    if (tenantId.isEmpty) return Stream.value([]);

    final now = DateTime.now();
    final endOfTodayLocal = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final endOfTodayUtc = endOfTodayLocal.toUtc();
    final cutoffUtc = DateTime.now().toUtc().subtract(const Duration(days: 400));
    final cutoffIso = cutoffUtc.toIso8601String();

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final filtered = rows.where((r) {
        if (r['deleted_at'] != null || r['invoiced_at'] != null) return false;
        if (!_isCleaningTaskRow(r)) return false;
        final completedAt = _parseDateTimeField(r['completed_at']);
        if (completedAt != null) {
          return !completedAt.isBefore(cutoffUtc);
        }
        final sched = _parseDateTimeField(r['scheduled_start']);
        final due = _parseDateTimeField(r['due_date']);
        final taskDate = sched ?? due;
        if (taskDate == null) return true;
        return !taskDate.isAfter(endOfTodayUtc);
      }).toList();
      filtered.sort((a, b) {
        final aVal = a['due_date'] ?? a['scheduled_start'] ?? '';
        final bVal = b['due_date'] ?? b['scheduled_start'] ?? '';
        return aVal.toString().compareTo(bVal.toString());
      });
      return filtered;
    }

    final safeTasks = SupabaseService.safeFrom('tasks', tenantId);
    final orCompleted = 'completed_at.is.null,completed_at.gte."$cutoffIso"';
    final stream = resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => safeTasks
          .stream(primaryKey: ['id'])
          .order('scheduled_start', ascending: false)
          .limit(_streamPostgrestSafetyLimit)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksRawForApartmentStatus',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final list = await fetchTaskMapsWithFallback(
            (cols) => safeTasks
                .select(cols)
            .isFilter('deleted_at', null)
            .isFilter('invoiced_at', null)
            .or(orCompleted)
            .order('scheduled_start', ascending: false),
            );
        return filterAndSort(list);
      },
    );
  }

  /// Lokální okno „dnes − 7 dní“ až „dnes + 14 dní“ pro výpočet vytížení na kartách Personálu (hranice v UTC).
  ///
  /// PROČ: Dispečer pracuje v lokálním kalendáři; stejné okno použijeme v SQL i při filtrování streamu.
  /// Při každém průchodu filtru znovu voláme [DateTime.now()], aby se okno po půlnoci posunulo bez nové subscription.
  static (DateTime startUtc, DateTime endUtc) teamWorkloadWindowBoundsUtc() {
    final now = DateTime.now();
    final startLocal =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final endLocal = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .add(const Duration(days: 14));
    return (startLocal.toUtc(), endLocal.toUtc());
  }

  /// Realtime stream úkolů jen pro okno výpočtu vytížení na obrazovce Personál.
  ///
  /// PROČ: Karty personálu nesmí záviset na [selectedTaskMonthProvider] ze záložky Úkoly – jinak by se
  /// metriky měnily při přepnutí měsíce. Úzké okno (~21 dní) výrazně omezí počet řádků oproti celému měsíci.
  /// Initial fetch spojí dva dotazy (scheduled_start a due_date), aby neunikly úkoly s termínem jen v jednom sloupci.
  ///
  /// Poznámka P1: UI preferuje derived filtr z [watchTasksRawForOpsWindow]; tato metoda zůstává
  /// pro případné izolované použití / zpětnou kompatibilitu.
  Stream<List<Map<String, dynamic>>> watchTasksRawForTeamWorkloadWindow(String tenantId) {
    if (tenantId.isEmpty) return Stream.value([]);

    bool isInWorkloadWindow(Map<String, dynamic> r) {
      if (r['deleted_at'] != null || r['invoiced_at'] != null) return false;
      final (startUtc, endUtc) = teamWorkloadWindowBoundsUtc();
      final s = r['scheduled_start'] ?? r['due_date'];
      if (s == null) return false;
      final dt = DateTime.tryParse(s.toString());
      if (dt == null) return false;
      final utc = dt.toUtc();
      return !utc.isBefore(startUtc) && !utc.isAfter(endUtc);
    }

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final filtered = rows.where(isInWorkloadWindow).toList();
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
          .limit(_streamPostgrestSafetyLimit)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminTasksRepository.watchTasksRawForTeamWorkloadWindow',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final (startUtc, endUtc) = teamWorkloadWindowBoundsUtc();
        final startIso = startUtc.toIso8601String();
        final endIso = endUtc.toIso8601String();

        Future<List<Map<String, dynamic>>> loadByColumn(String column) async {
          return fetchTaskMapsWithFallback(
              (cols) => safeTasks
                  .select(cols)
              .isFilter('deleted_at', null)
              .isFilter('invoiced_at', null)
              .gte(column, startIso)
              .lte(column, endIso)
              .order('scheduled_start', ascending: false),
              );
        }

        final byId = <String, Map<String, dynamic>>{};
        for (final r in await loadByColumn('scheduled_start')) {
          final id = r['id']?.toString();
          if (id != null && id.isNotEmpty) byId[id] = r;
        }
        for (final r in await loadByColumn('due_date')) {
          final id = r['id']?.toString();
          if (id != null && id.isNotEmpty) byId[id] = r;
        }
        return filterAndSort(byId.values.toList());
      },
    );
  }

  /// Načte všechny úkoly navázané na danou rezervaci – BEZ časového/měsíčního filtru.
  static Future<List<Map<String, dynamic>>> fetchTasksForReservation(String tenantId, String reservationId) async {
    if (tenantId.isEmpty || reservationId.isEmpty) return [];
    try {
      return fetchTaskMapsWithFallback(
          (cols) => SupabaseService.safeFrom('tasks', tenantId)
              .select(cols)
          .eq('reservation_id', reservationId)
          .isFilter('deleted_at', null)
          .order('scheduled_start', ascending: true),
          );
    } catch (e, st) {
      AppLogger.error('AdminTasksRepository.fetchTasksForReservation selhal', e, st);
      return [];
    }
  }

  /// Načte jeden úkol podle ID – BEZ filtru deleted_at/invoiced_at.
  static Future<Map<String, dynamic>?> fetchTaskById(String tenantId, String taskId) async {
    if (tenantId.isEmpty || taskId.isEmpty) return null;
    try {
      final res = await SupabaseService.safeFrom('tasks', tenantId)
          .select()
          .eq('id', taskId)
          .maybeSingle();
      return res != null ? Map<String, dynamic>.from(res as Map) : null;
    } catch (e, st) {
      AppLogger.error('AdminTasksRepository.fetchTaskById selhal', e, st);
      return null;
    }
  }

  static Stream<T> _streamWithInitialFetch<T>({
    required Stream<T> stream,
    required Future<T> Function() initialFetch,
  }) async* {
    yield await initialFetch();
    yield* stream;
  }
}
