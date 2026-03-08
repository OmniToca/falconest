import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/services/billing_action_service.dart';
import 'package:falconest/core/services/billing_export_service.dart';
import 'package:falconest/core/services/billing_pdf_service.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';
import 'package:falconest/features/admin/providers/reports_provider.dart';

/// Dialog podkladů pro fakturaci – měsíční přehled dokončených nevyfakturovaných úkolů.
///
/// Používáme ExpansionTile pro přehledné seskupení úkolů pod jednotlivé klienty (majitele),
/// aby měl manažer okamžitý přehled o celkové částce k fakturaci. Klient s více byty má
/// všechny své úkoly v jedné skupině – jedna souhrnná faktura. Každá karta rozbalí detail
/// s jednotlivými úkoly, cenami a typem plátce (majitel vs. host).
class FinanceBillingDialog extends StatelessWidget {
  const FinanceBillingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: FinanceBillingContent(inDialog: true),
      ),
    );
  }
}

/// Obsah podkladů pro fakturaci – použit v dialogu i v záložce Finance dashboardu.
///
/// [inDialog] = true: zobrazí tlačítko zavřít, při uzamčení měsíce zavře dialog.
/// [inDialog] = false: vloženo do záložky, žádné zavírání.
class FinanceBillingContent extends ConsumerStatefulWidget {
  const FinanceBillingContent({super.key, this.inDialog = false});

  final bool inDialog;

  @override
  ConsumerState<FinanceBillingContent> createState() => _FinanceBillingContentState();
}

class _FinanceBillingContentState extends ConsumerState<FinanceBillingContent> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
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

  Future<void> _onClientExportPdf(BuildContext context, BillingGroup group) async {
    final currency = ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.finance.billing_export_pdf_generating'.tr())),
      );
    }
    try {
      await BillingPdfService.generateAndDownloadPdf(
        group,
        DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        currency,
        externalDisplayName: 'admin.finance.billing_group_external'.tr(),
        payerLabels: {
          'owner': 'admin.finance.billing_payer_owner'.tr(),
          'guest': 'admin.finance.billing_payer_guest'.tr(),
          'client': 'admin.finance.billing_payer_client'.tr(),
        },
        footerLabels: {
          'report_title': 'admin.finance.billing_pdf_report_title'.tr(),
          'client_label': 'admin.finance.billing_client_label'.tr(),
          'guest_label': 'admin.finance.billing_guest_label'.tr(),
          'reservation_prefix': 'admin.finance.billing_reservation_prefix'.tr(),
          'standalone_services': 'admin.finance.billing_standalone_services'.tr(),
          'scheduled_label': 'admin.finance.billing_scheduled_label'.tr(),
          'completed_label': 'admin.finance.billing_completed_label'.tr(),
          'date_label': 'admin.finance.billing_date_label'.tr(),
          'fallback_client_name': 'admin.finance.billing_fallback_client_name'.tr(),
          'total_turnover': 'admin.finance.billing_total_turnover'.tr(),
          'paid_by_guests': 'admin.finance.billing_paid_by_guests'.tr(),
          'expenses_to_reimburse': 'admin.finance.billing_expenses_to_reimburse'.tr(),
          'expenses_section': 'admin.finance.billing_expenses_to_reimburse_section'.tr(),
          'final_pay': 'admin.finance.billing_final_owner_pay'.tr(),
          'payer': 'admin.finance.billing_payer'.tr(),
          'summary_section': 'admin.finance.billing_summary_section'.tr(),
          'services_breakdown': 'admin.finance.billing_services_breakdown'.tr(),
          'subtotal_per_reservation': 'admin.finance.billing_subtotal_per_reservation'.tr(),
          'turnover_short': 'admin.finance.billing_turnover_short'.tr(),
          'guest_paid_short': 'admin.finance.billing_guest_paid_short'.tr(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.finance.billing_export_pdf_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'common.error_with_message'.tr(namedArgs: {'message': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  Map<String, String> _buildExcelLabels() => {
    'col_client': 'admin.finance.billing_excel_col_client'.tr(),
    'col_reservation': 'admin.finance.billing_excel_col_reservation'.tr(),
    'col_task': 'admin.finance.billing_excel_col_task'.tr(),
    'col_scheduled': 'admin.finance.billing_excel_col_scheduled'.tr(),
    'col_completed': 'admin.finance.billing_excel_col_completed'.tr(),
    'col_payer': 'admin.finance.billing_excel_col_payer'.tr(),
    'col_price': 'admin.finance.billing_excel_col_price'.tr(),
    'col_currency': 'admin.finance.billing_excel_col_currency'.tr(),
    'row_total': 'admin.finance.billing_excel_row_total'.tr(),
    'row_amount_due': 'admin.finance.billing_excel_row_amount_due'.tr(),
    'paid_by_guests': 'admin.finance.billing_paid_by_guests'.tr(),
    'paid_by_guests_detail': 'admin.finance.billing_paid_by_guests_excel'.tr(),
    'owner': 'admin.finance.billing_payer_owner'.tr(),
    'guest': 'admin.finance.billing_payer_guest'.tr(),
    'client': 'admin.finance.billing_payer_client'.tr(),
    'file_prefix_bulk': 'admin.finance.billing_file_prefix_bulk'.tr(),
    'file_prefix_client': 'admin.finance.billing_file_prefix_client'.tr(),
    'fallback_client_name': 'admin.finance.billing_fallback_client_name'.tr(),
    'encode_error': 'admin.finance.billing_excel_encode_error'.tr(),
  };

  Future<void> _onClientExportExcel(BuildContext context, BillingGroup group) async {
    final currency = ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
    try {
      await BillingExportService.exportClientToExcel(
        group,
        DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        currency,
        externalDisplayName: 'admin.finance.billing_group_external'.tr(),
        labels: _buildExcelLabels(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.finance.billing_export_excel_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'common.error_with_message'.tr(namedArgs: {'message': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _onLockMonthPressed(BuildContext context, List<BillingGroup> groups) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.finance.billing_lock_confirm_title'.tr()),
        content: Text('admin.finance.billing_lock_confirm_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final tenantId = ref.read(authNotifierProvider).state.tenantId;
    final profileId = ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.finance.billing_lock_missing_auth'.tr())),
        );
      }
      return;
    }

    try {
      final currency = ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
      await BillingActionService.lockBillingMonth(
        groups,
        DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        tenantId,
        profileId,
        currency,
      );
      ref.invalidate(billingReportProvider(BillingMonthParam(year: _selectedMonth.year, month: _selectedMonth.month)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.finance.billing_lock_success'.tr())),
        );
        if (widget.inDialog) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'common.error_with_message'.tr(namedArgs: {'message': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _onExportSelected(BuildContext context, String value) async {
    if (value == 'pdf') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.finance.billing_export_preparing'.tr())),
      );
      return;
    }
    if (value == 'excel') {
      final param = BillingMonthParam(
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      );
      final asyncReport = ref.read(billingReportProvider(param));
      final state = asyncReport.valueOrNull;
      final groups = state?.groups;
      if (groups == null || groups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.finance.billing_empty'.tr())),
          );
        }
        return;
      }
      final currency = ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
      try {
        await BillingExportService.exportAllToExcel(
          groups,
          DateTime(_selectedMonth.year, _selectedMonth.month, 1),
          currency,
          externalDisplayName: 'admin.finance.billing_group_external'.tr(),
          labels: _buildExcelLabels(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.finance.billing_export_excel_success'.tr())),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'common.error_with_message'.tr(namedArgs: {'message': e.toString()}),
              ),
            ),
          );
        }
      }
    }
  }

  /// Proklik z řádku úkolu v podkladech pro fakturaci do dialogu úpravy. Po uložení invalidujeme
  /// podklady i Reporty, aby se změna (přeřazení klienta/byt) hned projevila.
  Future<void> _onBillingTaskTap(BuildContext context, String taskId) async {
    final task = await ref.read(taskByIdProvider(taskId).future);
    if (!context.mounted || task == null) return;
    AdminTasksScreen.showEditTaskDialog(
      context,
      ref,
      task,
      onSaved: () {
        ref.invalidate(billingReportProvider(BillingMonthParam(year: _selectedMonth.year, month: _selectedMonth.month)));
        ref.invalidate(reportsDataProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final param = BillingMonthParam(year: _selectedMonth.year, month: _selectedMonth.month);
    final asyncReport = ref.watch(billingReportProvider(param));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hlavička – titul, Export menu, volitelně tlačítko zavřít
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'admin.finance.billing_placeholder_title'.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.download),
                tooltip: 'admin.finance.billing_export_bulk_excel'.tr(),
                onSelected: (value) => _onExportSelected(context, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'excel',
                    child: Text('admin.finance.billing_export_bulk_excel'.tr()),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Text('admin.finance.billing_export_pdf_report'.tr()),
                  ),
                ],
              ),
              if (widget.inDialog)
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
              child: asyncReport.when(
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
                          'common.error_with_message'.tr(namedArgs: {'message': err.toString()}),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                data: (data) {
                  final groups = data.groups;
                  return Column(
                    children: [
                      if (data.isLocked)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade700, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock, color: Colors.amber.shade900, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'admin.finance.billing_month_locked_banner'.tr(),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.amber.shade900,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: groups.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'admin.finance.billing_empty'.tr(),
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : _BillingGroupsList(
                                groups: groups,
                                formatAmount: (v) => formatTaskAmount(context, ref, v),
                                selectedMonth: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
                                currency: ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR',
                                externalDisplayName: 'admin.finance.billing_group_external'.tr(),
                                onClientExportExcel: (group) => _onClientExportExcel(context, group),
                                onClientExportPdf: (group) => _onClientExportPdf(context, group),
                                onTaskTap: (taskId) => _onBillingTaskTap(context, taskId),
                              ),
                      ),
                      if (groups.isNotEmpty && !data.isLocked)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _onLockMonthPressed(context, groups),
                              icon: const Icon(Icons.lock_outline),
                              label: Text('admin.finance.billing_lock_month_btn'.tr()),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
  }
}

/// ListView skupin – ExpansionTile v Card pro každou BillingGroup (klienta).
///
/// Děti jsou hierarchicky seskupeny podle rezervací; úkoly bez rezervace
/// jsou v bloku „Samostatné služby (Mimo rezervace)“.
class _BillingGroupsList extends StatelessWidget {
  const _BillingGroupsList({
    required this.groups,
    required this.formatAmount,
    required this.selectedMonth,
    required this.currency,
    required this.externalDisplayName,
    required this.onClientExportExcel,
    required this.onClientExportPdf,
    this.onTaskTap,
  });

  final List<BillingGroup> groups;
  final String Function(num) formatAmount;
  final DateTime selectedMonth;
  final String currency;
  final String externalDisplayName;
  final void Function(BillingGroup group) onClientExportExcel;
  final void Function(BillingGroup group) onClientExportPdf;
  final void Function(String taskId)? onTaskTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final displayName = group.groupKey == 'external'
            ? externalDisplayName
            : (group.groupName.trim().isEmpty ? 'common.unknown'.tr() : group.groupName);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatAmount(group.finalToInvoice),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.download,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  padding: const EdgeInsets.all(4),
                  tooltip: 'admin.finance.billing_export_client_excel'.tr(),
                  onSelected: (value) {
                    if (value == 'excel') {
                      onClientExportExcel(group);
                    } else if (value == 'pdf') {
                      onClientExportPdf(group);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'excel',
                      child: Text('admin.finance.billing_export_client_excel'.tr()),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: Text('admin.finance.billing_export_client_pdf'.tr()),
                    ),
                  ],
                ),
              ],
            ),
            children: _buildGroupChildren(context, group, onTaskTap),
          ),
        );
      },
    );
  }

  /// Sestaví hierarchii: bloky rezervací, pak samostatné úkoly, nakonec souhrn.
  List<Widget> _buildGroupChildren(BuildContext context, BillingGroup group, void Function(String taskId)? onTaskTap) {
    final formatDate = (d) => DateFormat.yMd(context.locale.toString()).format(d);
    final tasksWithRes = <String, List<BillingTaskItem>>{};
    final tasksWithoutRes = <BillingTaskItem>[];

    for (final task in group.tasks) {
      final resId = task.reservationId;
      if (resId != null && resId.isNotEmpty) {
        tasksWithRes.putIfAbsent(resId, () => []).add(task);
      } else {
        tasksWithoutRes.add(task);
      }
    }

    final children = <Widget>[];

    // A) Bloky pro rezervace
    final resIds = tasksWithRes.keys.toList()..sort();
    final dateFormatShort = DateFormat('dd.MM.yyyy', context.locale.toString());
    for (final resId in resIds) {
      final tasks = tasksWithRes[resId]!;
      final first = tasks.first;
      final guestName = first.guestName;
      final shortId = resId.length > 8 ? resId.substring(0, 8) : resId;
      final baseTitle = guestName != null && guestName.isNotEmpty
          ? 'admin.finance.billing_host_label'.tr(namedArgs: {'name': guestName})
          : 'admin.finance.billing_reservation_label'.tr(namedArgs: {'id': shortId});
      final blockTitle = formatReservationBlockWithDates(
        baseTitle: baseTitle,
        reservationStart: first.reservationStart,
        reservationEnd: first.reservationEnd,
        formatDate: dateFormatShort.format,
      );
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              blockTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
            ),
          ),
        ),
      );
      for (final task in tasks) {
        children.add(
          _BillingTaskTile(
            task: task,
            formatAmount: formatAmount,
            formatDate: formatDate,
            onTaskTap: onTaskTap,
          ),
        );
      }
    }

    // B) Samostatné služby (Mimo rezervace)
    if (tasksWithoutRes.isNotEmpty) {
      children.add(const Divider(height: 24));
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'admin.finance.billing_standalone_services'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
            ),
          ),
        ),
      );
      for (final task in tasksWithoutRes) {
        children.add(
          _BillingTaskTile(
            task: task,
            formatAmount: formatAmount,
            formatDate: formatDate,
            onTaskTap: onTaskTap,
          ),
        );
      }
    }

    // C) Náklady k proplacení – detailní rozpis (datum, popis, částka, účtenka)
    if (group.expenses.isNotEmpty) {
      children.add(const Divider(height: 24));
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'admin.finance.billing_expenses_to_reimburse_section'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
            ),
          ),
        ),
      );
      for (final exp in group.expenses) {
        children.add(
          ListTile(
            leading: Icon(Icons.receipt, color: Colors.grey.shade600, size: 24),
            title: Text(
              exp.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              formatDate(exp.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatAmount(exp.amount),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (exp.mediaUrls.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.photo_camera, size: 18, color: Colors.grey.shade600),
                ],
              ],
            ),
          ),
        );
      }
    }

    // D) Souhrnný blok – obrat, uhrado hosty, náklady k proplacení, doplatek majitele
    children.add(
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryRow(
              label: 'admin.finance.billing_total_turnover'.tr(),
              value: formatAmount(group.totalToInvoice),
            ),
            if (group.totalPaidByGuest > 0)
              _SummaryRow(
                label: 'admin.finance.billing_paid_by_guests'.tr(),
                value: '-${formatAmount(group.totalPaidByGuest)}',
                valueColor: Colors.red.shade700,
              ),
            if (group.totalExpenses > 0)
              _SummaryRow(
                label: 'admin.finance.billing_expenses_to_reimburse'.tr(),
                value: '+${formatAmount(group.totalExpenses)}',
              ),
            const Divider(height: 16),
            _SummaryRow(
              label: 'admin.finance.billing_final_owner_pay'.tr(),
              value: formatAmount(group.finalToInvoice),
              bold: true,
              larger: true,
            ),
          ],
        ),
      ),
    );

    return children;
  }
}

/// Řádek souhrnu – label a hodnota.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
    this.larger = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final bool larger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.w600 : null,
                  fontSize: larger ? 16 : null,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  fontSize: larger ? 18 : null,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}

/// Jedna položka úkolu v detailu skupiny – title, datum, štítek plátce (Payer), cena, ikona fotodokumentace.
/// Klik otevře dialog úpravy úkolu (přeřazení klienta/byt); po uložení se invalidují podklady a Reporty.
class _BillingTaskTile extends StatelessWidget {
  const _BillingTaskTile({
    required this.task,
    required this.formatAmount,
    required this.formatDate,
    this.onTaskTap,
  });

  final BillingTaskItem task;
  final String Function(num) formatAmount;
  final String Function(DateTime) formatDate;
  final void Function(String taskId)? onTaskTap;

  String _payerLabel() {
    switch (task.payerType) {
      case 'owner':
        return 'admin.finance.billing_payer_owner'.tr();
      case 'guest':
        return 'admin.finance.billing_payer_guest'.tr();
      case 'client':
        return 'admin.finance.billing_payer_client'.tr();
      default:
        return 'admin.finance.billing_payer_guest'.tr();
    }
  }

  /// Řádek s přesnými časy plánu a dokončení – profesionální servisní log.
  String _formatTimesLine(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm', context.locale.toString());
    final plan = task.scheduledStart != null
        ? fmt.format(task.scheduledStart!)
        : '—';
    final done = task.completedAt != null ? fmt.format(task.completedAt!) : '—';
    return 'admin.finance.billing_times_line'.tr(
      namedArgs: {'plan': plan, 'done': done},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnerOrClient = task.payerType == 'owner' || task.payerType == 'client';

    final listTile = ListTile(
      onTap: onTaskTap != null ? () => onTaskTap!(task.taskId) : null,
      title: Text(
        task.title,
        style: Theme.of(context).textTheme.bodyMedium,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (task.completedAt != null)
                Text(
                  formatDate(task.completedAt!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              if (task.completedAt != null) const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOwnerOrClient
                      ? Colors.amber.shade100
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _payerLabel(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isOwnerOrClient
                            ? Colors.amber.shade900
                            : Colors.green.shade800,
                      ),
                ),
              ),
            ],
          ),
          if (task.scheduledStart != null || task.completedAt != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                Text(
                  _formatTimesLine(context),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatAmount(task.chargedPrice),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          if (task.mediaUrls.isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(Icons.photo_camera, size: 18, color: Colors.grey.shade600),
          ],
          if (onTaskTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
          ],
        ],
      ),
    );
    if (onTaskTap != null) {
      return Tooltip(
        message: 'admin.finance.billing_task_edit_tooltip'.tr(),
        child: listTile,
      );
    }
    return listTile;
  }
}
