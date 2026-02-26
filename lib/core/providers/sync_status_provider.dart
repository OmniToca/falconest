import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/providers/connectivity_provider.dart';

/// Stav synchronizace pro SyncStatusIcon – agreguje síť, frontu a běžící sync.
///
/// PROČ: Jednoduchá immutable třída – Riverpod preferuje value objects.
/// Umožňuje ikoně rozhodnout, který vizuální stav zobrazit.
class SyncStatusState {
  const SyncStatusState({
    required this.isOffline,
    required this.isSyncing,
    required this.pendingCount,
  });

  final bool isOffline;
  final bool isSyncing;
  final int pendingCount;

  /// Vše synchronizováno – online, žádná fronta, sync neběží.
  bool get isSynced => !isOffline && pendingCount == 0 && !isSyncing;

  /// Offline s položkami čekajícími na odeslání.
  bool get hasOfflinePending => isOffline && pendingCount > 0;
}

/// Globální příznak, že právě běží odesílání (runSync nebo auto-sync z NetworkSyncWatcher).
///
/// PROČ: StateProvider – jednoduchý bool, nastavuje se z WorkerSyncStateNotifier.runSync
/// a z NetworkSyncWatcher._triggerAutoSync. SyncStatusIcon z něj čte pro stav „Syncing“.
final syncInProgressProvider = StateProvider<bool>((ref) => false);

/// Agregovaný stav synchronizace pro SyncStatusIcon.
///
/// PROČ: StreamProvider s periodickým poll every 2 s – Isar nemá push notifikace,
/// pendingCount musíme načítat ručně. Při každém ticku čteme isOffline, isSyncing
/// a pendingCount. Na webu vracíme konstantu (vždy synced).
final syncStatusProvider = StreamProvider<SyncStatusState>((ref) async* {
  if (kIsWeb) {
    yield const SyncStatusState(isOffline: false, isSyncing: false, pendingCount: 0);
    return;
  }

  final mutationQueue = ref.read(mutationQueueServiceProvider);

  while (true) {
    final isOffline = ref.read(isOfflineProvider).value ?? false;
    final isSyncing = ref.read(syncInProgressProvider);
    final count = await mutationQueue.getPendingCount();
    yield SyncStatusState(
      isOffline: isOffline,
      isSyncing: isSyncing,
      pendingCount: count,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
  }
});
