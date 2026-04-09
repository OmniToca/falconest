import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web: bez SQLite – prázdné operace, aby šel projekt zkompilovat.
class WorkerTaskChecklistOpsController {
  const WorkerTaskChecklistOpsController();

  Future<void> toggleItemCompletedQueued({
    required int driftRowId,
    required bool completed,
    required String tenantId,
    String? completedByProfileId,
  }) async {}

  Future<void> attachStubPhoto({
    required int driftRowId,
    required String tenantId,
  }) async {}

  Future<bool> captureAndSavePhoto(String taskId, String itemId) async => false;
}

final workerTaskChecklistOpsControllerProvider =
    Provider<WorkerTaskChecklistOpsController>((ref) => const WorkerTaskChecklistOpsController());
