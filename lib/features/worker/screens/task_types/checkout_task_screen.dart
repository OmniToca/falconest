import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/features/worker/providers/worker_detail_provider.dart';

const _primaryBlue = Color(0xFF1565C0);

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
                        Text(
                          _mainHeading(detail),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        _buildScheduledTime(detail.scheduledStart),
                        const SizedBox(height: 16),
                        _buildAddressWithNavigate(context, detail.apartmentAddress),
                        const SizedBox(height: 16),
                        Text(
                          detail.description.isNotEmpty ? detail.description : '—',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        ..._buildCheckoutMetadata(context, detail.metadata ?? {}),
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

  static String _appBarTitle(dynamic detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    return raw.split(':').first.trim();
  }

  static String _mainHeading(dynamic detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    return raw.contains(':') ? raw.split(':').sublist(1).join(':').trim() : raw;
  }

  Widget _buildScheduledTime(DateTime? scheduledStart) {
    if (scheduledStart == null) return const SizedBox.shrink();
    final formatted = DateFormat('dd.MM.yyyy HH:mm').format(scheduledStart);
    return Row(
      children: [
        Icon(Icons.access_time, size: 22, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Text(
          formatted,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
        ),
      ],
    );
  }

  Widget _buildAddressWithNavigate(BuildContext context, String? address) {
    final addr = address?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          addr.isEmpty ? '—' : addr,
          style: TextStyle(fontSize: 17, color: Colors.grey.shade800),
        ),
        if (addr.isNotEmpty) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _openMaps(context, addr),
            icon: const Icon(Icons.map, size: 20),
            label: Text('worker.task_detail_navigate'.tr()),
          ),
        ],
      ],
    );
  }

  Future<void> _openMaps(BuildContext context, String address) async {
    final query = address.trim();
    if (query.isEmpty) return;
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Vykreslení metadat pro Check-out: custom_note (na co si dát pozor), audit, rozpad platby.
  List<Widget> _buildCheckoutMetadata(BuildContext context, Map<String, dynamic> meta) {
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
      widgets.add(_buildAuditCard(context, amount, meta['collection_breakdown']));
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

  /// Informační karta s očekávaným auditem a detailním rozpadem – ikona účtenky.
  Widget _buildAuditCard(BuildContext context, double? amount, dynamic breakdownRaw) {
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
          if (amount != null && amount > 0) ...[
            const SizedBox(height: 6),
            Text(
              NumberFormat.currency(locale: context.locale.toString(), symbol: '€', decimalDigits: 2).format(amount),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
          ],
          if (breakdownRaw is Map && breakdownRaw.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBreakdownCard(breakdownRaw),
          ],
        ],
      ),
    );
  }

  /// Detailní rozpad auditu – klíče přeloženy přes admin.task_type_*.
  Widget _buildBreakdownCard(Map map) {
    final parts = <Widget>[];
    for (final e in map.entries) {
      final key = e.key.toString().toLowerCase().replaceAll('-', '_');
      final label = _translateTaskTypeKey(key);
      final v = e.value;
      final val = (v is num) ? v.toStringAsFixed(2) : (v?.toString() ?? '');
      parts.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
            Text('$val €', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
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
