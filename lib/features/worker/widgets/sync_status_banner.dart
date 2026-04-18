import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/connectivity_provider.dart';
import 'package:falconest/core/providers/sync_status_provider.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_provider.dart';

enum _SyncBannerState {
  hidden,
  offline,
  syncing,
  synced,
}

/// Viditelný stavový banner synchronizace pro worker dashboard.
///
/// PROČ: Pracovník v terénu musí okamžitě vidět, zda je offline, zda probíhá sync
/// a zda změny opravdu odešly. Krátké „Synced“ potvrzení po úspěchu zvyšuje jistotu,
/// že se data nahrála do backendu.
class SyncStatusBanner extends ConsumerStatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  ConsumerState<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends ConsumerState<SyncStatusBanner> {
  Timer? _syncedHideTimer;
  Timer? _pendingRefreshTimer;
  _SyncBannerState _lastRawState = _SyncBannerState.hidden;
  bool _showSyncedPulse = false;

  @override
  void initState() {
    super.initState();
    // PROČ: workerPendingSyncCountProvider je FutureProvider; pravidelně invalidujeme,
    // aby banner reagoval dynamicky během práce bez ručního refresh.
    _pendingRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final tenantId = ref.read(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) return;
      ref.invalidate(workerPendingSyncCountProvider(tenantId));
    });
  }

  @override
  void dispose() {
    _syncedHideTimer?.cancel();
    _pendingRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final isSyncing = ref.watch(syncInProgressProvider);
    final pendingCount = tenantId == null || tenantId.isEmpty
        ? 0
        : (ref.watch(workerPendingSyncCountProvider(tenantId)).value ?? 0);

    final rawState = _resolveRawState(
      isOffline: isOffline,
      isSyncing: isSyncing,
      pendingCount: pendingCount,
    );
    _handleSyncedPulse(rawState);

    final visualState = _showSyncedPulse ? _SyncBannerState.synced : rawState;
    final banner = _buildBannerForState(
      context,
      visualState: visualState,
      pendingCount: pendingCount,
    );

    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: banner == null ? const Offset(0, -1) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: banner == null ? 0 : 1,
        child: banner ?? const SizedBox.shrink(),
      ),
    );
  }

  _SyncBannerState _resolveRawState({
    required bool isOffline,
    required bool isSyncing,
    required int pendingCount,
  }) {
    if (isOffline) return _SyncBannerState.offline;
    if (isSyncing) return _SyncBannerState.syncing;
    if (pendingCount > 0) return _SyncBannerState.syncing;
    return _SyncBannerState.hidden;
  }

  void _handleSyncedPulse(_SyncBannerState rawState) {
    final shouldPulse = _lastRawState != _SyncBannerState.hidden &&
        rawState == _SyncBannerState.hidden;

    _lastRawState = rawState;
    if (!shouldPulse) return;

    _syncedHideTimer?.cancel();
    if (!_showSyncedPulse) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _showSyncedPulse = true);
      });
    }
    _syncedHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showSyncedPulse = false);
    });
  }

  Widget? _buildBannerForState(
    BuildContext context, {
    required _SyncBannerState visualState,
    required int pendingCount,
  }) {
    switch (visualState) {
      case _SyncBannerState.hidden:
        return null;
      case _SyncBannerState.offline:
        return _SyncBannerShell(
          backgroundColor: context.customColors.warning,
          foregroundColor: context.customColors.onWarning,
          leading: const Icon(Icons.cloud_off_outlined),
          text: 'worker.sync_status_offline'.tr(
            namedArgs: {'count': '$pendingCount'},
          ),
        );
      case _SyncBannerState.syncing:
        return _SyncBannerShell(
          backgroundColor: context.customColors.info,
          foregroundColor: context.customColors.onInfo,
          leading: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.customColors.onInfo,
            ),
          ),
          text: 'worker.sync_status_syncing'.tr(),
        );
      case _SyncBannerState.synced:
        return _SyncBannerShell(
          backgroundColor: context.customColors.success,
          foregroundColor: context.customColors.onSuccess,
          leading: const Icon(Icons.check_circle_outline),
          text: 'worker.sync_status_synced'.tr(),
        );
    }
  }
}

class _SyncBannerShell extends StatelessWidget {
  const _SyncBannerShell({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.leading,
    required this.text,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconTheme(
            data: IconThemeData(color: foregroundColor, size: 18),
            child: leading,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
