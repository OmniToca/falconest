import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/offline/network_error_helper.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/task_photo_uploader.dart';

const _storageModuleTasks = 'tasks';

/// Sdílená sekce pro dokončení úkolu s podporou requires_photo.
///
/// PROČ: DRY – blokace tlačítka Dokončit při requires_photo bez fotek, SnackBar,
/// TaskPhotoUploader a upload před voláním updateStatus. Používá se ve všech
/// worker task screens (cleaning, default, checkin, checkout, transfer, …).
/// Callback před dokončením – např. CashCollectionDialog u Check-in.
/// Vrací: true = úkol byl dokončen v rámci callbacku (pop), null = pokračuj standardním flow.
typedef BeforeCompleteCallback = Future<bool?> Function(
  BuildContext context,
  WidgetRef ref,
  List<String> mediaUrls,
);

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
    final s = widget.detail.status.trim().toLowerCase();
    final isInProgress = s == 'in_progress' || s == 'probíhá';
    final isCompleted =
        s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo';
    final requiresPhoto =
        widget.detail.metadata?['requires_photo'] == true;
    final hasPhotos = _photoFiles.isNotEmpty ||
        (widget.detail.mediaUrls.isNotEmpty);
    final canComplete = !requiresPhoto || hasPhotos;

    if (isCompleted) {
      return SizedBox(
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
      );
    }

    if (isInProgress) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (requiresPhoto) ...[
            TaskPhotoUploader(
              onFilesChanged: _onFilesChanged,
              maxPhotos: 3,
              existingUrls: widget.detail.mediaUrls,
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canComplete
                  ? () => _onCompletePressed(context)
                  : () => _showRequiresPhotoSnackBar(context),
              style: FilledButton.styleFrom(
                backgroundColor: canComplete ? _primaryBlue : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(widget.finishKey.tr()),
            ),
          ),
        ],
      );
    }

    return SizedBox(
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
    );
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
      final done = await widget.beforeComplete!(context, ref, mediaUrls);
      if (done == true && context.mounted) context.pop();
      if (done != null) return;
    }

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
