import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/super_admin/providers/support_interventions_provider.dart';
import 'package:falconest/core/utils/app_modal_utils.dart';
import 'package:falconest/features/super_admin/services/support_interventions_repository.dart';

/// Modální dialog „Výkazy práce“ – historie zásahů podpory (Magic Login).
///
/// PROČ: Prevence zneužití Magic Loginu a podklady pro fakturaci/provize. Super-Admin
/// vidí, kdo, kdy a u koho zasahoval a jaký byl výkaz práce.
class WorkReportsModal {
  WorkReportsModal._();

  /// Otevře Výkazy práce jako modální dialog (blur, centrované okno). Stejný vizuál jako Audit Log.
  /// Používá [showAppModal] pro jednotný vizuál napříč aplikací.
  static Future<void> show(BuildContext hostContext) {
    return showAppModal<void>(
      context: hostContext,
      barrierLabel: 'super_admin.barrier_work_reports'.tr(),
      maxWidth: 1000,
      maxHeightPx: 800,
      child: _WorkReportsModalContent(hostContext: hostContext),
    );
  }
}

/// Obsah modalu – seznam zásahů (Kdo, Kdy, Jak dlouho, Agentura, Poznámka). Design jako Audit Log.
class _WorkReportsModalContent extends ConsumerWidget {
  const _WorkReportsModalContent({required this.hostContext});

  final BuildContext hostContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(supportInterventionsListProvider);

    return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Expanded(
                  child: listAsync.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            'super_admin.work_reports_empty'.tr(),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _WorkReportRow(entry: list[i]),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'super_admin.work_reports_load_error'.tr(),
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => ref.invalidate(supportInterventionsListProvider),
                            child: Text('common.retry'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'super_admin.work_reports_title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'common.cancel'.tr(),
            onPressed: () => Navigator.of(hostContext).pop(),
          ),
        ],
      ),
    );
  }
}

/// Jeden řádek záznamu: Kdo, Kdy, Jak dlouho, Agentura, Poznámka. Kompaktní layout jako Audit Log.
class _WorkReportRow extends StatelessWidget {
  const _WorkReportRow({required this.entry});

  final SupportInterventionRow entry;

  static String _formatDuration(int minutes) {
    if (minutes < 60) return 'super_admin.work_reports_duration_min'.tr(namedArgs: {'count': '$minutes'});
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return 'super_admin.work_reports_duration_h'.tr(namedArgs: {'count': '$h'});
    return '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final who = (entry.profileName != null && entry.profileName!.trim().isNotEmpty)
        ? entry.profileName!
        : entry.profileId;
    final agency = (entry.tenantName != null && entry.tenantName!.trim().isNotEmpty)
        ? entry.tenantName!
        : entry.tenantId;
    final started = DateFormat('d. M. yyyy HH:mm').format(entry.startedAt.toLocal());
    final duration = entry.durationMinutes(DateTime.now());
    final durationStr = _formatDuration(duration);
    final note = entry.workReport?.trim() ?? '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_agent, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  who,
                  style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$started • $durationStr • $agency',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note != '—') ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500], fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
