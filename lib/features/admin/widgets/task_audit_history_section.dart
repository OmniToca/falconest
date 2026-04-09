import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/task_audit_logs_provider.dart';
import 'package:falconest/features/super_admin/audit_log_display_helpers.dart';
import 'package:falconest/features/super_admin/services/audit_log_shared.dart';

/// Sekce „Historie úkolu“ – chronologie záznamů z `audit_logs` pro daný úkol.
///
/// PROČ: Při incidentu dispečer okamžitě vidí kdo měnil stav a kdy, bez Super Admin modulu.
class TaskAuditHistorySection extends ConsumerWidget {
  const TaskAuditHistorySection({
    super.key,
    required this.taskId,
  });

  final String taskId;

  static String _actorDisplay(AuditLogEntry e) {
    final d = e.details;
    if (d != null) {
      final snap = d['actor_snapshot'];
      if (snap is Map) {
        final n = snap['name']?.toString().trim();
        if (n != null && n.isNotEmpty) return n;
        final em = snap['email']?.toString().trim();
        if (em != null && em.isNotEmpty) return em;
      }
    }
    final uid = e.userId;
    if (uid != null && uid.trim().isNotEmpty) {
      return '${uid.substring(0, uid.length >= 8 ? 8 : uid.length)}…';
    }
    return 'admin.task_audit_actor_unknown'.tr();
  }

  static String? _summary(BuildContext context, AuditLogEntry e) {
    final d = e.details;
    if (d == null) return null;
    final ps = d['previous_state'];
    final ns = d['new_state'];
    if (ps is Map && ns is Map) {
      final os = ps['status']?.toString();
      final nss = ns['status']?.toString();
      if (os != null && nss != null && os != nss) {
        final a = _localizedStatus(os);
        final b = _localizedStatus(nss);
        return 'admin.task_audit_status_change'.tr(
          namedArgs: {'from': a, 'to': b},
        );
      }
    }
    return getAuditLogDisplayNameFromDetails(e);
  }

  static String _localizedStatus(String raw) {
    final sys = kanbanNormalizeToSystemStatus(raw);
    return 'task_status.$sys'.tr();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taskAuditLogsProvider(taskId));

    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.primary,
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          'admin.task_audit_load_error'.tr(),
          style: TextStyle(color: context.colors.error),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'admin.task_audit_empty'.tr(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'admin.task_audit_section_title'.tr(),
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            ...entries.map((e) {
              final local = e.createdAt.toLocal();
              final timeStr =
                  '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
                  '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
              final actionKey = auditLogActionToTranslationKey(e.actionType);
              final actionLabel = actionKey.tr();
              final sum = _summary(context, e);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeStr,
                        style: context.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        '${_actorDisplay(e)} · $actionLabel',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      if (sum != null && sum.trim().isNotEmpty) ...[
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          sum,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
