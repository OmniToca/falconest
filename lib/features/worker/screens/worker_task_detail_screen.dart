import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/communication/models/message_template_selector_context.dart';
import 'package:falconest/features/communication/widgets/message_template_selector_bottom_sheet.dart';
import 'package:falconest/core/repositories/task/task_repository_provider_export.dart';
import 'package:falconest/features/settings/providers/profile_provider.dart';
import 'package:falconest/features/worker/data/services/worker_sync_service.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/providers/worker_dashboard_provider.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_provider.dart';
import 'package:falconest/features/worker/screens/task_types/checkin_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/checkout_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/cleaning_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/default_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/issue_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/maintenance_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/material_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/transfer_task_screen.dart';
import 'package:falconest/features/worker/widgets/task_complete_with_photo_section.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';
import 'package:falconest/features/worker/widgets/worker_task_checklist_widget.dart';
import 'package:falconest/features/worker/widgets/worker_task_detail_offline_context_cards.dart';
import 'package:falconest/features/worker/widgets/worker_task_detail_sticky_header.dart';

/// Master detail úkolu – jeden Scaffold, AppBar, sticky stav/čas, scroll s checklistem nahoře a patičkou akcí.
///
/// PROČ: Typové obrazovky dodávají jen obsah ([SliverList] ekvivalent přes [SliverChildListDelegate]),
/// aby nevznikaly duplicitní AppBar a aby odpočet zůstal vidět při scrollu (pevná [Column] nad [CustomScrollView]).
class WorkerTaskDetailScreen extends ConsumerWidget {
  const WorkerTaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(workerTaskDetailProvider(taskId));

    return detailAsync.when(
      data: (detail) {
        if (detail == null) {
          return _buildNotFound(context);
        }
        final type = detail.taskType.trim().toLowerCase();
        final spec = _TaskBodySpec.resolve(type, taskId, detail);
        final est = parseTaskEstimateMinutes(detail.description, detail.metadata);

        return Scaffold(
          backgroundColor: spec.backgroundColor,
          floatingActionButton: detail.isCompleted
              ? null
              : FloatingActionButton.small(
                  tooltip: 'worker.quick_note_fab_tooltip'.tr(),
                  onPressed: () => _showWorkerQuickNoteDialog(context, ref, taskId),
                  child: const Icon(Icons.sticky_note_2_outlined),
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          appBar: AppBar(
            title: _buildAppBarTitle(context, detail),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black87,
            iconTheme: const IconThemeData(color: Colors.black87),
            actions: [
              IconButton(
                tooltip: 'communication.template_selector_whatsapp_tooltip'.tr(),
                icon: Icon(Icons.chat, color: Colors.green.shade700),
                onPressed: () {
                  final ctx = MessageTemplateSelectorContext.fromWorkerTask(
                    detail,
                    tenantIanaTimezone:
                        ref.read(authNotifierProvider).state.effectiveTenantTimezone,
                  );
                  MessageTemplateSelectorBottomSheet.show(context, ref, ctx);
                },
              ),
              ...spec.extraAppBarActions(context, ref),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkerTaskDetailStickyHeader(detail: detail, estimatedMinutes: est),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          WorkerTaskChecklistWidget(
                            taskId: taskId,
                            readOnly: !detail.isInProgress,
                          ),
                          const SizedBox(height: 8),
                          WorkerTaskDetailOfflineContextCards(detail: detail),
                          ...spec.buildScrollChildren(context, ref),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverToBoxAdapter(
                        child: TaskCompleteWithPhotoSection(
                          taskId: taskId,
                          detail: detail,
                          finishKey: spec.finishKey,
                          beforeComplete: spec.beforeComplete,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _buildNotFound(context),
    );
  }

  /// Dva řádky max: krátký název (před dvojtečkou u transferů/check-in) a referenční číslo.
  Widget _buildAppBarTitle(BuildContext context, WorkerTaskDetail detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? 'common.placeholder_dash'.tr());
    final line1 = raw.contains(':') ? raw.split(':').first.trim() : raw.trim();
    final refNum = detail.referenceNumber?.trim();
    final text = (refNum != null && refNum.isNotEmpty) ? '$line1\n#$refNum' : line1;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'worker.task_detail_not_found'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/worker'),
                icon: const Icon(Icons.arrow_back),
                label: Text('common.back'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sestavení obsahu a akcí podle `task_type`.
///
/// PROČ: Jeden centrální přepínač drží barvu pozadí, klíč tlačítka Dokončit a volitelný [beforeComplete]
/// na jednom místě; typové soubory exportují jen statické stavebnice widgetů bez vlastního [Scaffold].
class _TaskBodySpec {
  _TaskBodySpec({
    required this.backgroundColor,
    required this.finishKey,
    this.beforeComplete,
    required this.buildScrollChildren,
    required this.extraAppBarActions,
  });

  final Color backgroundColor;
  final String finishKey;
  final BeforeCompleteCallback? beforeComplete;
  final List<Widget> Function(BuildContext context, WidgetRef ref) buildScrollChildren;
  final List<Widget> Function(BuildContext context, WidgetRef ref) extraAppBarActions;

  static _TaskBodySpec resolve(String type, String taskId, WorkerTaskDetail detail) {
    switch (type) {
      case 'transfer_in':
      case 'transfer_out':
        return _TaskBodySpec(
          backgroundColor: TransferTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish_transfer',
          beforeComplete: TransferTaskScreen.beforeComplete(taskId, detail),
          buildScrollChildren: (c, r) =>
              TransferTaskScreen.buildScrollChildren(c, r, taskId, detail),
          extraAppBarActions: (c, r) => TransferTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'check_in':
        return _TaskBodySpec(
          backgroundColor: CheckinTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish',
          beforeComplete: CheckinTaskScreen.beforeComplete(taskId, detail),
          buildScrollChildren: (c, r) => CheckinTaskScreen.buildScrollChildren(c, r, detail),
          extraAppBarActions: (c, r) => CheckinTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'check_out':
        return _TaskBodySpec(
          backgroundColor: CheckoutTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish',
          beforeComplete: null,
          buildScrollChildren: (c, r) => CheckoutTaskScreen.buildScrollChildren(c, r, detail),
          extraAppBarActions: (c, r) => CheckoutTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'issue':
        return _TaskBodySpec(
          backgroundColor: IssueTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_resolved',
          beforeComplete: null,
          buildScrollChildren: (c, r) => IssueTaskScreen.buildScrollChildren(detail),
          extraAppBarActions: (c, r) => IssueTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'cleaning':
        return _TaskBodySpec(
          backgroundColor: CleaningTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish',
          beforeComplete: null,
          buildScrollChildren: (c, r) => CleaningTaskScreen.buildScrollChildren(c, r, detail),
          extraAppBarActions: (c, r) => CleaningTaskScreen.buildAppBarActions(c, r, taskId, detail),
        );
      case 'maintenance':
        return _TaskBodySpec(
          backgroundColor: MaintenanceTaskScreen.backgroundColor,
          finishKey: 'worker.action_maintenance_resolved',
          beforeComplete: null,
          buildScrollChildren: (c, r) => MaintenanceTaskScreen.buildScrollChildren(detail),
          extraAppBarActions: (c, r) => MaintenanceTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'material':
        return _TaskBodySpec(
          backgroundColor: MaterialTaskScreen.backgroundColor,
          finishKey: 'worker.action_material_restocked',
          beforeComplete: null,
          buildScrollChildren: (c, r) => MaterialTaskScreen.buildScrollChildren(detail),
          extraAppBarActions: (c, r) => MaterialTaskScreen.buildAppBarActions(c, r, detail),
        );
      default:
        return _TaskBodySpec(
          backgroundColor: DefaultTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish',
          beforeComplete: null,
          buildScrollChildren: (c, r) => DefaultTaskScreen.buildScrollChildren(detail),
          extraAppBarActions: (c, r) => DefaultTaskScreen.buildAppBarActions(c, r, detail),
        );
    }
  }
}

/// Rychlá poznámka k úkolu — append do `description` přes [ITaskRepository.appendWorkerQuickNote].
///
/// PROČ: Dispečer i worker vidí doplněný text po sync; čas a jméno zajišťují auditovatelnost v terénu.
Future<void> _showWorkerQuickNoteDialog(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
  final controller = TextEditingController();
  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('worker.quick_note_dialog_title'.tr()),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'worker.quick_note_dialog_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('worker.quick_note_save'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final raw = controller.text.trim();
    if (raw.isEmpty) return;

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;

    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final name = (profile?.name.trim().isNotEmpty == true)
        ? profile!.name.trim()
        : 'worker.quick_note_unknown_worker'.tr();

    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    final line = 'worker.quick_note_saved_line'.tr(
      namedArgs: {
        'time': timeStr,
        'name': name,
        'text': raw,
      },
    );

    await ref.read(taskRepositoryProvider).appendWorkerQuickNote(tenantId, taskId, line);
    ref.invalidate(workerTaskDetailProvider(taskId));
    ref.invalidate(workerTasksProvider);
    unawaited(
      WorkerSyncService.pushPendingUpdates(
        tenantId,
        onSyncError: ref.read(workerSyncStateProvider.notifier).reportSyncError,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('worker.quick_note_saved_snackbar'.tr())),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.generic_error_user_friendly'.tr())),
      );
    }
  } finally {
    controller.dispose();
  }
}
