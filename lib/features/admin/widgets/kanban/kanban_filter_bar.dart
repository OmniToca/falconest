import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';

/// Navigace měsíce pro záložku Úkoly – předchozí / vybraný měsíc a rok / následující.
/// Aktualizuje [selectedTaskMonthProvider]; stream úkolů se načte jen pro tento měsíc.
class TasksMonthNavigator extends ConsumerWidget {
  const TasksMonthNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedTaskMonthProvider);
    final monthLabel = DateFormat.yMMM().format(selectedMonth);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = DateTime(
                selectedMonth.year,
                selectedMonth.month - 1,
                1,
              );
              ref.read(selectedTaskMonthProvider.notifier).state = prev;
            },
            tooltip: 'admin.tasks_prev_month'.tr(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              monthLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = DateTime(
                selectedMonth.year,
                selectedMonth.month + 1,
                1,
              );
              ref.read(selectedTaskMonthProvider.notifier).state = next;
            },
            tooltip: 'admin.tasks_next_month'.tr(),
          ),
        ],
      ),
    );
  }
}

/// Tlačítko „Přepočítat personál“ – při neaktivním modulu automatic_tasks zobrazeno s 🔒 a při kliku dialog.
class RecalculateStaffButton extends StatelessWidget {
  const RecalculateStaffButton({
    super.key,
    required this.isRecalculating,
    required this.automaticTasksActive,
    required this.onRecalculateStaff,
    required this.onPremiumLockedTap,
  });

  final bool isRecalculating;
  final bool automaticTasksActive;
  final VoidCallback onRecalculateStaff;
  final VoidCallback onPremiumLockedTap;

  @override
  Widget build(BuildContext context) {
    if (automaticTasksActive) {
      return ElevatedButton.icon(
        onPressed: isRecalculating ? null : onRecalculateStaff,
        icon: isRecalculating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.autorenew, size: 20),
        label: Text(
          '${'admin.tasks_recalculate_staff'.tr()} ${'admin.tasks_batch_limit'.tr()}',
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPremiumLockedTap,
      icon: const Icon(Icons.lock_outline, size: 20),
      label: Text(
        '${'admin.tasks_recalculate_staff'.tr()} ${'admin.tasks_batch_limit'.tr()}',
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: context.colors.surfaceContainerHighest,
        foregroundColor: context.colors.onSurfaceVariant,
        elevation: 0,
      ),
    );
  }
}

/// Lišta pod vyhledáváním: vlevo výběr měsíce, vpravo Přepočítat personál (premium) a Schválit všechny.
class TasksFilterBar extends ConsumerWidget {
  const TasksFilterBar({
    super.key,
    required this.onApproveAll,
    required this.isApproving,
    required this.onRecalculateStaff,
    required this.isRecalculating,
    required this.automaticTasksActive,
    required this.onPremiumLockedTap,
  });

  final VoidCallback onApproveAll;
  final bool isApproving;
  final VoidCallback onRecalculateStaff;
  final bool isRecalculating;
  final bool automaticTasksActive;
  final VoidCallback onPremiumLockedTap;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const TasksMonthNavigator(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RecalculateStaffButton(
                isRecalculating: isRecalculating,
                automaticTasksActive: automaticTasksActive,
                onRecalculateStaff: onRecalculateStaff,
                onPremiumLockedTap: onPremiumLockedTap,
              ),
              SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: isApproving ? null : onApproveAll,
                icon: isApproving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all, size: 20),
                label: Text('admin.tasks_approve_all_pending'.tr()),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
