import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/core/presentation/widgets/app_card.dart';
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
import 'package:falconest/features/admin/providers/apartment_services_options_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/providers/settlements_provider.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';
import 'package:falconest/features/settings/models/tenant_service_model.dart';
// Sdílená komponenta pro zobrazení financí a poznámek z rezervace.
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/admin/widgets/task_metadata_section.dart';
import 'package:falconest/features/admin/widgets/wallet_detail_modal.dart';
import 'package:falconest/utils/task_visuals.dart';
import 'package:falconest/widgets/task_legend.dart';

/// Sekce pro výběr dalších pracovníků (assigned_user_ids). Skrývá hlavního pracovníka –
/// člověk nemůže být zároveň hlavní i další pracovník.
Widget _buildAdditionalAssigneesChips({
  required BuildContext context,
  required List<TeamMember> members,
  required String? mainAssigneeId,
  required List<String> selectedIds,
  required void Function(List<String>) onChanged,
  bool isReadOnly = false,
}) {
  final pendingLabel = 'admin.team_status_pending'.tr();
  // PROČ: Hlavní pracovník nesmí být v seznamu „dalších“ – vyloučíme ho.
  final available = members.where((m) => mainAssigneeId == null || m.dropdownId != mainAssigneeId).toList();
  if (available.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('tasks.additional_assignees'.tr(), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: available.map((m) {
          final isSelected = selectedIds.contains(m.dropdownId);
          return FilterChip(
            label: Text(m.isFromInvitation ? '${m.name} ($pendingLabel)' : m.name),
            selected: isSelected,
            onSelected: isReadOnly ? null : (v) {
              if (v == true) {
                onChanged([...selectedIds, m.dropdownId]);
              } else {
                onChanged(selectedIds.where((id) => id != m.dropdownId).toList());
              }
            },
          );
        }).toList(),
      ),
    ],
  );
}

/// Barvy pro stavy úkolu – stejný styl jako v ostatních admin obrazovkách.
const _statusDraft = Color(0xFF7B1FA2);
const _statusNew = Color(0xFF757575);
const _statusInProgress = Color(0xFF1565C0);
const _statusDone = Color(0xFF2E7D32);
const _statusProblem = Color(0xFFC62828);

/// Systémové hodnoty statusů v DB – backendová logika používá výhradně tyto stringy,
/// překlad probíhá až ve vrstvě UI pomocí klíčů task_status.* v JSON.
const _systemStatuses = ['pending', 'assigned', 'in_progress', 'completed', 'problem'];

/// Vrací kladnou částku k výběru z metadata.amount_to_collect, jinak null.
double? _amountToCollectFromMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  final amt = metadata['amount_to_collect'];
  if (amt is num && amt > 0) return amt.toDouble();
  if (amt != null) {
    final parsed = double.tryParse(amt.toString());
    return parsed != null && parsed > 0 ? parsed : null;
  }
  return null;
}

/// Zobrazí dialog pro výběr: jen dokončit úkol vs. dokončit a zapsat hotovost do peněženky.
/// Vrací true = zapsat do peněženky, false = jen dokončit.
Future<bool> _showCashCollectionOnCompleteDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('tasks.cash_collection_title'.tr()),
      content: Text('tasks.cash_collection_message'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('tasks.action_just_complete'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('tasks.action_complete_and_save_cash'.tr()),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Administrativní obrazovka úkolů – karty (dlaždice), propojení Apartmány + Personál.
class AdminTasksScreen extends ConsumerStatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  ConsumerState<AdminTasksScreen> createState() => _AdminTasksScreenState();

  /// Veřejná metoda pro otevření dialogu přidání úkolu.
  /// [initialApartmentId] a [initialReservationId] – při vytváření z rezervace (Související úkoly).
  /// [initialReservationInfo] – textová informace o rezervaci (host + termín) pro kontextový pruh.
  /// [initialClientId] – předvyplní klienta u externí služby (z kontextu Detailu klienta).
  static void showAddTaskDialog(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onSaved,
    String? initialApartmentId,
    String? initialReservationId,
    String? initialReservationInfo,
    String? initialClientId,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddTaskDialog(
        ref: ref,
        onSaved: onSaved ?? () {
          ref.invalidate(adminTasksProvider);
          ref.invalidate(adminTasksStreamProvider);
        },
        initialApartmentId: initialApartmentId,
        initialReservationId: initialReservationId,
        initialReservationInfo: initialReservationInfo,
        initialClientId: initialClientId,
      ),
    );
  }

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
        onSaved: onSaved ?? () {
          ref.invalidate(adminTasksProvider);
          ref.invalidate(adminTasksStreamProvider);
        },
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
      ref.invalidate(adminTasksStreamProvider);
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

  Future<void> _runApproveAllPending() async {
    setState(() => _isApproving = true);
    try {
      final count = await ref.read(adminTasksProvider.notifier).approveAllPendingTasks();
      if (!mounted) return;
      ref.invalidate(adminTasksProvider);
      ref.invalidate(adminTasksStreamProvider);
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
    final tasksAsync = ref.watch(adminTasksStreamProvider);

    return Scaffold(
      body: tasksAsync.when(
        data: (tasks) {
          final filtered = _computeFiltered(tasks);
          final automaticTasksActive = isModuleActive(ref, 'automatic_tasks');
          final lockedTaskIds = ref.watch(lockedFinancialTaskIdsProvider).valueOrNull ?? {};
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
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'admin.tasks_empty'.tr()
                              : 'admin.tasks_search_no_results'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : _KanbanBoard(
                        tasks: filtered,
                        ref: ref,
                        lockedFinancialTaskIds: lockedTaskIds,
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
    AdminTasksScreen.showAddTaskDialog(context, ref);
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

/// Navigace měsíce pro záložku Úkoly – předchozí / vybraný měsíc a rok / následující.
/// Aktualizuje [selectedTaskMonthProvider]; stream úkolů se načte jen pro tento měsíc.
class _TasksMonthNavigator extends ConsumerWidget {
  const _TasksMonthNavigator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedTaskMonthProvider);
    final monthLabel = DateFormat.yMMM().format(selectedMonth);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
              ref.read(selectedTaskMonthProvider.notifier).state = prev;
            },
            tooltip: 'admin.tasks_prev_month'.tr(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              monthLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
              ref.read(selectedTaskMonthProvider.notifier).state = next;
            },
            tooltip: 'admin.tasks_next_month'.tr(),
          ),
        ],
      ),
    );
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
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPremiumLockedTap,
      icon: const Icon(Icons.lock_outline, size: 20),
      label: Text('admin.tasks_generate'.tr()),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.grey.shade600,
        elevation: 0,
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
      icon: const Icon(Icons.lock_outline, size: 20),
      label: Text('${'admin.tasks_recalculate_staff'.tr()} ${'admin.tasks_batch_limit'.tr()}'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.grey.shade600,
        elevation: 0,
      ),
    );
  }
}

/// Lišta pod vyhledáváním: vlevo výběr měsíce, vpravo Přepočítat personál (premium) a Schválit všechny.
class _TasksFilterBar extends ConsumerWidget {
  const _TasksFilterBar({
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const _TasksMonthNavigator(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
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
    required this.lockedFinancialTaskIds,
    required this.categoriesByCode,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TaskRow> tasks;
  final WidgetRef ref;
  /// Úkoly s výplatami nebo provizemi – nelze přetahovat ani mazat (ochrana účetnictví).
  final Set<String> lockedFinancialTaskIds;
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
                lockedFinancialTaskIds: lockedFinancialTaskIds,
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
    required this.lockedFinancialTaskIds,
    required this.categoriesByCode,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TaskRow> tasks;
  final String systemStatus;
  final String titleKey;
  final WidgetRef ref;
  final Set<String> lockedFinancialTaskIds;
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
        // Finanční zámek: úkol s výplatami/provizemi nelze přetahovat (ochrana účetnictví).
        if (lockedFinancialTaskIds.contains(task.id)) return;

        // PROČ: Při dokončení úkolu s výběrem hotovosti nabídneme zápis do peněženky administrátora.
        if (systemStatus == 'completed') {
          final amount = _amountToCollectFromMetadata(task.metadata);
          if (amount != null && amount > 0) {
            final recordToWallet = await _showCashCollectionOnCompleteDialog(context);
            if (!context.mounted) return;
            if (recordToWallet) {
              final tenantId = ref.read(authNotifierProvider).tenantIdForData;
              final profileId = ref.read(authNotifierProvider).state.profileId;
              if (tenantId != null && profileId != null && tenantId.isNotEmpty && profileId.isNotEmpty) {
                try {
                  await CashWalletRepository.instance.recordCashCollection(
                    taskId: task.id,
                    amount: amount,
                    tenantId: tenantId,
                    profileId: profileId,
                    expectedAmount: amount,
                  );
                  if (context.mounted) {
                    ref.invalidate(employeeCashWalletsProvider);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
                        backgroundColor: Colors.red.shade700,
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
          await ref.read(adminTasksProvider.notifier).updateTaskStatus(task.id, systemStatus);
          if (context.mounted) {
            ref.invalidate(adminTasksProvider);
            ref.invalidate(adminTasksStreamProvider);
          }
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
                    final isFinanciallyLocked = lockedFinancialTaskIds.contains(task.id);
                    final isStatusCompleted = _normalizeToSystemStatus(task.status) == 'completed';
                    final isLocked = isFinanciallyLocked || isStatusCompleted;
                    final card = _TaskCard(
                      task: task,
                      categoriesByCode: categoriesByCode,
                      isFinanciallyLocked: isFinanciallyLocked,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    );
                    if (isLocked) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: card,
                      );
                    }
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
                          child: card,
                        ),
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

/// Obsah karty – sdílený pro feedback při táhnutí. Kompaktní layout shodný s _TaskCard.
class _KanbanTaskCardContent extends StatelessWidget {
  const _KanbanTaskCardContent({required this.task});

  final TaskRow task;

  /// Zobrazuje termín v lokálním čase (Supabase = UTC). Viz _formatDateTime.
  static String _formatDue(DateTime d) {
    final local = d.isUtc ? d.toLocal() : d;
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Auditing: Zámek – při drag feedbacku zobrazíme ikonu u dokončených
    final isLocked = _normalizeToSystemStatus(task.status) == 'completed';
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
        // 1. řádek – kontext: referenční číslo (pokud existuje) + přeložený název kategorie + zámeček (dokončené)
        Row(
          children: [
            if (task.referenceNumber != null && task.referenceNumber!.trim().isNotEmpty) ...[
              Text('#${task.referenceNumber!.trim()}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                _taskTypeLabelKey(task.taskType).tr(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            if (isLocked) Icon(Icons.lock, size: 16, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 4),
        // 2. řádek – hlavní nadpis (externí: custom_title modře; apartmán: title/apartmentName)
        Builder(
          builder: (context) {
            final isExternal = (task.apartmentId.trim().isEmpty);
            final displayTitle = isExternal
                ? (task.customTitle?.trim().isNotEmpty == true ? task.customTitle! : task.title.trim().isNotEmpty ? task.title : 'admin.task_no_title'.tr())
                : (task.title.trim().isNotEmpty ? task.title : (task.apartmentName?.trim().isNotEmpty == true ? task.apartmentName! : 'admin.task_no_title'.tr()));
            return Text(
              displayTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isExternal ? const Color(0xFF1565C0) : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        const SizedBox(height: 4),
        // 3. řádek – lokace: externí = custom_location; apartmán = apartmentName (jen pokud se liší od nadpisu)
        Builder(
          builder: (context) {
            final isExternal = (task.apartmentId.trim().isEmpty);
            if (isExternal && task.customLocation != null && task.customLocation!.trim().isNotEmpty) {
              return Text(
                task.customLocation!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }
            if (!isExternal && task.apartmentName != null && task.apartmentName!.trim().isNotEmpty && task.title.trim().isNotEmpty) {
              return Text(
                task.apartmentName!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }
            return const SizedBox.shrink();
          },
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
    this.isFinanciallyLocked = false,
  });

  final TaskRow task;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final ValueChanged<TaskRow> onEdit;
  final ValueChanged<TaskRow> onDelete;
  /// true = úkol má výplaty nebo provize – zámek a skrytí koše (ochrana účetnictví).
  final bool isFinanciallyLocked;

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
    // Auditing: Zámek – dokončené úkoly nebo finančně vypořádané (výplaty/provize) – ikona zámku, skrytí koše.
    final isLocked = isFinanciallyLocked || _normalizeToSystemStatus(task.status) == 'completed';
    final assigned = task.assignedToName != null
        ? 'admin.task_assigned'.tr(namedArgs: {'name': task.assignedToName!})
        : 'admin.task_unassigned'.tr();
    final local = task.dueDate.isUtc ? task.dueDate.toLocal() : task.dueDate;
    final dueStr =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final typeIcon = TaskVisuals.getIcon(task.taskType, categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null);
    // Dynamické pastelové pozadí podle typu úkolu – kritické pro UX dispečinku (odpovídá horním filtrům).
    final cardColor = TaskVisuals.getBackgroundColor(task.taskType, categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null);

    // Celá karta je klikatelná (Apple Vibe) – otevře detail/editaci úkolu, bez 3-tečkového menu.
    return AppCard(
      backgroundColor: cardColor,
      onTap: () => onEdit(task),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. řádek – kontext: referenční číslo (pokud existuje) + ikona + přeložený název kategorie
                    Row(
                      children: [
                        if (task.referenceNumber != null && task.referenceNumber!.trim().isNotEmpty) ...[
                          Text(
                            '#${task.referenceNumber!.trim()}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 6),
                        ],
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
                    // 2. řádek – hlavní nadpis (externí: custom_title modře; apartmán: title/apartmentName)
                    Builder(
                      builder: (context) {
                        final isExternal = (task.apartmentId.trim().isEmpty);
                        final displayTitle = isExternal
                            ? (task.customTitle?.trim().isNotEmpty == true ? task.customTitle! : task.title.trim().isNotEmpty ? task.title : 'admin.task_no_title'.tr())
                            : (task.title.trim().isNotEmpty ? task.title : (task.apartmentName?.trim().isNotEmpty == true ? task.apartmentName! : 'admin.task_no_title'.tr()));
                        return Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isExternal ? const Color(0xFF1565C0) : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // 3. řádek – lokace: externí = custom_location; apartmán = apartmentName
                    Builder(
                      builder: (context) {
                        final isExternal = (task.apartmentId.trim().isEmpty);
                        if (isExternal && task.customLocation != null && task.customLocation!.trim().isNotEmpty) {
                          return Text(
                            task.customLocation!,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }
                        if (!isExternal && task.apartmentName != null && task.apartmentName!.trim().isNotEmpty && task.title.trim().isNotEmpty) {
                          return Text(
                            task.apartmentName!,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }
                        return const SizedBox.shrink();
                      },
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
              // Ikona koše vpravo – Apple Vibe. U dokončených úkolů místo koše zámek (nelze mazat).
              if (isLocked)
                Icon(Icons.lock, size: 16, color: Colors.grey)
              else
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
    );
  }
}

// --- Add / Edit dialogy a pomocné funkce ---

/// Formátuje datum a čas pro zobrazení v UI. Vždy zobrazuje lokální čas.
/// PROČ toLocal(): Supabase vrací UTC (timestamptz). Bez převodu by se v CET zobrazoval posun -1h.
String _formatDateTime(DateTime d) {
  final local = d.isUtc ? d.toLocal() : d;
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
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

/// Zda je typ úkolu transfer – pro zobrazení pole čísla letu a uložení do metadata.
bool _isTransferTaskType(String? taskType) {
  if (taskType == null || taskType.trim().isEmpty) return false;
  return ['transfer_in', 'transfer_out', 'transfer'].contains(taskType.trim().toLowerCase());
}

/// Vrací položky dropdownu pro výběr služby z katalogu. Value = service.id.
/// [includeNone] – přidá položku "Žádná" pro Edit dialog, aby šlo odebrat službu.
/// PROČ: Umožňuje přenos requires_photo do metadata při manuální tvorbě/úpravě úkolu.
List<DropdownMenuItem<String?>> _buildServiceDropdownItems(
  List<TenantServiceModel> catalog,
  String? selectedServiceId, {
  bool includeNone = false,
}) {
  if (catalog.isEmpty) {
    return [DropdownMenuItem(value: null, child: Text('admin.no_services_in_catalog'.tr()))];
  }
  final items = catalog
      .map<DropdownMenuItem<String?>>((s) => DropdownMenuItem(
            value: s.id,
            child: Text(s.name.trim().isEmpty ? s.serviceType : s.name),
          ))
      .toList();
  if (includeNone) {
    items.insert(0, DropdownMenuItem(value: null, child: Text('common.none'.tr())));
  }
  return items;
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
///
/// [initialApartmentId] a [initialReservationId] – volitelné při vytváření úkolu z rezervace
/// (sekce Související úkoly). Předvyberou apartmán a provážou úkol s rezervací v DB.
/// [initialReservationInfo] – text hosta a termínu pro kontextový pruh (např. "Káťa (4.3. - 11.3.2026)").
/// [initialClientId] – předvybrání klienta u externí služby (z kontextu Detailu klienta).
class _AddTaskDialog extends ConsumerStatefulWidget {
  const _AddTaskDialog({
    required this.ref,
    required this.onSaved,
    this.initialApartmentId,
    this.initialReservationId,
    this.initialReservationInfo,
    this.initialClientId,
  });

  final WidgetRef ref;
  final VoidCallback onSaved;
  /// Při vytvoření z rezervace – předvybrání apartmánu.
  final String? initialApartmentId;
  /// Při vytvoření z rezervace – provázání úkolu s rezervací (reservation_id v payloadu).
  final String? initialReservationId;
  /// Při vytvoření z rezervace – text pro kontextový pruh (host + termín).
  final String? initialReservationInfo;
  /// Z kontextu Detailu klienta – předvybrání klienta u externí služby.
  final String? initialClientId;

  @override
  ConsumerState<_AddTaskDialog> createState() => _AddTaskDialogState();
}

/// Kontextový pruh v dialogu přidání úkolu – apartmán a rezervace (při vytváření z rezervace).
class _AddTaskContextBar extends StatelessWidget {
  const _AddTaskContextBar({
    required this.apartmentsAsync,
    required this.selectedApartmentId,
    required this.taskMode,
    this.initialReservationInfo,
  });

  final AsyncValue<List<ApartmentRow>> apartmentsAsync;
  final String? selectedApartmentId;
  final _TaskFormMode taskMode;
  final String? initialReservationInfo;

  @override
  Widget build(BuildContext context) {
    final hasApartment = taskMode == _TaskFormMode.apartmentBound &&
        selectedApartmentId != null &&
        selectedApartmentId!.isNotEmpty;
    final reservationInfoText = initialReservationInfo?.trim();
    final hasReservation = reservationInfoText != null && reservationInfoText.isNotEmpty;

    if (!hasApartment && !hasReservation) return const SizedBox.shrink();

    String? apartmentName;
    if (hasApartment) {
      final apartments = apartmentsAsync.valueOrNull ?? [];
      apartmentName = apartments
          .where((a) => a.id == selectedApartmentId)
          .firstOrNull
          ?.name;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasApartment && apartmentName != null && apartmentName.isNotEmpty)
            Row(
              children: [
                Icon(Icons.apartment_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'admin.task_context_apartment'.tr(namedArgs: {'name': apartmentName}),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          if (hasApartment && hasReservation) const SizedBox(height: 8),
          if (hasReservation)
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'admin.task_context_reservation'.tr(namedArgs: {'guest': reservationInfoText}),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Modul v Supabase Storage pro přílohy úkolů – konzistence s mobilní aplikací.
const _storageModuleTasks = 'tasks';

/// Wrapper pro Rychlý výběr adres – odvozuje addressSourceClientId z vybraného klienta.
///
/// PROČ: Agency = vlastní adresy; external s agencyId = adresy agentury; external bez agencyId =
/// nezobrazit. Potřebujeme clientsProvider pro výpočet, proto oddělený widget. Používá se
/// v Add i Edit Task dialogu.
class _TaskAddressQuickSelectWrapper extends ConsumerWidget {
  const _TaskAddressQuickSelectWrapper({
    required this.selectedClientId,
    required this.controller,
    this.onFilled,
    this.enabled = true,
  });

  final String? selectedClientId;
  final TextEditingController controller;
  final VoidCallback? onFilled;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedClientId == null || selectedClientId!.isEmpty) {
      return const SizedBox.shrink();
    }
    final clientsAsync = ref.watch(clientsFullListProvider);
    return clientsAsync.when(
      data: (clients) {
        final client = clients.where((c) => c.id == selectedClientId).firstOrNull;
        final addressSourceId = _addressSourceClientId(client);
        if (addressSourceId == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ClientAddressQuickSelect(
              addressSourceClientId: addressSourceId,
              controller: controller,
              onFilled: onFilled,
              enabled: enabled,
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Vrací ID klienta, ze kterého načíst adresy pro Rychlý výběr.
///
/// PROČ: Agency má vlastní adresy; external s agencyId „půjčuje si“ adresy své
/// doporučující agentury (Pepa dohodnutý Davidem → Davidovy adresy).
String? _addressSourceClientId(ClientModel? client) {
  if (client == null) return null;
  final t = client.clientType?.toLowerCase() ?? '';
  if (t == 'agency') return client.id;
  if (t == 'external' &&
      client.agencyId != null &&
      client.agencyId!.trim().isNotEmpty) {
    return client.agencyId;
  }
  return null;
}

/// Rychlý výběr adres z adresáře klienta – zobrazí se nad polem pro vlastní adresu.
///
/// PROČ: U ručních externích úkolů (bez bytu) má klient často uložené adresy v Adresáři.
/// [addressSourceClientId] = ID klienta, jehož adresy se zobrazí. U agency je to
/// sám klient; u external s agencyId je to jeho doporučující agentura.
class _ClientAddressQuickSelect extends ConsumerWidget {
  const _ClientAddressQuickSelect({
    required this.addressSourceClientId,
    required this.controller,
    this.onFilled,
    this.enabled = true,
  });

  final String addressSourceClientId;
  final TextEditingController controller;
  final VoidCallback? onFilled;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(clientAddressesProvider(addressSourceClientId));
    return addressesAsync.when(
      data: (addresses) {
        if (addresses.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'tasks.form_quick_address_select'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: addresses.map((addr) {
                return ActionChip(
                  label: Text(addr.label),
                  onPressed: enabled
                      ? () {
                          controller.text = addr.address;
                          controller.selection = TextSelection.collapsed(offset: controller.text.length);
                          onFilled?.call();
                        }
                      : null,
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Typ úkolu: vázáno na apartmán (výchozí) nebo externí služba bez bytu.
enum _TaskFormMode { apartmentBound, externalService }

class _AddTaskDialogState extends ConsumerState<_AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();
  /// Pro externí službu: adresa/lokace (custom_location).
  final _customLocationController = TextEditingController();
  /// Pro externí službu – cena v EUR při „Vybere personál v hotovosti“.
  final _priceController = TextEditingController();
  /// Historical pricing: Cena služby u úkolu vázaného na apartmán – zamrazí se do metadata['service_price'].
  /// Auto-fill z apartment_services při výběru bytu a služby; dispečer může přepsat.
  final _servicePriceController = TextEditingController();
  /// Číslo letu pro transfery – uloží se do metadata['flight_number'], zobrazí jen při transfer_in/out/transfer.
  final _flightNumberController = TextEditingController();
  _TaskFormMode _taskMode = _TaskFormMode.apartmentBound;
  String? _selectedApartmentId;
  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    // Při vytvoření z rezervace: předvyber apartmán a typ "Vázáno na apartmán".
    if (widget.initialApartmentId != null && widget.initialApartmentId!.isNotEmpty) {
      _taskMode = _TaskFormMode.apartmentBound;
      _selectedApartmentId = widget.initialApartmentId;
    }
    // Z kontextu Detailu klienta (externí/agency): předvyber klienta a typ "Externí služba".
    if (widget.initialClientId != null && widget.initialClientId!.isNotEmpty) {
      _taskMode = _TaskFormMode.externalService;
      _selectedClientId = widget.initialClientId;
    }
  }
  String? _selectedAssignedTo;
  /// Další přiřazení pracovníci (assigned_user_ids) – pro sdílení úkolu mezi více lidmi.
  List<String> _selectedAdditionalUserIds = [];
  /// ID vybrané služby z katalogu. PROČ: Umožňuje odvodit task_type a requires_photo.
  String? _selectedServiceId;
  /// Způsob platby u externí služby: true = vybere personál v hotovosti, false = faktura/zaplaceno předem.
  bool _staffCollectsCash = false;
  String _status = _systemStatuses.first;
  bool _isSaving = false;
  /// Nově vybrané soubory k nahrání – bytes z file_picker (withData: true).
  List<PlatformFile> _pendingAttachments = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    _customLocationController.dispose();
    _priceController.dispose();
    _servicePriceController.dispose();
    _flightNumberController.dispose();
    super.dispose();
  }

  /// Otevře file_picker pro výběr přílohy (obrázek nebo PDF). withData: true získá bytes pro upload na web.
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final valid = result.files.where((f) => f.bytes != null && f.name.isNotEmpty).toList();
      if (valid.isNotEmpty) {
        setState(() => _pendingAttachments = [..._pendingAttachments, ...valid]);
      }
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final isExternal = _taskMode == _TaskFormMode.externalService;
    if (!isExternal && (_selectedApartmentId == null || _selectedApartmentId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_apartment_required_short'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (isExternal && (_selectedClientId == null || _selectedClientId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_client_required'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (isExternal && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_service_name_required'.tr()),
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
      final catalog = ref.read(tenantServicesProvider).valueOrNull ?? [];
      TenantServiceModel? service;
      if (_selectedServiceId != null && catalog.isNotEmpty) {
        try {
          service = catalog.firstWhere((s) => s.id == _selectedServiceId);
        } catch (_) {}
      }
      final taskType = service?.serviceType ?? 'extra';
      final metadata = <String, dynamic>{};
      if (service?.requiresPhoto == true) metadata['requires_photo'] = true;

      // PROČ: Externí služba – metadata.amount_to_collect. Mobilní aplikace zobrazí personálu
      // částku k vybrání. Pokud dispečer zvolil „Faktura/Zaplaceno předem“, amount_to_collect nenastavujeme.
      if (isExternal && _staffCollectsCash) {
        final priceStr = _priceController.text.trim();
        final price = double.tryParse(priceStr);
        if (price != null && price > 0) {
          metadata['amount_to_collect'] = price;
        }
      }

      // Historical pricing: Manuální úkol vázaný na apartmán – zamražení ceny v okamžiku vytvoření.
      // Reporty a fakturace čtou metadata['service_price']; změna ceníku pak nezmění historický obrat.
      if (!isExternal) {
        final priceStr = _servicePriceController.text.trim();
        final servicePrice = double.tryParse(priceStr);
        if (servicePrice != null && servicePrice > 0) {
          metadata['service_price'] = servicePrice;
        }
      }

      // PROČ: Číslo letu pro transfery – řidič v mobilní aplikaci získá proklik na FlightRadar24.
      if (_isTransferTaskType(taskType)) {
        final fn = _flightNumberController.text.trim();
        if (fn.isNotEmpty) metadata['flight_number'] = fn;
      }

      final assignedToUuid = _selectedAssignedTo != null && _selectedAssignedTo!.isNotEmpty
          ? _selectedAssignedTo
          : null;
      final dueIso = dueDate.toUtc().toIso8601String();
      final titleText = _titleController.text.trim();

      // KROK 1: Nahrání příloh na Supabase Storage (bytes z file_picker).
      List<String> mediaUrls = [];
      for (final file in _pendingAttachments) {
        if (file.bytes == null || file.bytes!.isEmpty) continue;
        try {
          final url = await MediaService.instance.uploadMediaBytes(
            file.bytes!,
            fileName: file.name,
            tenantId: tenantId,
            moduleName: _storageModuleTasks,
          );
          if (url != null && url.isNotEmpty) mediaUrls.add(url);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      final payload = <String, dynamic>{
        'tenant_id': tenantId,
        'apartment_id': isExternal ? null : _selectedApartmentId,
        if (!isExternal && widget.initialReservationId != null && widget.initialReservationId!.isNotEmpty) 'reservation_id': widget.initialReservationId,
        if (isExternal && _selectedClientId != null) 'client_id': _selectedClientId,
        if (isExternal) 'custom_title': titleText,
        if (isExternal) 'custom_location': _customLocationController.text.trim(),
        'assigned_to': assignedToUuid,
        if (_selectedAdditionalUserIds.isNotEmpty) 'assigned_user_ids': _selectedAdditionalUserIds,
        'title': titleText,
        'description': _descriptionController.text.trim(),
        'status': _status,
        'task_type': taskType,
        'due_date': dueIso,
        'scheduled_start': dueIso,
        if (service != null) 'service_id': service.id,
        'metadata': metadata,
        if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
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
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    final teamAsync = ref.watch(teamFullListProvider);
    final catalogAsync = ref.watch(tenantServicesProvider);

    // Historical pricing – auto-fill ceny při výběru bytu a služby. Provider reaguje na oba parametry.
    ref.listen(
      manualTaskServicePriceProvider((
        _selectedApartmentId ?? '',
        _selectedServiceId ?? '',
      )),
      (prev, next) {
        next.whenData((price) {
          if (!mounted) return;
          if (price != null && price > 0) {
            _servicePriceController.text = price.toStringAsFixed(2);
          }
        });
      },
    );

    return ModernAdminPanel(
      title: 'admin.tasks_add'.tr(),
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AddTaskContextBar(
                apartmentsAsync: apartmentsAsync,
                selectedApartmentId: _selectedApartmentId,
                taskMode: _taskMode,
                initialReservationInfo: widget.initialReservationInfo,
              ),
              // Přepínač: Vázáno na apartmán vs Externí služba.
            Text(
              'tasks.form_task_type'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<_TaskFormMode>(
              segments: [
                ButtonSegment<_TaskFormMode>(
                  value: _TaskFormMode.apartmentBound,
                  icon: const Icon(Icons.apartment, size: 18),
                  label: Text('tasks.form_mode_apartment'.tr()),
                ),
                ButtonSegment<_TaskFormMode>(
                  value: _TaskFormMode.externalService,
                  icon: const Icon(Icons.person_pin_circle, size: 18),
                  label: Text('tasks.form_mode_external'.tr()),
                ),
              ],
              selected: {_taskMode},
              onSelectionChanged: (s) => setState(() => _taskMode = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.label_outline),
                labelText: 'admin.task_field_title'.tr(),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return _taskMode == _TaskFormMode.apartmentBound
                      ? 'admin.validation_title_required'.tr()
                      : 'tasks.validation_service_name_required'.tr();
                }
                return null;
              },
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
                    // PROČ: Výběr služby (ne jen typu) umožňuje předat requires_photo do metadata.
                    final items = _buildServiceDropdownItems(catalog, _selectedServiceId);
                    final validValue = items.any((i) => i.value == _selectedServiceId)
                        ? _selectedServiceId
                        : (items.isNotEmpty ? items.first.value : null);
                    if (validValue != _selectedServiceId) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _selectedServiceId = validValue));
                    }
                    TenantServiceModel? service;
                    if (_selectedServiceId != null && catalog.isNotEmpty) {
                      try { service = catalog.firstWhere((s) => s.id == _selectedServiceId); } catch (_) {}
                    }
                    final taskType = service?.serviceType;
                    final showFlightField = _isTransferTaskType(taskType);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String?>(
                          value: validValue,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.list_alt_outlined),
                            labelText: 'admin.task_service_label'.tr(),
                            border: const OutlineInputBorder(),
                          ),
                          items: items,
                          onChanged: (v) => setState(() => _selectedServiceId = v),
                        ),
                        if (showFlightField) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _flightNumberController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.flight_takeoff_outlined),
                              labelText: 'tasks.flight_number_label'.tr(),
                              hintText: 'tasks.flight_number_hint'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => DropdownButtonFormField<String>(
                    value: null,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.list_alt_outlined),
                      labelText: 'admin.task_service_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [DropdownMenuItem(value: null, child: Text('common.loading'.tr()))],
                    onChanged: null,
                  ),
                  error: (_, __) => DropdownButtonFormField<String>(
                    value: null,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.list_alt_outlined),
                      labelText: 'admin.task_service_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [DropdownMenuItem(value: null, child: Text('admin.task_type_label'.tr()))],
                    onChanged: null,
                  ),
                ),
                const SizedBox(height: 12),
                // Vázáno na apartmán: výběr bytu a cena služby. Externí: klient + název služby + adresa.
                if (_taskMode == _TaskFormMode.apartmentBound)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      apartmentsAsync.when(
                        data: (apartments) {
                          return DropdownButtonFormField<String?>(
                            value: _selectedApartmentId,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.apartment),
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
                      // Historical pricing: Cena služby – auto-fill z apartment_services, dispečer může přepsat.
                      TextFormField(
                        controller: _servicePriceController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.euro),
                          labelText: 'tasks.form_service_price'.tr(),
                          hintText: 'common.zero_placeholder'.tr(),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                if (_taskMode == _TaskFormMode.externalService) ...[
                  ref.watch(clientsFullListProvider).when(
                    data: (allClients) {
                      // PROČ: Externí služba – zobrazujeme POUZE agency a external. Majitelé
                      // nemají smysl u úkolu bez bytu (fakturace jde na klienta, ne na majitele).
                      final clients = allClients
                          .where((c) {
                            final t = c.clientType?.toLowerCase() ?? '';
                            return t == 'agency' || t == 'external';
                          })
                          .toList();
                      if (clients.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'tasks.no_clients_hint'.tr(),
                            style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                          ),
                        );
                      }
                      final validValue = clients.any((c) => c.id == _selectedClientId)
                          ? _selectedClientId
                          : null;
                      if (validValue != _selectedClientId) {
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => setState(() => _selectedClientId = validValue));
                      }
                      return DropdownButtonFormField<String?>(
                        value: validValue,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person),
                          labelText: 'tasks.form_client'.tr(),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('tasks.validation_client_required'.tr()),
                          ),
                          ...clients.map((c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              )),
                        ],
                        onChanged: (v) => setState(() => _selectedClientId = v),
                        validator: (v) => (v == null || v.isEmpty) ? 'tasks.validation_client_required'.tr() : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
                  ),
                  const SizedBox(height: 12),
                  _TaskAddressQuickSelectWrapper(
                    selectedClientId: _selectedClientId,
                    controller: _customLocationController,
                    onFilled: () => setState(() {}),
                  ),
                  TextFormField(
                    controller: _customLocationController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      labelText: 'tasks.form_location'.tr(),
                      hintText: 'tasks.form_location_hint'.tr(),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Finanční blok pro externí službu.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'tasks.form_payment_block'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.euro),
                            labelText: 'tasks.form_price'.tr(),
                            hintText: 'common.zero_placeholder'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'tasks.form_payment_method'.tr(),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment<bool>(
                              value: true,
                              icon: const Icon(Icons.payments, size: 16),
                              label: Text('tasks.form_payment_cash'.tr()),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              icon: const Icon(Icons.receipt_long, size: 16),
                              label: Text('tasks.form_payment_invoice'.tr()),
                            ),
                          ],
                          selected: {_staffCollectsCash},
                          onSelectionChanged: (s) => setState(() => _staffCollectsCash = s.first),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _TaskAttachmentsSection(
                  existingUrls: const [],
                  onRemoveExisting: null,
                  pendingFiles: _pendingAttachments,
                  onRemovePending: (i) => setState(() => _pendingAttachments = List.from(_pendingAttachments)..removeAt(i)),
                  onAddPressed: _pickAttachment,
                  isUploading: _isSaving,
                ),
                const SizedBox(height: 12),
                teamAsync.when(
                  data: (members) {
                    // BUGFIX: Majitelé apartmánů (owners) jsou klienti, nesmí se jim přiřazovat úkoly. Filtrujeme pouze reálný personál.
                    final staffMembers = members.where((m) => m.role != 'property_owner').toList();
                    final seenValues = <String>{};
                    final unique = <TeamMember>[];
                    for (final m in staffMembers) {
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
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedAssignedTo,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline),
                            labelText: 'admin.task_field_assign_to'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          items: items,
                          onChanged: (v) => setState(() {
                            _selectedAssignedTo = v;
                            // PROČ: Hlavní pracovník nesmí být v „dalších“ – odebereme ho.
                            if (v != null && v.isNotEmpty) {
                              _selectedAdditionalUserIds = _selectedAdditionalUserIds.where((id) => id != v).toList();
                            }
                          }),
                        ),
                        const SizedBox(height: 12),
                        _buildAdditionalAssigneesChips(
                          context: context,
                          members: unique,
                          mainAssigneeId: _selectedAssignedTo,
                          selectedIds: _selectedAdditionalUserIds,
                          onChanged: (v) => setState(() => _selectedAdditionalUserIds = v),
                        ),
                      ],
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
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    if (_pendingAttachments.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('tasks.attachment_uploading'.tr()),
                    ],
                  ],
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}

/// Sekce příloh úkolu – stávající URL (klikací odkaz + mazání) a nově vybrané soubory.
/// Používá se v _AddTaskDialog i _EditTaskDialog pro nahrávání fotek/PDF z administrace.
class _TaskAttachmentsSection extends StatelessWidget {
  const _TaskAttachmentsSection({
    required this.existingUrls,
    required this.onRemoveExisting,
    required this.pendingFiles,
    required this.onRemovePending,
    required this.onAddPressed,
    required this.isUploading,
  });

  final List<String> existingUrls;
  final void Function(int index)? onRemoveExisting;
  final List<PlatformFile> pendingFiles;
  final void Function(int index) onRemovePending;
  final VoidCallback? onAddPressed;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final hasExisting = existingUrls.isNotEmpty;
    final hasPending = pendingFiles.isNotEmpty;
    if (!hasExisting && !hasPending && onAddPressed == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'tasks.attachments_title'.tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          if (onAddPressed != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isUploading ? null : onAddPressed,
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text('tasks.add_attachment_button'.tr()),
            ),
          ],
          if (hasExisting || hasPending) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < existingUrls.length; i++) ...[
                  _AttachmentChip(
                    label: '${'tasks.attachments_title'.tr()} ${i + 1}',
                    onTap: () => launchUrl(Uri.parse(existingUrls[i]), mode: LaunchMode.externalApplication),
                    onRemove: onRemoveExisting != null ? () => onRemoveExisting!(i) : null,
                    isExisting: true,
                  ),
                ],
                for (var i = 0; i < pendingFiles.length; i++) ...[
                  _AttachmentChip(
                    label: pendingFiles[i].name,
                    onRemove: () => onRemovePending(i),
                    isExisting: false,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Čip jedné přílohy – label, volitelně klik na otevření, křížek pro smazání.
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.label,
    this.onTap,
    this.onRemove,
    required this.isExisting,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool isExisting;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label.length > 25 ? '${label.substring(0, 22)}...' : label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isExisting ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
              decoration: isExisting ? TextDecoration.underline : null,
            ),
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: Colors.red.shade700),
          ),
        ],
      ],
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: child,
        ),
      ),
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

    // Referenční číslo úkolu – zobrazeno nahoře pro rychlou identifikaci.
    if (task.referenceNumber != null && task.referenceNumber!.trim().isNotEmpty) {
      chips.add(_ContextChip(
        icon: Icons.tag,
        text: '#${task.referenceNumber!.trim()}',
      ));
    }

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

/// Sekce přiložených fotek u úkolu typu Issue – horizontální seznam miniatur.
///
/// PROČ: Hlášení závad od pracovníků může mít více fotek. Klik otevře dialog
/// s InteractiveViewer (recyklace logiky z detailu účtenky).
class _TaskMediaSection extends StatelessWidget {
  const _TaskMediaSection({required this.mediaUrls});

  final List<String> mediaUrls;

  @override
  Widget build(BuildContext context) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'admin.task_media_attached_photos'.tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mediaUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final url = mediaUrls[index];
                return GestureDetector(
                  onTap: () => WalletDetailModal.showReceiptDialog(context, url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade600),
                      ),
                    ),
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
  late final TextEditingController _customLocationController;
  late final TextEditingController _priceController;
  late final TextEditingController _flightNumberController;
  late String _selectedApartmentId;
  late String? _selectedClientId;
  late String? _selectedAssignedTo;
  /// Další přiřazení pracovníci (assigned_user_ids) – pro sdílení úkolu mezi více lidmi.
  late List<String> _selectedAdditionalUserIds;
  /// ID vybrané služby z katalogu. PROČ: Umožňuje aktualizovat metadata.requires_photo při změně služby.
  late String? _selectedServiceId;
  late String _status;
  late bool _staffCollectsCash;
  bool _isSaving = false;
  /// Nově vybrané soubory k nahrání.
  List<PlatformFile> _pendingAttachments = [];
  /// Stávající URL z media_urls – uživatel může odstraňovat před uložením.
  late List<String> _existingMediaUrls;

  /// Externí úkol = bez apartment_id (apartmentId prázdné).
  bool get _isExternal => widget.task.apartmentId.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _existingMediaUrls = List.from(widget.task.mediaUrls);
    final t = widget.task;
    // Externí úkol: custom_title je hlavní název; jinak title.
    final isExt = t.apartmentId.trim().isEmpty;
    _titleController = TextEditingController(text: isExt ? (t.customTitle ?? t.title) : t.title);
    _descriptionController = TextEditingController(text: t.description);
    _dueDateController = TextEditingController(text: _formatDateTime(t.dueDate));
    _customLocationController = TextEditingController(text: t.customLocation ?? '');
    _selectedApartmentId = t.apartmentId;
    _selectedClientId = t.clientId;
    _selectedAssignedTo = t.assignedTo;
    _selectedAdditionalUserIds = List.from(t.assignedUserIds);
    _selectedServiceId = t.serviceId;
    _status = _normalizeToSystemStatus(t.status);
    // amount_to_collect v metadata znamená, že personál vybírá hotovost.
    final amt = t.metadata?['amount_to_collect'];
    _staffCollectsCash = amt != null && (amt is num && amt > 0);
    _priceController = TextEditingController(
      text: _staffCollectsCash && amt is num ? amt.toString() : '',
    );
    // PROČ: Číslo letu z metadat – řidič získá proklik na FlightRadar24.
    final fn = t.metadata?['flight_number'];
    _flightNumberController = TextEditingController(
      text: fn is String ? fn.trim() : (fn?.toString().trim() ?? ''),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    _customLocationController.dispose();
    _priceController.dispose();
    _flightNumberController.dispose();
    super.dispose();
  }

  /// Otevře file_picker pro výběr přílohy (obrázek nebo PDF). withData: true získá bytes pro upload na web.
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final valid = result.files.where((f) => f.bytes != null && f.name.isNotEmpty).toList();
      if (valid.isNotEmpty) {
        setState(() => _pendingAttachments = [..._pendingAttachments, ...valid]);
      }
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isExternal && (_selectedClientId == null || _selectedClientId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_client_required'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isExternal && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_service_name_required'.tr()),
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

    final apartments = ref.read(apartmentsFullListProvider).valueOrNull ?? [];
    final apartmentIdToSave = _isExternal
        ? null
        : (apartments.any((a) => a.id == _selectedApartmentId)
            ? _selectedApartmentId
            : (apartments.isNotEmpty ? apartments.first.id : _selectedApartmentId));

    try {
      final catalog = ref.read(tenantServicesProvider).valueOrNull ?? [];
      TenantServiceModel? service;
      if (_selectedServiceId != null && catalog.isNotEmpty) {
        try {
          service = catalog.firstWhere((s) => s.id == _selectedServiceId);
        } catch (_) {}
      }
      final taskType = service?.serviceType ?? widget.task.taskType;
      final mergedMetadata = Map<String, dynamic>.from(widget.task.metadata ?? {});
      mergedMetadata['requires_photo'] = service?.requiresPhoto == true;
      if (mergedMetadata['requires_photo'] == false) mergedMetadata.remove('requires_photo');

      // PROČ: Externí úkol – metadata.amount_to_collect. Při Faktura/Zaplaceno předem amount_to_collect nenastavujeme.
      if (_isExternal) {
        if (_staffCollectsCash) {
          final price = double.tryParse(_priceController.text.trim());
          if (price != null && price > 0) {
            mergedMetadata['amount_to_collect'] = price;
          } else {
            mergedMetadata.remove('amount_to_collect');
          }
        } else {
          mergedMetadata.remove('amount_to_collect');
        }
      }

      // PROČ: Číslo letu pro transfery – přidáme/odebereme dle zadané hodnoty, bez mazání ostatních metadat.
      if (_isTransferTaskType(taskType)) {
        final fn = _flightNumberController.text.trim();
        if (fn.isNotEmpty) {
          mergedMetadata['flight_number'] = fn;
        } else {
          mergedMetadata.remove('flight_number');
        }
      }

      // PROČ: Při dokončení úkolu s výběrem hotovosti nabídneme zápis do peněženky administrátora.
      if (_status == 'completed') {
        final amount = _amountToCollectFromMetadata(mergedMetadata);
        if (amount != null && amount > 0) {
          final recordToWallet = await _showCashCollectionOnCompleteDialog(context);
          if (!mounted) {
            setState(() => _isSaving = false);
            return;
          }
          if (recordToWallet) {
            final profileId = ref.read(authNotifierProvider).state.profileId;
            if (profileId != null && profileId.isNotEmpty) {
              try {
                await CashWalletRepository.instance.recordCashCollection(
                  taskId: widget.task.id,
                  amount: amount,
                  tenantId: tenantId,
                  profileId: profileId,
                  expectedAmount: amount,
                );
                if (mounted) ref.invalidate(employeeCashWalletsProvider);
              } catch (e) {
                if (mounted) {
                  setState(() => _isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
            }
          }
        }
      }

      final assignedToUuid = _selectedAssignedTo != null && _selectedAssignedTo!.isNotEmpty
          ? _selectedAssignedTo
          : null;
      final dueIso = dueDate.toUtc().toIso8601String();
      final titleText = _titleController.text.trim();

      // KROK 1: Nahrání nových příloh na Supabase Storage.
      List<String> mediaUrls = List.from(_existingMediaUrls);
      for (final file in _pendingAttachments) {
        if (file.bytes == null || file.bytes!.isEmpty) continue;
        try {
          final url = await MediaService.instance.uploadMediaBytes(
            file.bytes!,
            fileName: file.name,
            tenantId: tenantId,
            moduleName: _storageModuleTasks,
          );
          if (url != null && url.isNotEmpty) mediaUrls.add(url);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      // Při přepnutí na byt explicitně vynulujeme client_id, aby v DB nezůstal starý odkaz (přeřazení).
      final updateFields = <String, dynamic>{
        'apartment_id': apartmentIdToSave,
        if (_isExternal && _selectedClientId != null) 'client_id': _selectedClientId,
        if (!_isExternal) 'client_id': null,
        if (_isExternal) 'custom_title': titleText,
        if (_isExternal) 'custom_location': _customLocationController.text.trim(),
        'assigned_to': assignedToUuid,
        'assigned_user_ids': _selectedAdditionalUserIds,
        'title': titleText,
        'description': _descriptionController.text.trim(),
        'status': _status,
        'task_type': taskType,
        'due_date': dueIso,
        'scheduled_start': dueIso,
        'metadata': mergedMetadata,
        'service_id': service?.id,
        'media_urls': mediaUrls,
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
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    final teamAsync = ref.watch(teamFullListProvider);
    final catalogAsync = ref.watch(tenantServicesProvider);
    final lockedTaskIds = ref.watch(lockedFinancialTaskIdsProvider).valueOrNull ?? {};

    // Finanční zámek: úkol s výplatami nebo provizemi nelze měnit (ochrana účetnictví).
    final isFinanciallyLocked = lockedTaskIds.contains(widget.task.id);
    // Auditing: Zámek editace pro dokončené úkoly – neměnnost historie pro účetní audit.
    final isReadOnly = isFinanciallyLocked || _normalizeToSystemStatus(widget.task.status) == 'completed';
    // Přeřazení: u dokončených úkolů ponecháme editovatelné vazby (klient / byt), aby šlo opravit sirotky.
    final isReassignEnabled = !isFinanciallyLocked;

    final refNum = widget.task.referenceNumber?.trim();
    final editTitle = refNum != null && refNum.isNotEmpty
        ? '${'admin.tasks_edit'.tr()} • #$refNum'
        : 'admin.tasks_edit'.tr();
    return ModernAdminPanel(
      title: editTitle,
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
            if (isFinanciallyLocked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.orange.shade800, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'admin.task_financially_locked'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isReadOnly && !isFinanciallyLocked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'tasks.task_locked_info'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (!isFinanciallyLocked) ...[
              const SizedBox(height: 16),
            ],
            // Sekce Přeřazení – oprava vazby na klienta/byt (sirotčí úkoly po smazání klienta v CRM).
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'admin.tasks_reassign_section'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'admin.tasks_reassign_section_hint'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            TextFormField(
              controller: _titleController,
              readOnly: isReadOnly,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.label_outline),
                labelText: 'admin.task_field_title'.tr(),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return _isExternal
                      ? 'tasks.validation_service_name_required'.tr()
                      : 'admin.validation_title_required'.tr();
                }
                return null;
              },
            ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  readOnly: isReadOnly,
                  maxLines: 3,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.description_outlined),
                    labelText: 'admin.task_field_description'.tr(),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                TaskMetadataSection(metadata: widget.task.metadata),
                if (widget.task.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _TaskMediaSection(mediaUrls: widget.task.mediaUrls),
                ],
                const SizedBox(height: 12),
                catalogAsync.when(
                  data: (catalog) {
                    // PROČ: Výběr služby umožňuje aktualizovat metadata.requires_photo při změně služby.
                    final items = _buildServiceDropdownItems(catalog, _selectedServiceId, includeNone: true);
                    final validValue = items.any((i) => i.value == _selectedServiceId)
                        ? _selectedServiceId
                        : (items.isNotEmpty ? items.first.value : _selectedServiceId);
                    if (validValue != _selectedServiceId) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _selectedServiceId = validValue));
                    }
                    TenantServiceModel? service;
                    if (_selectedServiceId != null && catalog.isNotEmpty) {
                      try { service = catalog.firstWhere((s) => s.id == _selectedServiceId); } catch (_) {}
                    }
                    final taskType = service?.serviceType ?? widget.task.taskType;
                    final showFlightField = _isTransferTaskType(taskType);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String?>(
                          value: validValue,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.list_alt_outlined),
                            labelText: 'admin.task_service_label'.tr(),
                            border: const OutlineInputBorder(),
                          ),
                          items: items,
                          onChanged: isReadOnly ? null : (v) => setState(() => _selectedServiceId = v),
                        ),
                        if (showFlightField) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _flightNumberController,
                            readOnly: isReadOnly,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.flight_takeoff_outlined),
                              labelText: 'tasks.flight_number_label'.tr(),
                              hintText: 'tasks.flight_number_hint'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => DropdownButtonFormField<String?>(
                    value: _selectedServiceId,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.list_alt_outlined),
                      labelText: 'admin.task_service_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [DropdownMenuItem(value: _selectedServiceId, child: Text('common.loading'.tr()))],
                    onChanged: null,
                  ),
                  error: (_, __) => DropdownButtonFormField<String?>(
                    value: _selectedServiceId,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.list_alt_outlined),
                      labelText: 'admin.task_service_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [DropdownMenuItem(value: _selectedServiceId, child: Text('admin.task_type_label'.tr()))],
                    onChanged: null,
                  ),
                ),
                const SizedBox(height: 12),
                // Vázáno na apartmán: výběr bytu. Externí: klient + název služby + adresa + platba.
                // Přeřazení: dropdowny zůstávají editovatelné i u dokončeného úkolu (isReassignEnabled).
                if (!_isExternal)
                  apartmentsAsync.when(
                    data: (apartments) {
                      final validId = apartments.any((a) => a.id == _selectedApartmentId)
                          ? _selectedApartmentId
                          : (apartments.isNotEmpty ? apartments.first.id : null);
                      return DropdownButtonFormField<String?>(
                        value: validId,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.apartment),
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
                        onChanged: isReassignEnabled ? (v) => setState(() => _selectedApartmentId = v ?? '') : null,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'admin.validation_apartment_required_short'.tr() : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('admin.apartments_load_error'.tr()),
                  ),
                if (_isExternal) ...[
                  ref.watch(clientsFullListProvider).when(
                    data: (allClients) {
                      // PROČ: Externí úkol – zobrazujeme POUZE agency a external (stejná logika jako Add Task).
                      final clients = allClients
                          .where((c) {
                            final t = c.clientType?.toLowerCase() ?? '';
                            return t == 'agency' || t == 'external';
                          })
                          .toList();
                      if (clients.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'tasks.no_clients_hint'.tr(),
                            style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                          ),
                        );
                      }
                      // Sirotčí klient: aktuální ID není v seznamu (smazaný klient) – nepřepisujeme na null,
                      // aby dropdown zobrazil položku „Neplatný klient (ID: …)“ a uživatel mohl vybrat nového.
                      final isOrphan = _selectedClientId != null &&
                          _selectedClientId!.trim().isNotEmpty &&
                          !clients.any((c) => c.id == _selectedClientId);
                      final dropdownValue = isOrphan ? _selectedClientId : (clients.any((c) => c.id == _selectedClientId) ? _selectedClientId : null);
                      final orphanShortId = _selectedClientId != null && _selectedClientId!.length > 8
                          ? _selectedClientId!.substring(0, 8)
                          : (_selectedClientId ?? '');
                      return DropdownButtonFormField<String?>(
                        value: dropdownValue,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person),
                          labelText: 'tasks.form_client'.tr(),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('tasks.validation_client_required'.tr()),
                          ),
                          if (isOrphan)
                            DropdownMenuItem<String?>(
                              value: _selectedClientId,
                              child: Text('tasks.client_orphan_label'.tr(namedArgs: {'id': orphanShortId})),
                            ),
                          ...clients.map((c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              )),
                        ],
                        onChanged: isReassignEnabled ? (v) => setState(() => _selectedClientId = v) : null,
                        validator: (v) => (v == null || v.isEmpty) ? 'tasks.validation_client_required'.tr() : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
                  ),
                  const SizedBox(height: 12),
                  _TaskAddressQuickSelectWrapper(
                    selectedClientId: _selectedClientId,
                    controller: _customLocationController,
                    onFilled: () => setState(() {}),
                    enabled: !isReadOnly,
                  ),
                  TextFormField(
                    controller: _customLocationController,
                    readOnly: isReadOnly,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      labelText: 'tasks.form_location'.tr(),
                      hintText: 'tasks.form_location_hint'.tr(),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'tasks.form_payment_block'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _priceController,
                          readOnly: isReadOnly,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.euro),
                            labelText: 'tasks.form_price'.tr(),
                            hintText: 'common.zero_placeholder'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'tasks.form_payment_method'.tr(),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment<bool>(
                              value: true,
                              icon: const Icon(Icons.payments, size: 16),
                              label: Text('tasks.form_payment_cash'.tr()),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              icon: const Icon(Icons.receipt_long, size: 16),
                              label: Text('tasks.form_payment_invoice'.tr()),
                            ),
                          ],
                          selected: {_staffCollectsCash},
                          onSelectionChanged: isReadOnly ? null : (s) => setState(() => _staffCollectsCash = s.first),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _TaskAttachmentsSection(
                  existingUrls: _existingMediaUrls,
                  onRemoveExisting: isReadOnly ? null : (i) => setState(() => _existingMediaUrls = List.from(_existingMediaUrls)..removeAt(i)),
                  pendingFiles: _pendingAttachments,
                  onRemovePending: isReadOnly ? (_) {} : (i) => setState(() => _pendingAttachments = List.from(_pendingAttachments)..removeAt(i)),
                  onAddPressed: isReadOnly ? null : _pickAttachment,
                  isUploading: _isSaving,
                ),
                const SizedBox(height: 12),
                teamAsync.when(
                  data: (members) {
                    // BUGFIX: Majitelé apartmánů (owners) jsou klienti, nesmí se jim přiřazovat úkoly. Filtrujeme pouze reálný personál.
                    final staffMembers = members.where((m) => m.role != 'property_owner').toList();
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

                    for (final m in staffMembers) {
                      addProfileItem(m.dropdownId, m.name, m.isFromInvitation);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedAssignedTo != null && seenIds.contains(_selectedAssignedTo) ? _selectedAssignedTo : null,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline),
                            labelText: 'admin.task_field_assign_to'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          items: dropdownItems,
                          onChanged: isReadOnly
                              ? null
                              : (v) => setState(() {
                                    _selectedAssignedTo = v;
                                    if (v != null && v.isNotEmpty) {
                                      _selectedAdditionalUserIds =
                                          _selectedAdditionalUserIds.where((id) => id != v).toList();
                                    }
                                  }),
                        ),
                        const SizedBox(height: 12),
                        _buildAdditionalAssigneesChips(
                          context: context,
                          members: staffMembers,
                          mainAssigneeId: _selectedAssignedTo,
                          selectedIds: _selectedAdditionalUserIds,
                          onChanged: (v) => setState(() => _selectedAdditionalUserIds = v),
                          isReadOnly: isReadOnly,
                        ),
                      ],
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
                  onTap: isReadOnly
                      ? null
                      : () async {
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
                  onChanged: isReadOnly ? null : (v) => setState(() => _status = v ?? _systemStatuses.first),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(isReadOnly ? 'common.close'.tr() : 'common.cancel'.tr()),
        ),
        // U dokončeného úkolu zobrazíme Uložit i při isReadOnly, pokud je povoleno přeřazení (oprava vazby na klienta/byt).
        if (!isReadOnly || isReassignEnabled) ...[
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    if (_pendingAttachments.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('tasks.attachment_uploading'.tr()),
                    ],
                  ],
                )
              : Text('common.save'.tr()),
        ),
        ],
      ],
    );
  }
}
