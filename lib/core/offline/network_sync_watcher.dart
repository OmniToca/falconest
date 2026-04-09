import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/offline/transient_i18n_snack_provider.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/providers/connectivity_provider.dart';
import 'package:falconest/core/providers/sync_status_provider.dart';
import 'package:falconest/features/worker/data/services/worker_sync_service.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_drift_stub.dart'
    if (dart.library.io) 'package:falconest/features/worker/providers/worker_sync_state_drift_io.dart'
    as drift_sync;
import 'package:falconest/features/worker/providers/worker_sync_state_provider.dart';
import 'package:falconest/features/super_admin/services/audit_log_repository.dart';

/// Neviditelný widget, který sedí na pozadí a spouští Auto-Sync při návratu sítě.
///
/// PROČ: Tento watcher sedí na pozadí a čeká, až telefon chytí signál (např. když
/// uklízečka vyjde ze sklepa). Jakmile je online, automaticky potichu odešle všechny
/// visící změny (úkoly, rezervace, audit akce). Bez něj by musel uživatel ručně
/// zatáhnout pro refresh.
///
/// Technicky: Poslouchá [isOfflineProvider]. Při přechodu OFFLINE → ONLINE zavolá:
/// - WorkerSyncService.pushPendingUpdates (úkoly)
/// - WorkerSyncService.pushPendingReservationUpdates (rezervace)
/// - AuditLogRepository.processPendingAuditActions (restore/hard delete z Odpadkového koše)
///
/// Na webu je no-op (WorkerSyncService a AuditLog mají prázdné implementace).
class NetworkSyncWatcher extends ConsumerWidget {
  const NetworkSyncWatcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Naslouchání změně connectivity – při přechodu offline→online spustit sync.
    ref.listen<AsyncValue<bool>>(isOfflineProvider, (previous, next) {
      final wasOffline = previous?.value ?? false;
      final isNowOnline = next.value == false;
      if (wasOffline && isNowOnline) {
        ref.read(syncInProgressProvider.notifier).state = true;
        _triggerAutoSync(ref).whenComplete(() {
          ref.read(syncInProgressProvider.notifier).state = false;
        });
      }
    });

    return child;
  }

  /// Spustí odeslání všech pending změn do Supabase.
  /// Volá se při detekci přechodu z offline do online.
  Future<void> _triggerAutoSync(WidgetRef ref) async {
    if (kIsWeb) return;

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;

    final reportError = ref.read(workerSyncStateProvider.notifier).reportSyncError;

    // A) pushPendingUpdates: nejdřív odešle rezervace (pushPendingReservationUpdates),
    // poté úkoly. Jedna metoda pokryje obojí.
    await WorkerSyncService.pushPendingUpdates(
      tenantId,
      onSyncError: reportError,
      driftRepos: drift_sync.getDriftReposForSync(ref),
      onSmartMergeApplied: () {
        ref.read(transientI18nSnackKeyProvider.notifier).state =
            'worker.sync_smart_merge_snack';
      },
    );

    // B) Odeslat pending audit akce (restore/hard delete z Odpadkového koše).
    await AuditLogRepository.processPendingAuditActions();

    // C) Odeslat univerzální frontu mutací (Admin úkoly zachráněné při offline).
    await ref.read(mutationQueueServiceProvider).processQueue();
  }
}
