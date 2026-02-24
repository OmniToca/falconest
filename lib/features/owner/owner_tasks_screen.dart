import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/owner/providers/owner_tasks_provider.dart';
import 'package:falconest/utils/task_visuals.dart';

/// Obrazovka přehledu úkolů (prací) pro Klientský portál.
///
/// Zobrazuje read-only Kanban board se třemi sloupci: Zadáno, Probíhá, Hotovo.
/// Majitel vidí pouze úkoly u svých bytů; návrhy (draft) jsou filtrovány v provideru.
class OwnerTasksScreen extends ConsumerWidget {
  const OwnerTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(ownerTasksProvider);
    final categoriesByCode = ref.watch(taskCategoriesProvider).valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text('owner.tasks_title'.tr()),
      ),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Text(
                'owner.tasks_empty'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          return _OwnerTasksKanbanBoard(
            tasks: tasks,
            categoriesByCode: categoriesByCode,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 16),
              Text(
                'owner.tasks_load_error'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(ownerTasksProvider),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mapování sloupce Kanbanu pro majitele – pouze tři sloupce.
enum _OwnerColumn { assigned, inProgress, completed }

/// Určí, do kterého sloupce patří úkol podle statusu.
_OwnerColumn _columnForStatus(String? status) {
  if (status == null || status.trim().isEmpty) return _OwnerColumn.assigned;
  final s = status.trim().toLowerCase();
  if (s == 'in_progress' || s == 'probíhá' || s == 'problem' || s == 'problém') {
    return _OwnerColumn.inProgress;
  }
  if (s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno') {
    return _OwnerColumn.completed;
  }
  return _OwnerColumn.assigned;
}

/// Read-only Kanban board – tři sloupce, bez Drag&Drop.
class _OwnerTasksKanbanBoard extends StatelessWidget {
  const _OwnerTasksKanbanBoard({
    required this.tasks,
    required this.categoriesByCode,
  });

  final List<TaskRow> tasks;
  final Map<String, TaskCategoryModel> categoriesByCode;

  List<TaskRow> _tasksForColumn(_OwnerColumn col) {
    return tasks.where((t) => _columnForStatus(t.status) == col).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OwnerKanbanColumn(
            tasks: _tasksForColumn(_OwnerColumn.assigned),
            titleKey: 'owner.tasks_column_assigned',
            categoriesByCode: categoriesByCode,
          ),
          _OwnerKanbanColumn(
            tasks: _tasksForColumn(_OwnerColumn.inProgress),
            titleKey: 'owner.tasks_column_in_progress',
            categoriesByCode: categoriesByCode,
          ),
          _OwnerKanbanColumn(
            tasks: _tasksForColumn(_OwnerColumn.completed),
            titleKey: 'owner.tasks_column_completed',
            categoriesByCode: categoriesByCode,
          ),
        ].map((w) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: w,
        ))).toList(),
      ),
    );
  }
}

/// Jeden sloupec Kanbanu – bez DragTarget, pouze zobrazení.
class _OwnerKanbanColumn extends StatelessWidget {
  const _OwnerKanbanColumn({
    required this.tasks,
    required this.titleKey,
    required this.categoriesByCode,
  });

  final List<TaskRow> tasks;
  final String titleKey;
  final Map<String, TaskCategoryModel> categoriesByCode;

  @override
  Widget build(BuildContext context) {
    final title = titleKey.tr();
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              '$title (${tasks.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OwnerTaskCard(
                    task: tasks[index],
                    categoriesByCode: categoriesByCode,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Zjednodušená karta úkolu pro majitele.
///
/// UI: Karta je striktně read-only, bez Drag&Drop a jmen personálu.
/// Zobrazuje: typ úkolu, název, byt, datum a čas. Interní poznámky a jméno
/// zaměstnance jsou skryty (nahrazeno generickým „Personál agentury“).
class _OwnerTaskCard extends StatelessWidget {
  const _OwnerTaskCard({
    required this.task,
    required this.categoriesByCode,
  });

  final TaskRow task;
  final Map<String, TaskCategoryModel> categoriesByCode;

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
      case 'material':
        return 'admin.task_type_material';
      case 'jiné':
        return 'admin.task_type_other';
      default:
        return 'admin.task_type_other';
    }
  }

  static Color _statusColor(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'in_progress' || s == 'probíhá') return const Color(0xFF1565C0);
    if (s == 'problem' || s == 'problém') return const Color(0xFFC62828);
    if (s == 'completed' || s == 'done' || s == 'hotovo') return const Color(0xFF2E7D32);
    return const Color(0xFF757575);
  }

  static String _statusLabel(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'in_progress' || s == 'probíhá') return 'task_status.in_progress'.tr();
    if (s == 'problem' || s == 'problém') return 'task_status.problem'.tr();
    if (s == 'completed' || s == 'done' || s == 'hotovo') return 'task_status.completed'.tr();
    return 'task_status.assigned'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final dueStr = _formatDue(task.dueDate);
    final cardColor = TaskVisuals.getBackgroundColor(
      task.taskType,
      categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null,
    );
    final typeIcon = TaskVisuals.getIcon(
      task.taskType,
      categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null,
    );
    final statusColor = _statusColor(task.status);

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(typeIcon, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _taskTypeLabelKey(task.taskType).tr(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              (task.title.trim().isNotEmpty)
                  ? task.title
                  : (task.apartmentName?.trim().isNotEmpty == true
                      ? task.apartmentName!
                      : 'admin.task_no_title'.tr()),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (task.apartmentName != null &&
                task.apartmentName!.trim().isNotEmpty &&
                task.title.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.apartmentName!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            // Ochrana soukromí: místo jména zaměstnance generický text.
            Text(
              'owner.tasks_staff_label'.tr(),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(task.status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 10, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'admin.task_due'.tr(namedArgs: {'date': dueStr}),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
