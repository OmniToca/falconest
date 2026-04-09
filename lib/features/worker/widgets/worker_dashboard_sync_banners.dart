import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/providers/connectivity_provider.dart';
import 'package:falconest/core/providers/sync_status_provider.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_provider.dart';

/// Bannery a indikátory synchronizace pod AppBarem na worker dashboardu.
///
/// PROČ: Personál musí vidět (1) offline režim, (2) probíhající sync, (3) chybu odeslání
/// úkolů/rezervací z [workerSyncStateProvider], (4) neprázdnou frontu [DriftMutationQueueService]
/// v online režimu – žlutý panel otevře detailní obrazovku lokální fronty mutací.
class WorkerDashboardSyncBanners extends ConsumerWidget {
  const WorkerDashboardSyncBanners({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final syncStatusAsync = ref.watch(syncStatusProvider);
    final syncError = ref.watch(workerSyncStateProvider);

    final showProgress = syncStatusAsync.isLoading ||
        (syncStatusAsync.hasValue && syncStatusAsync.requireValue.isSyncing);

    final mutationStuckOnline = syncStatusAsync.maybeWhen(
      data: (s) => !s.isOffline && s.pendingCount > 0 && !s.isSyncing,
      orElse: () => false,
    );
    final pendingMutationCount = syncStatusAsync.maybeWhen(
      data: (s) => s.pendingCount,
      orElse: () => 0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.orange.shade700,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'worker.offline_mode_banner'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (showProgress)
          Semantics(
            label: 'worker.sync_processing'.tr(),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.blue.shade100,
              color: Colors.blue.shade700,
            ),
          ),
        if (syncError != null && syncError.isNotEmpty)
          Material(
            color: Colors.red.shade700,
            child: InkWell(
              onTap: () => ref.read(workerSyncStateProvider.notifier).clearSyncError(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.error_outline, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'worker.sync_push_failed_title'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            syncError,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'worker.sync_push_failed_dismiss_hint'.tr(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.close, color: Colors.white.withValues(alpha: 0.9), size: 20),
                  ],
                ),
              ),
            ),
          ),
        if (mutationStuckOnline && pendingMutationCount > 0)
          Material(
            color: Colors.amber.shade900,
            child: InkWell(
              onTap: () {
                // PROČ: Detail fronty a ruční sync na samostatné obrazovce – přehlednější než tichý processQueue.
                context.pushNamed('workerMutationQueue');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.cloud_upload, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'worker.sync_mutation_queue_title'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'worker.sync_mutation_queue_body'.tr(
                              namedArgs: {'count': '$pendingMutationCount'},
                            ),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'worker.sync_mutation_queue_tap_open'.tr(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
