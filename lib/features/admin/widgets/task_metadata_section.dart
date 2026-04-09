import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:falconest/core/presentation/widgets/task_guest_cash_summary.dart';
import 'package:falconest/core/theme/theme_ext.dart';

/// Sdílená read-only komponenta pro zobrazení JSONB metadat úkolu.
/// Zobrazuje custom_note, souhrn hotovosti od hosta (agentura + průtok), service_price (+ payer_type), expected_audit_total, collection_breakdown.
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

    final amountCollect = taskMetadataAmountEur(meta, 'amount_to_collect');
    final expectedAudit = taskMetadataAmountEur(meta, 'expected_audit_total');
    final transitCash = taskMetadataAmountEur(meta, 'transit_amount_to_collect');
    final agencyCash = amountCollect > 0 ? amountCollect : expectedAudit;
    if (agencyCash + transitCash > 0) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: TaskGuestCashSummary(
            agencyEur: agencyCash,
            transitEur: transitCash,
            formatEurAmount: (e) => _formatAmount(context, e),
            variant: TaskGuestCashSummaryVariant.compact,
          ),
        ),
      );
    }

    // Cena služby k fakturaci (např. úklid platí majitel) – z metadata.service_price a metadata.payer_type.
    if (meta.containsKey('service_price')) {
      final v = meta['service_price'];
      final amount = (v is num) ? v.toDouble() : (v != null ? double.tryParse(v.toString()) ?? 0.0 : 0.0);
      if (amount > 0) {
        final pt = meta['payer_type'];
        final payerStr = pt is String ? pt.trim().toLowerCase() : (pt?.toString().trim().toLowerCase() ?? '');
        final payerLabel = _payerTypeLabel(payerStr);
        final labelKey = 'admin.task_metadata_service_price'.tr();
        final paysKey = 'admin.task_metadata_pays'.tr();
        final valueText = '${_formatAmount(context, amount)} ($paysKey: $payerLabel)';
        final labelText = labelKey.isEmpty || labelKey == 'admin.task_metadata_service_price'
            ? 'Cena služby k fakturaci'
            : labelKey;
        rows.add(_MetadataRow(
          icon: Icons.receipt_outlined,
          label: labelText,
          value: valueText,
          valueBold: false,
        ));
      }
    }

    final coveredExpectedInGuestSummary =
        expectedAudit > 0 && amountCollect <= 0 && agencyCash + transitCash > 0;
    if (meta.containsKey('expected_audit_total')) {
      final v = meta['expected_audit_total'];
      final amount = (v is num) ? v.toDouble() : (v != null ? double.tryParse(v.toString()) ?? 0.0 : 0.0);
      if (amount > 0 && !coveredExpectedInGuestSummary) {
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
        // PROČ: metadata box je sekundární panel – používáme nejnižší surface vrstvu.
        color: context.colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
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
              color: context.colors.onSurface,
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

  /// Přeloží payer_type z metadat (owner/guest/client) – i18n s českým fallbackem.
  static String _payerTypeLabel(String payerStr) {
    switch (payerStr) {
      case 'owner':
        final t = 'admin.task_metadata_payer_owner'.tr();
        return t.isEmpty ? 'Majitel' : t;
      case 'guest':
        final t = 'admin.task_metadata_payer_guest'.tr();
        return t.isEmpty ? 'Host' : t;
      case 'client':
        final t = 'admin.task_metadata_payer_client'.tr();
        return t.isEmpty ? 'Klient' : t;
      default:
        final t = 'admin.task_metadata_payer_owner'.tr();
        return t.isEmpty ? 'Majitel' : t;
    }
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
          Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: context.colors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
                    color: valueColor ?? context.colors.onSurface,
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
