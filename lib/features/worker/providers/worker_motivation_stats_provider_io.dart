import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';

/// Měsíční motivační metriky z Driftu (offline-first) – reaktivně při změně lokálních úkolů.
///
/// PROČ: Stejný zdroj pravdy jako týdenní statistiky v draweru; po dokončení úkolu se karta přepočítá.
final workerMotivationStatsProvider = StreamProvider.autoDispose<WorkerMonthMotivationStats>((ref) {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final workerId = ref.watch(authNotifierProvider).profileId;
  if (tenantId == null ||
      tenantId.isEmpty ||
      workerId == null ||
      workerId.isEmpty) {
    return Stream.value(
      const WorkerMonthMotivationStats(
        completedCount: 0,
        workedHours: 0,
        onTimeCount: 0,
        onTimeEligibleCount: 0,
      ),
    );
  }
  final repo = ref.watch(driftTaskRepositoryProvider);
  return repo.watchMonthlyMotivationStats(tenantId, workerId);
});
