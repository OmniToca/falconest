import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/settlement_export_service.dart';
import 'package:falconest/features/admin/providers/current_tenant_name_provider.dart';
import 'package:falconest/features/admin/providers/settlements_provider.dart';

/// Dialog historie výplat – zobrazuje vyplacené odměny a provize seskupené podle měsíce.
///
/// PROČ: Admin potřebuje přehled, co bylo v daném měsíci vyplaceno (po označení jako paid).
/// Přepínač měsíců umožňuje prohlížet historii obdobím.
class SettlementHistoryDialog extends StatefulWidget {
  const SettlementHistoryDialog({
    super.key,
    required this.ref,
    this.initialMonth,
  });

  final WidgetRef ref;
  final DateTime? initialMonth;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    DateTime? initialMonth,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SettlementHistoryDialog(
        ref: ref,
        initialMonth: initialMonth ?? DateTime.now(),
      ),
    );
  }

  @override
  State<SettlementHistoryDialog> createState() => _SettlementHistoryDialogState();
}

class _SettlementHistoryDialogState extends State<SettlementHistoryDialog> {
  late DateTime _selectedMonth;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth ?? DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    final now = DateTime.now();
    if (next.year < now.year || (next.year == now.year && next.month <= now.month)) {
      setState(() => _selectedMonth = next);
    }
  }

  String _formatMonthYear() {
    return DateFormat.yMMMM(context.locale.toString()).format(
      DateTime(_selectedMonth.year, _selectedMonth.month, 1),
    );
  }

  Future<void> _onExportPdf() async {
    if (_isExporting) return;
    final monthParam = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    var groups = widget.ref.read(paidSettlementsByMonthProvider(monthParam)).valueOrNull;
    if (groups == null) {
      groups = await widget.ref.read(paidSettlementsByMonthProvider(monthParam).future);
    }
    final groupsList = groups ?? <PayoutGroup>[];
    if (groupsList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.settlements.history_empty'.tr())),
        );
      }
      return;
    }

    setState(() => _isExporting = true);
    try {
      final currency =
          widget.ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
      final tenantName =
          widget.ref.read(currentTenantNameProvider).valueOrNull ?? '';

      await SettlementExportService.exportPayoutHistoryToPdf(
        month: monthParam,
        monthLabel: _formatMonthYear(),
        locale: context.locale.toString(),
        data: groupsList,
        tenantCurrency: currency,
        tenantName: tenantName.trim().isNotEmpty ? tenantName : null,
        labels: {
          'report_title': 'admin.settlements.export_pdf_title'.tr(),
          'col_name': 'admin.settlements.export_pdf_col_name'.tr(),
          'col_type': 'admin.settlements.export_pdf_col_type'.tr(),
          'col_amount': 'admin.settlements.export_pdf_col_amount'.tr(),
          'total': 'admin.settlements.export_pdf_total'.tr(),
          'type_employee': 'admin.settlements.export_pdf_type_employee'.tr(),
          'type_partner': 'admin.settlements.export_pdf_type_partner'.tr(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.settlements.export_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthParam = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final groupsAsync = widget.ref.watch(paidSettlementsByMonthProvider(monthParam));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hlavička – titul, tlačítko export, tlačítko zavřít
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'admin.settlements.history_title'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: _isExporting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    onPressed: _isExporting ? null : _onExportPdf,
                    tooltip: 'admin.settlements.export_button'.tr(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'common.close'.tr(),
                  ),
                ],
              ),
            ),
            // Přepínač měsíce: šipka vlevo | Měsíc Rok | šipka vpravo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _previousMonth,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatMonthYear(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ),
            ),
            // Obsah: loading / error / data
            Expanded(
              child: groupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                        const SizedBox(height: 16),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'admin.settlements.history_empty'.tr(),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _HistoryRowCard(
                        group: group,
                        formatAmount: (v) => formatWalletAmount(context, widget.ref, v),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jedna řádková karta příjemce v historii – jméno, ikona, částka.
class _HistoryRowCard extends StatelessWidget {
  const _HistoryRowCard({
    required this.group,
    required this.formatAmount,
  });

  final PayoutGroup group;
  final String Function(double) formatAmount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              group.isEmployee ? Icons.person : Icons.business,
              size: 20,
              color: group.isEmployee ? Colors.blue.shade700 : Colors.purple.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.recipientName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              formatAmount(group.totalAmount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
