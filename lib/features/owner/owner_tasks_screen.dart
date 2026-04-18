import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_tasks_provider.dart';
import 'package:falconest/features/owner/widgets/owner_report_issue_dialog.dart';
import 'package:falconest/features/owner/widgets/owner_task_card.dart';
import 'package:falconest/features/owner/widgets/owner_task_detail_dialog.dart';

/// Obrazovka přehledu úkolů (prací) pro Klientský portál.
///
/// Záložky **Aktivní práce** (Kanban: Zadáno, Probíhá) a **Historie** (dokončené úkoly).
/// Majitel vidí pouze úkoly u svých bytů; návrhy (draft) jsou filtrovány v provideru.
class OwnerTasksScreen extends ConsumerWidget {
  const OwnerTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesByCode = ref.watch(taskCategoriesProvider).valueOrNull ?? {};
    final apartments = ref.read(ownerApartmentsProvider).valueOrNull ?? [];
    final profileId = ref.read(authNotifierProvider).state.profileId ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text('owner.tasks_title'.tr()),
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            tabs: [
              Tab(text: 'owner.tasks_tab_active'.tr()),
              Tab(text: 'owner.tasks_tab_history'.tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActiveTasksTab(
              categoriesByCode: categoriesByCode,
              currentUserProfileId: profileId,
            ),
            _HistoryTasksTab(
              categoriesByCode: categoriesByCode,
              currentUserProfileId: profileId,
            ),
          ],
        ),
        floatingActionButton: apartments.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => openOwnerReportIssueDialog(
                  context,
                  apartments: apartments,
                  profileId: profileId,
                  onSuccess: () {
                    ref.invalidate(ownerTasksProvider);
                    ref.invalidate(ownerTaskHistoryProvider);
                  },
                ),
                icon: const Icon(Icons.report_problem_outlined),
                label: Text('owner.report_issue_btn'.tr()),
              ),
      ),
    );
  }
}

/// Záložka aktivních úkolů – Kanban bez sloupce „Hotovo“ (dokončené jsou v Historii).
class _ActiveTasksTab extends ConsumerWidget {
  const _ActiveTasksTab({
    required this.categoriesByCode,
    required this.currentUserProfileId,
  });

  final Map<String, TaskCategoryModel> categoriesByCode;
  final String currentUserProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(ownerTasksProvider);
    return tasksAsync.when(
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
          currentUserProfileId: currentUserProfileId,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _TasksError(onRetry: () => ref.invalidate(ownerTasksProvider)),
    );
  }
}

/// Záložka historie – dokončené úkoly, řazení od nejnovějších (provider).
class _HistoryTasksTab extends ConsumerWidget {
  const _HistoryTasksTab({
    required this.categoriesByCode,
    required this.currentUserProfileId,
  });

  final Map<String, TaskCategoryModel> categoriesByCode;
  final String currentUserProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(ownerTaskHistoryProvider);
    return historyAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'owner.tasks_history_empty'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OwnerTaskCard(
                task: task,
                categoriesByCode: categoriesByCode,
                currentUserProfileId: currentUserProfileId,
                onTap: () => OwnerTaskDetailDialog.show(
                  context,
                  OwnerTaskDetailData(
                    taskId: task.id,
                    title: task.title,
                    taskType: task.taskType,
                    apartmentName: task.apartmentName,
                    scheduledStart: task.scheduledStart ?? task.dueDate,
                    status: task.status,
                    description:
                        task.description.trim().isEmpty ? null : task.description,
                    mediaUrls: task.mediaUrls,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _TasksError(onRetry: () => ref.invalidate(ownerTaskHistoryProvider)),
    );
  }
}

class _TasksError extends StatelessWidget {
  const _TasksError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
            onPressed: onRetry,
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Dva sloupce Kanbanu: Zadáno, Probíhá (bez dokončených).
enum _OwnerColumn { assigned, inProgress }

_OwnerColumn _columnForActiveStatus(String? status) {
  if (status == null || status.trim().isEmpty) return _OwnerColumn.assigned;
  final s = status.trim().toLowerCase();
  if (s == 'in_progress' || s == 'probíhá' || s == 'problem' || s == 'problém') {
    return _OwnerColumn.inProgress;
  }
  if (isOwnerTaskCompletedStatus(status)) {
    return _OwnerColumn.assigned;
  }
  return _OwnerColumn.assigned;
}

/// Read-only Kanban – dva sloupce (aktivní práce).
class _OwnerTasksKanbanBoard extends StatelessWidget {
  const _OwnerTasksKanbanBoard({
    required this.tasks,
    required this.categoriesByCode,
    required this.currentUserProfileId,
  });

  static const double _narrowKanbanMaxWidth = 600;

  final List<TaskRow> tasks;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final String currentUserProfileId;

  List<TaskRow> _tasksForColumn(_OwnerColumn col) {
    return tasks.where((t) => _columnForActiveStatus(t.status) == col).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < _narrowKanbanMaxWidth;

        if (isNarrow) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OwnerKanbanColumn(
                  tasks: _tasksForColumn(_OwnerColumn.assigned),
                  titleKey: 'owner.tasks_column_assigned',
                  categoriesByCode: categoriesByCode,
                  currentUserProfileId: currentUserProfileId,
                  expandList: false,
                ),
                const SizedBox(height: 28),
                _OwnerKanbanColumn(
                  tasks: _tasksForColumn(_OwnerColumn.inProgress),
                  titleKey: 'owner.tasks_column_in_progress',
                  categoriesByCode: categoriesByCode,
                  currentUserProfileId: currentUserProfileId,
                  expandList: false,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OwnerKanbanColumn(
                tasks: _tasksForColumn(_OwnerColumn.assigned),
                titleKey: 'owner.tasks_column_assigned',
                categoriesByCode: categoriesByCode,
                currentUserProfileId: currentUserProfileId,
              ),
              _OwnerKanbanColumn(
                tasks: _tasksForColumn(_OwnerColumn.inProgress),
                titleKey: 'owner.tasks_column_in_progress',
                categoriesByCode: categoriesByCode,
                currentUserProfileId: currentUserProfileId,
              ),
            ]
                .map(
                  (w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: w,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _OwnerKanbanColumn extends StatelessWidget {
  const _OwnerKanbanColumn({
    required this.tasks,
    required this.titleKey,
    required this.categoriesByCode,
    required this.currentUserProfileId,
    this.expandList = true,
  });

  final List<TaskRow> tasks;
  final String titleKey;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final String currentUserProfileId;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    final title = titleKey.tr();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final listView = ListView.builder(
      shrinkWrap: !expandList,
      physics: expandList
          ? null
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OwnerTaskCard(
            task: task,
            categoriesByCode: categoriesByCode,
            currentUserProfileId: currentUserProfileId,
            onTap: () => OwnerTaskDetailDialog.show(
              context,
              OwnerTaskDetailData(
                taskId: task.id,
                title: task.title,
                taskType: task.taskType,
                apartmentName: task.apartmentName,
                scheduledStart: task.scheduledStart ?? task.dueDate,
                status: task.status,
                description: task.description.trim().isEmpty ? null : task.description,
                mediaUrls: task.mediaUrls,
              ),
            ),
          ),
        );
      },
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      child: Text(
        '$title (${tasks.length})',
        style: tt.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: cs.onSurface,
        ),
      ),
    );

    if (expandList) {
      return Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: listView),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        listView,
      ],
    );
  }
}
