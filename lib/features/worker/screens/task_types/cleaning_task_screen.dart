import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/widgets/sync_status_icon.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/utils/cash_collection_dialog.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';
import 'package:falconest/features/worker/widgets/worker_task_shared_header.dart';

/// Obsah scrollu pro úklid – bez Scaffold; master layout drží [WorkerTaskDetailScreen].
abstract final class CleaningTaskScreen {
  CleaningTaskScreen._();

  static const Color backgroundColor = Color(0xFFF3E5F5);

  static List<Widget> buildAppBarActions(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    WorkerTaskDetail detail,
  ) {
    return [
      const SyncStatusIcon(),
      IconButton(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        tooltip: 'worker.cash_enter_button_tooltip'.tr(),
        onPressed: () async {
          await maybeShowCashCollectionDialog(
            context,
            ref,
            detail,
            taskId: taskId,
            onCompleted: () {},
            forceShowForExtraOnly: true,
            completeTaskOnConfirm: false,
          );
        },
      ),
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

  static List<Widget> buildScrollChildren(
    BuildContext context,
    WidgetRef ref,
    WorkerTaskDetail detail,
  ) {
    return [
      WorkerTaskAddressContextBar(
        address: detail.displayAddress,
        latitude: detail.latitude,
        longitude: detail.longitude,
      ),
      const SizedBox(height: 16),
      ..._buildKeyboxAndOwnerNotes(detail),
      const SizedBox(height: 12),
      ..._buildTimeEstimateCard(detail.description),
      ..._buildCleaningMetadata(detail.metadata ?? {}),
    ];
  }

  static List<Widget> _buildKeyboxAndOwnerNotes(WorkerTaskDetail detail) {
    final widgets = <Widget>[];
    final keybox = detail.keybox?.trim();
    final notes = detail.ownerNotes?.trim();
    if (keybox != null && keybox.isNotEmpty) {
      widgets.add(_buildInfoCard('worker.label_keybox'.tr(), keybox, Icons.key));
      widgets.add(const SizedBox(height: 12));
    }
    if (notes != null && notes.isNotEmpty) {
      widgets.add(_buildInfoCard('worker.label_owner_notes'.tr(), notes, Icons.note_outlined));
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  static Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.purple.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _buildTimeEstimateCard(String description) {
    if (description.trim().isEmpty) return [];
    final match = RegExp(r'(?:Odhad|Estimate|Estimación)[:\s]*(\d+)\s*min|(\d+)\s*min')
        .firstMatch(description.trim());
    final minutes = match != null
        ? (int.tryParse(match.group(1) ?? '') ?? int.tryParse(match.group(2) ?? ''))
        : null;
    if (minutes == null || minutes <= 0) return [];

    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.access_time, size: 24, color: Colors.purple.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'worker.cleaning_time_estimate'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'worker.cleaning_time_estimate_minutes'.tr(namedArgs: {'minutes': '$minutes'}),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  static List<Widget> _buildCleaningMetadata(Map<String, dynamic> meta) {
    final note = meta['custom_note'];
    final instructions = meta['instructions'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    final instructionsText =
        instructions is String ? instructions.trim() : (instructions?.toString().trim() ?? '');
    final combined = [noteText, instructionsText].where((s) => s.isNotEmpty).join('\n\n');
    if (combined.isEmpty) return [];

    return [
      const SizedBox(height: 12),
      _buildCustomInstructionsCard(combined),
    ];
  }

  static Widget _buildCustomInstructionsCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outlined, size: 24, color: Colors.amber.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.cleaning_custom_instructions'.tr(),
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
