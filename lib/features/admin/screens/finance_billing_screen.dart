import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/providers/current_tenant_name_provider.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';
import 'package:falconest/features/admin/providers/finance_repository.dart';
import 'package:falconest/core/services/pdf_billing_service.dart';

/// Obrazovka fakturačních podkladů – měsíční přehled DOKONČENÝCH a NEVYFAKTUROVANÝCH ÚKOLŮ.
///
/// PROČ úkolová logika: Fakturujeme pouze reálně vykonané úkoly (status completed, invoiced_at null).
/// Rezervace = záměr; úkol = skutečnost. Po vyfakturování úkoly zmizí z přehledu.
class FinanceBillingScreen extends ConsumerStatefulWidget {
  const FinanceBillingScreen({super.key});

  @override
  ConsumerState<FinanceBillingScreen> createState() => _FinanceBillingScreenState();
}

class _FinanceBillingScreenState extends ConsumerState<FinanceBillingScreen> {
  late int _year;
  late int _month;
  bool _isInvoicing = false;

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

  Future<void> _exportPdf(List<BillingApartmentGroup> groups) async {
    if (groups.isEmpty) return;
    final tenantName = ref.read(currentTenantNameProvider).valueOrNull ?? '';
    String formatPrice(double amount) => formatTaskAmount(context, ref, amount);
    final monthYearLabel = _formatMonthYear();

    try {
      final doc = await PdfBillingService.generateDocument(
        groups: groups,
        tenantName: tenantName.isNotEmpty ? tenantName : 'Agentura',
        formatPrice: formatPrice,
        monthYearLabel: monthYearLabel,
      );
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'vyuctovani-$_year-${_month.toString().padLeft(2, '0')}.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.finance.billing_export_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.finance.billing_invoice_error'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _invoiceMonth(List<BillingApartmentGroup> groups) async {
    final taskIds = <String>[];
    for (final g in groups) {
      for (final t in g.tasks) {
        if (t.taskId.isNotEmpty) taskIds.add(t.taskId);
      }
    }
    if (taskIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.finance.billing_invoice_confirm_title'.tr()),
        content: Text(
          'admin.finance.billing_invoice_confirm_message'.tr(namedArgs: {'count': taskIds.length.toString()}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('admin.finance.billing_btn_invoice_month'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isInvoicing = true);
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() => _isInvoicing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.finance.billing_invoice_error'.tr(namedArgs: {'error': 'No tenant'})),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await FinanceRepository.instance.invoiceTasks(tenantId, taskIds);
      ref.invalidate(billingReportProvider(BillingMonthParam(year: _year, month: _month)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.finance.billing_invoice_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.finance.billing_invoice_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInvoicing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final param = BillingMonthParam(year: _year, month: _month);
    final reportAsync = ref.watch(billingReportProvider(param));

    return Scaffold(
      appBar: AppBar(
        title: Text('admin.finance.billing_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          reportAsync.when(
            data: (groups) => IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'admin.finance.billing_export_pdf'.tr(),
              onPressed: groups.isEmpty ? null : () => _exportPdf(groups),
            ),
            loading: () => const IconButton(
              icon: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              onPressed: null,
            ),
            error: (err, st) => const SizedBox.shrink(),
          ),
        ],
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
            data: (groups) {
              if (groups.isEmpty) {
                final emptyMsg = 'admin.finance.billing_empty'.tr();
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          emptyMsg,
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
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == groups.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: FilledButton.icon(
                            onPressed: _isInvoicing
                                ? null
                                : () => _invoiceMonth(groups),
                            icon: _isInvoicing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text('admin.finance.billing_btn_invoice_month'.tr()),
                          ),
                        );
                      }
                      return _BillingApartmentCard(
                        group: groups[index],
                        formatCurrency: _formatCurrency,
                        formatDate: (d) => DateFormat.yMd(context.locale.toString()).format(d),
                      );
                    },
                    childCount: groups.length + 1,
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
                        'common.error_with_message'.tr(namedArgs: {'message': err.toString()}),
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

class _BillingApartmentCard extends StatefulWidget {
  const _BillingApartmentCard({
    required this.group,
    required this.formatCurrency,
    required this.formatDate,
  });

  final BillingApartmentGroup group;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;

  @override
  State<_BillingApartmentCard> createState() => _BillingApartmentCardState();
}

class _BillingApartmentCardState extends State<_BillingApartmentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.apartmentName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          '${widget.group.tasks.length} ${'admin.finance.billing_col_task'.tr().toLowerCase()}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${'admin.finance.col_invoice'.tr()}: ${widget.formatCurrency(widget.group.totalToInvoice)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      Text(
                        '${'admin.finance.col_cash'.tr()}: ${widget.formatCurrency(widget.group.totalCashCollected)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              if (_expanded) ...[
                const Divider(height: 24),
                ...widget.group.tasks.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              t.title,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (t.completedAt != null)
                            Text(
                              widget.formatDate(t.completedAt!),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                            ),
                          const SizedBox(width: 12),
                          Text(
                            widget.formatCurrency(t.chargedPrice),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          if (t.payerType == 'owner')
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'admin.finance.col_invoice'.tr().split(':').first.trim(),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.amber.shade900,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
