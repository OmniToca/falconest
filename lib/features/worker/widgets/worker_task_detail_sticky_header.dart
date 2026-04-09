import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/utils/worker_task_guest_context.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';

/// Sticky panel pod AppBar – stav úkolu a buď živý odpočet (in_progress + odhad), nebo plánovaný začátek.
///
/// PROČ: Pracovník musí vidět čas a stav i při scrollu hlavního obsahu; proto tento widget sedí
/// v pevné [Column] nad [CustomScrollView] v [WorkerTaskDetailScreen], nikoli uvnitř sliverů.
class WorkerTaskDetailStickyHeader extends StatelessWidget {
  const WorkerTaskDetailStickyHeader({
    super.key,
    required this.detail,
    required this.estimatedMinutes,
  });

  final WorkerTaskDetail detail;
  final int estimatedMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusText = _statusLabel(detail);
    final showCountdown = detail.isInProgress &&
        detail.completedAt == null &&
        estimatedMinutes > 0;
    final showGuestHighlight = workerTaskDetailShouldShowProminentGuestName(detail);
    final guestName = detail.guestName?.trim() ?? '';

    return Material(
      elevation: 2,
      shadowColor: Colors.black26,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            if (showGuestHighlight) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.person_outline, size: 22, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'worker.task_detail_guest_name_prominent'.tr(namedArgs: {'name': guestName}),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            if (detail.isCompleted) ...[
              Text(
                'worker.task_detail_sticky_completed_hint'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ] else if (showCountdown)
              TaskCountdownTimer(
                startedAt: detail.startedAt,
                completedAt: detail.completedAt,
                estimatedMinutes: estimatedMinutes,
                embedInSticky: true,
              )
            else if (detail.isInProgress)
              Text(
                'worker.task_detail_sticky_no_estimate'.tr(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              )
            else
              _PlannedStartRow(scheduledStart: detail.scheduledStart),
          ],
        ),
      ),
    );
  }

  /// Mapování backendového stavu na srozumitelný text pro pracovníka (i18n).
  String _statusLabel(WorkerTaskDetail d) {
    if (d.isCompleted) {
      return 'worker.task_detail_status_completed'.tr();
    }
    if (d.isInProgress) {
      return 'worker.task_detail_status_in_progress'.tr();
    }
    final s = d.status.trim().toLowerCase();
    if (s == 'assigned') {
      return 'worker.task_detail_status_assigned'.tr();
    }
    if (s == 'draft') {
      return 'worker.task_detail_status_draft'.tr();
    }
    return 'worker.task_detail_status_pending'.tr();
  }
}

/// Řádek s plánovaným začátkem, když úkol ještě neběží.
class _PlannedStartRow extends StatelessWidget {
  const _PlannedStartRow({required this.scheduledStart});

  final DateTime scheduledStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = DateFormat('dd.MM.yyyy HH:mm').format(scheduledStart.toLocal());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.event, size: 26, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'worker.task_detail_sticky_planned_label'.tr(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatted,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
