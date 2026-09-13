import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/connectivity_provider.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/core/repositories/task/task_repository_provider_export.dart';
import 'package:falconest/features/worker/data/services/worker_sync_service.dart';
import 'package:falconest/features/worker/providers/worker_dashboard_provider.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_provider.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_drift_stub.dart'
    if (dart.library.io) 'package:falconest/features/worker/providers/worker_sync_state_drift_io.dart'
    as drift_sync;

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

/// Načte detail úkolu – používá taskRepositoryProvider (web: Supabase, mobil: Drift).
final workerTaskDetailProvider =
    FutureProvider.family<WorkerTaskDetail?, String>((ref, taskId) async {
  if (taskId.isEmpty) return null;
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return null;

  try {
    final repo = ref.watch(taskRepositoryProvider);
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

  /// [startedAt] – při přechodu do in_progress (Time Tracking).
  /// [completedAt] – při přechodu do completed (Time Tracking).
  /// [metadataOverlay] – volitelně sloučí klíče do metadata (např. cash_collection_failed).
  /// [mediaUrls] – URL fotek z Supabase Storage (úkoly s requires_photo).
  /// [localPhotoPaths] – při offline cesty k zkopírovaným fotkám (mobil).
  /// [existingMediaUrls] – již nahrané URL při offline flow pro merge v procesoru.
  /// [flushToServerWhenOnline] – při online krátce počká na push pending změn (mobil).
  Future<void> updateStatus(
    String taskId,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadataOverlay,
    List<String>? mediaUrls,
    List<String>? localPhotoPaths,
    List<String>? existingMediaUrls,
    bool flushToServerWhenOnline = true,
  }) async {
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

      final repo = _ref.read(taskRepositoryProvider);
      await repo.updateTaskStatus(
        tenantId,
        taskId,
        status,
        startedAt: startedAt,
        completedAt: completedAt,
        metadataOverlay: metadataOverlay,
        mediaUrls: mediaUrls,
        localPhotoPaths: localPhotoPaths,
        existingMediaUrls: existingMediaUrls,
      );

      _ref.invalidate(workerTaskDetailProvider(taskId));
      _ref.invalidate(workerTasksProvider);

      final driftRepos = drift_sync.getDriftReposForSync(_ref);
      final onSyncError =
          _ref.read(workerSyncStateProvider.notifier).reportSyncError;
      final isOnline = _ref.read(isOfflineProvider).valueOrNull == false;

      if (flushToServerWhenOnline && isOnline) {
        await WorkerSyncService.flushPendingUpdatesBestEffort(
          tenantId,
          onSyncError: onSyncError,
          driftRepos: driftRepos,
        );
      } else {
        unawaited(WorkerSyncService.pushPendingUpdates(
          tenantId,
          onSyncError: onSyncError,
          driftRepos: driftRepos,
        ));
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final workerTaskStatusNotifierProvider =
    StateNotifierProvider<WorkerTaskStatusNotifier, AsyncValue<void>>((ref) {
  return WorkerTaskStatusNotifier(ref);
});
