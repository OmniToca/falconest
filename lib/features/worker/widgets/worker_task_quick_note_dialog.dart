import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/task/task_repository_provider_export.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/settings/providers/profile_provider.dart';
import 'package:falconest/features/worker/data/services/worker_sync_service.dart';
import 'package:falconest/features/worker/providers/worker_dashboard_provider.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_provider.dart';

/// Zobrazí dialog rychlé poznámky k úkolu (append do popisu + invalidace + push fronty).
///
/// PROČ: Logika je mimo [WorkerTaskDetailScreen], aby master soubor zůstal tenký; loading a
/// `try-catch` chrání před „mrtvým“ UI při chybě DB/sítě a skutečná výjimka jde do logu.
Future<void> showWorkerTaskQuickNoteDialog(BuildContext parentContext, String taskId) {
  return showDialog<void>(
    context: parentContext,
    builder: (dialogContext) => WorkerTaskQuickNoteDialog(
      parentContext: parentContext,
      taskId: taskId,
    ),
  );
}

/// Dialog s textovým polem a uložením přes [ITaskRepository.appendWorkerQuickNote].
class WorkerTaskQuickNoteDialog extends ConsumerStatefulWidget {
  const WorkerTaskQuickNoteDialog({
    super.key,
    required this.parentContext,
    required this.taskId,
  });

  /// Kontext obrazovky detailu — po zavření dialogu pro SnackBar na správném [ScaffoldMessenger].
  final BuildContext parentContext;
  final String taskId;

  @override
  ConsumerState<WorkerTaskQuickNoteDialog> createState() => _WorkerTaskQuickNoteDialogState();
}

class _WorkerTaskQuickNoteDialogState extends ConsumerState<WorkerTaskQuickNoteDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSavePressed() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('worker.quick_note_save_failed'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
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

      await ref.read(taskRepositoryProvider).appendWorkerQuickNote(tenantId, widget.taskId, line);
      ref.invalidate(workerTaskDetailProvider(widget.taskId));
      ref.invalidate(workerTasksProvider);
      await WorkerSyncService.pushPendingUpdates(
        tenantId,
        onSyncError: ref.read(workerSyncStateProvider.notifier).reportSyncError,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      if (!widget.parentContext.mounted) return;
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(content: Text('worker.quick_note_saved_snackbar'.tr())),
      );
    } catch (e, st) {
      AppLogger.error('WorkerTaskQuickNoteDialog: uložení rychlé poznámky selhalo', e, st);
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('worker.quick_note_save_failed'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        title: Text('worker.quick_note_dialog_title'.tr()),
        content: SizedBox(
          width: 420,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TextField(
                controller: _controller,
                maxLines: 4,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  hintText: 'worker.quick_note_dialog_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_isSaving)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.88),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text('worker.quick_note_saving'.tr()),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _onSavePressed,
            child: Text('worker.quick_note_save'.tr()),
          ),
        ],
      ),
    );
  }
}
