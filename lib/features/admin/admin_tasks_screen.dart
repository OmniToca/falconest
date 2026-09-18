import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/widgets/app_empty_state.dart';
import 'package:falconest/core/widgets/export_i18n_editor_dialog.dart';
import 'package:falconest/core/widgets/falconest_network_image.dart';
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
import 'package:falconest/features/admin/widgets/task_external_client_picker.dart';
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
import 'package:falconest/features/admin/models/task_form_draft.dart';
import 'package:falconest/features/admin/widgets/task_draft_from_text_dialog.dart';
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

// Části dialogů a formulářů úkolů – záměrně `part of` kvůli sdíleným private helperům.
part 'widgets/admin_tasks_recalculate_and_helpers.dart';
part 'widgets/admin_tasks_add_dialog.dart';
part 'widgets/admin_tasks_form_sections.dart';
part 'widgets/admin_tasks_edit_dialog.dart';


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
    TaskFormDraft? aiPrefill,
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
        aiPrefill: aiPrefill,
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

  /// Běží hromadná změna stavu / přiřazení nebo mazání úkolu — celé tělo obrazovky je zablokované overlayem.
  bool _isProcessingBulk = false;

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
    setState(() => _isProcessingBulk = true);
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
    } catch (e, st) {
      AppLogger.error('AdminTasksScreen: hromadná změna stavu úkolů selhala', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.bulk_action_failed'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingBulk = false);
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
    setState(() => _isProcessingBulk = true);
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
    } catch (e, st) {
      AppLogger.error('AdminTasksScreen: hromadné přiřazení úkolů selhalo', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.bulk_action_failed'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingBulk = false);
    }
  }

  /// Hromadné soft-delete vybraných úkolů (stejný zápis jako u jednotlivého mazání v Kanbanu).
  ///
  /// PROČ: Dispečer může vyčistit šarži záznamů najednou; auditní stopa zůstane po jednom záznamu na úkol.
  Future<void> _runBulkDelete() async {
    if (_selectedKanbanTaskIds.isEmpty) return;
    final count = _selectedKanbanTaskIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.tasks_bulk_delete_title'.tr()),
        content: Text(
          'admin.tasks_bulk_delete_message'.tr(namedArgs: {'count': '$count'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('admin.tasks_bulk_delete_confirm'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isProcessingBulk = true);
    try {
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        throw StateError('tenant_missing');
      }
      final selectedIds = _selectedKanbanTaskIds.toList();
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.safeFrom('tasks', tenantId).update({
        'deleted_at': deletedAt,
      }).inFilter('id', selectedIds);

      final userId = SupabaseService.client.auth.currentUser?.id;
      for (final id in selectedIds) {
        await AuditLogService.log(
          tenantId: auth.tenantIdForData,
          userId: userId,
          actionType: 'SOFT_DELETE',
          tableName: 'tasks',
          recordId: id,
        );
      }

      if (!mounted) return;
      ref.invalidate(adminTasksProvider);
      ref.invalidate(adminTasksStreamProvider);
      _exitKanbanSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.bulk_delete_success'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      AppLogger.error('AdminTasksScreen: hromadné mazání úkolů selhalo', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.bulk_action_failed'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingBulk = false);
    }
  }

  Future<void> _runGenerateSmartTasks() async {
    setState(() => _isGenerating = true);
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    try {
      final notifier = ref.read(adminTasksProvider.notifier);
      // PROČ: Dva samostatné try — v logu hned poznáme, zda spadl smart generátor (rezervace) nebo scheduled (údržba).
      int count1 = 0;
      try {
        count1 = await notifier.generateSmartTasks(
          getEstimateHoursText: (h) =>
              'admin.task_estimate_time_hours'.tr(namedArgs: {'hours': '$h'}),
          getEstimate1HourText: () => 'admin.task_estimate_time_1_hour'.tr(),
          getEstimateMinutesText: (m) =>
              'admin.task_estimate_minutes'.tr(namedArgs: {'minutes': '$m'}),
          getGuestUnknownLabel: () => 'admin.dashboard_guest_unknown'.tr(),
        );
      } catch (e, st) {
        AppLogger.error(
          'AdminTasksScreen: Generovat návrhy — generateSmartTasks selhalo '
          '(tenantId=$tenantId, web=$kIsWeb)',
          e,
          st,
        );
        rethrow;
      }
      int count2 = 0;
      try {
        count2 = await notifier.generateScheduledTasks(
          getEstimateMinutesText: (m) =>
              'admin.task_estimate_minutes'.tr(namedArgs: {'minutes': '$m'}),
          getScheduledMaintenanceSuffix: () =>
              'admin.task_title_scheduled_maintenance'.tr(),
        );
      } catch (e, st) {
        AppLogger.error(
          'AdminTasksScreen: Generovat návrhy — generateScheduledTasks selhalo '
          '(tenantId=$tenantId, web=$kIsWeb)',
          e,
          st,
        );
        rethrow;
      }
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
    } catch (e, st) {
      // PROČ: Uživatel vidí jen obecný snackbar; skutečná příčina (PostgREST RLS, chybějící sloupec, timeout)
      // musí být v konzoli pro podporu a QA — viz AppLogger (debugPrint).
      AppLogger.error(
        'AdminTasksScreen: Generovat návrhy (max 50) — celý tok selhal '
        '(tenantId=$tenantId, web=$kIsWeb, error=${e.runtimeType}: $e)',
        e,
        st,
      );
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopActionBar(
                searchController: _searchController,
                onSearchChanged: () {
                  ref.read(kanbanTasksSearchQueryProvider.notifier).state =
                      _searchController.text.trim().toLowerCase();
                },
                onAdd: () => _showAddDialog(context, ref),
                onAddFromText: () => _showAddFromTextDialog(context, ref),
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
                  onBulkDelete: _runBulkDelete,
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
          if (_isProcessingBulk)
            Positioned.fill(
              child: AbsorbPointer(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: Center(
                    child: Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            SizedBox(height: AppSpacing.md),
                            Text(
                              'admin.bulk_action_processing'.tr(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    AdminTasksScreen.showAddTaskDialog(context, ref);
  }

  /// Human-in-the-loop: AI předvyplní formulář z WhatsApp textu; uložení a validace zůstává ruční.
  Future<void> _showAddFromTextDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final draft = await TaskDraftFromTextDialog.show(context);
    if (!context.mounted || draft == null) return;
    AdminTasksScreen.showAddTaskDialog(context, ref, aiPrefill: draft);
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
    BuildContext dialogContext,
    WidgetRef ref,
    String taskId,
  ) async {
    final auth = ref.read(authNotifierProvider);
    final tenantId = auth.tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text('common.error'.tr()),
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessingBulk = true);
    try {
      Navigator.of(dialogContext).pop();
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
      if (!mounted) return;
      ref.invalidate(adminTasksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_deleted'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      AppLogger.error('AdminTasksScreen: mazání úkolu (soft delete) selhalo', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.bulk_action_failed'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingBulk = false);
    }
  }
}

/// Horní lišta – titulek, vyhledávání, Generovat návrhy (premium), Nový úkol.
class _TopActionBar extends StatelessWidget {
  const _TopActionBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onAddFromText,
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
  final VoidCallback onAddFromText;
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
          OutlinedButton.icon(
            onPressed: onAddFromText,
            icon: const Icon(Icons.content_paste_go, size: 20),
            label: Text('admin.task_draft_from_text'.tr()),
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
