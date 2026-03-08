import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/sync_status_provider.dart';
import 'package:falconest/features/worker/data/services/worker_sync_service.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_drift_stub.dart'
    if (dart.library.io) 'package:falconest/features/worker/providers/worker_sync_state_drift_io.dart' as drift_sync;

/// Stav synchronizace – pro UI upozornění na selhání push do Supabase.
///
/// Uchovává poslední chybovou zprávu a umožňuje ji smazat (např. po znovu obnovení).
class WorkerSyncStateNotifier extends StateNotifier<String?> {
  WorkerSyncStateNotifier(this._ref) : super(null);

  final Ref _ref;

  /// Nastaví chybu – volá se z WorkerSyncService.onSyncError.
  void reportSyncError(String message) {
    state = message;
  }

  /// Smaže chybovou zprávu (uživatel zavře banner nebo zkusí znovu).
  void clearSyncError() {
    state = null;
  }

  /// Provede plnou synchronizaci a při chybě nastaví reportSyncError.
  /// PROČ: syncInProgressProvider – SyncStatusIcon zobrazí stav „Syncing“ během běhu.
  Future<void> runSync() async {
    state = null;
    final tenantId = _ref.read(authNotifierProvider).tenantIdForData;
    final workerId = _ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null || workerId == null) return;

    _ref.read(syncInProgressProvider.notifier).state = true;
    try {
      await WorkerSyncService.syncTasksFromSupabase(
        workerId,
        tenantId,
        onSyncError: reportSyncError,
        driftRepos: drift_sync.getDriftReposForSync(_ref) as dynamic,
      );
    } finally {
      _ref.read(syncInProgressProvider.notifier).state = false;
    }
  }
}

/// Provider pro stav synchronizace – sleduje, zda push na backend selhal.
final workerSyncStateProvider =
    StateNotifierProvider<WorkerSyncStateNotifier, String?>((ref) {
  return WorkerSyncStateNotifier(ref);
});

/// Počet záznamů čekajících na odeslání (úkoly + rezervace s syncStatus pending).
final workerPendingSyncCountProvider =
    FutureProvider.family<int, String>((ref, tenantId) async {
  final driftRepos = drift_sync.getDriftReposForSync(ref);
  return WorkerSyncService.getPendingSyncCount(tenantId, driftRepos: driftRepos);
});
