import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Sdílená read-only komponenta pro zobrazení JSONB metadat úkolu.
/// Zobrazuje custom_note, amount_to_collect, expected_audit_total, collection_breakdown.
/// Používá se v dialogu úpravy úkolu (admin tasks i plánovací kalendář).
class TaskMetadataSection extends StatelessWidget {
  const TaskMetadataSection({
    super.key,
    this.metadata,
  });

  /// JSONB metadata z tabulky tasks (custom_note, amount_to_collect, expected_audit_total, collection_breakdown).
  /// Když null nebo prázdné, sekce se nevykreslí.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final meta = metadata ?? {};
    if (meta.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];

    if (meta.containsKey('custom_note')) {
      final note = meta['custom_note'];
      final text = note is String ? note : (note?.toString() ?? '');
      if (text.trim().isNotEmpty) {
        rows.add(_MetadataRow(
          icon: Icons.note_outlined,
          label: 'admin.task_metadata_custom_note'.tr(),
          value: text.trim(),
          valueBold: false,
        ));
      }
    }

    if (meta.containsKey('amount_to_collect')) {
      final v = meta['amount_to_collect'];
      final amount = (v is num) ? v.toDouble() : (v != null ? double.tryParse(v.toString()) ?? 0.0 : 0.0);
      if (amount > 0) {
        rows.add(_MetadataRow(
          icon: Icons.payments_outlined,
          label: 'admin.task_metadata_amount_to_collect'.tr(),
          value: _formatAmount(context, amount),
          valueBold: true,
          valueColor: Colors.orange.shade700,
        ));
      }
    }

    if (meta.containsKey('expected_audit_total')) {
      final v = meta['expected_audit_total'];
      final amount = (v is num) ? v.toDouble() : (v != null ? double.tryParse(v.toString()) ?? 0.0 : 0.0);
      if (amount > 0) {
        rows.add(_MetadataRow(
          icon: Icons.receipt_long_outlined,
          label: 'admin.task_metadata_expected_audit'.tr(),
          value: _formatAmount(context, amount),
          valueBold: true,
        ));
      }
    }

    if (meta.containsKey('collection_breakdown')) {
      final cb = meta['collection_breakdown'];
      final text = (cb is Map) ? _formatBreakdown(context, cb) : (cb?.toString() ?? '');
      if (text.isNotEmpty) {
        rows.add(_MetadataRow(
          icon: Icons.account_balance_wallet_outlined,
          label: 'admin.task_metadata_collection_breakdown'.tr(),
          value: text,
          valueBold: false,
        ));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'admin.task_metadata_title'.tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  /// Formátuje částku podle locale/currency (zatím jednoduchý formát s €).
  static String _formatAmount(BuildContext context, double amount) {
    return NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: '€',
      decimalDigits: 2,
    ).format(amount);
  }

  /// Zjednodušený výpis collection_breakdown – klíče (service_type) se překládají přes admin.task_type_*, částky jako měna.
  static String _formatBreakdown(BuildContext context, Map<dynamic, dynamic> map) {
    final parts = <String>[];
    for (final e in map.entries) {
      final rawKey = e.key.toString().trim();
      final key = rawKey.isEmpty ? 'other' : rawKey;
      final label = _translateTaskTypeKey(key);
      final v = e.value;
      final amount = (v is num) ? v.toDouble() : (v != null ? double.tryParse(v.toString()) : null);
      final valStr = amount != null
          ? NumberFormat.currency(
              locale: context.locale.toString(),
              symbol: '€',
              decimalDigits: 2,
            ).format(amount)
          : (v?.toString() ?? '');
      parts.add('$label: $valStr');
    }
    return parts.join(' • ');
  }

  /// Přeloží identifikátor service_type přes admin.task_type_* s fallbackem na task_type_other.
  static String _translateTaskTypeKey(String key) {
    final norm = key.toLowerCase().replaceAll('-', '_');
    final candidate = 'admin.task_type_$norm';
    final translated = candidate.tr();
    return translated == candidate ? 'admin.task_type_other'.tr() : translated;
  }
}

/// Jeden řádek metadat: ikona, label, hodnota (případně tučně a barevně).
class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueBold = false,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool valueBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
                    color: valueColor ?? Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
