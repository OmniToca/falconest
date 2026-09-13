import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/features/worker/data/services/worker_sync_service.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_provider.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_drift_stub.dart'
    if (dart.library.io) 'package:falconest/features/worker/providers/worker_sync_state_drift_io.dart'
    as drift_sync;

/// Po startu UI a při návratu z pozadí znovu spustí registraci FCM do `user_devices`.
/// Při přechodu na pozadí (paused/inactive) best-effort flush pending mutací worker app.
///
/// PROČ: Pracovník často minimalizuje app hned po dokončení úkolu – krátké okno před uspáním
/// procesu využijeme k odeslání Drift pending změn a fronty mutací na Supabase.
class AppLifecycleFcmListener extends ConsumerStatefulWidget {
  const AppLifecycleFcmListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleFcmListener> createState() =>
      _AppLifecycleFcmListenerState();
}

class _AppLifecycleFcmListenerState extends ConsumerState<AppLifecycleFcmListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).retryFcmRegistrationIfLoggedIn();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authNotifierProvider.notifier).retryFcmRegistrationIfLoggedIn();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_flushWorkerPendingMutations());
    }
  }

  /// Best-effort sync před uspáním – neblokuje UI, data zůstávají v Drift při timeoutu.
  Future<void> _flushWorkerPendingMutations() async {
    if (kIsWeb) return;

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;

    final driftRepos = drift_sync.getDriftReposForSync(ref);
    await WorkerSyncService.flushPendingUpdatesBestEffort(
      tenantId,
      driftRepos: driftRepos,
      onSyncError: ref.read(workerSyncStateProvider.notifier).reportSyncError,
      timeout: const Duration(seconds: 2),
    );
    await ref.read(mutationQueueServiceProvider).processQueue();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
