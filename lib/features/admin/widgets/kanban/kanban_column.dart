import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/admin/widgets/kanban/kanban_shared.dart';
import 'package:falconest/features/admin/widgets/kanban/kanban_task_card.dart';

/// Definice sloupce Kanbanu – systémový status (hodnota v DB) a i18n klíč pro nadpis.
class KanbanColumnDef {
  const KanbanColumnDef({required this.systemStatus, required this.titleKey});
  final String systemStatus;
  final String titleKey;
}

/// Kanban nástěnka se 4 sloupci a Drag & Drop.
///
/// PROČ bez vlastního [ref.watch] streamu: data berou sloupce přes [tasksBySystemStatusProvider],
/// aby se při změně jednoho úkolu nepřestavoval celý řádek sloupců.
class KanbanBoard extends StatelessWidget {
  const KanbanBoard({
    super.key,
    required this.lockedFinancialTaskIds,
    required this.categoriesByCode,
    required this.onEdit,
    required this.onDelete,
    required this.selectionMode,
    required this.selectedTaskIds,
    required this.onToggleTaskSelection,
    required this.onEnterSelectionWithTask,
  });

  /// Úkoly s výplatami nebo provizemi – nelze přetahovat ani mazat (ochrana účetnictví).
  final Set<String> lockedFinancialTaskIds;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final ValueChanged<TaskRow> onEdit;
  final ValueChanged<TaskRow> onDelete;

  /// Víceúčelový výběr karet (checkbox + hromadné akce).
  final bool selectionMode;
  final Set<String> selectedTaskIds;
  final ValueChanged<String> onToggleTaskSelection;
  final ValueChanged<String> onEnterSelectionWithTask;

  static const _columns = [
    KanbanColumnDef(
      systemStatus: 'pending',
      titleKey: 'admin.tasks_kanban_pending',
    ),
    KanbanColumnDef(
      systemStatus: 'assigned',
      titleKey: 'admin.tasks_kanban_assigned',
    ),
    KanbanColumnDef(
      systemStatus: 'in_progress',
      titleKey: 'admin.tasks_kanban_in_progress',
    ),
    KanbanColumnDef(
      systemStatus: 'completed',
      titleKey: 'admin.tasks_kanban_completed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _columns.map((col) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: KanbanColumn(
                systemStatus: col.systemStatus,
                titleKey: col.titleKey,
                lockedFinancialTaskIds: lockedFinancialTaskIds,
                categoriesByCode: categoriesByCode,
                onEdit: onEdit,
                onDelete: onDelete,
                selectionMode: selectionMode,
                selectedTaskIds: selectedTaskIds,
                onToggleTaskSelection: onToggleTaskSelection,
                onEnterSelectionWithTask: onEnterSelectionWithTask,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Jeden sloupec Kanbanu: šedé pozadí, nadpis s počtem, DragTarget, scrollovatelný seznam karet.
///
/// [ConsumerWidget]: odebírá jen [tasksBySystemStatusProvider] pro tento sloupec – granulární překreslení.
class KanbanColumn extends ConsumerWidget {
  const KanbanColumn({
    super.key,
    required this.systemStatus,
    required this.titleKey,
    required this.lockedFinancialTaskIds,
    required this.categoriesByCode,
    required this.onEdit,
    required this.onDelete,
    required this.selectionMode,
    required this.selectedTaskIds,
    required this.onToggleTaskSelection,
    required this.onEnterSelectionWithTask,
  });

  final String systemStatus;
  final String titleKey;
  final Set<String> lockedFinancialTaskIds;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final ValueChanged<TaskRow> onEdit;
  final ValueChanged<TaskRow> onDelete;
  final bool selectionMode;
  final Set<String> selectedTaskIds;
  final ValueChanged<String> onToggleTaskSelection;
  final ValueChanged<String> onEnterSelectionWithTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columnTasks = ref.watch(tasksBySystemStatusProvider(systemStatus)).tasks;
    final title = titleKey.tr();
    return DragTarget<TaskRow>(
      onAcceptWithDetails: (details) async {
        final task = details.data;
        if (normalizeToSystemStatus(task.status) == systemStatus) return;
        // Finanční zámek: úkol s výplatami/provizemi nelze přetahovat (ochrana účetnictví).
        if (lockedFinancialTaskIds.contains(task.id)) return;

        // PROČ: Při dokončení úkolu s výběrem hotovosti nabídneme zápis do peněženky administrátora.
        if (systemStatus == 'completed') {
          final amount = amountToCollectFromMetadata(task.metadata);
          if (amount != null && amount > 0) {
            final recordToWallet = await showCashCollectionOnCompleteDialog(
              context,
            );
            if (!context.mounted) return;
            if (recordToWallet) {
              final tenantId = ref.read(authNotifierProvider).tenantIdForData;
              final profileId = ref.read(authNotifierProvider).state.profileId;
              if (tenantId != null &&
                  profileId != null &&
                  tenantId.isNotEmpty &&
                  profileId.isNotEmpty) {
                try {
                  await CashWalletRepository.instance.recordCashCollection(
                    taskId: task.id,
                    amount: amount,
                    tenantId: tenantId,
                    profileId: profileId,
                    expectedAmount: amount,
                    reservationId: task.reservationId,
                  );
                  if (context.mounted) {
                    ref.invalidate(employeeCashWalletsProvider);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'common.generic_error_user_friendly'.tr(),
                        ),
                        backgroundColor: context.colors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                }
              }
            }
          }
        }

        try {
          await ref
              .read(adminTasksProvider.notifier)
              .updateTaskStatus(task.id, systemStatus);
          if (context.mounted) {
            ref.invalidate(adminTasksProvider);
            ref.invalidate(adminTasksStreamProvider);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'common.generic_error_user_friendly'.tr(),
                ),
                backgroundColor: context.colors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: candidateData.isNotEmpty
                  ? context.colors.primary.withValues(alpha: 0.5)
                  : context.colors.outlineVariant,
              width: candidateData.isNotEmpty ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  AppSpacing.sm,
                  14,
                  AppSpacing.sm,
                ),
                child: Text(
                  '$title (${columnTasks.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    0,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  itemCount: columnTasks.length,
                  itemBuilder: (context, index) {
                    final task = columnTasks[index];
                    final isFinanciallyLocked = lockedFinancialTaskIds.contains(
                      task.id,
                    );
                    final isStatusCompleted =
                        normalizeToSystemStatus(task.status) == 'completed';
                    final isLocked = isFinanciallyLocked || isStatusCompleted;
                    final card = TaskCard(
                      key: ValueKey<String>(task.id),
                      task: task,
                      categoriesByCode: categoriesByCode,
                      isFinanciallyLocked: isFinanciallyLocked,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      selectionMode: selectionMode,
                      isSelected: selectedTaskIds.contains(task.id),
                      onToggleSelect: () => onToggleTaskSelection(task.id),
                      onLongPressSelect: () => onEnterSelectionWithTask(task.id),
                    );
                    if (isLocked || selectionMode) {
                      return Padding(
                        key: ValueKey<String>('kanban_pad_${task.id}'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: card,
                      );
                    }
                    return Padding(
                      key: ValueKey<String>('kanban_pad_${task.id}'),
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Draggable<TaskRow>(
                        key: ValueKey<String>('kanban_drag_${task.id}'),
                        data: task,
                        feedback: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 200,
                            child: KanbanTaskCardContent(
                              key: ValueKey<String>('kanban_fb_${task.id}'),
                              task: task,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.5, child: card),
                        child: card,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
