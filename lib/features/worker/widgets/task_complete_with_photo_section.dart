import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/offline/network_error_helper.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/features/worker/models/worker_task_checklist_line.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/providers/worker_task_checklist_provider.dart';
import 'package:falconest/features/worker/widgets/task_photo_uploader.dart';

const _storageModuleTasks = 'tasks';

/// Sdílená sekce pro dokončení úkolu s podporou requires_photo a dynamickým checklistem.
///
/// PROČ: DRY – blokace tlačítka Dokončit při requires_photo bez fotek, SnackBar,
/// TaskPhotoUploader a upload před voláním updateStatus.
///
/// **Checklist:** vykresluje ho master [WorkerTaskDetailScreen] nad scrollem (karta nahoře);
/// tato sekce jen blokuje Dokončit přes [workerTaskChecklistAllowsCompletion] z Driftu.
/// Callback před dokončením – např. CashCollectionDialog u Check-in.
/// Vrací: true = úkol byl dokončen v rámci callbacku (pop), null = pokračuj standardním flow.
/// [localPhotoPaths] – při offline flow cesty k zkopírovaným fotkám pro zpožděný upload.
typedef BeforeCompleteCallback = Future<bool?> Function(
  BuildContext context,
  WidgetRef ref,
  List<String> mediaUrls, {
  List<String>? localPhotoPaths,
});

class TaskCompleteWithPhotoSection extends ConsumerStatefulWidget {
  const TaskCompleteWithPhotoSection({
    super.key,
    required this.taskId,
    required this.detail,
    required this.finishKey,
    this.beforeComplete,
  });

  final String taskId;
  final WorkerTaskDetail detail;
  final String finishKey;
  /// Volitelně: dialog před dokončením (např. CashCollectionDialog). Při true = hotovo v rámci callbacku.
  final BeforeCompleteCallback? beforeComplete;

  @override
  ConsumerState<TaskCompleteWithPhotoSection> createState() =>
      _TaskCompleteWithPhotoSectionState();
}

class _TaskCompleteWithPhotoSectionState
    extends ConsumerState<TaskCompleteWithPhotoSection> {
  List<File> _photoFiles = [];

  void _onFilesChanged(List<File> files) {
    setState(() => _photoFiles = files);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final isInProgress = d.isInProgress;
    final isCompleted = d.isCompleted;
    final requiresPhoto =
        widget.detail.metadata?['requires_photo'] == true;
    final hasPhotos = _photoFiles.isNotEmpty ||
        (widget.detail.mediaUrls.isNotEmpty);
    // PROČ: Dynamic Checklists – dokončení je blokované, dokud nejsou splněné body i povinné fotky u položek (Drift).
    final checklistAsync = ref.watch(workerTaskChecklistProvider(widget.taskId));
    final checklistOk = checklistAsync.when(
      data: workerTaskChecklistAllowsCompletion,
      loading: () => false,
      error: (_, _) => false,
    );
    final canComplete = checklistOk && (!requiresPhoto || hasPhotos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCompleted) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.pop(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('common.back'.tr()),
            ),
          ),
        ] else if (isInProgress) ...[
          // PROČ: Fotodokumentaci zobrazujeme vždy — pracovník může přiložit snímky i bez requires_photo;
          // [isRequired] pouze mění vizuál a validace zůstává v [canComplete] (!requiresPhoto || hasPhotos).
          TaskPhotoUploader(
            onFilesChanged: _onFilesChanged,
            maxPhotos: 3,
            existingUrls: widget.detail.mediaUrls,
            isRequired: requiresPhoto,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canComplete
                  ? () => _onCompletePressed(context)
                  : () => _onBlockedCompletePressed(context, checklistOk: checklistOk),
              style: FilledButton.styleFrom(
                backgroundColor: canComplete ? _primaryBlue : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(widget.finishKey.tr()),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _onStartPressed(context),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('worker.task_detail_start_work'.tr()),
            ),
          ),
        ],
      ],
    );
  }

  /// Zkopíruje fotky do trvalého úložiště – aby se nesmazaly z cache před sync.
  static Future<List<String>> _copyPhotosToPersistentStorage({
    required String taskId,
    required List<File> files,
  }) async {
    if (files.isEmpty) return [];
    final dir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${dir.path}/offline_task_photos');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    final result = <String>[];
    final uuid = const Uuid();
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      if (!await file.exists()) continue;
      final targetPath = '${offlineDir.path}/${taskId}_${ts}_${uuid.v4()}_$i.jpg';
      try {
        await file.copy(targetPath);
        result.add(targetPath);
      } catch (e, st) {
        AppLogger.error('TaskCompleteWithPhotoSection: kopie fotky do offline_task_photos selhala', e, st);
      }
    }
    return result;
  }

  void _showRequiresPhotoSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('worker.requires_photo_snackbar'.tr()),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.amber.shade800,
      ),
    );
  }

  /// PROČ: Rozlišíme blokaci kvůli checklistu vs. kvůli fotce u úkolu (requires_photo).
  void _onBlockedCompletePressed(BuildContext context, {required bool checklistOk}) {
    if (!checklistOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.checklist_not_completed_error'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    _showRequiresPhotoSnackBar(context);
  }

  Future<void> _onStartPressed(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('worker.confirm_start_title'.tr()),
        content: Text('worker.confirm_start_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
          widget.taskId,
          'in_progress',
          startedAt: DateTime.now().toUtc(),
        );
  }

  Future<void> _onCompletePressed(BuildContext context) async {
    // PROČ: Obrana proti race – tlačítko musí být šedé, ale dvojitá kontrola z Drift stavu checklistu.
    final checklistSnap = ref.read(workerTaskChecklistProvider(widget.taskId));
    final lines = checklistSnap.valueOrNull ?? [];
    if (!workerTaskChecklistAllowsCompletion(lines)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.checklist_not_completed_error'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    List<String> mediaUrls = List.from(widget.detail.mediaUrls);
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;

    if (_photoFiles.isNotEmpty && tenantId != null && tenantId.isNotEmpty) {
      try {
        for (final file in _photoFiles) {
          final url = await MediaService.instance.uploadMedia(
            file,
            tenantId: tenantId,
            moduleName: _storageModuleTasks,
          );
          if (url != null && url.isNotEmpty) mediaUrls.add(url);
        }
      } catch (e) {
        // Offline fallback: zkopíruj fotky do persistent storage a ulož do fronty.
        if (!kIsWeb && MutationQueueService.isNetworkError(e)) {
          final copiedPaths = await _copyPhotosToPersistentStorage(
            taskId: widget.taskId,
            files: _photoFiles,
          );
          if (copiedPaths.isEmpty) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('worker.issue_reporter_photo_upload_error'.tr()),
                backgroundColor: Colors.red.shade700,
              ),
            );
            return;
          }
          if (widget.beforeComplete != null) {
            if (!context.mounted) return;
            final done = await widget.beforeComplete!(
              context,
              ref,
              widget.detail.mediaUrls,
              localPhotoPaths: copiedPaths,
            );
            if (done == true && context.mounted) context.pop();
            if (done != null) return;
          }
          if (!context.mounted) return;
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('worker.confirm_finish_title'.tr()),
              content: Text('worker.confirm_finish_message'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('common.cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('common.ok'.tr()),
                ),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
                widget.taskId,
                'completed',
                completedAt: DateTime.now().toUtc(),
                localPhotoPaths: copiedPaths,
                existingMediaUrls: widget.detail.mediaUrls,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('worker.task_complete_queued_offline'.tr()),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.orange.shade700,
              ),
            );
            context.pop();
          }
          return;
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNetworkError(e)
                ? 'worker.issue_reporter_photo_required_online'.tr()
                : 'worker.issue_reporter_photo_upload_error'.tr()),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;

    if (widget.beforeComplete != null) {
      if (!context.mounted) return;
      final done = await widget.beforeComplete!(context, ref, mediaUrls);
      if (done == true && context.mounted) context.pop();
      if (done != null) return;
    }

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('worker.confirm_finish_title'.tr()),
        content: Text('worker.confirm_finish_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
          widget.taskId,
          'completed',
          completedAt: DateTime.now().toUtc(),
          mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
        );
    if (context.mounted) context.pop();
  }
}

const _primaryBlue = Color(0xFF1565C0);
