import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';

/// Lišta hromadných akcí Kanbanu – zobrazí se při výběru nebo v režimu výběru.
///
/// PROČ samostatný soubor: čitelnost `admin_tasks_screen.dart` – lišta nemění logiku, jen kompozici UI.
class KanbanBulkSelectionBar extends StatelessWidget {
  const KanbanBulkSelectionBar({
    super.key,
    required this.selectedCount,
    required this.onChangeStatus,
    required this.onAssignWorker,
    required this.onCancel,
  });

  final int selectedCount;
  final VoidCallback onChangeStatus;
  final VoidCallback onAssignWorker;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: context.colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.checklist_rtl, color: context.colors.primary, size: 22),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'admin.tasks_bulk_selected_count'.tr(
                  namedArgs: {'count': '$selectedCount'},
                ),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: selectedCount == 0 ? null : onChangeStatus,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: Text('admin.tasks_bulk_change_status'.tr()),
            ),
            SizedBox(width: AppSpacing.xs),
            TextButton.icon(
              onPressed: selectedCount == 0 ? null : onAssignWorker,
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: Text('admin.tasks_bulk_assign_worker'.tr()),
            ),
            SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: 'admin.tasks_bulk_exit_selection'.tr(),
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
