import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/worker/models/worker_task_checklist_line.dart';

/// Web: Drift není k dispozici – žádný checklist (kompatibilní s úkoly bez šablony).
final workerTaskChecklistProvider =
    StreamProvider.autoDispose.family<List<WorkerTaskChecklistLine>, String>((ref, taskId) {
  return Stream.value(const <WorkerTaskChecklistLine>[]);
});
