import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/widgets/app_empty_state.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/utils/geo_json_point.dart';
import 'package:falconest/core/services/geocoding_service.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/admin_cross_nav_provider.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartment_services_options_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/checklist_templates_list_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/providers/settlements_provider.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';
import 'package:falconest/features/settings/models/tenant_service_model.dart';
// Sdílená komponenta pro zobrazení financí a poznámek z rezervace.
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/admin/widgets/admin_entity_cross_links.dart';
import 'package:falconest/features/admin/models/task_custom_tag.dart';
import 'package:falconest/features/admin/widgets/task_checklist_instance_editor_section.dart';
import 'package:falconest/features/admin/widgets/task_audit_history_section.dart';
import 'package:falconest/features/admin/widgets/task_custom_tags_editor.dart';
import 'package:falconest/features/admin/widgets/task_metadata_section.dart';
import 'package:falconest/features/admin/widgets/wallet_detail_modal.dart';
import 'package:falconest/features/communication/models/message_template_selector_context.dart';
import 'package:falconest/features/communication/providers/message_templates_admin_provider.dart';
import 'package:falconest/features/communication/services/template_placeholder_service.dart';
import 'package:falconest/features/communication/services/whatsapp_sender_service.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart'
    show parseTaskEstimateMinutes;
import 'package:falconest/widgets/task_legend.dart';
import 'package:falconest/features/admin/widgets/kanban/kanban_bulk_selection_bar.dart';
import 'package:falconest/features/admin/widgets/kanban/kanban_column.dart';
import 'package:falconest/features/admin/widgets/kanban/kanban_filter_bar.dart';
import 'package:falconest/features/admin/widgets/kanban/kanban_shared.dart';

/// SnackBar při PostgREST chybě – připojí [PostgrestException.message] k obecnému textu (debug u zákazníka).
String _postgrestSnackMessage(PostgrestException e) {
  final base = 'common.generic_error_user_friendly'.tr();
  final detail = e.message.trim();
  if (detail.isEmpty) return base;
  return '$base: $detail';
}

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
  final available = members
      .where((m) => mainAssigneeId == null || m.dropdownId != mainAssigneeId)
      .toList();
  if (available.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'tasks.additional_assignees'.tr(),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: available.map((m) {
          final isSelected = selectedIds.contains(m.dropdownId);
          final rolesString = m.roles.isNotEmpty
              ? m.roles.map((r) => 'admin.role_$r'.tr()).join(', ')
              : null;
          final hasRoles = rolesString != null && rolesString.isNotEmpty;
          final String chipLabel;
          if (hasRoles) {
            chipLabel = m.isFromInvitation
                ? '${m.name} ($pendingLabel) • $rolesString'
                : '${m.name} ($rolesString)';
          } else {
            chipLabel = m.isFromInvitation
                ? '${m.name} ($pendingLabel)'
                : m.name;
          }
          return FilterChip(
            label: Text(
              chipLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            selected: isSelected,
            onSelected: isReadOnly
                ? null
                : (v) {
                    if (v == true) {
                      onChanged([...selectedIds, m.dropdownId]);
                    } else {
                      onChanged(
                        selectedIds.where((id) => id != m.dropdownId).toList(),
                      );
                    }
                  },
          );
        }).toList(),
      ),
    ],
  );
}

/// Systémové hodnoty statusů v DB – backendová logika používá výhradně tyto stringy,
/// překlad probíhá až ve vrstvě UI pomocí klíčů task_status.* v JSON.
const _systemStatuses = [
  'pending',
  'assigned',
  'in_progress',
  'completed',
  'problem',
];

/// Hodnota vrácená z dialogu hromadného přiřazení při zvolení „Nikdo“ (není platné UUID).
const String _kBulkUnassignToken = '__bulk_unassign__';

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
        onSaved:
            onSaved ??
            () {
              ref.invalidate(adminTasksProvider);
              ref.invalidate(adminTasksStreamProvider);
              invalidatePlanningCalendarCaches(ref);
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
        onSaved:
            onSaved ??
            () {
              ref.invalidate(adminTasksProvider);
              ref.invalidate(adminTasksStreamProvider);
              invalidatePlanningCalendarCaches(ref);
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

  /// Režim výběru více úkolů v Kanbanu (checkboxy + hromadné akce). Drag & drop zůstává mimo tento režim.
  bool _kanbanSelectionMode = false;

  /// Vybrané úkoly pro hromadné změny (id).
  final Set<String> _selectedKanbanTaskIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleKanbanTaskSelection(String taskId) {
    setState(() {
      if (_selectedKanbanTaskIds.contains(taskId)) {
        _selectedKanbanTaskIds.remove(taskId);
      } else {
        _selectedKanbanTaskIds.add(taskId);
      }
    });
  }

  /// Dlouhé podržení karty: zapne výběr a přidá úkol.
  void _enterKanbanSelectionWith(String taskId) {
    setState(() {
      _kanbanSelectionMode = true;
      _selectedKanbanTaskIds.add(taskId);
    });
  }

  void _exitKanbanSelection() {
    setState(() {
      _kanbanSelectionMode = false;
      _selectedKanbanTaskIds.clear();
    });
  }

  void _toggleKanbanSelectionModeButton() {
    setState(() {
      _kanbanSelectionMode = !_kanbanSelectionMode;
      if (!_kanbanSelectionMode) {
        _selectedKanbanTaskIds.clear();
      }
    });
  }

  Future<void> _runBulkStatusChange() async {
    if (_selectedKanbanTaskIds.isEmpty) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('admin.tasks_bulk_status_title'.tr()),
        children: [
          for (final s in _systemStatuses)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(s),
              child: Text('task_status.$s'.tr()),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await ref.read(adminTasksProvider.notifier).bulkUpdateTaskStatus(
            _selectedKanbanTaskIds.toList(),
            picked,
          );
      if (!mounted) return;
      ref.invalidate(adminTasksProvider);
      ref.invalidate(adminTasksStreamProvider);
      _exitKanbanSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.tasks_bulk_success'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _runBulkAssign() async {
    if (_selectedKanbanTaskIds.isEmpty) return;
    final team = ref.read(teamFullListProvider).valueOrNull ?? [];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('admin.tasks_bulk_assign_title'.tr()),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(_kBulkUnassignToken),
            child: Text('admin.tasks_assign_nobody'.tr()),
          ),
          for (final m in team)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(m.dropdownId),
              child: Text(m.name),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (picked == null) return;
    final profileId = picked == _kBulkUnassignToken ? null : picked;
    try {
      await ref.read(adminTasksProvider.notifier).bulkAssignTasks(
            _selectedKanbanTaskIds.toList(),
            profileId,
          );
      if (!mounted) return;
      ref.invalidate(adminTasksProvider);
      ref.invalidate(adminTasksStreamProvider);
      _exitKanbanSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.tasks_bulk_success'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                : 'admin.tasks_generated_count'.tr(
                    namedArgs: {'count': '$totalCount'},
                  ),
          ),
          backgroundColor: totalCount == 0
              ? context.customColors.warning
              : context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'common.generic_error_user_friendly'.tr(),
          ),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _runApproveAllPending() async {
    setState(() => _isApproving = true);
    try {
      final count = await ref
          .read(adminTasksProvider.notifier)
          .approveAllPendingTasks();
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
          backgroundColor: count == 0
              ? context.customColors.warning
              : context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'common.generic_error_user_friendly'.tr(),
          ),
          backgroundColor: context.colors.error,
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
      final proposals = await ref
          .read(adminTasksProvider.notifier)
          .recalculateAssignees();
      if (!mounted) return;
      setState(() => _isRecalculating = false);
      if (proposals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.recalculate_no_changes'.tr()),
            backgroundColor: context.customColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => RecalculateProposalsDialog(
          ref: ref,
          proposals: proposals,
          onApplied: () {
            ref.invalidate(adminTasksProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('admin.tasks_recalculate_staff_success'.tr()),
                backgroundColor: context.customColors.success,
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
          content: Text(
            'common.generic_error_user_friendly'.tr(),
          ),
          backgroundColor: context.colors.error,
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
    // PROČ select(0/1/2): při změně jednoho úkolu zůstane fáze „data“ – Scaffold se nepřestavuje celý.
    final loadPhase = ref.watch(
      adminTasksStreamProvider.select((async) {
        if (async.isLoading) return 0;
        if (async.hasError) return 1;
        return 2;
      }),
    );

    if (loadPhase == 0) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (loadPhase == 1) {
      final err = ref.read(adminTasksStreamProvider).error;
      final st = ref.read(adminTasksStreamProvider).stackTrace;
      if (kDebugMode) {
        debugPrint('adminTasksStreamProvider error: $err');
        debugPrint('$st');
      }
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colors.error),
              SizedBox(height: AppSpacing.md),
              Text(
                'admin.tasks_load_error'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'common.generic_error_user_friendly'.tr(),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => ref.invalidate(adminTasksStreamProvider),
                child: Text('admin.tasks_retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    final automaticTasksActive = isModuleActive(ref, 'automatic_tasks');

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopActionBar(
            searchController: _searchController,
            onSearchChanged: () {
              ref.read(kanbanTasksSearchQueryProvider.notifier).state =
                  _searchController.text.trim().toLowerCase();
            },
            onAdd: () => _showAddDialog(context, ref),
            onGenerate: _runGenerateSmartTasks,
            isGenerating: _isGenerating,
            automaticTasksActive: automaticTasksActive,
            onPremiumLockedTap: () => _showPremiumLockedDialog(context),
            kanbanSelectionMode: _kanbanSelectionMode,
            onToggleKanbanSelectionMode: _toggleKanbanSelectionModeButton,
          ),
          if (_kanbanSelectionMode || _selectedKanbanTaskIds.isNotEmpty)
            KanbanBulkSelectionBar(
              selectedCount: _selectedKanbanTaskIds.length,
              onChangeStatus: _runBulkStatusChange,
              onAssignWorker: _runBulkAssign,
              onCancel: _exitKanbanSelection,
            ),
          TasksFilterBar(
            onApproveAll: _runApproveAllPending,
            isApproving: _isApproving,
            onRecalculateStaff: _runRecalculateAssignees,
            isRecalculating: _isRecalculating,
            automaticTasksActive: automaticTasksActive,
            onPremiumLockedTap: () => _showPremiumLockedDialog(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TaskLegend(),
          ),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final hasVisible = ref.watch(kanbanHasVisibleTasksProvider);
                final lockedTaskIds =
                    ref.watch(lockedFinancialTaskIdsProvider).valueOrNull ?? {};
                final categoriesByCode =
                    ref.watch(taskCategoriesProvider).valueOrNull ?? {};
                if (!hasVisible) {
                  final qEmpty = ref.watch(kanbanTasksSearchQueryProvider).isEmpty;
                  return Center(
                    child: AppEmptyState(
                      icon: Icons.assignment_outlined,
                      title: qEmpty
                          ? 'admin.tasks_empty'.tr()
                          : 'admin.tasks_search_no_results'.tr(),
                      subtitle: qEmpty
                          ? null
                          : 'admin.general.search_empty_subtitle'.tr(),
                    ),
                  );
                }
                return KanbanBoard(
                  lockedFinancialTaskIds: lockedTaskIds,
                  categoriesByCode: categoriesByCode,
                  onEdit: (t) => _showEditDialog(context, ref, t),
                  onDelete: (t) => _showDeleteConfirm(context, ref, t),
                  selectionMode: _kanbanSelectionMode,
                  selectedTaskIds: _selectedKanbanTaskIds,
                  onToggleTaskSelection: _toggleKanbanTaskSelection,
                  onEnterSelectionWithTask: _enterKanbanSelectionWith,
                );
              },
            ),
          ),
        ],
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
      onReservationTap:
          task.reservationId != null && task.reservationId!.isNotEmpty
          ? (id) => _navigateToReservation(context, ref, id)
          : null,
    );
  }

  /// Zavře dialog úkolu, přepne na záložku Rezervace a otevře detail dané rezervace.
  /// Voláno při kliknutí na odkaz rezervace v kontextovém bloku.
  void _navigateToReservation(
    BuildContext context,
    WidgetRef ref,
    String reservationId,
  ) {
    Navigator.of(context).pop();
    ref.read(adminTabJumpRequestProvider.notifier).state = adminTabIndexReservations;
    ref.read(adminCrossNavPendingProvider.notifier).openReservation(reservationId);
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

  Future<void> _doDelete(
    BuildContext context,
    WidgetRef ref,
    String taskId,
  ) async {
    try {
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('common.error'.tr()),
              backgroundColor: context.colors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.safeFrom(
        'tasks',
        tenantId,
      ).update({'deleted_at': deletedAt}).eq('id', taskId);
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
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
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
    required this.kanbanSelectionMode,
    required this.onToggleKanbanSelectionMode,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onAdd;
  final Future<void> Function() onGenerate;
  final bool isGenerating;

  /// Modul automatic_tasks – když false, tlačítko „Generovat návrhy“ je zamčené (ikona 🔒 + dialog).
  final bool automaticTasksActive;
  final VoidCallback onPremiumLockedTap;

  /// Režim výběru více úkolů v Kanbanu (zobrazí checkboxy na kartách).
  final bool kanbanSelectionMode;
  final VoidCallback onToggleKanbanSelectionMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            'admin.tasks_title'.tr(),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
                fillColor: context.colors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          IconButton(
            tooltip: kanbanSelectionMode
                ? 'admin.tasks_bulk_exit_selection'.tr()
                : 'admin.tasks_bulk_enter_selection'.tr(),
            onPressed: onToggleKanbanSelectionMode,
            icon: Icon(
              kanbanSelectionMode ? Icons.checklist : Icons.checklist_outlined,
              color: kanbanSelectionMode ? context.colors.primary : null,
            ),
          ),
          _GenerateButton(
            isGenerating: isGenerating,
            automaticTasksActive: automaticTasksActive,
            onGenerate: onGenerate,
            onPremiumLockedTap: onPremiumLockedTap,
          ),
          SizedBox(width: AppSpacing.sm),
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
        label: Text(
          isGenerating
              ? 'admin.tasks_generating'.tr()
              : '${'admin.tasks_generate'.tr()} (max 50)',
        ),
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
        backgroundColor: context.colors.surfaceContainerHighest,
        foregroundColor: context.colors.onSurfaceVariant,
        elevation: 0,
      ),
    );
  }
}

/// Dialog s návrhy změn přiřazení – checkboxy pro výběr, potvrzení pouze vybraných.
/// Po kliku „Potvrdit vybrané“ volá applyRecalculationProposals a onApplied.
class RecalculateProposalsDialog extends StatefulWidget {
  const RecalculateProposalsDialog({
    super.key,
    required this.ref,
    required this.proposals,
    required this.onApplied,
  });

  final WidgetRef ref;
  final List<TaskRecalculationProposal> proposals;
  final VoidCallback onApplied;

  @override
  State<RecalculateProposalsDialog> createState() =>
      _RecalculateProposalsDialogState();
}

class _RecalculateProposalsDialogState
    extends State<RecalculateProposalsDialog> {
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

  /// Formátuje řádek návrhu; časy zobrazuje v lokálním čase (.toLocal()), aby dispečer neviděl falešný posun UTC vs Local.
  String _formatProposalRow(BuildContext context, TaskRecalculationProposal p) {
    final loc = context.locale.languageCode;
    final newly = 'admin.recalculate_proposals_newly'.tr();
    final newName = p.newAssigneeName ?? 'common.none'.tr();
    final newStartLocal = p.newStart.isUtc ? p.newStart.toLocal() : p.newStart;
    String newTime = '';
    try {
      newTime = DateFormat('HH:mm', loc).format(newStartLocal);
    } catch (e, st) {
      AppLogger.error('admin_tasks_screen: formát času návrhu přepočtu (nový začátek) selhal', e, st);
    }
    final hasOldAssignee =
        p.oldAssigneeName != null &&
        p.oldAssigneeName!.trim().isNotEmpty &&
        p.oldAssigneeName != 'common.none'.tr();
    if (hasOldAssignee) {
      final originally = 'admin.recalculate_proposals_originally'.tr();
      final oldStartLocal = p.oldStart.isUtc
          ? p.oldStart.toLocal()
          : p.oldStart;
      String oldTime = '';
      try {
        oldTime = DateFormat('HH:mm', loc).format(oldStartLocal);
      } catch (e, st) {
        AppLogger.error('admin_tasks_screen: formát času návrhu přepočtu (původní začátek) selhal', e, st);
      }
      return '${p.taskTitle}\n$originally: ${p.oldAssigneeName} ($oldTime)\n$newly: $newName ($newTime)';
    }
    return '${p.taskTitle}\n$newly: $newName ($newTime)';
  }

  Future<void> _confirmSelected() async {
    final approved = widget.proposals
        .where((p) => _selected[p.taskId] == true)
        .toList();
    if (approved.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await widget.ref
        .read(adminTasksProvider.notifier)
        .applyRecalculationProposals(approved);
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
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: _allSelected,
                onChanged: (_) => _toggleSelectAll(),
                title: Text(
                  _allSelected
                      ? 'admin.recalculate_proposals_deselect_all'.tr()
                      : 'admin.recalculate_proposals_select_all'.tr(),
                ),
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
                      onChanged: (v) =>
                          setState(() => _selected[p.taskId] = v ?? false),
                      title: Text(
                        _formatProposalRow(context, p),
                        style: context.textTheme.bodyMedium,
                      ),
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
  } catch (e, st) {
    AppLogger.error('admin_tasks_screen: parsování data/času z řetězce (_parseDateTime) selhalo', e, st);
  }
  return null;
}

/// Odhad v minutách pro panel časové rentability v adminu.
///
/// PROČ: Stejná priorita jako u pracovníka ([parseTaskEstimateMinutes]); pokud v metadatech/regexu nic není,
/// použijeme stejný fallback jako pole trvání ve formuláři, aby čísla seděla s tím, co manažer vidí při editaci.
int _estimateMinutesForAdminProfitability(TaskRow t) {
  final parsed = parseTaskEstimateMinutes(t.description, t.metadata);
  if (parsed > 0) return parsed;
  return initialDurationMinutesForTask(t);
}

/// Skutečné trvání z `started_at` a `completed_at`. Null = úkol nedokončený nebo chybí začátek / rozpor časů.
int? _actualDurationMinutesForAdmin(TaskRow t) {
  final completed = t.completedAt;
  final started = t.startedAt;
  if (completed == null || started == null) return null;
  final diff = completed.difference(started).inMinutes;
  if (diff < 0) return null;
  return diff;
}

Future<String?> _showDateTimePicker(
  BuildContext context, {
  DateTime? initial,
}) async {
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

/// Zda je typ úkolu transfer – pro zobrazení pole čísla letu a uložení do metadata.
bool _isTransferTaskType(String? taskType) {
  if (taskType == null || taskType.trim().isEmpty) return false;
  return [
    'transfer_in',
    'transfer_out',
    'transfer',
  ].contains(taskType.trim().toLowerCase());
}

/// Vrací položky dropdownu pro výběr služby z katalogu. Value = service.id.
/// [includeNone] – přidá položku "Žádná" pro Edit dialog, aby šlo odebrat službu.
/// [taskType] – u Edit dialogu: pokud úkol má task_type (např. check_out) ale service_id není v katalogu,
/// přidá se fallback položka s názvem z task_categories (Check-Out, Úklid), aby se neukazovala pomlčka.
List<DropdownMenuItem<String?>> _buildServiceDropdownItems(
  List<TenantServiceModel> catalog,
  String? selectedServiceId, {
  bool includeNone = false,
  String? taskType,
}) {
  if (catalog.isEmpty) {
    return [
      DropdownMenuItem(
        value: null,
        child: Text('admin.no_services_in_catalog'.tr()),
      ),
    ];
  }
  final items = catalog
      .map<DropdownMenuItem<String?>>(
        (s) => DropdownMenuItem(
          value: s.id,
          child: Text(s.name.trim().isEmpty ? s.serviceType : s.name),
        ),
      )
      .toList();
  if (includeNone) {
    items.insert(
      0,
      DropdownMenuItem(value: null, child: Text('common.none'.tr())),
    );
  }
  // Fallback: úkol má service_id (např. smazaná služba) a task_type – zobrazíme název typu místo pomlčky.
  final taskTypeNorm = taskType?.trim().toLowerCase().replaceAll('-', '_');
  if (taskTypeNorm != null &&
      taskTypeNorm.isNotEmpty &&
      selectedServiceId != null &&
      selectedServiceId.trim().isNotEmpty &&
      !catalog.any((s) => s.id == selectedServiceId)) {
    items.add(
      DropdownMenuItem<String?>(
        value: selectedServiceId,
        child: Text(taskTypeLabelKey(taskTypeNorm).tr()),
      ),
    );
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
    final hasApartment =
        taskMode == _TaskFormMode.apartmentBound &&
        selectedApartmentId != null &&
        selectedApartmentId!.isNotEmpty;
    final reservationInfoText = initialReservationInfo?.trim();
    final hasReservation =
        reservationInfoText != null && reservationInfoText.isNotEmpty;

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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasApartment && apartmentName != null && apartmentName.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.apartment_outlined,
                  size: 16,
                  color: context.colors.onSurfaceVariant,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'admin.task_context_apartment'.tr(
                      namedArgs: {'name': apartmentName},
                    ),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          if (hasApartment && hasReservation) SizedBox(height: AppSpacing.sm),
          if (hasReservation)
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: context.colors.onSurfaceVariant,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'admin.task_context_reservation'.tr(
                      namedArgs: {'guest': reservationInfoText},
                    ),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
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

/// Modul v Supabase Storage pro přílohy úkolů – konzistence s mobilní aplikací.
const _storageModuleTasks = 'tasks';

/// Wrapper pro Rychlý výběr adres – odvozuje addressSourceClientId z vybraného klienta.
///
/// PROČ: Agency = vlastní adresy; external s agencyId = adresy agentury; external bez agencyId =
/// nezobrazit. Potřebujeme clientsFullListProvider pro výpočet, proto oddělený widget. Používá se
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
        final client = clients
            .where((c) => c.id == selectedClientId)
            .firstOrNull;
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
      error: (_, _) => const SizedBox.shrink(),
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
    final addressesAsync = ref.watch(
      clientAddressesProvider(addressSourceClientId),
    );
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
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 6,
              children: addresses.map((addr) {
                return ActionChip(
                  label: Text(addr.label),
                  onPressed: enabled
                      ? () {
                          controller.text = addr.address;
                          controller.selection = TextSelection.collapsed(
                            offset: controller.text.length,
                          );
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
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Typ úkolu: vázáno na apartmán (výchozí) nebo externí služba bez bytu.
enum _TaskFormMode { apartmentBound, externalService }

class _AddTaskDialogState extends ConsumerState<_AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Plánovaný začátek okna úkolu – výchozí „teď“ aby šlo hned uložit bez prázdného termínu.
  final _scheduledStartController = TextEditingController(
    text: _formatDateTime(DateTime.now()),
  );

  /// Trvání v minutách – spolu se začátkem určuje `due_date` v DB.
  final _durationMinutesController = TextEditingController(text: '60');

  /// Pro externí službu: adresa/lokace (custom_location).
  final _customLocationController = TextEditingController();

  /// Jedno pole GPS pro externí lokaci (`tasks.geo_location`) – paste z map.
  final _externalGpsController = TextEditingController();

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
    if (widget.initialApartmentId != null &&
        widget.initialApartmentId!.isNotEmpty) {
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
  /// Probíhá geokódování textu lokace (externí úkol) přes Nominatim.
  bool _isGeocodingExternal = false;

  /// Nově vybrané soubory k nahrání – bytes z file_picker (withData: true).
  List<PlatformFile> _pendingAttachments = [];

  /// Volitelná šablona checklistu – po uložení se zkopíruje do instance úkolu (null = bez checklistu).
  String? _selectedChecklistTemplateId;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _scheduledStartController.dispose();
    _durationMinutesController.dispose();
    _customLocationController.dispose();
    _externalGpsController.dispose();
    _priceController.dispose();
    _servicePriceController.dispose();
    _flightNumberController.dispose();
    super.dispose();
  }

  /// Doplní GPS z pole lokace (custom_location) u nového externího úkolu.
  Future<void> _fetchGpsFromExternalLocation() async {
    final addr = _customLocationController.text.trim();
    if (addr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_no_address'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isGeocodingExternal = true);
    try {
      final ll = await GeocodingService().getCoordinatesFromAddress(addr);
      if (!mounted) return;
      if (ll == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_no_result'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _externalGpsController.text = '${ll.latitude}, ${ll.longitude}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_success'.tr()),
            backgroundColor: context.customColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_error'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeocodingExternal = false);
    }
  }

  /// Otevře file_picker pro výběr přílohy (obrázek nebo PDF). withData: true získá bytes pro upload na web.
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final valid = result.files
          .where((f) => f.bytes != null && f.name.isNotEmpty)
          .toList();
      if (valid.isNotEmpty) {
        setState(
          () => _pendingAttachments = [..._pendingAttachments, ...valid],
        );
      }
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final isExternal = _taskMode == _TaskFormMode.externalService;
    if (!isExternal &&
        (_selectedApartmentId == null || _selectedApartmentId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_apartment_required_short'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (isExternal &&
        (_selectedClientId == null || _selectedClientId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_client_required'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (isExternal && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_service_name_required'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final scheduledStart = _parseDateTime(
      _scheduledStartController.text.trim(),
    );
    if (scheduledStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_datetime_required_short'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final durationMinutes = int.tryParse(
      _durationMinutesController.text.trim(),
    );
    if (durationMinutes == null || durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_duration_minutes_positive'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final dueDate = scheduledStart.add(Duration(minutes: durationMinutes));
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error'.tr()),
            backgroundColor: context.colors.error,
          ),
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
        } catch (e, st) {
          AppLogger.error('admin_tasks_screen: služba podle _selectedServiceId v katalogu nenalezena (vytvoření úkolu)', e, st);
        }
      }
      final taskType = service?.serviceType ?? 'extra';
      final metadata = <String, dynamic>{};
      if (service?.requiresPhoto == true) metadata['requires_photo'] = true;
      // PROČ: Jednotný odhad pro reporty a mobilní odpočet – musí odpovídat skutečnému intervalu v DB.
      metadata['estimated_minutes'] = durationMinutes;

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

      // KROK 3 OPRAVA: Explicitní payer_type – úkol nese 100 % finančních dat (viz AUDIT_TASK_FINANCE_LIFECYCLE).
      if (isExternal) {
        metadata['payer_type'] = _staffCollectsCash ? 'guest' : 'client';
      } else {
        metadata['payer_type'] = 'owner';
      }

      final assignedToUuid =
          _selectedAssignedTo != null && _selectedAssignedTo!.isNotEmpty
          ? _selectedAssignedTo
          : null;
      final scheduledIso = scheduledStart.toUtc().toIso8601String();
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
                content: Text(
                  'common.generic_error_user_friendly'.tr(),
                ),
                backgroundColor: context.colors.error,
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
        if (!isExternal &&
            widget.initialReservationId != null &&
            widget.initialReservationId!.isNotEmpty)
          'reservation_id': widget.initialReservationId,
        if (isExternal && _selectedClientId != null)
          'client_id': _selectedClientId,
        if (isExternal) 'custom_title': titleText,
        if (isExternal)
          'custom_location': _customLocationController.text.trim(),
        'assigned_to': assignedToUuid,
        if (_selectedAdditionalUserIds.isNotEmpty)
          'assigned_user_ids': _selectedAdditionalUserIds,
        'title': titleText,
        'description': _descriptionController.text.trim(),
        'status': _status,
        'task_type': taskType,
        'due_date': dueIso,
        'scheduled_start': scheduledIso,
        if (service != null) 'service_id': service.id,
        'metadata': metadata,
        if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
      };
      if (isExternal) {
        final g = GeoJsonPoint.tryParseSmartGpsText(_externalGpsController.text);
        payload['geo_location'] = GeoJsonPoint.toPostgrestJson(
          g?.latitude,
          g?.longitude,
        );
      }
      await ref
          .read(adminTasksProvider.notifier)
          .insertTaskInAdmin(
            payload,
            checklistTemplateId: _selectedChecklistTemplateId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_saved'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('task save Postgrest: ${e.message} (code ${e.code})');
        if (e.code == '42703' || e.message.contains('column')) {
          debugPrint(
            '--- CHYBÍ SLOUPCE V TABULCE tasks. Spusť v Supabase SQL Editor příkazy z admin_tasks_provider.dart (_buildAlterTableSql).',
          );
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _postgrestSnackMessage(e),
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'common.generic_error_user_friendly'.tr(),
          ),
          backgroundColor: context.colors.error,
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
    // Dostupný personál v den úkolu (smlouva + schválené absence) – stejná logika jako automatický generátor.
    final taskDate =
        _parseDateTime(_scheduledStartController.text.trim()) ?? DateTime.now();
    final teamAsync = ref.watch(availableTeamForTaskProvider(taskDate));
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
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
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
              // PROČ: Dispečer může připnout aktivní šablonu; body se zkopírují do úkolu po INSERTu.
              ref
                  .watch(checklistTemplatesListProvider)
                  .when(
                    data: (templates) {
                      final active = templates
                          .where((t) => t.isActive)
                          .toList();
                      final validIds = active.map((t) => t.id).toSet();
                      final validValue =
                          _selectedChecklistTemplateId != null &&
                              validIds.contains(_selectedChecklistTemplateId!)
                          ? _selectedChecklistTemplateId
                          : null;
                      if (validValue != _selectedChecklistTemplateId) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(
                              () => _selectedChecklistTemplateId = validValue,
                            );
                          }
                        });
                      }
                      return DropdownButtonFormField<String?>(
                        initialValue: validValue,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.checklist_rtl_outlined),
                          labelText: 'tasks.select_checklist_template'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('tasks.no_checklist'.tr()),
                          ),
                          ...active.map(
                            (t) => DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(t.name),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedChecklistTemplateId = v),
                      );
                    },
                    loading: () => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'tasks.checklist_templates_load_error'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 12),
              catalogAsync.when(
                data: (catalog) {
                  // PROČ: Výběr služby (ne jen typu) umožňuje předat requires_photo do metadata.
                  final items = _buildServiceDropdownItems(
                    catalog,
                    _selectedServiceId,
                  );
                  final validValue =
                      items.any((i) => i.value == _selectedServiceId)
                      ? _selectedServiceId
                      : (items.isNotEmpty ? items.first.value : null);
                  if (validValue != _selectedServiceId) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => setState(() => _selectedServiceId = validValue),
                    );
                  }
                  TenantServiceModel? service;
                  if (_selectedServiceId != null && catalog.isNotEmpty) {
                    try {
                      service = catalog.firstWhere(
                        (s) => s.id == _selectedServiceId,
                      );
                    } catch (e, st) {
                      AppLogger.error('admin_tasks_screen: služba v katalogu nenalezena (dialog úkolu)', e, st);
                    }
                  }
                  final taskType = service?.serviceType;
                  final showFlightField = _isTransferTaskType(taskType);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue: validValue,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.list_alt_outlined),
                          labelText: 'admin.task_service_label'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: items,
                        onChanged: (v) =>
                            setState(() => _selectedServiceId = v),
                      ),
                      if (showFlightField) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _flightNumberController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.flight_takeoff_outlined,
                            ),
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
                  initialValue: null,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.list_alt_outlined),
                    labelText: 'admin.task_service_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('common.loading'.tr()),
                    ),
                  ],
                  onChanged: null,
                ),
                error: (_, _) => DropdownButtonFormField<String>(
                  initialValue: null,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.list_alt_outlined),
                    labelText: 'admin.task_service_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('admin.task_type_label'.tr()),
                    ),
                  ],
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
                          initialValue: _selectedApartmentId,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.apartment),
                            labelText: 'admin.task_field_apartment'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'admin.validation_apartment_required_short'
                                    .tr(),
                              ),
                            ),
                            ...apartments.map(
                              (a) => DropdownMenuItem<String?>(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedApartmentId = v),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'admin.validation_apartment_required_short'.tr()
                              : null,
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) =>
                          Text('admin.apartments_load_error'.tr()),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              if (_taskMode == _TaskFormMode.externalService) ...[
                ref
                    .watch(clientsFullListProvider)
                    .when(
                      data: (allClients) {
                        // PROČ: Externí služba – zobrazujeme POUZE agency a external. Majitelé
                        // nemají smysl u úkolu bez bytu (fakturace jde na klienta, ne na majitele).
                        final clients = allClients.where((c) {
                          final t = c.clientType?.toLowerCase() ?? '';
                          return t == 'agency' || t == 'external';
                        }).toList();
                        if (clients.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Text(
                              'tasks.no_clients_hint'.tr(),
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.customColors.warning,
                              ),
                            ),
                          );
                        }
                        final validValue =
                            clients.any((c) => c.id == _selectedClientId)
                            ? _selectedClientId
                            : null;
                        if (validValue != _selectedClientId) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) =>
                                setState(() => _selectedClientId = validValue),
                          );
                        }
                        return DropdownButtonFormField<String?>(
                          initialValue: validValue,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person),
                            labelText: 'tasks.form_client'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'tasks.validation_client_required'.tr(),
                              ),
                            ),
                            ...clients.map(
                              (c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedClientId = v),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'tasks.validation_client_required'.tr()
                              : null,
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(
                        'common.generic_error_user_friendly'.tr(),
                      ),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isGeocodingExternal
                        ? null
                        : () => _fetchGpsFromExternalLocation(),
                    icon: _isGeocodingExternal
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.my_location_outlined),
                    label: Text('admin.geocoding_fetch_gps'.tr()),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _externalGpsController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.explore_outlined),
                    labelText: 'admin.geo_smart_gps_field'.tr(),
                    hintText: 'admin.geo_smart_gps_hint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                  maxLines: 2,
                  validator: (_) => GeoJsonPoint.validateOptionalSmartGpsText(
                        _externalGpsController.text,
                      )
                      ?.tr(),
                ),
                const SizedBox(height: 16),
                // Finanční blok pro externí službu.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'tasks.form_payment_block'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'tasks.form_payment_method'.tr(),
                        style: context.textTheme.labelLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
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
                        onSelectionChanged: (s) =>
                            setState(() => _staffCollectsCash = s.first),
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
                onRemovePending: (i) => setState(
                  () =>
                      _pendingAttachments = List.from(_pendingAttachments)
                        ..removeAt(i),
                ),
                onAddPressed: _pickAttachment,
                isUploading: _isSaving,
              ),
              const SizedBox(height: 12),
              // PROČ Začátek před výběrem personálu: Dostupný personál se filtruje podle data (availableTeamForTaskProvider).
              // Uživatel nejdřív zvolí plánovaný začátek a trvání, pak vidí roletku s lidmi – logický průchod formulářem.
              TextFormField(
                controller: _scheduledStartController,
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  labelText: 'admin.task_field_scheduled_start'.tr(),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final initial = _parseDateTime(
                    _scheduledStartController.text,
                  );
                  final result = await _showDateTimePicker(
                    context,
                    initial: initial,
                  );
                  if (result != null && mounted) {
                    setState(() => _scheduledStartController.text = result);
                  }
                },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'admin.validation_datetime_required_short'.tr()
                    : null,
              ),
              SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _durationMinutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.timelapse_outlined),
                  labelText: 'admin.task_field_duration_minutes'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) {
                    return 'admin.validation_duration_minutes_positive'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              teamAsync.when(
                data: (members) {
                  // BUGFIX: Majitelé apartmánů (owners) jsou klienti, nesmí se jim přiřazovat úkoly. Filtrujeme pouze reálný personál.
                  final staffMembers = members
                      .where((m) => m.role != 'property_owner')
                      .toList();
                  final seenValues = <String>{};
                  final unique = <TeamMember>[];
                  for (final m in staffMembers) {
                    final value = m.dropdownId;
                    if (value.isEmpty) continue;
                    if (seenValues.contains(value)) continue;
                    final byName = unique
                        .where((x) => x.name == m.name)
                        .toList();
                    if (byName.isNotEmpty) {
                      final existing = byName.first;
                      if (existing.profileId != null && m.profileId == null) {
                        continue;
                      }
                      if (existing.profileId == null && m.profileId != null) {
                        unique.removeWhere((x) => x.name == m.name);
                        seenValues.remove(existing.dropdownId);
                      }
                    }
                    seenValues.add(value);
                    unique.add(m);
                  }
                  // PROČ stejná logika jako v Edit dialogu: sjednocení UX – v roletce „Přiřadit osobě“ zobrazujeme i pracovní pozice (role).
                  final pendingLabel = 'admin.team_status_pending'.tr();
                  final items = <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('admin.tasks_assign_nobody'.tr()),
                    ),
                    ...unique.map((m) {
                      final rolesString = m.roles.isNotEmpty
                          ? m.roles.map((r) => 'admin.role_$r'.tr()).join(', ')
                          : null;
                      final hasRoles =
                          rolesString != null && rolesString.isNotEmpty;
                      final String label;
                      if (hasRoles) {
                        label = m.isFromInvitation
                            ? '${m.name} ($pendingLabel) • $rolesString'
                            : '${m.name} ($rolesString)';
                      } else {
                        label = m.isFromInvitation
                            ? '${m.name} ($pendingLabel)'
                            : m.name;
                      }
                      return DropdownMenuItem<String?>(
                        value: m.dropdownId,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: m.isFromInvitation
                                ? context.colors.outline
                                : context.colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
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
                            _selectedAdditionalUserIds =
                                _selectedAdditionalUserIds
                                    .where((id) => id != v)
                                    .toList();
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      _buildAdditionalAssigneesChips(
                        context: context,
                        members: unique,
                        mainAssigneeId: _selectedAssignedTo,
                        selectedIds: _selectedAdditionalUserIds,
                        onChanged: (v) =>
                            setState(() => _selectedAdditionalUserIds = v),
                      ),
                    ],
                  );
                },
                loading: () => DropdownButtonFormField<String?>(
                  initialValue: null,
                  items: const [],
                  onChanged: null,
                  decoration: InputDecoration(
                    labelText: 'admin.task_field_assign_to'.tr(),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    hintText: 'admin.team_loading_available'.tr(),
                  ),
                ),
                error: (e, st) => Text('admin.team_load_error'.tr()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _systemStatuses.contains(_status)
                    ? _status
                    : _systemStatuses.first,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.list_alt_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _systemStatuses
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(localizedTaskStatus(s)),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _status = v ?? _systemStatuses.first),
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
    if (!hasExisting && !hasPending && onAddPressed == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'tasks.attachments_title'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
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
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < existingUrls.length; i++) ...[
                  _AttachmentChip(
                    label: '${'tasks.attachments_title'.tr()} ${i + 1}',
                    onTap: () => launchUrl(
                      Uri.parse(existingUrls[i]),
                      mode: LaunchMode.externalApplication,
                    ),
                    onRemove: onRemoveExisting != null
                        ? () => onRemoveExisting!(i)
                        : null,
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
            style: context.textTheme.labelLarge?.copyWith(
              color: isExisting
                  ? context.colors.primary
                  : context.colors.onSurfaceVariant,
              decoration: isExisting ? TextDecoration.underline : null,
            ),
          ),
        ),
        if (onRemove != null) ...[
          SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: context.colors.error),
          ),
        ],
      ],
    );

    return Material(
      color: context.colors.surface,
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
  const _TaskContextSection({required this.task, this.onReservationTap});

  final TaskRow task;
  final void Function(String reservationId)? onReservationTap;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    final dateLoc = context.locale.languageCode;

    // Referenční číslo úkolu – zobrazeno nahoře pro rychlou identifikaci.
    if (task.referenceNumber != null &&
        task.referenceNumber!.trim().isNotEmpty) {
      chips.add(
        _ContextChip(icon: Icons.tag, text: '#${task.referenceNumber!.trim()}'),
      );
    }

    // Apartmán – ikona + lokalizovaný text s názvem bytu.
    final aptName = task.apartmentName;
    if (aptName != null && aptName.trim().isNotEmpty) {
      chips.add(
        _ContextChip(
          icon: Icons.apartment_outlined,
          text: 'admin.task_context_apartment'.tr(
            namedArgs: {'name': aptName.trim()},
          ),
        ),
      );
    }

    // Rezervace – host + termín (jen pokud máme reservationGuestName nebo termín).
    final guest = task.reservationGuestName;
    final start = task.reservationStartDate;
    final end = task.reservationEndDate;
    final hasReservation =
        (guest != null && guest.trim().isNotEmpty) ||
        start != null ||
        end != null;
    if (hasReservation) {
      final parts = <String>[];
      if (guest != null && guest.trim().isNotEmpty) {
        parts.add(guest.trim());
      }
      if (start != null || end != null) {
        final fmt = DateFormat('d.M.', dateLoc);
        final range = start != null && end != null
            ? '${fmt.format(start.toLocal())} – ${fmt.format(end.toLocal())}'
            : (start != null
                  ? fmt.format(start.toLocal())
                  : (end != null ? fmt.format(end.toLocal()) : null));
        if (range != null) {
          parts.add(parts.isEmpty ? range : '($range)');
        }
      }
      if (parts.isNotEmpty) {
        final reservationText = 'admin.task_context_reservation'.tr(
          namedArgs: {'guest': parts.join(' ')},
        );
        final reservationId = task.reservationId;
        final isClickable =
            reservationId != null &&
            reservationId.trim().isNotEmpty &&
            onReservationTap != null;
        chips.add(
          isClickable
              ? _ContextLinkChip(
                  icon: Icons.calendar_today_outlined,
                  text: reservationText,
                  onTap: () => onReservationTap!(reservationId),
                )
              : _ContextChip(
                  icon: Icons.calendar_today_outlined,
                  text: reservationText,
                ),
        );
      }
    }

    // Hosté – počet osob.
    final count = task.reservationGuestCount;
    if (count != null && count > 0) {
      chips.add(
        _ContextChip(
          icon: Icons.people_outline,
          text: 'admin.task_context_guests'.tr(
            namedArgs: {'count': count.toString()},
          ),
        ),
      );
    }

    // Audit – datum vytvoření.
    final createdAt = task.createdAt;
    if (createdAt != null) {
      chips.add(
        _ContextChip(
          icon: Icons.access_time,
          text: 'admin.task_context_created_at'.tr(
            namedArgs: {
              'date': DateFormat(
                'd.M.yyyy HH:mm',
                dateLoc,
              ).format(createdAt.toLocal()),
            },
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Wrap(spacing: 12, runSpacing: AppSpacing.sm, children: chips),
    );
  }
}

/// Read-only přehled odhad vs. skutečnost vs. odchylka – výpočet on-the-fly z existujících polí (bez migrací).
class _TaskTimeProfitabilitySection extends StatelessWidget {
  const _TaskTimeProfitabilitySection({required this.task});

  final TaskRow task;

  @override
  Widget build(BuildContext context) {
    final estimated = _estimateMinutesForAdminProfitability(task);
    final isCompleted = task.completedAt != null;
    final actualMinutes = _actualDurationMinutesForAdmin(task);

    final children = <Widget>[
      _TimeProfitChip(
        icon: Icons.schedule_outlined,
        text: 'tasks.time_estimated'.tr(
          namedArgs: {'minutes': estimated.toString()},
        ),
      ),
    ];
    if (isCompleted) {
      if (actualMinutes != null) {
        children.add(
          _TimeProfitChip(
            icon: Icons.timer_outlined,
            text: 'tasks.time_actual'.tr(
              namedArgs: {'minutes': actualMinutes.toString()},
            ),
          ),
        );
        final diff = actualMinutes - estimated;
        if (diff <= 0) {
          children.add(
            _TimeProfitChip(
              icon: Icons.trending_down,
              text: 'tasks.time_saved'.tr(namedArgs: {'minutes': '${(-diff)}'}),
              accent: context.customColors.success,
            ),
          );
        } else {
          children.add(
            _TimeProfitChip(
              icon: Icons.trending_up,
              text: 'tasks.time_overtime'.tr(
                namedArgs: {'minutes': diff.toString()},
              ),
              accent: context.colors.error,
            ),
          );
        }
      } else {
        children.add(
          _TimeProfitChip(
            icon: Icons.timer_off_outlined,
            text: 'tasks.time_actual_unknown'.tr(),
            accent: context.colors.onSurfaceVariant,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'tasks.time_profitability_title'.tr(),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: children
              .map(
                (w) => ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160),
                  child: w,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// Jedna „kartička“ v řádku rentability – ikona + jeden řádek textu.
class _TimeProfitChip extends StatelessWidget {
  const _TimeProfitChip({required this.icon, required this.text, this.accent});

  final IconData icon;
  final String text;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? context.colors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: accent ?? context.colors.onSurfaceVariant,
          ),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              text,
              style: context.textTheme.bodyMedium?.copyWith(
                color: c,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Jeden kontextový čip: ikona + lokalizovaný text (emoji jsou již v i18n řetězci).
class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.icon, required this.text});

  final IconData icon;

  /// Plný lokalizovaný text (např. z admin.task_context_apartment.tr(namedArgs: {...})).
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: context.textTheme.labelLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
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
                style: context.textTheme.labelLarge?.copyWith(
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
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'admin.task_media_attached_photos'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mediaUrls.length,
              separatorBuilder: (_, _) => SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final url = mediaUrls[index];
                return GestureDetector(
                  onTap: () =>
                      WalletDetailModal.showReceiptDialog(context, url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 100,
                        height: 100,
                        color: context.colors.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: context.colors.onSurfaceVariant,
                        ),
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
  late final TextEditingController _scheduledStartController;
  late final TextEditingController _durationMinutesController;
  late final TextEditingController _customLocationController;
  late final TextEditingController _externalGpsController;
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
  /// Probíhá geokódování textu lokace (externí úkol) přes Nominatim.
  bool _isGeocodingExternal = false;

  /// Vlastní barevné štítky (VIP, reklamace…) — persistují se v `metadata.custom_tags`.
  late List<TaskCustomTag> _customTags;

  /// UI override pro indikaci „vygenerováno/odesláno“ bez nutnosti zavírat a znovu otevírat dialog.
  ///
  /// PROČ: aktualizace DB last_communication_at je fire-and-forget, takže UI potřebuje okamžitou zpětnou vazbu.
  String? _lastCommunicationTemplateIdUi;
  DateTime? _lastCommunicationAtUi;

  /// Nově vybrané soubory k nahrání.
  List<PlatformFile> _pendingAttachments = [];

  /// Stávající URL z media_urls – uživatel může odstraňovat před uložením.
  late List<String> _existingMediaUrls;

  /// Uložení změn ve zmrazeném checklistu (`task_checklist_items`) při Uložit hlavního dialogu.
  final GlobalKey<TaskChecklistInstanceEditorSectionState>
  _taskChecklistEditorKey =
      GlobalKey<TaskChecklistInstanceEditorSectionState>();

  /// Externí úkol = bez apartment_id (apartmentId prázdné).
  bool get _isExternal => widget.task.apartmentId.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _existingMediaUrls = List.from(widget.task.mediaUrls);
    final t = widget.task;
    // Externí úkol: custom_title je hlavní název; jinak title.
    final isExt = t.apartmentId.trim().isEmpty;
    _titleController = TextEditingController(
      text: isExt ? (t.customTitle ?? t.title) : t.title,
    );
    _descriptionController = TextEditingController(text: t.description);
    // PROČ: Začátek z scheduled_start; fallback due_date kvůli starým řádkům bez rozlišení intervalu.
    final startForUi = t.scheduledStart ?? t.dueDate;
    _scheduledStartController = TextEditingController(
      text: _formatDateTime(startForUi),
    );
    _durationMinutesController = TextEditingController(
      text: initialDurationMinutesForTask(t).toString(),
    );
    _customLocationController = TextEditingController(
      text: t.customLocation ?? '',
    );
    final extGpsInitial = (t.latitude != null && t.longitude != null)
        ? '${t.latitude}, ${t.longitude}'
        : '';
    _externalGpsController = TextEditingController(text: extGpsInitial);
    _selectedApartmentId = t.apartmentId;
    _selectedClientId = t.clientId;
    _selectedAssignedTo = t.assignedTo;
    _selectedAdditionalUserIds = List.from(t.assignedUserIds);
    _selectedServiceId = t.serviceId;
    _status = normalizeToSystemStatus(t.status);
    _lastCommunicationTemplateIdUi = t.lastCommunicationTemplateId;
    _lastCommunicationAtUi = t.lastCommunicationAt;
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
    _customTags = TaskCustomTag.listFromMetadata(t.metadata);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _scheduledStartController.dispose();
    _durationMinutesController.dispose();
    _customLocationController.dispose();
    _externalGpsController.dispose();
    _priceController.dispose();
    _flightNumberController.dispose();
    super.dispose();
  }

  /// Doplní GPS z pole lokace u externího úkolu (úprava).
  Future<void> _fetchGpsFromExternalLocation() async {
    final addr = _customLocationController.text.trim();
    if (addr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_no_address'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isGeocodingExternal = true);
    try {
      final ll = await GeocodingService().getCoordinatesFromAddress(addr);
      if (!mounted) return;
      if (ll == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_no_result'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _externalGpsController.text = '${ll.latitude}, ${ll.longitude}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_success'.tr()),
            backgroundColor: context.customColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_error'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeocodingExternal = false);
    }
  }

  /// Otevře file_picker pro výběr přílohy (obrázek nebo PDF). withData: true získá bytes pro upload na web.
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final valid = result.files
          .where((f) => f.bytes != null && f.name.isNotEmpty)
          .toList();
      if (valid.isNotEmpty) {
        setState(
          () => _pendingAttachments = [..._pendingAttachments, ...valid],
        );
      }
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isExternal &&
        (_selectedClientId == null || _selectedClientId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_client_required'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isExternal && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_service_name_required'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final scheduledStart = _parseDateTime(
      _scheduledStartController.text.trim(),
    );
    if (scheduledStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_datetime_required_short'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final durationMinutes = int.tryParse(
      _durationMinutesController.text.trim(),
    );
    if (durationMinutes == null || durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_duration_minutes_positive'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final dueDate = scheduledStart.add(Duration(minutes: durationMinutes));
    if (_isSaving) return;

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error'.tr()),
          backgroundColor: context.colors.error,
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
              : (apartments.isNotEmpty
                    ? apartments.first.id
                    : _selectedApartmentId));

    try {
      // PROČ: Nejdřív instance checklistu (`task_checklist_items`); šablony katalogu zůstávají nedotčené.
      await _taskChecklistEditorKey.currentState?.persistChecklistIfNeeded(
        tenantId,
      );
      if (!context.mounted) {
        setState(() => _isSaving = false);
        return;
      }
      final catalog = ref.read(tenantServicesProvider).valueOrNull ?? [];
      TenantServiceModel? service;
      if (_selectedServiceId != null && catalog.isNotEmpty) {
        try {
          service = catalog.firstWhere((s) => s.id == _selectedServiceId);
        } catch (e, st) {
          AppLogger.error('admin_tasks_screen: služba v katalogu nenalezena (úprava úkolu)', e, st);
        }
      }
      final taskType = service?.serviceType ?? widget.task.taskType;
      final mergedMetadata = Map<String, dynamic>.from(
        widget.task.metadata ?? {},
      );
      TaskCustomTag.applyToMetadata(mergedMetadata, _customTags);
      mergedMetadata['requires_photo'] = service?.requiresPhoto == true;
      if (mergedMetadata['requires_photo'] == false) {
        mergedMetadata.remove('requires_photo');
      }

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

      // KROK 3 OPRAVA: Explicitní payer_type při úpravě úkolu.
      mergedMetadata['payer_type'] = _isExternal
          ? (_staffCollectsCash ? 'guest' : 'client')
          : 'owner';

      // PROČ: Sjednocení s interval scheduled_start–due_date; reporty a mobilní UI čtou estimated_minutes.
      mergedMetadata['estimated_minutes'] = durationMinutes;

      // PROČ: Při dokončení úkolu s výběrem hotovosti nabídneme zápis do peněženky administrátora.
      if (_status == 'completed') {
        if (!context.mounted) {
          setState(() => _isSaving = false);
          return;
        }
        final amount = amountToCollectFromMetadata(mergedMetadata);
        if (amount != null && amount > 0) {
          final recordToWallet = await showCashCollectionOnCompleteDialog(
            // ignore: use_build_context_synchronously
            context,
          );
          // PROČ: Kontrola musí odpovídat BuildContextu dialogu, ne jen State.mounted.
          if (!context.mounted) {
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
                  reservationId: widget.task.reservationId,
                );
                if (mounted) ref.invalidate(employeeCashWalletsProvider);
              } catch (e) {
                if (mounted) {
                  setState(() => _isSaving = false);
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
                return;
              }
            }
          }
        }
      }

      final assignedToUuid =
          _selectedAssignedTo != null && _selectedAssignedTo!.isNotEmpty
          ? _selectedAssignedTo
          : null;
      final scheduledIso = scheduledStart.toUtc().toIso8601String();
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
                content: Text(
                  'common.generic_error_user_friendly'.tr(),
                ),
                backgroundColor: context.colors.error,
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
        if (_isExternal && _selectedClientId != null)
          'client_id': _selectedClientId,
        if (!_isExternal) 'client_id': null,
        if (_isExternal) 'custom_title': titleText,
        if (_isExternal)
          'custom_location': _customLocationController.text.trim(),
        'assigned_to': assignedToUuid,
        'assigned_user_ids': _selectedAdditionalUserIds,
        'title': titleText,
        'description': _descriptionController.text.trim(),
        'status': _status,
        'task_type': taskType,
        'due_date': dueIso,
        'scheduled_start': scheduledIso,
        'metadata': mergedMetadata,
        'service_id': service?.id,
        'media_urls': mediaUrls,
      };
      if (_isExternal) {
        final g = GeoJsonPoint.tryParseSmartGpsText(_externalGpsController.text);
        updateFields['geo_location'] = GeoJsonPoint.toPostgrestJson(
          g?.latitude,
          g?.longitude,
        );
      }
      // Při novém přiřazení vymažeme Soft-Unassign kontext (UI už neukáže „Původní pracovník“).
      if (assignedToUuid != null && assignedToUuid.isNotEmpty) {
        updateFields['unassigned_info'] = null;
      }
      await ref
          .read(adminTasksProvider.notifier)
          .updateTaskInAdmin(widget.task.id, updateFields);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_saved'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('task update Postgrest: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _postgrestSnackMessage(e),
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'common.generic_error_user_friendly'.tr(),
          ),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Sekce „Komunikace s hostem“ – seznam šablon odpovídajících taskType + general, indikátor odeslání z tasks.
  Widget _buildTaskCommunicationSection(BuildContext context) {
    final taskType = (widget.task.taskType).trim().toLowerCase();
    final templatesAsync = ref.watch(messageTemplatesAdminProvider);
    final reservations =
        ref.watch(adminReservationsProvider).valueOrNull ?? <ReservationRow>[];
    final clients =
        ref.watch(clientsFullListProvider).valueOrNull ?? <ClientModel>[];
    final reservation = widget.task.reservationId != null
        ? reservations
              .where((r) => r.id == widget.task.reservationId)
              .firstOrNull
        : null;
    final client = widget.task.clientId != null
        ? clients.where((c) => c.id == widget.task.clientId).firstOrNull
        : null;
    if (reservation == null && client == null) return const SizedBox.shrink();
    final guestLangLower = reservation?.guestLanguage?.trim().isNotEmpty == true
        ? reservation!.guestLanguage!.trim().toLowerCase()
        : (client?.languageCode?.trim().isNotEmpty == true
              ? client!.languageCode!.trim().toLowerCase()
              : 'en');
    final apartments =
        ref.watch(apartmentsFullListProvider).valueOrNull ?? <ApartmentRow>[];
    final apt = widget.task.apartmentId.isNotEmpty
        ? apartments.where((a) => a.id == widget.task.apartmentId).firstOrNull
        : null;
    final aptCtx = apt != null
        ? ApartmentPlaceholderContext(
            name: apt.name,
            address: apt.address,
            keybox: apt.keybox,
            parkingInstructions: apt.parkingInstructions,
            reviewLink: apt.reviewLink,
            ownerNotes: apt.ownerNotes,
          )
        : null;
    final ctx = MessageTemplateSelectorContext.fromAdminTask(
      widget.task,
      reservation: reservation,
      apartment: aptCtx,
      client: client,
      tenantIanaTimezone: ref.read(authNotifierProvider).state.effectiveTenantTimezone,
    );

    final lastTemplateId =
        _lastCommunicationTemplateIdUi ??
        widget.task.lastCommunicationTemplateId;
    final lastAt = _lastCommunicationAtUi ?? widget.task.lastCommunicationAt;

    return templatesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (allTemplates) {
        final filtered = allTemplates.where((t) {
          if (t.channel != 'whatsapp') return false;
          final body = t.resolvedBodyForGuest(guestLangLower);
          if (body.trim().isEmpty) return false;

          final trig = t.triggerContext?.trim().toLowerCase();
          if (trig == null || trig.isEmpty) return true;
          return trig == taskType;
        }).toList();
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'admin.reservations_communication_section'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Text(
                  'communication.no_templates_for_task_language'.tr(
                    namedArgs: {'language': guestLangLower.toUpperCase()},
                  ),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...filtered.map((template) {
                  final isSent = lastTemplateId == template.id;
                  final dateStr = (isSent && lastAt != null)
                      ? DateFormat(
                          'd.M.',
                          context.locale.languageCode,
                        ).format(lastAt.toLocal())
                      : null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      template.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSent && lastAt != null) ...[
                          Icon(
                            Icons.check_circle,
                            color: context.customColors.success,
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'communication.message_generated_label'.tr(
                              namedArgs: {'date': dateStr ?? ''},
                            ),
                            style: context.textTheme.labelLarge?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          icon: Icon(
                            Icons.chat,
                            color: context.customColors.success,
                            size: 22,
                          ),
                          tooltip:
                              'communication.template_selector_whatsapp_tooltip'
                                  .tr(),
                          onPressed: () async {
                            final ok = await WhatsAppSenderService.send(
                              context,
                              ref,
                              ctx,
                              WhatsAppTemplateData(
                                name: template.name,
                                body: template.resolvedBodyForGuest(
                                  guestLangLower,
                                ),
                                triggerContext: template.triggerContext,
                                templateId: template.id,
                              ),
                            );
                            if (!mounted) return;
                            if (ok) {
                              setState(() {
                                _lastCommunicationTemplateIdUi = template.id;
                                _lastCommunicationAtUi = DateTime.now().toUtc();
                              });
                              ref.invalidate(adminTasksProvider);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    // Dostupný personál v den úkolu (smlouva + schválené absence) – stejná logika jako automatický generátor.
    final taskDate =
        _parseDateTime(_scheduledStartController.text.trim()) ??
        widget.task.scheduledStart ??
        widget.task.dueDate;
    final teamAsync = ref.watch(availableTeamForTaskProvider(taskDate));
    final catalogAsync = ref.watch(tenantServicesProvider);
    final lockedTaskIds =
        ref.watch(lockedFinancialTaskIdsProvider).valueOrNull ?? {};

    // Finanční zámek: úkol s výplatami nebo provizemi nelze měnit (ochrana účetnictví).
    final isFinanciallyLocked = lockedTaskIds.contains(widget.task.id);
    // Auditing: Zámek editace pro dokončené úkoly – neměnnost historie pro účetní audit.
    final isReadOnly =
        isFinanciallyLocked ||
        normalizeToSystemStatus(widget.task.status) == 'completed';
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
              AdminTaskCrossLinkRow(task: widget.task),
              _TaskContextSection(
                task: widget.task,
                onReservationTap: widget.onReservationTap,
              ),
              const SizedBox(height: AppSpacing.md),
              _TaskTimeProfitabilitySection(task: widget.task),
              if (isFinanciallyLocked) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.customColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.customColors.warning.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock,
                        color: context.customColors.warning,
                        size: 24,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'admin.task_financially_locked'.tr(),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.customColors.warning,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: context.colors.primary, size: 24),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'tasks.task_locked_info'.tr(),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.onPrimaryContainer,
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
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.tasks_reassign_section'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'admin.tasks_reassign_section_hint'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
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
              TaskCustomTagsEditor(
                initialTags: _customTags,
                readOnly: isReadOnly,
                onChanged: (tags) => setState(() => _customTags = tags),
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
                  // taskType: fallback položka, když service_id není v katalogu (např. Check-Out z task_categories).
                  final items = _buildServiceDropdownItems(
                    catalog,
                    _selectedServiceId,
                    includeNone: true,
                    taskType: widget.task.taskType,
                  );
                  final validValue =
                      items.any((i) => i.value == _selectedServiceId)
                      ? _selectedServiceId
                      : (items.isNotEmpty
                            ? items.first.value
                            : _selectedServiceId);
                  if (validValue != _selectedServiceId) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => setState(() => _selectedServiceId = validValue),
                    );
                  }
                  TenantServiceModel? service;
                  if (_selectedServiceId != null && catalog.isNotEmpty) {
                    try {
                      service = catalog.firstWhere(
                        (s) => s.id == _selectedServiceId,
                      );
                    } catch (e, st) {
                      AppLogger.error('admin_tasks_screen: služba v katalogu nenalezena (read-only dialog úkolu)', e, st);
                    }
                  }
                  final taskType = service?.serviceType ?? widget.task.taskType;
                  final showFlightField = _isTransferTaskType(taskType);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue: validValue,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.list_alt_outlined),
                          labelText: 'admin.task_service_label'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: items,
                        onChanged: isReadOnly
                            ? null
                            : (v) => setState(() => _selectedServiceId = v),
                      ),
                      if (showFlightField) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _flightNumberController,
                          readOnly: isReadOnly,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.flight_takeoff_outlined,
                            ),
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
                  initialValue: _selectedServiceId,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.list_alt_outlined),
                    labelText: 'admin.task_service_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _selectedServiceId,
                      child: Text('common.loading'.tr()),
                    ),
                  ],
                  onChanged: null,
                ),
                error: (_, _) => DropdownButtonFormField<String?>(
                  initialValue: _selectedServiceId,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.list_alt_outlined),
                    labelText: 'admin.task_service_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _selectedServiceId,
                      child: Text('admin.task_type_label'.tr()),
                    ),
                  ],
                  onChanged: null,
                ),
              ),
              const SizedBox(height: 12),
              // Vázáno na apartmán: výběr bytu. Externí: klient + název služby + adresa + platba.
              // Přeřazení: dropdowny zůstávají editovatelné i u dokončeného úkolu (isReassignEnabled).
              if (!_isExternal)
                apartmentsAsync.when(
                  data: (apartments) {
                    final validId =
                        apartments.any((a) => a.id == _selectedApartmentId)
                        ? _selectedApartmentId
                        : (apartments.isNotEmpty ? apartments.first.id : null);
                    return DropdownButtonFormField<String?>(
                      initialValue: validId,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.apartment),
                        labelText: 'admin.task_field_apartment'.tr(),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'admin.validation_apartment_required_short'.tr(),
                          ),
                        ),
                        ...apartments.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        ),
                      ],
                      onChanged: isReassignEnabled
                          ? (v) =>
                                setState(() => _selectedApartmentId = v ?? '')
                          : null,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'admin.validation_apartment_required_short'.tr()
                          : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, st) => Text('admin.apartments_load_error'.tr()),
                ),
              if (_isExternal) ...[
                ref
                    .watch(clientsFullListProvider)
                    .when(
                      data: (allClients) {
                        // PROČ: Externí úkol – zobrazujeme POUZE agency a external (stejná logika jako Add Task).
                        final clients = allClients.where((c) {
                          final t = c.clientType?.toLowerCase() ?? '';
                          return t == 'agency' || t == 'external';
                        }).toList();
                        if (clients.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Text(
                              'tasks.no_clients_hint'.tr(),
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.customColors.warning,
                              ),
                            ),
                          );
                        }
                        // Sirotčí klient: aktuální ID není v seznamu (smazaný klient) – nepřepisujeme na null,
                        // aby dropdown zobrazil položku „Neplatný klient (ID: …)“ a uživatel mohl vybrat nového.
                        final isOrphan =
                            _selectedClientId != null &&
                            _selectedClientId!.trim().isNotEmpty &&
                            !clients.any((c) => c.id == _selectedClientId);
                        final dropdownValue = isOrphan
                            ? _selectedClientId
                            : (clients.any((c) => c.id == _selectedClientId)
                                  ? _selectedClientId
                                  : null);
                        final orphanShortId =
                            _selectedClientId != null &&
                                _selectedClientId!.length > 8
                            ? _selectedClientId!.substring(0, 8)
                            : (_selectedClientId ?? '');
                        return DropdownButtonFormField<String?>(
                          initialValue: dropdownValue,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person),
                            labelText: 'tasks.form_client'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'tasks.validation_client_required'.tr(),
                              ),
                            ),
                            if (isOrphan)
                              DropdownMenuItem<String?>(
                                value: _selectedClientId,
                                child: Text(
                                  'tasks.client_orphan_label'.tr(
                                    namedArgs: {'id': orphanShortId},
                                  ),
                                ),
                              ),
                            ...clients.map(
                              (c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: isReassignEnabled
                              ? (v) => setState(() => _selectedClientId = v)
                              : null,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'tasks.validation_client_required'.tr()
                              : null,
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(
                        'common.generic_error_user_friendly'.tr(),
                      ),
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
                if (!isReadOnly)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isGeocodingExternal
                          ? null
                          : () => _fetchGpsFromExternalLocation(),
                      icon: _isGeocodingExternal
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.my_location_outlined),
                      label: Text('admin.geocoding_fetch_gps'.tr()),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _externalGpsController,
                  readOnly: isReadOnly,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.explore_outlined),
                    labelText: 'admin.geo_smart_gps_field'.tr(),
                    hintText: 'admin.geo_smart_gps_hint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                  maxLines: 2,
                  validator: (_) => GeoJsonPoint.validateOptionalSmartGpsText(
                        _externalGpsController.text,
                      )
                      ?.tr(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'tasks.form_payment_block'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'tasks.form_payment_method'.tr(),
                        style: context.textTheme.labelLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
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
                        onSelectionChanged: isReadOnly
                            ? null
                            : (s) =>
                                  setState(() => _staffCollectsCash = s.first),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _TaskAttachmentsSection(
                existingUrls: _existingMediaUrls,
                onRemoveExisting: isReadOnly
                    ? null
                    : (i) => setState(
                        () =>
                            _existingMediaUrls = List.from(_existingMediaUrls)
                              ..removeAt(i),
                      ),
                pendingFiles: _pendingAttachments,
                onRemovePending: isReadOnly
                    ? (_) {}
                    : (i) => setState(
                        () =>
                            _pendingAttachments = List.from(_pendingAttachments)
                              ..removeAt(i),
                      ),
                onAddPressed: isReadOnly ? null : _pickAttachment,
                isUploading: _isSaving,
              ),
              const SizedBox(height: 12),
              TaskChecklistInstanceEditorSection(
                key: _taskChecklistEditorKey,
                taskId: widget.task.id,
                readOnly: isReadOnly,
              ),
              const SizedBox(height: 12),
              teamAsync.when(
                data: (members) {
                  // BUGFIX: Majitelé apartmánů (owners) jsou klienti, nesmí se jim přiřazovat úkoly. Filtrujeme pouze reálný personál.
                  final staffMembers = members
                      .where((m) => m.role != 'property_owner')
                      .toList();
                  final availableIds = staffMembers
                      .map((m) => m.dropdownId)
                      .toSet();
                  // Původně přiřazený není v tento termín dostupný → datově musí být null, UX varování zobrazíme pod dropdownem.
                  final isOriginalUnavailable =
                      widget.task.assignedTo != null &&
                      widget.task.assignedTo!.isNotEmpty &&
                      !availableIds.contains(widget.task.assignedTo!);
                  if (isOriginalUnavailable &&
                      _selectedAssignedTo == widget.task.assignedTo) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedAssignedTo = null);
                    });
                  }
                  final pendingLabel = 'admin.team_status_pending'.tr();
                  final dropdownItems = <DropdownMenuItem<String?>>[];
                  final seenIds = <String>{};

                  void addProfileItem(
                    String id,
                    String name,
                    bool isPending, {
                    List<String> roles = const [],
                  }) {
                    if (id.isEmpty || seenIds.contains(id)) return;
                    seenIds.add(id);
                    final rolesString = roles.isNotEmpty
                        ? roles.map((r) => 'admin.role_$r'.tr()).join(', ')
                        : null;
                    final hasRoles =
                        rolesString != null && rolesString.isNotEmpty;
                    final String label;
                    if (hasRoles) {
                      label = isPending
                          ? '$name ($pendingLabel) • $rolesString'
                          : '$name ($rolesString)';
                    } else {
                      label = isPending ? '$name ($pendingLabel)' : name;
                    }
                    dropdownItems.add(
                      DropdownMenuItem<String?>(
                        value: id,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isPending
                                ? context.colors.outline
                                : context.colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }

                  dropdownItems.add(
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('admin.tasks_assign_nobody'.tr()),
                    ),
                  );
                  for (final m in staffMembers) {
                    addProfileItem(
                      m.dropdownId,
                      m.name,
                      m.isFromInvitation,
                      roles: m.roles,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue:
                            _selectedAssignedTo != null &&
                                seenIds.contains(_selectedAssignedTo)
                            ? _selectedAssignedTo
                            : null,
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
                                      _selectedAdditionalUserIds
                                          .where((id) => id != v)
                                          .toList();
                                }
                              }),
                      ),
                      if (isOriginalUnavailable) ...[
                        SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: context.colors.error,
                              size: 20,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'admin.task_assignee_original_unavailable_warning'
                                    .tr(
                                      namedArgs: {
                                        'name':
                                            widget.task.assignedToName ??
                                            'planning_calendar.unknown'.tr(),
                                      },
                                    ),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (widget.task.assignedTo == null &&
                          widget.task.unassignedInfo != null &&
                          widget.task.unassignedInfo!.isNotEmpty) ...[
                        SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: context.colors.error,
                              size: 20,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'admin.task_auto_unassigned_warning'.tr(
                                  namedArgs: {
                                    'name':
                                        (widget.task.unassignedInfo!['previous_name']
                                                    ?.toString()
                                                    .trim() ??
                                                '')
                                            .isEmpty
                                        ? 'planning_calendar.unknown'.tr()
                                        : widget
                                              .task
                                              .unassignedInfo!['previous_name']
                                              .toString(),
                                  },
                                ),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildAdditionalAssigneesChips(
                        context: context,
                        members: staffMembers,
                        mainAssigneeId: _selectedAssignedTo,
                        selectedIds: _selectedAdditionalUserIds,
                        onChanged: (v) =>
                            setState(() => _selectedAdditionalUserIds = v),
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
                controller: _scheduledStartController,
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  labelText: 'admin.task_field_scheduled_start'.tr(),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: isReadOnly
                    ? null
                    : () async {
                        final initial = _parseDateTime(
                          _scheduledStartController.text,
                        );
                        final result = await _showDateTimePicker(
                          context,
                          initial: initial,
                        );
                        if (result != null && mounted) {
                          setState(
                            () => _scheduledStartController.text = result,
                          );
                        }
                      },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'admin.validation_datetime_required_short'.tr()
                    : null,
              ),
              SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _durationMinutesController,
                readOnly: isReadOnly,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.timelapse_outlined),
                  labelText: 'admin.task_field_duration_minutes'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (isReadOnly) return null;
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) {
                    return 'admin.validation_duration_minutes_positive'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _systemStatuses.contains(_status)
                    ? _status
                    : _systemStatuses.first,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.list_alt_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _systemStatuses
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(localizedTaskStatus(s)),
                      ),
                    )
                    .toList(),
                onChanged: isReadOnly
                    ? null
                    : (v) =>
                          setState(() => _status = v ?? _systemStatuses.first),
              ),
              const SizedBox(height: 24),
              _buildTaskCommunicationSection(context),
              const SizedBox(height: 24),
              TaskAuditHistorySection(taskId: widget.task.id),
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
