import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';
import 'package:falconest/features/worker/widgets/worker_task_shared_header.dart';

/// Obsah scrollu pro závadu – bez Scaffold.
abstract final class IssueTaskScreen {
  IssueTaskScreen._();

  static const Color backgroundColor = Color(0xFFFFEBEE);

  static List<Widget> buildAppBarActions(
    BuildContext context,
    WidgetRef ref,
    WorkerTaskDetail detail,
  ) {
    return [
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
    ];
  }

  static List<Widget> buildScrollChildren(WorkerTaskDetail detail) {
    return [
      WorkerTaskAddressContextBar(
        address: detail.displayAddress,
        latitude: detail.latitude,
        longitude: detail.longitude,
      ),
      const SizedBox(height: 12),
      ..._buildKeyboxCard(detail.keybox),
      ..._buildIssueDescriptionCard(detail.description),
      ..._buildIssueMetadata(detail.metadata ?? {}),
      const SizedBox(height: 12),
      _buildPhotoPlaceholderCard(),
    ];
  }

  static List<Widget> _buildKeyboxCard(String? keybox) {
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

  static List<Widget> _buildIssueDescriptionCard(String description) {
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

  static Widget _buildPhotoPlaceholderCard() {
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

  static List<Widget> _buildIssueMetadata(Map<String, dynamic> meta) {
    final note = meta['custom_note'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    if (noteText.isEmpty) return [];

    return [
      const SizedBox(height: 16),
      _buildCustomNoteCard(noteText, icon: Icons.build),
    ];
  }

  static Widget _buildCustomNoteCard(String text, {IconData icon = Icons.note_outlined}) {
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
