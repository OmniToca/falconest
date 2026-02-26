import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/widgets/task_header_widget.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';

const _primaryBlue = Color(0xFF1565C0);

/// MVP obrazovka pro ostatní typy úkolů (Materiál, Jiné).
/// Jednoduché zobrazení dat a tlačítko Dokončit.
class DefaultTaskScreen extends ConsumerWidget {
  const DefaultTaskScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(workerTaskDetailProvider(taskId));

    return detailAsync.when(
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            body: Center(child: Text('worker.task_detail_not_found'.tr())),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: Text(
              detail.title.isNotEmpty ? detail.title : detail.apartmentName ?? '—',
              style: const TextStyle(color: Colors.black87),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black87,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            actions: [
              IconButton(
                icon: const Icon(Icons.report_problem_outlined),
                onPressed: () {
                  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
                  if (tenantId == null || tenantId.isEmpty) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => IssueReporterDialog(
                      tenantId: tenantId,
                      apartmentId: detail.apartmentId,
                    ),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sjednocená hlavička podle vzoru Check-in/Check-out (nadpis + clock/time řádek).
                        TaskHeaderWidget(
                          title: detail.title.isNotEmpty ? detail.title : detail.apartmentName ?? '—',
                          scheduledStart: detail.scheduledStart,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          detail.apartmentAddress ?? '—',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          detail.description.isNotEmpty ? detail.description : '—',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        // Poznámka (custom_note) pro ostatní typy úkolů.
                        ..._buildDefaultMetadata(detail.metadata ?? {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionButton(context, ref, taskId, detail.status, 'worker.task_detail_finish'),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        body: Center(child: Text('worker.task_detail_not_found'.tr())),
      ),
    );
  }

  // Dvoufázové odpracování: Nejprve Zahájit (in_progress), poté Dokončit (completed).
  // Uložení přesného UTC času pro sledování reálné doby práce.
  Widget _buildActionButton(BuildContext context, WidgetRef ref, String taskId, String status, String finishKey) {
    final s = status.trim().toLowerCase();
    final isInProgress = s == 'in_progress' || s == 'probíhá';
    final isCompleted = s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo';

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
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () async {
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
                  taskId,
                  'completed',
                  completedAt: DateTime.now().toUtc(),
                );
            if (context.mounted) context.pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(finishKey.tr()),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () async {
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
                taskId,
                'in_progress',
                startedAt: DateTime.now().toUtc(),
              );
        },
        style: FilledButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text('worker.task_detail_start_work'.tr()),
      ),
    );
  }

  /// Vykreslení metadat pro Ostatní typy úkolů – custom_note.
  List<Widget> _buildDefaultMetadata(Map<String, dynamic> meta) {
    final note = meta['custom_note'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    if (noteText.isEmpty) return [];

    return [
      const SizedBox(height: 16),
      _buildCustomNoteCard(noteText, icon: Icons.assignment_outlined),
    ];
  }

  Widget _buildCustomNoteCard(String text, {IconData icon = Icons.note_outlined}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.custom_note'.tr(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
