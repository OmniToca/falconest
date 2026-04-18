import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/owner/widgets/owner_portal_ui.dart';
import 'package:falconest/utils/task_visuals.dart';

/// Údržba nahlášená majitelem – výrazný štítek „Moje hlášení“ (jen maintenance + created_by).
///
/// PROČ: Logika patří ke kartě; sdílená jen uvnitř tohoto widgetu (SRP vs. obrazovka se seznamem).
bool _isMyMaintenanceReport(TaskRow task, String profileId) {
  if (profileId.isEmpty || task.createdBy == null || task.createdBy != profileId) {
    return false;
  }
  final tt = task.taskType.toLowerCase().trim();
  return tt == 'maintenance' || tt == 'údržba' || tt == 'udrzba';
}

/// Zjednodušená karta úkolu pro majitele (Kanban / historie).
///
/// PROČ: Odděleno od [OwnerTasksScreen], aby obrazovka řídila záložky a data, ne vykreslení jedné karty.
class OwnerTaskCard extends StatelessWidget {
  const OwnerTaskCard({
    super.key,
    required this.task,
    required this.categoriesByCode,
    required this.currentUserProfileId,
    required this.onTap,
  });

  final TaskRow task;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final String currentUserProfileId;
  final VoidCallback onTap;

  static String _formatDue(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _taskTypeLabelKey(String taskType) {
    switch (taskType.toLowerCase()) {
      case 'cleaning':
      case 'úklid':
        return 'admin.task_type_cleaning';
      case 'transfer_in':
      case 'transfer':
        return 'admin.task_type_transfer_in';
      case 'transfer_out':
        return 'admin.task_type_transfer_out';
      case 'check_in':
        return 'admin.task_type_check_in';
      case 'check_out':
        return 'admin.task_type_check_out';
      case 'issue':
        return 'admin.task_type_issue';
      case 'maintenance':
      case 'údržba':
        return 'admin.task_type_maintenance';
      case 'material':
        return 'admin.task_type_material';
      case 'jiné':
        return 'admin.task_type_other';
      default:
        return 'admin.task_type_other';
    }
  }

  static (Color bg, Color fg) _statusPillColors(BuildContext context, String? status) {
    final cs = Theme.of(context).colorScheme;
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'in_progress' || s == 'probíhá') {
      return (
        Color.alphaBlend(const Color(0xFF1565C0).withValues(alpha: 0.12), cs.surface),
        const Color(0xFF1565C0),
      );
    }
    if (s == 'problem' || s == 'problém') {
      return (
        Color.alphaBlend(cs.error.withValues(alpha: 0.12), cs.surface),
        cs.error,
      );
    }
    if (s == 'completed' || s == 'done' || s == 'hotovo') {
      return (
        Color.alphaBlend(const Color(0xFF2E7D32).withValues(alpha: 0.12), cs.surface),
        const Color(0xFF2E7D32),
      );
    }
    return (
      cs.surfaceContainerHighest.withValues(alpha: 0.65),
      cs.onSurfaceVariant,
    );
  }

  static String _statusLabel(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'in_progress' || s == 'probíhá') return 'task_status.in_progress'.tr();
    if (s == 'problem' || s == 'problém') return 'task_status.problem'.tr();
    if (s == 'completed' || s == 'done' || s == 'hotovo') return 'task_status.completed'.tr();
    if (s == 'pending') return 'owner.task_status_new'.tr();
    return 'task_status.assigned'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final showMyReportBadge = _isMyMaintenanceReport(task, currentUserProfileId);
    final dueStr = _formatDue(task.dueDate);
    final accent = TaskVisuals.getBorderColor(
      task.taskType,
      categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null,
    );
    final iconFill = ownerPortalMutedTaskFill(context, accent);
    final typeIcon = TaskVisuals.getIcon(
      task.taskType,
      categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null,
    );
    final (statusBg, statusFg) = _statusPillColors(context, task.status);
    final cs = context.colors;
    final tt = Theme.of(context).textTheme;
    final titleText = (task.title.trim().isNotEmpty)
        ? task.title
        : (task.apartmentName?.trim().isNotEmpty == true
            ? task.apartmentName!
            : 'admin.task_no_title'.tr());

    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'admin.task_due'.tr(namedArgs: {'date': dueStr}),
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            titleText,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              height: 1.25,
              color: cs.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.apartmentName != null &&
              task.apartmentName!.trim().isNotEmpty &&
              task.title.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.apartmentName!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _taskTypeLabelKey(task.taskType).tr(),
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (showMyReportBadge) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color.alphaBlend(cs.primary.withValues(alpha: 0.12), cs.surface),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'owner.tasks_my_report_badge'.tr(),
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'owner.tasks_staff_label'.tr(),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _statusLabel(task.status),
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: statusFg,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );

    final outline = Theme.of(context).colorScheme.outlineVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kOwnerPortalKanbanCardRadius),
        boxShadow: ownerPortalKanbanCardShadows(),
        border: Border.all(
          color: showMyReportBadge
              ? cs.primary.withValues(alpha: 0.35)
              : outline.withValues(alpha: 0.08),
          width: showMyReportBadge ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kOwnerPortalKanbanCardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(kOwnerPortalKanbanCardRadius),
          onTap: onTap,
          child: inner,
        ),
      ),
    );
  }
}
