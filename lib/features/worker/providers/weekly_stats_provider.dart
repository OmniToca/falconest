import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/worker/providers/worker_dashboard_provider.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';

/// Agregované statistiky úkolů pro aktuální kalendářní týden (po–ne).
///
/// Používá se v Drawer pro zobrazení přehledu týdne – počet úkolů a součet
/// odhadovaných minut. Reaktivně se přepočítá při změně workerTasksProvider.
class WeeklyStats {
  const WeeklyStats({
    required this.totalTasks,
    required this.totalEstimatedMinutes,
  });

  final int totalTasks;
  final int totalEstimatedMinutes;

  /// Hodiny pro zobrazení (minuty / 60, zaokrouhleno na 1 des. místo).
  double get totalHours => totalEstimatedMinutes / 60.0;
}

/// Vrátí začátek aktuálního týdne (pondělí 00:00) v lokálním čase.
/// PROČ: ISO 8601 týden začíná pondělím – konzistentní s evropským kalendářem.
DateTime _startOfWeek(DateTime now) {
  final daysFromMonday = now.weekday - 1; // 0 = pondělí, 6 = neděle
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysFromMonday));
}

/// Vrátí konec aktuálního týdne (neděle 23:59:59.999) v lokálním čase.
DateTime _endOfWeek(DateTime now) {
  final start = _startOfWeek(now);
  return start.add(const Duration(
    days: 6,
    hours: 23,
    minutes: 59,
    seconds: 59,
    milliseconds: 999,
  ));
}

/// Filtruje úkoly, jejichž scheduledStart spadá do aktuálního kalendářního týdne.
bool _isInCurrentWeek(DateTime scheduledStart) {
  final now = DateTime.now();
  final start = _startOfWeek(now);
  final end = _endOfWeek(now);
  return !scheduledStart.isBefore(start) && !scheduledStart.isAfter(end);
}

/// Provider pro statistiky týdne – počet úkolů a součet odhadovaných minut.
///
/// Filtruje workerTasksProvider podle aktuálního kalendářního týdne (po–ne).
/// Odhad minut se parsuje z description/metadata pomocí parseTaskEstimateMinutes.
final weeklyStatsProvider = Provider<AsyncValue<WeeklyStats>>((ref) {
  final tasksAsync = ref.watch(workerTasksProvider);
  return tasksAsync.when(
    data: (tasks) {
      final weekTasks = tasks.where((t) => _isInCurrentWeek(t.scheduledStart)).toList();
      final totalTasks = weekTasks.length;
      // Součet odhadů – WorkerTask nemá metadata, předáváme null; regex v description funguje.
      final totalEstimatedMinutes = weekTasks.fold<int>(
        0,
        (sum, t) => sum + parseTaskEstimateMinutes(t.description, null),
      );
      return AsyncValue.data(WeeklyStats(
        totalTasks: totalTasks,
        totalEstimatedMinutes: totalEstimatedMinutes,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
