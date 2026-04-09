import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/features/worker/providers/weekly_stats_types.dart';

/// Týdenní přehled z Driftu – dokončené úkoly s `completed_at` v aktuálním týdnu.
///
/// PROČ: Drawer má odrážet skutečně odvedenou práci, ne plán; data jsou 100 % lokální.
final weeklyStatsProvider = StreamProvider.autoDispose<WeeklyStats>((ref) {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final workerId = ref.watch(authNotifierProvider).profileId;
  if (tenantId == null || tenantId.isEmpty || workerId == null || workerId.isEmpty) {
    return Stream.value(const WeeklyStats(totalTasks: 0, totalEstimatedMinutes: 0));
  }
  final repo = ref.watch(driftTaskRepositoryProvider);
  return repo.watchWeeklyCompletedTaskStats(tenantId, workerId).map(
        (s) => WeeklyStats(
          totalTasks: s.totalTasks,
          totalEstimatedMinutes: s.totalEstimatedMinutes,
        ),
      );
});
