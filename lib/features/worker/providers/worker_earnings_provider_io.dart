import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/features/worker/models/worker_earnings_models.dart';

/// Výdělky z lokálního Driftu – reaktivní stream po syncu nebo změně úkolů (JOIN název).
///
/// PROČ: Striktní offline-first; Supabase se volá jen ve [WorkerSyncService], ne z této obrazovky.
final myEarningsProvider = StreamProvider.autoDispose<WorkerEarningsSummary>((ref) {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final profileId = ref.watch(authNotifierProvider).profileId;
  if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
    return Stream.value(
      const WorkerEarningsSummary(pendingTotal: 0, paidTotal: 0, rows: []),
    );
  }
  final repo = ref.watch(driftTaskPayoutRepositoryProvider);
  return repo.watchEarningsForProfile(tenantId, profileId).map((snap) {
    // PROČ: Surový název z Drift JOINu; popisek výplata vs. provize formátuje UI přes worker.earnings.*_for_task.
    final rows = snap.rows
        .map(
          (line) => WorkerEarningsRow(
            id: line.id,
            taskId: line.taskId,
            taskTitle: line.taskTitle,
            completedAt: line.completedAt,
            amount: line.amount,
            status: line.status,
            isCommission: line.isCommission,
          ),
        )
        .toList();
    return WorkerEarningsSummary(
      pendingTotal: snap.pendingTotal,
      paidTotal: snap.paidTotal,
      rows: rows,
    );
  });
});
