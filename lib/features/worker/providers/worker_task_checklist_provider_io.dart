import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/features/worker/models/worker_task_checklist_line.dart';
import 'package:falconest_drift/app_database.dart' as drift_db;

/// Reaktivní seznam položek checklistu z Driftu pro daný úkol (UUID).
///
/// PROČ: [StreamProvider] překreslí UI po každém odškrtnutí nebo přidání fotky.
final workerTaskChecklistProvider =
    StreamProvider.autoDispose.family<List<WorkerTaskChecklistLine>, String>((ref, taskId) {
  if (taskId.isEmpty) return Stream.value(const []);
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return Stream.value(const []);
  final repo = ref.watch(driftTaskChecklistRepositoryProvider);
  return repo.watchItemsForTask(tenantId, taskId).map(_mapRows);
});

List<WorkerTaskChecklistLine> _mapRows(List<drift_db.TaskChecklistItem> rows) {
  return rows
      .map(
        (r) => WorkerTaskChecklistLine(
          driftRowId: r.id,
          supabaseItemId: r.supabaseId,
          title: r.title,
          isPhotoRequired: r.isPhotoRequired,
          isCompleted: r.isCompleted,
          photoUrl: r.photoUrl,
          localPhotoPath: r.localPhotoPath,
        ),
      )
      .toList();
}
