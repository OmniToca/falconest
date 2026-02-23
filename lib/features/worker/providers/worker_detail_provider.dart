import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/core/repositories/task/task_repository_export.dart';
import 'package:falconest/features/worker/data/services/worker_sync_service.dart';
import 'package:falconest/features/worker/providers/worker_dashboard_provider.dart';

/// Re-export WorkerTaskDetail pro konzumenty (Worker UI).
export 'package:falconest/core/repositories/task/task_repository.dart' show WorkerTaskDetail;

/// Rozšíření WorkerTaskDetail o pomocné gettery pro UI (canStart, isInProgress, isCompleted).
extension WorkerTaskDetailExt on WorkerTaskDetail {
  bool get canStart {
    final s = status.trim().toLowerCase();
    return s == 'pending' || s == 'assigned' || s == 'draft' || s == 'nový' || s == 'new';
  }

  bool get isInProgress {
    final s = status.trim().toLowerCase();
    return s == 'in_progress' || s == 'probíhá';
  }

  bool get isCompleted {
    final s = status.trim().toLowerCase();
    return s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo';
  }
}

/// Načte detail úkolu – používá ITaskRepository (web: Supabase, mobil: Isar).
final workerTaskDetailProvider =
    FutureProvider.family<WorkerTaskDetail?, String>((ref, taskId) async {
  if (taskId.isEmpty) return null;
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return null;

  try {
    final repo = getTaskRepository();
    return repo.getWorkerTaskDetail(tenantId, taskId);
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('WorkerTaskDetail: REPO ERROR: $e');
    }
    return null;
  }
});

/// Provider pro aktualizaci stavu úkolu (zahájit/dokončit).
class WorkerTaskStatusNotifier extends StateNotifier<AsyncValue<void>> {
  WorkerTaskStatusNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> updateStatus(String taskId, String status) async {
    state = const AsyncValue.loading();
    final tenantId = _ref.read(authNotifierProvider).tenantIdForData;

    try {
      if (tenantId == null || tenantId.isEmpty) {
        state = AsyncValue.error(
          Exception('Tenant nedostupný'),
          StackTrace.current,
        );
        return;
      }

      final repo = getTaskRepository();
      await repo.updateTaskStatus(tenantId, taskId, status);

      _ref.invalidate(workerTaskDetailProvider(taskId));
      _ref.invalidate(workerTasksProvider);
      state = const AsyncValue.data(null);

      unawaited(WorkerSyncService.pushPendingUpdates(tenantId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final workerTaskStatusNotifierProvider =
    StateNotifierProvider<WorkerTaskStatusNotifier, AsyncValue<void>>((ref) {
  return WorkerTaskStatusNotifier(ref);
});
