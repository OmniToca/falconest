import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/screens/task_types/checkin_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/checkout_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/cleaning_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/default_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/issue_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/maintenance_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/material_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/transfer_task_screen.dart';
import 'package:falconest/features/worker/utils/cash_collection_dialog.dart';
import 'package:falconest/features/worker/widgets/task_complete_with_photo_section.dart';

/// Sestavení obsahu a akcí worker detailu podle `task_type`.
///
/// PROČ: Oddělením od [WorkerTaskDetailScreen] zůstane master obrazovka čitelná; typové obrazovky
/// exportují jen statické stavebnice a callbacky bez vlastního [Scaffold].
class WorkerTaskBodySpec {
  WorkerTaskBodySpec({
    required this.backgroundColor,
    required this.finishKey,
    this.beforeComplete,
    required this.buildScrollChildren,
    required this.extraAppBarActions,
  });

  final Color backgroundColor;
  /// Lokalizovaný popisek tlačítka dokončení (klíč + `.tr()` při sestavení spec).
  final String finishKey;
  final BeforeCompleteCallback? beforeComplete;
  final List<Widget> Function(BuildContext context, WidgetRef ref) buildScrollChildren;
  final List<Widget> Function(BuildContext context, WidgetRef ref) extraAppBarActions;

  /// Univerzální callback pro typy úkolů, kde může vzniknout výběr hotovosti.
  ///
  /// PROČ: Nechceme být závislí jen na task_type check-in/transfer; rozhodnutí, zda dialog
  /// opravdu zobrazit, dělá až [maybeShowCashCollectionDialog] podle metadat úkolu
  /// (`amount_to_collect` + `transit_amount_to_collect`).
  static BeforeCompleteCallback _cashCollectionBeforeComplete(
    String taskId,
    WorkerTaskDetail detail,
  ) {
    return (ctx, ref, mediaUrls, {localPhotoPaths}) => maybeShowCashCollectionDialog(
          ctx,
          ref,
          detail,
          taskId: taskId,
          onCompleted: () {
            ref.invalidate(workerTaskDetailProvider(taskId));
            if (ctx.mounted) ctx.pop();
          },
          mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
          localPhotoPaths: localPhotoPaths,
        );
  }

  /// Centrální přepínač typů úkolů → barva pozadí, [finishKey], [beforeComplete] a sestavitelé obsahu.
  static WorkerTaskBodySpec resolve(String type, String taskId, WorkerTaskDetail detail) {
    switch (type) {
      case 'transfer_in':
      case 'transfer_out':
        return WorkerTaskBodySpec(
          backgroundColor: TransferTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish_transfer'.tr(),
          beforeComplete: TransferTaskScreen.beforeComplete(taskId, detail),
          buildScrollChildren: (c, r) =>
              TransferTaskScreen.buildScrollChildren(c, r, taskId, detail),
          extraAppBarActions: (c, r) => TransferTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'check_in':
        return WorkerTaskBodySpec(
          backgroundColor: CheckinTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish'.tr(),
          beforeComplete: CheckinTaskScreen.beforeComplete(taskId, detail),
          buildScrollChildren: (c, r) => CheckinTaskScreen.buildScrollChildren(c, r, detail),
          extraAppBarActions: (c, r) => CheckinTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'check_out':
        return WorkerTaskBodySpec(
          backgroundColor: CheckoutTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish'.tr(),
          beforeComplete: _cashCollectionBeforeComplete(taskId, detail),
          buildScrollChildren: (c, r) => CheckoutTaskScreen.buildScrollChildren(c, r, detail),
          extraAppBarActions: (c, r) => CheckoutTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'issue':
        return WorkerTaskBodySpec(
          backgroundColor: IssueTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_resolved'.tr(),
          beforeComplete: null,
          buildScrollChildren: (c, r) => IssueTaskScreen.buildScrollChildren(detail),
          extraAppBarActions: (c, r) => IssueTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'cleaning':
        return WorkerTaskBodySpec(
          backgroundColor: CleaningTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish'.tr(),
          beforeComplete: null,
          buildScrollChildren: (c, r) => CleaningTaskScreen.buildScrollChildren(c, r, detail),
          extraAppBarActions: (c, r) => CleaningTaskScreen.buildAppBarActions(c, r, taskId, detail),
        );
      case 'maintenance':
        return WorkerTaskBodySpec(
          backgroundColor: MaintenanceTaskScreen.backgroundColor,
          finishKey: 'worker.action_maintenance_resolved'.tr(),
          beforeComplete: null,
          buildScrollChildren: (c, r) => MaintenanceTaskScreen.buildScrollChildren(detail),
          extraAppBarActions: (c, r) => MaintenanceTaskScreen.buildAppBarActions(c, r, detail),
        );
      case 'material':
        return WorkerTaskBodySpec(
          backgroundColor: MaterialTaskScreen.backgroundColor,
          finishKey: 'worker.action_material_restocked'.tr(),
          beforeComplete: null,
          buildScrollChildren: (c, r) => MaterialTaskScreen.buildScrollChildren(detail),
          extraAppBarActions: (c, r) => MaterialTaskScreen.buildAppBarActions(c, r, detail),
        );
      default:
        return WorkerTaskBodySpec(
          backgroundColor: DefaultTaskScreen.backgroundColor,
          finishKey: 'worker.task_detail_finish'.tr(),
          beforeComplete: _cashCollectionBeforeComplete(taskId, detail),
          buildScrollChildren: (c, r) => DefaultTaskScreen.buildScrollChildren(detail),
          extraAppBarActions: (c, r) => DefaultTaskScreen.buildAppBarActions(c, r, detail),
        );
    }
  }
}
