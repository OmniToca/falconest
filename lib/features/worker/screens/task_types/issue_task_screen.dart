import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';
import 'package:falconest/features/worker/widgets/worker_task_shared_header.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';
import 'package:falconest/features/worker/widgets/task_complete_with_photo_section.dart';

/// MVP obrazovka pro úkoly typu Závada/Údržba.
/// Jednoduché zobrazení dat a tlačítko Dokončit.
class IssueTaskScreen extends ConsumerWidget {
  const IssueTaskScreen({super.key, required this.taskId});

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
          backgroundColor: const Color(0xFFFFEBEE),
          appBar: AppBar(
            title: Text(
              _appBarTitle(detail),
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
                        WorkerTaskSharedHeader(
                          title: detail.title.isNotEmpty ? detail.title : detail.apartmentName ?? '—',
                          scheduledStart: detail.scheduledStart,
                          apartmentAddress: detail.apartmentAddress,
                          startedAt: detail.startedAt,
                          completedAt: detail.completedAt,
                          estimatedMinutes: parseTaskEstimateMinutes(
                            detail.description,
                            detail.metadata,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // PROČ: Kód schránky – údržbář potřebuje vstup do bytu.
                        ..._buildKeyboxCard(detail.keybox),
                        // PROČ: Popis závady z description – hlavní info o problému v odlišené kartě.
                        ..._buildIssueDescriptionCard(detail.description),
                        // Poznámka z metadat (custom_note) – doplňující info.
                        ..._buildIssueMetadata(detail.metadata ?? {}),
                        const SizedBox(height: 12),
                        // PROČ: Placeholder pro fotografie – připraveno pro v2.0, zatím jen "žádná fotka".
                        _buildPhotoPlaceholderCard(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TaskCompleteWithPhotoSection(
                  taskId: taskId,
                  detail: detail,
                  finishKey: 'worker.task_detail_resolved',
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(child: Text('worker.task_detail_not_found'.tr())),
      ),
    );
  }

  static String _appBarTitle(dynamic detail) {
    final base = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    final ref = detail.referenceNumber?.trim();
    return (ref != null && ref.isNotEmpty) ? '$base • #$ref' : base;
  }

  /// Karta s kódem schránky – stejný styl jako Transfer (modré pozadí).
  List<Widget> _buildKeyboxCard(String? keybox) {
    final code = keybox?.trim();
    if (code == null || code.isEmpty) return [];

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.key, size: 24, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'worker.label_keybox'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(code, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  /// Karta popisu závady – červeno/oranžové pozadí, ikona wrench (problém k řešení).
  List<Widget> _buildIssueDescriptionCard(String description) {
    final text = description.trim();
    if (text.isEmpty) return [];

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.build, size: 24, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'worker.issue_detail_title'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  /// Placeholder pro fotografie závady – připraveno pro v2.0, zatím jen "žádná fotka".
  Widget _buildPhotoPlaceholderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 24, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.issue_photo_placeholder'.tr(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  'worker.issue_no_photo'.tr(),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vykreslení metadat pro Závada/Údržbu – custom_note (doplňující popis).
  List<Widget> _buildIssueMetadata(Map<String, dynamic> meta) {
    final note = meta['custom_note'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    if (noteText.isEmpty) return [];

    return [
      const SizedBox(height: 16),
      _buildCustomNoteCard(noteText, icon: Icons.build),
    ];
  }

  Widget _buildCustomNoteCard(String text, {IconData icon = Icons.note_outlined}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.red.shade700),
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
