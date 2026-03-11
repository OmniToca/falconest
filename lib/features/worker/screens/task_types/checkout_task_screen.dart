import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';
import 'package:falconest/features/worker/widgets/worker_task_shared_header.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';
import 'package:falconest/features/worker/widgets/task_complete_with_photo_section.dart';

/// MVP obrazovka pro úkoly typu Check-out (vlastní obrazovka – odděleno od Check-in).
/// Zobrazuje data úkolu a tlačítko Dokončit. Může zobrazovat očekávaný audit z metadat.
class CheckoutTaskScreen extends ConsumerWidget {
  const CheckoutTaskScreen({super.key, required this.taskId});

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
          backgroundColor: const Color(0xFFE8F5E9),
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
                          title: _mainHeading(detail),
                          scheduledStart: detail.scheduledStart,
                          apartmentAddress: detail.apartmentAddress,
                          startedAt: detail.startedAt,
                          completedAt: detail.completedAt,
                          estimatedMinutes: parseTaskEstimateMinutes(
                            detail.description,
                            detail.metadata,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          detail.description.isNotEmpty ? detail.description : '—',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        ..._buildCheckoutMetadata(context, ref, detail.metadata ?? {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TaskCompleteWithPhotoSection(
                  taskId: taskId,
                  detail: detail,
                  finishKey: 'worker.task_detail_finish',
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
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    final base = raw.split(':').first.trim();
    final ref = detail.referenceNumber?.trim();
    return (ref != null && ref.isNotEmpty) ? '$base • #$ref' : base;
  }

  static String _mainHeading(dynamic detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    return raw.contains(':') ? raw.split(':').sublist(1).join(':').trim() : raw;
  }

  /// Vykreslení metadat pro Check-out: custom_note (na co si dát pozor), audit, rozpad platby.
  /// [ref] – pro formatTaskAmount (měna dle tenanta, fallback profil).
  List<Widget> _buildCheckoutMetadata(BuildContext context, WidgetRef ref, Map<String, dynamic> meta) {
    final widgets = <Widget>[];

    // Poznámka (na co si dát pozor při kontrole bytu).
    final note = meta['custom_note'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    if (noteText.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 16),
        _buildCustomNoteCard(noteText, icon: Icons.checklist),
      ]);
    }

    // Informační karta s očekávaným auditem (expected_audit_total) a ikonou účtenky.
    final expectedTotal = meta['expected_audit_total'];
    final amount = (expectedTotal is num) ? expectedTotal.toDouble() : (expectedTotal != null ? double.tryParse(expectedTotal.toString()) : null);
    final hasBreakdown = meta['collection_breakdown'] is Map && (meta['collection_breakdown'] as Map).isNotEmpty;

    if (amount != null || hasBreakdown) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(_buildAuditCard(context, ref, amount, meta['collection_breakdown']));
    }

    return widgets;
  }

  /// Karta s poznámkou pro check-out (na co si dát pozor při kontrole).
  Widget _buildCustomNoteCard(String text, {IconData icon = Icons.note_outlined}) {
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

  /// Sjednocené formátování přes formatTaskAmount – měna dle tenanta, fallback profil uživatele.
  Widget _buildAuditCard(BuildContext context, WidgetRef ref, double? amount, dynamic breakdownRaw) {
    final amountFormatted = amount != null && amount > 0
        ? formatTaskAmount(context, ref, amount)
        : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, size: 24, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'worker.task_expected_audit'.tr(),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              ),
            ],
          ),
          if (amountFormatted != null) ...[
            const SizedBox(height: 6),
            Text(
              amountFormatted,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
          ],
          if (breakdownRaw is Map && breakdownRaw.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBreakdownCard(context, ref, breakdownRaw),
          ],
        ],
      ),
    );
  }

  /// Sjednocené formátování přes formatTaskAmount – měna dle tenanta, fallback profil uživatele.
  Widget _buildBreakdownCard(BuildContext context, WidgetRef ref, Map map) {
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

  String _translateTaskTypeKey(String key) {
    final candidate = 'admin.task_type_$key';
    final translated = candidate.tr();
    return translated == candidate ? 'admin.task_type_other'.tr() : translated;
  }
}
