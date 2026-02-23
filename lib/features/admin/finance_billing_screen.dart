import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/providers/finance_billing_provider.dart';

/// Obrazovka fakturačních podkladů – měsíční přehled služeb u ukončených rezervací.
/// Vyžaduje modul finance_export. Zobrazuje agregaci reservation_services podle plátce.
class FinanceBillingScreen extends ConsumerStatefulWidget {
  const FinanceBillingScreen({super.key});

  @override
  ConsumerState<FinanceBillingScreen> createState() => _FinanceBillingScreenState();
}

class _FinanceBillingScreenState extends ConsumerState<FinanceBillingScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  Future<void> _pickMonthYear() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year, _month, 1),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) {
      setState(() {
        _year = picked.year;
        _month = picked.month;
      });
    }
  }

  String _formatMonthYear() {
    final dt = DateTime(_year, _month, 1);
    return DateFormat.yMMMM(context.locale.toString()).format(dt);
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: '€',
      decimalDigits: 2,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final param = BillingMonthParam(year: _year, month: _month);
    final reportAsync = ref.watch(billingReportProvider(param));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('admin.finance.billing_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'admin.finance.billing_month'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _pickMonthYear,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              _formatMonthYear(),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          reportAsync.when(
            data: (rows) {
              if (rows.isEmpty) {
                final emptyMsg = 'admin.finance.billing_empty'.tr();
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          emptyMsg.isEmpty ? 'Žádná data pro tento měsíc.' : emptyMsg,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columns: [
                        DataColumn(label: Text('admin.finance.col_reservation'.tr())),
                        DataColumn(
                          label: Text('admin.finance.col_total'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('admin.finance.col_cash'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('admin.finance.col_invoice'.tr()),
                          numeric: true,
                        ),
                      ],
                      rows: rows.map((row) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row.apartmentName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  Text(row.periodLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            DataCell(Text(_formatCurrency(row.totalValue))),
                            DataCell(Text(_formatCurrency(row.cashCollected))),
                            DataCell(Text(_formatCurrency(row.toInvoice))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, st) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                      const SizedBox(height: 16),
                      Text(
                        'Chyba: $err',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
