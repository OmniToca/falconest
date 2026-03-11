import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/providers/sync_status_provider.dart';

/// Vizuální indikátor stavu synchronizace – zobrazuje v AppBar, zda jsou data
/// synchronizována, čekají offline, nebo právě probíhá odesílání.
///
/// PROČ: Samostatný widget – lze vložit do libovolného AppBar (dashboard, task screens).
/// Používá syncStatusProvider, který agreguje connectivity, MutationQueueService
/// a syncInProgressProvider. Uživatel (uklízečka, řidič) okamžitě vidí, zda jsou
/// jeho změny v cloudu.
class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(syncStatusProvider);

    return statusAsync.when(
      data: (state) => _buildIcon(context, state),
      loading: () => _buildIcon(
        context,
        const SyncStatusState(isOffline: false, isSyncing: true, pendingCount: 0),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// Vykreslí ikonu podle stavu – synced, offline+pending, nebo syncing.
  Widget _buildIcon(BuildContext context, SyncStatusState state) {
    final Color iconColor;
    final IconData icon;
    final String tooltip;

    if (state.isSyncing) {
      iconColor = Colors.blue.shade700;
      icon = Icons.cloud_sync;
      tooltip = 'sync_status.syncing'.tr();
    } else if (state.hasOfflinePending) {
      iconColor = Colors.orange.shade700;
      icon = Icons.cloud_off;
      tooltip = 'sync_status.offline_pending'.tr(namedArgs: {'count': '${state.pendingCount}'});
    } else if (state.isSynced) {
      iconColor = Colors.green.shade700;
      icon = Icons.cloud_done;
      tooltip = 'sync_status.synced'.tr();
    } else {
      // Offline, žádná fronta
      iconColor = Colors.grey.shade600;
      icon = Icons.cloud_off;
      tooltip = 'sync_status.offline'.tr();
    }

    Widget child = Icon(icon, color: iconColor, size: 22);

    if (state.hasOfflinePending && state.pendingCount > 0) {
      child = Badge(
        label: Text(
          state.pendingCount > 99 ? '99+' : '${state.pendingCount}',
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
        backgroundColor: Colors.orange.shade700,
        child: child,
      );
    }

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
    );
  }
}
