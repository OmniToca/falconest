import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';

/// Dialog pro nahlášení problému v apartmánu – plná offline podpora.
///
/// Vytvoří nový úkol typu 'issue' v tabulce tasks. Protože pracovník může být
/// offline (apartmán bez signálu), zápis prochází výhradně přes MutationQueueService.
/// NetworkSyncWatcher při návratu sítě odešle frontu do Supabase.
class IssueReporterDialog extends ConsumerStatefulWidget {
  const IssueReporterDialog({
    super.key,
    required this.tenantId,
    required this.apartmentId,
  });

  final String tenantId;
  final String apartmentId;

  @override
  ConsumerState<IssueReporterDialog> createState() => _IssueReporterDialogState();
}

class _IssueReporterDialogState extends ConsumerState<IssueReporterDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final desc = _controller.text.trim();
    if (desc.isEmpty) return;

    setState(() => _submitting = true);

    final profileId = ref.read(authNotifierProvider).state.profileId;
    if (profileId == null || profileId.isEmpty) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.issue_reporter_error'.tr(namedArgs: {'error': 'Missing profile'})),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    final now = DateTime.now().toUtc();
    final dueIso = now.toIso8601String();

    // PROČ: Hlášení problému ukládáme přes MutationQueueService, aby to fungovalo
    // i v apartmánech bez signálu. Následně si to NetworkSyncWatcher odešle do cloudu.
    // V1_RELEASE_AUDIT: try-catch kolem enqueueMutation – při chybě zobrazit SnackBar místo tiché výjimky.
    try {
      final payload = {
        'id': const Uuid().v4(),
        'tenant_id': widget.tenantId,
        'apartment_id': widget.apartmentId,
        'task_type': 'issue',
        'status': 'pending',
        'title': 'worker.issue_reporter_task_title'.tr(),
        'description': desc,
        'created_by': profileId,
        'due_date': dueIso,
        'scheduled_start': dueIso,
        'metadata': <String, dynamic>{},
      };

      await ref.read(mutationQueueServiceProvider).enqueueMutation(
            table: 'tasks',
            action: 'INSERT',
            payload: payload,
          );

      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('worker.issue_reporter_recorded'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('worker.issue_reporter_error'.tr(namedArgs: {'error': e.toString()})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.report_problem_outlined, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Text('worker.issue_reporter_title'.tr()),
        ],
      ),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'worker.issue_reporter_hint'.tr(),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text('worker.issue_reporter_cancel'.tr()),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () {
                  final desc = _controller.text.trim();
                  if (desc.isEmpty) return;
                  _submit();
                },
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('worker.issue_reporter_submit'.tr()),
        ),
      ],
    );
  }
}
