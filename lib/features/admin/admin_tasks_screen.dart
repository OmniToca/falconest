import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/admin_reservations_screen.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';
import 'package:falconest/features/settings/models/tenant_service_model.dart';
// Sdílená komponenta pro zobrazení financí a poznámek z rezervace.
import 'package:falconest/features/admin/widgets/task_metadata_section.dart';
import 'package:falconest/utils/task_visuals.dart';
import 'package:falconest/widgets/task_legend.dart';

/// Barvy pro stavy úkolu – stejný styl jako v ostatních admin obrazovkách.
const _statusDraft = Color(0xFF7B1FA2);
const _statusNew = Color(0xFF757575);
const _statusInProgress = Color(0xFF1565C0);
const _statusDone = Color(0xFF2E7D32);
const _statusProblem = Color(0xFFC62828);

/// Systémové hodnoty statusů v DB – backendová logika používá výhradně tyto stringy,
/// překlad probíhá až ve vrstvě UI pomocí klíčů task_status.* v JSON.
const _systemStatuses = ['pending', 'assigned', 'in_progress', 'completed', 'problem'];

/// Filtr zobrazení úkolů podle data termínu (due_date).
enum TasksDateFilter { all, today, tomorrow }

/// Administrativní obrazovka úkolů – karty (dlaždice), propojení Apartmány + Personál.
class AdminTasksScreen extends ConsumerStatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  ConsumerState<AdminTasksScreen> createState() => _AdminTasksScreenState();

  /// Veřejná metoda pro otevření dialogu úpravy úkolu (např. z Plánovacího kalendáře). Po uložení volá [onSaved].
  /// [onReservationTap] – callback při kliknutí na odkaz rezervace v kontextu; použije se pro navigaci na detail.
  static void showEditTaskDialog(
    BuildContext context,
    WidgetRef ref,
    TaskRow task, {
    VoidCallback? onSaved,
    void Function(String reservationId)? onReservationTap,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _EditTaskDialog(
        ref: ref,
        task: task,
        onSaved: onSaved ?? () => ref.invalidate(adminTasksProvider),
        onReservationTap: onReservationTap,
      ),
    );
  }
}

class _AdminTasksScreenState extends ConsumerState<AdminTasksScreen> {
  final _searchController = TextEditingController();
  bool _isGenerating = false;
  bool _isApproving = false;
  bool _isRecalculating = false;
  TasksDateFilter _dateFilter = TasksDateFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runGenerateSmartTasks() async {
    setState(() => _isGenerating = true);
    try {
      final notifier = ref.read(adminTasksProvider.notifier);
      final count1 = await notifier.generateSmartTasks(
            getEstimateHoursText: (h) =>
                'admin.task_estimate_time_hours'.tr(namedArgs: {'hours': '$h'}),
            getEstimate1HourText: () => 'admin.task_estimate_time_1_hour'.tr(),
            getEstimateMinutesText: (m) =>
                'admin.task_estimate_minutes'.tr(namedArgs: {'minutes': '$m'}),
          );
      final count2 = await notifier.generateScheduledTasks(
            getEstimateMinutesText: (m) =>
                'admin.task_estimate_minutes'.tr(namedArgs: {'minutes': '$m'}),
          );
      final totalCount = count1 + count2;
      if (!mounted) return;
      ref.invalidate(adminTasksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            totalCount == 0
                ? 'admin.tasks_all_planned'.tr()
                : 'admin.tasks_generated_count'.tr(namedArgs: {'count': '$totalCount'}),
          ),
          backgroundColor: totalCount == 0 ? Colors.orange : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  List<TaskRow> _computeFiltered(List<TaskRow> tasks) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return tasks;
    return tasks.where((t) {
      final title = (t.title).toLowerCase();
      final desc = (t.description).toLowerCase();
      final apt = (t.apartmentName ?? '').toLowerCase();
      final who = (t.assignedToName ?? '').toLowerCase();
      return title.contains(query) ||
          desc.contains(query) ||
          apt.contains(query) ||
          who.contains(query);
    }).toList();
  }

  /// Filtruje úkoly podle zvoleného dne (termín due_date).
  List<TaskRow> _applyDateFilter(List<TaskRow> tasks) {
    if (_dateFilter == TasksDateFilter.all) return tasks;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = _dateFilter == TasksDateFilter.today
        ? today
        : today.add(const Duration(days: 1));
    final nextDay = targetDay.add(const Duration(days: 1));
    return tasks.where((t) {
      final d = t.dueDate;
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(targetDay) && day.isBefore(nextDay);
    }).toList();
  }

  Future<void> _runApproveAllPending() async {
    setState(() => _isApproving = true);
    try {
      final count = await ref.read(adminTasksProvider.notifier).approveAllPendingTasks();
      if (!mounted) return;
      ref.invalidate(adminTasksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'admin.tasks_approve_all_none'.tr()
                : 'admin.tasks_approve_all_success'.tr(),
          ),
          backgroundColor: count == 0 ? Colors.orange : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  /// Přepočet personálu: simulace (bez zápisu), potom dialog s návrhy změn k potvrzení.
  /// Volá recalculateAssignees() – pokud prázdné, SnackBar. Jinak otevře _RecalculateProposalsDialog.
  Future<void> _runRecalculateAssignees() async {
    setState(() => _isRecalculating = true);
    try {
      final proposals = await ref.read(adminTasksProvider.notifier).recalculateAssignees();
      if (!mounted) return;
      setState(() => _isRecalculating = false);
      if (proposals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.recalculate_no_changes'.tr()),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => _RecalculateProposalsDialog(
          ref: ref,
          proposals: proposals,
          onApplied: () {
            ref.invalidate(adminTasksProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('admin.tasks_recalculate_staff_success'.tr()),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error_with_message'.tr(namedArgs: {'message': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  /// Zobrazí premium upsell dialog (cena, trial aktivace, audit) při kliku na zamčenou automatizaci.
  void _showPremiumLockedDialog(BuildContext context) {
    PremiumUpsellDialog.show(context, moduleKey: 'automatic_tasks');
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(adminTasksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: tasksAsync.when(
        data: (tasks) {
          final filtered = _computeFiltered(tasks);
          final dateFiltered = _applyDateFilter(filtered);
          final automaticTasksActive = isModuleActive(ref, 'automatic_tasks');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopActionBar(
                searchController: _searchController,
                onSearchChanged: () => setState(() {}),
                onAdd: () => _showAddDialog(context, ref),
                onGenerate: _runGenerateSmartTasks,
                isGenerating: _isGenerating,
                automaticTasksActive: automaticTasksActive,
                onPremiumLockedTap: () => _showPremiumLockedDialog(context),
              ),
              _TasksFilterBar(
                dateFilter: _dateFilter,
                onDateFilterChanged: (v) => setState(() => _dateFilter = v),
                onApproveAll: _runApproveAllPending,
                isApproving: _isApproving,
                onRecalculateStaff: _runRecalculateAssignees,
                isRecalculating: _isRecalculating,
                automaticTasksActive: automaticTasksActive,
                onPremiumLockedTap: () => _showPremiumLockedDialog(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: TaskLegend(),
              ),
              Expanded(
                child: dateFiltered.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'admin.tasks_empty'.tr()
                              : 'admin.tasks_search_no_results'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : _KanbanBoard(
                        tasks: dateFiltered,
                        ref: ref,
                        categoriesByCode: ref.watch(taskCategoriesProvider).valueOrNull ?? {},
                        onEdit: (t) => _showEditDialog(context, ref, t),
                        onDelete: (t) => _showDeleteConfirm(context, ref, t),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 16),
              Text(
                'admin.tasks_load_error'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  error.toString(),
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(adminTasksProvider),
                child: Text('admin.tasks_retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddTaskDialog(
        ref: ref,
        onSaved: () => ref.invalidate(adminTasksProvider),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, TaskRow task) {
    AdminTasksScreen.showEditTaskDialog(
      context,
      ref,
      task,
      onReservationTap: task.reservationId != null && task.reservationId!.isNotEmpty
          ? (id) => _navigateToReservation(context, ref, id)
          : null,
    );
  }

  /// Zavře dialog úkolu, přepne na záložku Rezervace a otevře detail dané rezervace.
  /// Voláno při kliknutí na odkaz rezervace v kontextovém bloku.
  void _navigateToReservation(BuildContext context, WidgetRef ref, String reservationId) {
    Navigator.of(context).pop();
    final reservations = ref.read(adminReservationsProvider).valueOrNull ?? [];
    final reservation = reservations.where((r) => r.id == reservationId).firstOrNull;
    if (reservation != null) {
      AdminTabScope.of(context)?.call(adminTabIndexReservations);
      AdminReservationsScreen.showEditReservationDialog(context, ref, reservation);
    }
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, TaskRow task) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.task_delete_title'.tr()),
        content: Text('admin.task_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => _doDelete(ctx, ref, task.id),
            child: Text('admin.task_delete'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _doDelete(BuildContext context, WidgetRef ref, String taskId) async {
    try {
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('common.error'.tr()),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.client
          .from('tasks')
          .update({'deleted_at': deletedAt})
          .eq('id', taskId)
          .eq('tenant_id', tenantId);
      await AuditLogService.log(
        tenantId: auth.tenantIdForData,
        userId: SupabaseService.client.auth.currentUser?.id,
        actionType: 'SOFT_DELETE',
        tableName: 'tasks',
        recordId: taskId,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ref.invalidate(adminTasksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_deleted'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_delete_error'.tr(namedArgs: {'message': e.toString()})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Horní lišta – titulek, vyhledávání, Generovat návrhy (premium), Nový úkol.
class _TopActionBar extends StatelessWidget {
  const _TopActionBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onGenerate,
    required this.isGenerating,
    required this.automaticTasksActive,
    required this.onPremiumLockedTap,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onAdd;
  final Future<void> Function() onGenerate;
  final bool isGenerating;
  /// Modul automatic_tasks – když false, tlačítko „Generovat návrhy“ je zamčené (ikona 🔒 + dialog).
  final bool automaticTasksActive;
  final VoidCallback onPremiumLockedTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Text(
            'admin.tasks_title'.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: (v) => onSearchChanged(),
              decoration: InputDecoration(
                hintText: 'admin.tasks_search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _GenerateButton(
            isGenerating: isGenerating,
            automaticTasksActive: automaticTasksActive,
            onGenerate: onGenerate,
            onPremiumLockedTap: onPremiumLockedTap,
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            label: Text('admin.task_new'.tr()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tlačítko „Generovat návrhy“ – při neaktivním modulu automatic_tasks zobrazeno s 🔒 a při kliku dialog.
class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.isGenerating,
    required this.automaticTasksActive,
    required this.onGenerate,
    required this.onPremiumLockedTap,
  });

  final bool isGenerating;
  final bool automaticTasksActive;
  final Future<void> Function() onGenerate;
  final VoidCallback onPremiumLockedTap;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.grey.shade600;
    if (automaticTasksActive) {
      return ElevatedButton.icon(
        onPressed: isGenerating ? null : () => onGenerate(),
        icon: isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, size: 20),
        label: Text(isGenerating
            ? 'admin.tasks_generating'.tr()
            : '${'admin.tasks_generate'.tr()} (max 50)'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPremiumLockedTap,
      icon: Icon(Icons.lock_outline, size: 20, color: muted),
      label: Text('admin.tasks_generate'.tr()),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: muted,
      ),
    );
  }
}

/// Dialog s návrhy změn přiřazení – checkboxy pro výběr, potvrzení pouze vybraných.
/// Po kliku „Potvrdit vybrané“ volá applyRecalculationProposals a onApplied.
class _RecalculateProposalsDialog extends StatefulWidget {
  const _RecalculateProposalsDialog({
    required this.ref,
    required this.proposals,
    required this.onApplied,
  });

  final WidgetRef ref;
  final List<TaskRecalculationProposal> proposals;
  final VoidCallback onApplied;

  @override
  State<_RecalculateProposalsDialog> createState() => _RecalculateProposalsDialogState();
}

class _RecalculateProposalsDialogState extends State<_RecalculateProposalsDialog> {
  /// Mapa taskId -> zda je řádek vybrán k potvrzení.
  late Map<String, bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {for (final p in widget.proposals) p.taskId: true};
  }

  bool get _allSelected => _selected.values.every((v) => v);
  void _toggleSelectAll() {
    setState(() {
      final val = !_allSelected;
      _selected = {for (final k in _selected.keys) k: val};
    });
  }

  String _formatProposalRow(TaskRecalculationProposal p) {
    final newly = 'admin.recalculate_proposals_newly'.tr();
    final newName = p.newAssigneeName ?? 'common.none'.tr();
    String newTime = '';
    try {
      newTime = DateFormat('HH:mm').format(p.newStart);
    } catch (_) {}
    final hasOldAssignee = p.oldAssigneeName != null &&
        p.oldAssigneeName!.trim().isNotEmpty &&
        p.oldAssigneeName != 'common.none'.tr();
    if (hasOldAssignee) {
      final originally = 'admin.recalculate_proposals_originally'.tr();
      String oldTime = '';
      try {
        oldTime = DateFormat('HH:mm').format(p.oldStart);
      } catch (_) {}
      return '${p.taskTitle}\n$originally: ${p.oldAssigneeName} ($oldTime)\n$newly: $newName ($newTime)';
    }
    return '${p.taskTitle}\n$newly: $newName ($newTime)';
  }

  Future<void> _confirmSelected() async {
    final approved = widget.proposals.where((p) => _selected[p.taskId] == true).toList();
    if (approved.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await widget.ref.read(adminTasksProvider.notifier).applyRecalculationProposals(approved);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onApplied();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('admin.recalculate_proposals_title'.tr()),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: _allSelected,
                onChanged: (_) => _toggleSelectAll(),
                title: Text(_allSelected ? 'admin.recalculate_proposals_deselect_all'.tr() : 'admin.recalculate_proposals_select_all'.tr()),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  itemCount: widget.proposals.length,
                  itemBuilder: (context, i) {
                    final p = widget.proposals[i];
                    return CheckboxListTile(
                      value: _selected[p.taskId] ?? false,
                      onChanged: (v) => setState(() => _selected[p.taskId] = v ?? false),
                      title: Text(_formatProposalRow(p), style: const TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _confirmSelected,
          child: Text('admin.recalculate_proposals_confirm'.tr()),
        ),
      ],
    );
  }
}

/// Tlačítko „Přepočítat personál“ – při neaktivním modulu automatic_tasks zobrazeno s 🔒 a při kliku dialog.
class _RecalculateStaffButton extends StatelessWidget {
  const _RecalculateStaffButton({
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
    final muted = Colors.grey.shade600;
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
        label: Text('${'admin.tasks_recalculate_staff'.tr()} ${'admin.tasks_batch_limit'.tr()}'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPremiumLockedTap,
      icon: Icon(Icons.lock_outline, size: 20, color: muted),
      label: Text('${'admin.tasks_recalculate_staff'.tr()} ${'admin.tasks_batch_limit'.tr()}'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: muted,
      ),
    );
  }
}

/// Lišta pod vyhledáváním: filtr podle data (Vše / Dnes / Zítra), Přepočítat personál (premium), Schválit všechny.
class _TasksFilterBar extends StatelessWidget {
  const _TasksFilterBar({
    required this.dateFilter,
    required this.onDateFilterChanged,
    required this.onApproveAll,
    required this.isApproving,
    required this.onRecalculateStaff,
    required this.isRecalculating,
    required this.automaticTasksActive,
    required this.onPremiumLockedTap,
  });

  final TasksDateFilter dateFilter;
  final ValueChanged<TasksDateFilter> onDateFilterChanged;
  final VoidCallback onApproveAll;
  final bool isApproving;
  final VoidCallback onRecalculateStaff;
  final bool isRecalculating;
  final bool automaticTasksActive;
  final VoidCallback onPremiumLockedTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          SegmentedButton<TasksDateFilter>(
            segments: [
              ButtonSegment<TasksDateFilter>(
                value: TasksDateFilter.all,
                label: Text('admin.tasks_filter_all'.tr()),
                icon: const Icon(Icons.calendar_view_week, size: 18),
              ),
              ButtonSegment<TasksDateFilter>(
                value: TasksDateFilter.today,
                label: Text('admin.tasks_filter_today'.tr()),
                icon: const Icon(Icons.today, size: 18),
              ),
              ButtonSegment<TasksDateFilter>(
                value: TasksDateFilter.tomorrow,
                label: Text('admin.tasks_filter_tomorrow'.tr()),
                icon: const Icon(Icons.event, size: 18),
              ),
            ],
            selected: {dateFilter},
            onSelectionChanged: (Set<TasksDateFilter> selected) {
              if (selected.isNotEmpty) onDateFilterChanged(selected.first);
            },
          ),
          const Spacer(),
          _RecalculateStaffButton(
            isRecalculating: isRecalculating,
            automaticTasksActive: automaticTasksActive,
            onRecalculateStaff: onRecalculateStaff,
            onPremiumLockedTap: onPremiumLockedTap,
          ),
          const SizedBox(width: 8),
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
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Definice sloupce Kanbanu – systémový status (hodnota v DB) a i18n klíč pro nadpis.
class _KanbanColumnDef {
  const _KanbanColumnDef({required this.systemStatus, required this.titleKey});
  final String systemStatus;
  final String titleKey;
}

/// Normalizuje surový status z DB na systémovou hodnotu (pending, assigned, in_progress, completed, problem).
/// Zajišťuje zpětnou kompatibilitu s legacy hodnotami (Návrh, Nový, Probíhá, Hotovo).
String _normalizeToSystemStatus(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'pending';
  final s = raw.trim().toLowerCase();
  if (s == 'pending' || s == 'draft' || s == 'návrh') return 'pending';
  if (s == 'assigned' || s == 'new' || s == 'nový' || s == 'zadáno') return 'assigned';
  if (s == 'in_progress' || s == 'probíhá') return 'in_progress';
  if (s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno') return 'completed';
  if (s == 'problém' || s == 'problem' || s == 'issue') return 'problem';
  if (_systemStatuses.contains(raw.trim())) return raw.trim();
  return 'pending';
}

/// Lokalizovaný text statusu – využití easy_localization (task_status.* v JSON).
String _getLocalizedStatus(String systemStatus) {
  return 'task_status.$systemStatus'.tr();
}

/// Rozdělení úkolů do sloupců – filtrování čistě na základě systémových hodnot z DB.
List<TaskRow> _tasksForColumn(List<TaskRow> tasks, String systemStatus) {
  if (systemStatus == 'in_progress') {
    return tasks.where((t) {
      final norm = _normalizeToSystemStatus(t.status);
      return norm == 'in_progress' || norm == 'problem';
    }).toList();
  }
  return tasks.where((t) => _normalizeToSystemStatus(t.status) == systemStatus).toList();
}

/// Kanban nástěnka se 4 sloupci a Drag & Drop.
class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({
    required this.tasks,
    required this.ref,
    required this.categoriesByCode,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TaskRow> tasks;
  final WidgetRef ref;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final ValueChanged<TaskRow> onEdit;
  final ValueChanged<TaskRow> onDelete;

  static const _columns = [
    _KanbanColumnDef(systemStatus: 'pending', titleKey: 'admin.tasks_kanban_pending'),
    _KanbanColumnDef(systemStatus: 'assigned', titleKey: 'admin.tasks_kanban_assigned'),
    _KanbanColumnDef(systemStatus: 'in_progress', titleKey: 'admin.tasks_kanban_in_progress'),
    _KanbanColumnDef(systemStatus: 'completed', titleKey: 'admin.tasks_kanban_completed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _columns.map((col) {
          final columnTasks = _tasksForColumn(tasks, col.systemStatus);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _KanbanColumn(
                tasks: columnTasks,
                systemStatus: col.systemStatus,
                titleKey: col.titleKey,
                ref: ref,
                categoriesByCode: categoriesByCode,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Jeden sloupec Kanbanu: šedé pozadí, nadpis s počtem, DragTarget, scrollovatelný seznam karet.
class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.tasks,
    required this.systemStatus,
    required this.titleKey,
    required this.ref,
    required this.categoriesByCode,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TaskRow> tasks;
  final String systemStatus;
  final String titleKey;
  final WidgetRef ref;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final ValueChanged<TaskRow> onEdit;
  final ValueChanged<TaskRow> onDelete;

  @override
  Widget build(BuildContext context) {
    final title = titleKey.tr();
    return DragTarget<TaskRow>(
      onAcceptWithDetails: (details) async {
        final task = details.data;
        if (_normalizeToSystemStatus(task.status) == systemStatus) return;
        try {
          await ref.read(adminTasksProvider.notifier).updateTaskStatus(task.id, systemStatus);
          if (context.mounted) ref.invalidate(adminTasksProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: candidateData.isNotEmpty ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5) : Colors.grey.shade300,
              width: candidateData.isNotEmpty ? 2 : 1,
            ),
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
                    final task = tasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Draggable<TaskRow>(
                        data: task,
                        feedback: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 200,
                            child: _KanbanTaskCardContent(task: task),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.5,
                          child: _TaskCard(
                            task: task,
                            categoriesByCode: categoriesByCode,
                            onEdit: onEdit,
                            onDelete: onDelete,
                          ),
                        ),
                        child: _TaskCard(
                          task: task,
                          categoriesByCode: categoriesByCode,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
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

/// Obsah karty – sdílený pro feedback při táhnutí. Kompaktní layout shodný s _TaskCard.
class _KanbanTaskCardContent extends StatelessWidget {
  const _KanbanTaskCardContent({required this.task});

  final TaskRow task;

  static String _formatDue(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final assignedText = task.assignedToName != null
        ? 'admin.task_assigned'.tr(namedArgs: {'name': task.assignedToName!})
        : 'admin.task_unassigned'.tr();
    final dueStr = _formatDue(task.dueDate);
    final statusColor = _TaskCard._statusColor(_normalizeToSystemStatus(task.status));
    // Stejná hierarchie jako _TaskCard (bez ikony koše – drag feedback)
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. řádek – kontext: přeložený název kategorie
        Text(
          _taskTypeLabelKey(task.taskType).tr(),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        // 2. řádek – hlavní nadpis
        Text(
          (task.title.trim().isNotEmpty)
              ? task.title
              : (task.apartmentName?.trim().isNotEmpty == true
                  ? task.apartmentName!
                  : 'admin.task_no_title'.tr()),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // 3. řádek – lokace (jen pokud se liší od nadpisu) a osoba
        if (task.apartmentName != null &&
            task.apartmentName!.trim().isNotEmpty &&
            (task.title.trim().isNotEmpty))
          Text(
            task.apartmentName!,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        Text(
          assignedText,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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
                _TaskCard._statusLabel(_normalizeToSystemStatus(task.status)),
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
    );
  }
}

/// Jedna karta úkolu: kontext (kategorie) → hlavní nadpis (task.title) → lokace, přiřazení → pilulky. Celá karta klikatelná + ikona koše.
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.categoriesByCode,
    required this.onEdit,
    required this.onDelete,
  });

  final TaskRow task;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final ValueChanged<TaskRow> onEdit;
  final ValueChanged<TaskRow> onDelete;

  /// Barva podle systémového statusu (pending, assigned, in_progress, completed, problem).
  static Color _statusColor(String systemStatus) {
    switch (systemStatus) {
      case 'pending':
        return _statusDraft;
      case 'assigned':
        return _statusNew;
      case 'in_progress':
        return _statusInProgress;
      case 'problem':
        return _statusProblem;
      case 'completed':
        return _statusDone;
      default:
        return _statusNew;
    }
  }

  static String _statusLabel(String systemStatus) => _getLocalizedStatus(systemStatus);

  @override
  Widget build(BuildContext context) {
    final assigned = task.assignedToName != null
        ? 'admin.task_assigned'.tr(namedArgs: {'name': task.assignedToName!})
        : 'admin.task_unassigned'.tr();
    final dueStr =
        '${task.dueDate.day.toString().padLeft(2, '0')}.${task.dueDate.month.toString().padLeft(2, '0')} '
        '${task.dueDate.hour.toString().padLeft(2, '0')}:${task.dueDate.minute.toString().padLeft(2, '0')}';
    final isAlert = _isTaskTypeAlert(task.taskType);
    final cardColor = TaskVisuals.getBackgroundColor(task.taskType, categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null);
    final borderColor = isAlert ? Colors.red.shade400 : Colors.grey.shade300;
    final typeIcon = TaskVisuals.getIcon(task.taskType, categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null);

    // Celá karta je klikatelná (Apple Vibe) – otevře detail/editaci úkolu, bez 3-tečkového menu.
    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isAlert ? 2 : 1),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => onEdit(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. řádek – kontext: ikona + přeložený název kategorie
                    Row(
                      children: [
                        Icon(
                          typeIcon,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _taskTypeLabelKey(task.taskType).tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 2. řádek – hlavní nadpis: task.title (nebo fallback)
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
                    const SizedBox(height: 4),
                    // 3. řádek – lokace (jen pokud se liší od nadpisu) a osoba
                    if (task.apartmentName != null &&
                        task.apartmentName!.trim().isNotEmpty &&
                        (task.title.trim().isNotEmpty))
                      Text(
                        task.apartmentName!,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      assigned,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 4. řádek – pilulky (stav, datum)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(_normalizeToSystemStatus(task.status)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabel(_normalizeToSystemStatus(task.status)),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(_normalizeToSystemStatus(task.status)),
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
              const SizedBox(width: 4),
              // Ikona koše vpravo – Apple Vibe, samostatně klikatelná
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300),
                onPressed: () => onDelete(task),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Add / Edit dialogy a pomocné funkce ---

String _formatDateTime(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

DateTime? _parseDateTime(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final trimmed = s.trim();
  try {
    if (trimmed.contains(' ')) {
      final parts = trimmed.split(' ');
      final dParts = parts[0].split('.');
      final tParts = parts[1].split(':');
      if (dParts.length >= 3 && tParts.length >= 2) {
        return DateTime(
          int.parse(dParts[2]),
          int.parse(dParts[1]),
          int.parse(dParts[0]),
          int.parse(tParts[0]),
          int.parse(tParts[1]),
        );
      }
    } else {
      final dParts = trimmed.split('.');
      if (dParts.length >= 3) {
        return DateTime(
          int.parse(dParts[2]),
          int.parse(dParts[1]),
          int.parse(dParts[0]),
          12,
          0,
        );
      }
    }
  } catch (_) {}
  return null;
}

Future<String?> _showDateTimePicker(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final initialDt = initial ?? now;
  final date = await showDatePicker(
    context: context,
    initialDate: initialDt,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initialDt.hour, minute: initialDt.minute),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (time == null || !context.mounted) return null;
  final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  return _formatDateTime(dt);
}

/// Vrací lokalizační klíč pro daný task_type (fallback pro smazané/systémové typy mimo katalog).
String _taskTypeLabelKey(String taskType) {
  switch (taskType) {
    case 'cleaning':
      return 'admin.task_type_cleaning';
    case 'transfer_in':
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
    case 'Úklid':
      return 'admin.task_type_cleaning';
    case 'Transfer':
      return 'admin.task_type_transfer_in';
    case 'Jiné':
      return 'admin.task_type_other';
    default:
      return 'admin.task_type_other';
  }
}

/// Zda má být karta úkolu vizuálně zvýrazněna (závada, materiál).
bool _isTaskTypeAlert(String? taskType) {
  return taskType == 'issue' || taskType == 'material';
}

/// Dynamické načtení typů úkolů z katalogu klienta (tenant_services) s fallbackem pro smazané/systémové typy.
/// [catalog] = aktivní služby z DB, [currentValue] = typ úkolu při editaci – pokud není v katalogu, přidá se uměle.
List<DropdownMenuItem<String>> _buildTaskTypeDropdownItems(
  List<TenantServiceModel> catalog,
  String? currentValue,
) {
  final typeToName = <String, String>{};
  for (final s in catalog) {
    final st = s.serviceType.trim().toLowerCase();
    if (st.isNotEmpty && !typeToName.containsKey(st)) {
      typeToName[st] = s.name.trim().isEmpty ? st : s.name.trim();
    }
  }
  final items = typeToName.entries
      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
      .toList();
  if (currentValue != null && currentValue.trim().isNotEmpty) {
    final cv = currentValue.trim().toLowerCase();
    if (!typeToName.containsKey(cv)) {
      items.insert(0, DropdownMenuItem(
        value: cv,
        child: Text(_taskTypeLabelKey(cv).tr()),
      ));
    }
  }
  if (items.isEmpty) {
    items.add(DropdownMenuItem(value: 'extra', child: Text(_taskTypeLabelKey('extra').tr())));
  }
  return items;
}

/// Dialog pro přidání nového úkolu.
class _AddTaskDialog extends ConsumerStatefulWidget {
  const _AddTaskDialog({required this.ref, required this.onSaved});

  final WidgetRef ref;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<_AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();
  String? _selectedApartmentId;
  String? _selectedAssignedTo;
  String _taskType = 'extra';
  String _status = _systemStatuses.first;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApartmentId == null || _selectedApartmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_apartment_required_short'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final dueDate = _parseDateTime(_dueDateController.text.trim());
    if (dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_datetime_required_short'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error'.tr()), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    try {
      final assignedToUuid = _selectedAssignedTo != null && _selectedAssignedTo!.isNotEmpty
          ? _selectedAssignedTo
          : null;
      final dueIso = dueDate.toUtc().toIso8601String();
      final payload = {
        'tenant_id': tenantId,
        'apartment_id': _selectedApartmentId,
        'assigned_to': assignedToUuid,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': _status,
        'task_type': _taskType,
        'due_date': dueIso,
        'scheduled_start': dueIso,
      };
      await ref.read(adminTasksProvider.notifier).insertTaskInAdmin(payload);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == '42703' || e.message.contains('column')) {
        // ignore: avoid_print
        print('--- CHYBÍ SLOUPCE V TABULCE tasks. Spusť v Supabase SQL Editor příkazy z admin_tasks_provider.dart (_buildAlterTableSql).');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_save_error'.tr(namedArgs: {'error': e.message})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_save_error'.tr(namedArgs: {'error': e.toString()})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsProvider);
    final teamAsync = ref.watch(adminTeamProvider);
    final catalogAsync = ref.watch(tenantServicesProvider);

    return ModernAdminPanel(
      title: 'admin.tasks_add'.tr(),
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.label_outline),
                labelText: 'admin.task_field_title'.tr(),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'admin.validation_title_required'.tr() : null,
            ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.description_outlined),
                    labelText: 'admin.task_field_description'.tr(),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                catalogAsync.when(
                  data: (catalog) {
                    // Dynamické načtení typů úkolů z katalogu klienta (tenant_services) s fallbackem pro smazané/systémové typy.
                    final items = _buildTaskTypeDropdownItems(catalog, null);
                    final validValue = items.any((i) => i.value == _taskType)
                        ? _taskType
                        : (items.isNotEmpty ? items.first.value! : 'extra');
                    if (validValue != _taskType) WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _taskType = validValue));
                    return DropdownButtonFormField<String>(
                      value: validValue,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.list_alt_outlined),
                        labelText: 'admin.task_type_label'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: items,
                      onChanged: (v) => setState(() => _taskType = v ?? 'extra'),
                    );
                  },
                  loading: () => DropdownButtonFormField<String>(
                    value: 'extra',
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.list_alt_outlined),
                      labelText: 'admin.task_type_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [DropdownMenuItem(value: 'extra', child: Text(_taskTypeLabelKey('extra').tr()))],
                    onChanged: null,
                  ),
                  error: (_, __) => DropdownButtonFormField<String>(
                    value: 'extra',
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.list_alt_outlined),
                      labelText: 'admin.task_type_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [DropdownMenuItem(value: 'extra', child: Text(_taskTypeLabelKey('extra').tr()))],
                    onChanged: (v) => setState(() => _taskType = v ?? 'extra'),
                  ),
                ),
                const SizedBox(height: 12),
                apartmentsAsync.when(
                  data: (apartments) {
                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedApartmentId,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.list_alt_outlined),
                        labelText: 'admin.task_field_apartment'.tr(),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('admin.validation_apartment_required_short'.tr()),
                        ),
                        ...apartments.map((a) => DropdownMenuItem<String?>(
                              value: a.id,
                              child: Text(a.name),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedApartmentId = v),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'admin.validation_apartment_required_short'.tr() : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, st) => Text('admin.apartments_load_error'.tr()),
                ),
                const SizedBox(height: 12),
                teamAsync.when(
                  data: (members) {
                    final seenValues = <String>{};
                    final unique = <TeamMember>[];
                    for (final m in members) {
                      final value = m.dropdownId;
                      if (value.isEmpty) continue;
                      if (seenValues.contains(value)) continue;
                      final byName = unique.where((x) => x.name == m.name).toList();
                      if (byName.isNotEmpty) {
                        final existing = byName.first;
                        if (existing.profileId != null && m.profileId == null) continue;
                        if (existing.profileId == null && m.profileId != null) {
                          unique.removeWhere((x) => x.name == m.name);
                          seenValues.remove(existing.dropdownId);
                        }
                      }
                      seenValues.add(value);
                      unique.add(m);
                    }
                    final pendingLabel = 'admin.team_status_pending'.tr();
                    final items = <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(value: null, child: Text('admin.tasks_assign_nobody'.tr())),
                      ...unique.map((m) => DropdownMenuItem<String?>(
                          value: m.dropdownId,
                          child: Text(m.isFromInvitation ? '${m.name} ($pendingLabel)' : m.name),
                        )),
                    ];
                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedAssignedTo,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        labelText: 'admin.task_field_assign_to'.tr(),
                        border: OutlineInputBorder(),
                      ),
                      items: items,
                      onChanged: (v) => setState(() => _selectedAssignedTo = v),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, st) => Text('admin.team_load_error'.tr()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dueDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    labelText: 'admin.task_field_due_date'.tr(),
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  onTap: () async {
                    final initial = _parseDateTime(_dueDateController.text);
                    final result = await _showDateTimePicker(context, initial: initial);
                    if (result != null && mounted) {
                      setState(() => _dueDateController.text = result);
                    }
                  },
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'admin.validation_datetime_required_short'.tr() : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _systemStatuses.contains(_status) ? _status : _systemStatuses.first,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.list_alt_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _systemStatuses
                      .map((s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(_getLocalizedStatus(s)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _systemStatuses.first),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}

/// Read-only blok kontextových informací úkolu („Apple Vibe“).
/// Zobrazuje apartmán, rezervaci, hosty a audit – jen pokud jsou data k dispozici.
/// Rezervace je klikatelná (odkaz) při platném task.reservationId a [onReservationTap].
class _TaskContextSection extends StatelessWidget {
  const _TaskContextSection({
    required this.task,
    this.onReservationTap,
  });

  final TaskRow task;
  final void Function(String reservationId)? onReservationTap;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    // Apartmán – ikona + lokalizovaný text s názvem bytu.
    final aptName = task.apartmentName;
    if (aptName != null && aptName.trim().isNotEmpty) {
      chips.add(_ContextChip(
        icon: Icons.apartment_outlined,
        text: 'admin.task_context_apartment'.tr(namedArgs: {'name': aptName.trim()}),
      ));
    }

    // Rezervace – host + termín (jen pokud máme reservationGuestName nebo termín).
    final guest = task.reservationGuestName;
    final start = task.reservationStartDate;
    final end = task.reservationEndDate;
    final hasReservation = (guest != null && guest.trim().isNotEmpty) || start != null || end != null;
    if (hasReservation) {
      final parts = <String>[];
      if (guest != null && guest.trim().isNotEmpty) {
        parts.add(guest.trim());
      }
      if (start != null || end != null) {
        final fmt = DateFormat('d.M.');
        final range = start != null && end != null
            ? '${fmt.format(start.toLocal())} – ${fmt.format(end.toLocal())}'
            : (start != null ? fmt.format(start.toLocal()) : (end != null ? fmt.format(end.toLocal()) : null));
        if (range != null) {
          parts.add(parts.isEmpty ? range : '($range)');
        }
      }
      if (parts.isNotEmpty) {
        final reservationText = 'admin.task_context_reservation'.tr(namedArgs: {'guest': parts.join(' ')});
        final reservationId = task.reservationId;
        final isClickable = reservationId != null &&
            reservationId.trim().isNotEmpty &&
            onReservationTap != null;
        chips.add(isClickable
            ? _ContextLinkChip(
                icon: Icons.calendar_today_outlined,
                text: reservationText,
                onTap: () => onReservationTap!(reservationId),
              )
            : _ContextChip(
                icon: Icons.calendar_today_outlined,
                text: reservationText,
              ));
      }
    }

    // Hosté – počet osob.
    final count = task.reservationGuestCount;
    if (count != null && count > 0) {
      chips.add(_ContextChip(
        icon: Icons.people_outline,
        text: 'admin.task_context_guests'.tr(namedArgs: {'count': count.toString()}),
      ));
    }

    // Audit – datum vytvoření.
    final createdAt = task.createdAt;
    if (createdAt != null) {
      chips.add(_ContextChip(
        icon: Icons.access_time,
        text: 'admin.task_context_created_at'.tr(
          namedArgs: {'date': DateFormat('d.M.yyyy HH:mm').format(createdAt.toLocal())},
        ),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: chips,
      ),
    );
  }
}

/// Jeden kontextový čip: ikona + lokalizovaný text (emoji jsou již v i18n řetězci).
class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  /// Plný lokalizovaný text (např. z admin.task_context_apartment.tr(namedArgs: {...})).
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

/// Klikatelný kontextový čip (odkaz) – primární barva, podtržení, cursor pointer.
/// Používá se pro rezervaci v kontextu úkolu (navigace na detail rezervace).
class _ContextLinkChip extends StatelessWidget {
  const _ContextLinkChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: primary),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: primary,
                  decoration: TextDecoration.underline,
                  decorationColor: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog pro úpravu existujícího úkolu.
class _EditTaskDialog extends ConsumerStatefulWidget {
  const _EditTaskDialog({
    required this.ref,
    required this.task,
    required this.onSaved,
    this.onReservationTap,
  });

  final WidgetRef ref;
  final TaskRow task;
  final VoidCallback onSaved;
  /// Callback při kliknutí na odkaz rezervace – zavře dialog a otevře detail rezervace.
  final void Function(String reservationId)? onReservationTap;

  @override
  ConsumerState<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends ConsumerState<_EditTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dueDateController;
  late String _selectedApartmentId;
  late String? _selectedAssignedTo;
  late String _taskType;
  late String _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t.title);
    _descriptionController = TextEditingController(text: t.description);
    _dueDateController = TextEditingController(text: _formatDateTime(t.dueDate));
    _selectedApartmentId = t.apartmentId;
    _selectedAssignedTo = t.assignedTo;
    _taskType = t.taskType.trim().isEmpty ? 'extra' : t.taskType.trim().toLowerCase();
    _status = _normalizeToSystemStatus(t.status);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final dueDate = _parseDateTime(_dueDateController.text.trim());
    if (dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_datetime_required_short'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isSaving) return;

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final apartments = ref.read(apartmentsProvider).valueOrNull ?? [];
    final apartmentIdToSave = apartments.any((a) => a.id == _selectedApartmentId)
        ? _selectedApartmentId
        : (apartments.isNotEmpty ? apartments.first.id : _selectedApartmentId);

    try {
      final assignedToUuid = _selectedAssignedTo != null && _selectedAssignedTo!.isNotEmpty
          ? _selectedAssignedTo
          : null;
      final dueIso = dueDate.toUtc().toIso8601String();
      final updateFields = {
        'apartment_id': apartmentIdToSave,
        'assigned_to': assignedToUuid,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': _status,
        'task_type': _taskType,
        'due_date': dueIso,
        'scheduled_start': dueIso,
      };
      await ref.read(adminTasksProvider.notifier).updateTaskInAdmin(widget.task.id, updateFields);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_save_error'.tr(namedArgs: {'error': e.message})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_save_error'.tr(namedArgs: {'error': e.toString()})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsProvider);
    final teamAsync = ref.watch(adminTeamProvider);
    final catalogAsync = ref.watch(tenantServicesProvider);

    return ModernAdminPanel(
      title: 'admin.tasks_edit'.tr(),
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TaskContextSection(
              task: widget.task,
              onReservationTap: widget.onReservationTap,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.label_outline),
                labelText: 'admin.task_field_title'.tr(),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'admin.validation_title_required'.tr() : null,
            ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.description_outlined),
                    labelText: 'admin.task_field_description'.tr(),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                TaskMetadataSection(metadata: widget.task.metadata),
                const SizedBox(height: 12),
                catalogAsync.when(
                  data: (catalog) {
                    // Dynamické načtení typů úkolů z katalogu klienta (tenant_services) s fallbackem pro smazané/systémové typy.
                    final items = _buildTaskTypeDropdownItems(catalog, _taskType);
                    final validValue = items.any((i) => i.value == _taskType) ? _taskType : items.first.value!;
                    return DropdownButtonFormField<String>(
                      value: validValue,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.list_alt_outlined),
                        labelText: 'admin.task_type_label'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: items,
                      onChanged: (v) => setState(() => _taskType = v ?? validValue),
                    );
                  },
                  loading: () => DropdownButtonFormField<String>(
                    value: _taskType,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.list_alt_outlined),
                      labelText: 'admin.task_type_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [DropdownMenuItem(value: _taskType, child: Text(_taskTypeLabelKey(_taskType).tr()))],
                    onChanged: null,
                  ),
                  error: (_, __) => DropdownButtonFormField<String>(
                    value: _taskType,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.list_alt_outlined),
                      labelText: 'admin.task_type_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [DropdownMenuItem(value: _taskType, child: Text(_taskTypeLabelKey(_taskType).tr()))],
                    onChanged: (v) => setState(() => _taskType = v ?? _taskType),
                  ),
                ),
                const SizedBox(height: 12),
                apartmentsAsync.when(
                  data: (apartments) {
                    final validId = apartments.any((a) => a.id == _selectedApartmentId)
                        ? _selectedApartmentId
                        : (apartments.isNotEmpty ? apartments.first.id : null);
                    return DropdownButtonFormField<String?>(
                      initialValue: validId,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.list_alt_outlined),
                        labelText: 'admin.task_field_apartment'.tr(),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('admin.validation_apartment_required_short'.tr()),
                        ),
                        ...apartments.map((a) => DropdownMenuItem<String?>(
                              value: a.id,
                              child: Text(a.name),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedApartmentId = v ?? ''),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'admin.validation_apartment_required_short'.tr() : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, st) => Text('admin.apartments_load_error'.tr()),
                ),
                const SizedBox(height: 12),
                teamAsync.when(
                  data: (members) {
                    final currentUserId = widget.task.assignedTo;
                    final currentUserName = widget.task.assignedToName ?? 'planning_calendar.unknown'.tr();
                    final pendingLabel = 'admin.team_status_pending'.tr();
                    final dropdownItems = <DropdownMenuItem<String?>>[];
                    final seenIds = <String>{};

                    void addProfileItem(String id, String name, bool isPending) {
                      if (id.isEmpty || seenIds.contains(id)) return;
                      seenIds.add(id);
                      dropdownItems.add(
                        DropdownMenuItem<String?>(
                          value: id,
                          child: Text(
                            isPending ? '$name ($pendingLabel)' : name,
                            style: TextStyle(color: isPending ? Colors.grey : Colors.black),
                          ),
                        ),
                      );
                    }

                    dropdownItems.add(DropdownMenuItem<String?>(value: null, child: Text('admin.tasks_assign_nobody'.tr())));

                    if (currentUserId != null && currentUserId.isNotEmpty) {
                      final known = members.where((m) => m.dropdownId == currentUserId).toList();
                      if (known.isNotEmpty) {
                        addProfileItem(currentUserId, known.first.name, known.first.isFromInvitation);
                      } else {
                        addProfileItem(currentUserId, currentUserName, true);
                      }
                    }

                    for (final m in members) {
                      addProfileItem(m.dropdownId, m.name, m.isFromInvitation);
                    }

                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedAssignedTo != null && seenIds.contains(_selectedAssignedTo) ? _selectedAssignedTo : null,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        labelText: 'admin.task_field_assign_to'.tr(),
                        border: OutlineInputBorder(),
                      ),
                      items: dropdownItems,
                      onChanged: (v) => setState(() => _selectedAssignedTo = v),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, st) => Text('admin.team_load_error'.tr()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dueDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    labelText: 'admin.task_field_due_date'.tr(),
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  onTap: () async {
                    final initial = _parseDateTime(_dueDateController.text);
                    final result = await _showDateTimePicker(context, initial: initial);
                    if (result != null && mounted) {
                      setState(() => _dueDateController.text = result);
                    }
                  },
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'admin.validation_datetime_required_short'.tr() : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _systemStatuses.contains(_status) ? _status : _systemStatuses.first,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.list_alt_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _systemStatuses
                      .map((s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(_getLocalizedStatus(s)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _systemStatuses.first),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}
