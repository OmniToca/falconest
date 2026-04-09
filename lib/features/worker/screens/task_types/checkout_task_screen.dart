import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/presentation/widgets/task_guest_cash_summary.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';
import 'package:falconest/features/worker/widgets/worker_task_shared_header.dart';

/// Obsah scrollu pro Check-out – bez Scaffold.
abstract final class CheckoutTaskScreen {
  CheckoutTaskScreen._();

  static const Color backgroundColor = Color(0xFFE8F5E9);

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
      Text(
        detail.description.isNotEmpty ? detail.description : 'common.placeholder_dash'.tr(),
        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
      ),
      ..._buildCheckoutMetadata(context, ref, detail.metadata ?? {}),
    ];
  }

  static List<Widget> _buildCheckoutMetadata(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> meta,
  ) {
    final widgets = <Widget>[];

    final note = meta['custom_note'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    if (noteText.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 16),
        _buildCustomNoteCard(noteText, icon: Icons.checklist),
      ]);
    }

    final audit = taskMetadataAmountEur(meta, 'expected_audit_total');
    final amountCollect = taskMetadataAmountEur(meta, 'amount_to_collect');
    final transit = taskMetadataAmountEur(meta, 'transit_amount_to_collect');
    final agencyPortion = amountCollect > 0 ? amountCollect : audit;
    final hasBreakdown = meta['collection_breakdown'] is Map && (meta['collection_breakdown'] as Map).isNotEmpty;

    if (agencyPortion + transit > 0 || hasBreakdown) {
      widgets.add(const SizedBox(height: 16));
      if (agencyPortion + transit > 0) {
        widgets.add(
          TaskGuestCashSummary(
            agencyEur: agencyPortion,
            transitEur: transit,
            formatEurAmount: (e) => formatTaskAmount(context, ref, e),
            variant: TaskGuestCashSummaryVariant.checkoutBanner,
          ),
        );
      }
      if (hasBreakdown) {
        widgets.add(const SizedBox(height: 12));
        widgets.add(_buildBreakdownCard(context, ref, meta['collection_breakdown'] as Map));
      }
    }

    return widgets;
  }

  static Widget _buildCustomNoteCard(String text, {IconData icon = Icons.note_outlined}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.custom_note'.tr(),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Text(text, style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildBreakdownCard(BuildContext context, WidgetRef ref, Map map) {
    final parts = <Widget>[];
    for (final e in map.entries) {
      final key = e.key.toString().toLowerCase().replaceAll('-', '_');
      final label = _translateTaskTypeKey(key);
      final v = e.value;
      final amountEur = (v is num) ? v.toDouble() : (double.tryParse(v?.toString() ?? '0') ?? 0);
      final formatted = formatTaskAmount(context, ref, amountEur);
      parts.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
            Text(formatted, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ],
        ),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'worker.collection_breakdown'.tr(),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          ...parts,
        ],
      ),
    );
  }

  static String _translateTaskTypeKey(String key) {
    final candidate = 'admin.task_type_$key';
    final translated = candidate.tr();
    return translated == candidate ? 'admin.task_type_other'.tr() : translated;
  }
}
