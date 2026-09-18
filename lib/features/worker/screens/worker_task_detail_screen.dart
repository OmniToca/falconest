import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/communication/models/message_template_selector_context.dart';
import 'package:falconest/features/communication/widgets/message_template_selector_bottom_sheet.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/utils/worker_task_body_resolver.dart';
import 'package:falconest/features/worker/widgets/task_complete_with_photo_section.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';
import 'package:falconest/features/worker/widgets/worker_task_checklist_widget.dart';
import 'package:falconest/features/worker/widgets/worker_task_detail_offline_context_cards.dart';
import 'package:falconest/features/worker/widgets/worker_task_detail_sticky_header.dart';
import 'package:falconest/features/worker/widgets/worker_task_quick_note_dialog.dart';
import 'package:falconest/features/worker/widgets/worker_task_signature_section.dart';
import 'package:falconest/features/legal_spain/widgets/worker_legal_checkin_section.dart';

/// Master detail úkolu – jeden Scaffold, AppBar, sticky stav/čas, scroll s checklistem nahoře a patičkou akcí.
///
/// PROČ: Typové obrazovky dodávají jen obsah ([SliverList] ekvivalent přes [SliverChildListDelegate]),
/// aby nevznikaly duplicitní AppBar a aby odpočet zůstal vidět při scrollu (pevná [Column] nad [CustomScrollView]).
/// Mapování typu úkolu na obsah řeší [WorkerTaskBodySpec.resolve] v samostatném souboru.
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
        final spec = WorkerTaskBodySpec.resolve(type, taskId, detail);
        final est = parseTaskEstimateMinutes(detail.description, detail.metadata);

        return Scaffold(
          backgroundColor: spec.backgroundColor,
          floatingActionButton: detail.isCompleted
              ? null
              : FloatingActionButton.small(
                  tooltip: 'worker.quick_note_fab_tooltip'.tr(),
                  onPressed: () => showWorkerTaskQuickNoteDialog(context, taskId),
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
                          const SizedBox(height: 8),
                          WorkerTaskSignatureSection(taskId: taskId, detail: detail),
                          WorkerLegalCheckinSection(taskId: taskId),
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
