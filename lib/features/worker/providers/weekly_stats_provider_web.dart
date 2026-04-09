import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/worker/providers/weekly_stats_types.dart';
import 'package:falconest/features/worker/providers/worker_dashboard_provider.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';

/// Web: žádný Drift – statistiky z [workerTasksProvider] dle plánovaného začátku v týdnu (původní chování).
final weeklyStatsProvider = Provider<AsyncValue<WeeklyStats>>((ref) {
  final tasksAsync = ref.watch(workerTasksProvider);
  return tasksAsync.when(
    data: (tasks) {
      final weekTasks = tasks.where((t) => weeklyStatsIsScheduledInCurrentWeek(t.scheduledStart)).toList();
      final totalTasks = weekTasks.length;
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
