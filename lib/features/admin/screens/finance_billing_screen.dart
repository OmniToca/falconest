import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/widgets/app_empty_state.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
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
  ConsumerState<FinanceBillingContent> createState() =>
      _FinanceBillingContentState();
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
    if (next.year < now.year ||
        (next.year == now.year && next.month <= now.month)) {
      setState(() => _selectedMonth = next);
    }
  }

  String _formatMonthYear() {
    return DateFormat.yMMMM(
      context.locale.toString(),
    ).format(DateTime(_selectedMonth.year, _selectedMonth.month, 1));
  }

  Future<void> _onClientExportPdf(
    BuildContext context,
    BillingGroup group,
  ) async {
    final currency =
        ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.finance.billing_export_pdf_generating'.tr()),
        ),
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
          'standalone_services': 'admin.finance.billing_standalone_services'
              .tr(),
          'scheduled_label': 'admin.finance.billing_scheduled_label'.tr(),
          'completed_label': 'admin.finance.billing_completed_label'.tr(),
          'date_label': 'admin.finance.billing_date_label'.tr(),
          'fallback_client_name': 'admin.finance.billing_fallback_client_name'
              .tr(),
          'total_turnover': 'admin.finance.billing_total_turnover'.tr(),
          'paid_by_guests': 'admin.finance.billing_paid_by_guests'.tr(),
          'expenses_to_reimburse': 'admin.finance.billing_expenses_to_reimburse'
              .tr(),
          'expenses_section':
              'admin.finance.billing_expenses_to_reimburse_section'.tr(),
          'monthly_management_fee':
              'admin.finance.billing_monthly_management_fee'.tr(),
          'task_price_label': 'admin.finance.billing_task_price_label'.tr(),
          'task_guest_paid_label': 'admin.finance.billing_task_guest_paid_label'
              .tr(),
          'task_shortfall_due_label':
              'admin.finance.billing_task_shortfall_due_label'.tr(),
          'final_pay': 'admin.finance.billing_final_owner_pay'.tr(),
          'payer': 'admin.finance.billing_payer'.tr(),
          'summary_section': 'admin.finance.billing_summary_section'.tr(),
          'services_breakdown': 'admin.finance.billing_services_breakdown'.tr(),
          'subtotal_per_reservation':
              'admin.finance.billing_subtotal_per_reservation'.tr(),
          'turnover_short': 'admin.finance.billing_turnover_short'.tr(),
          'guest_paid_short': 'admin.finance.billing_guest_paid_short'.tr(),
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.finance.billing_export_pdf_success'.tr()),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.generic_error_user_friendly'.tr())),
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

  Future<void> _onClientExportExcel(
    BuildContext context,
    BillingGroup group,
  ) async {
    final currency =
        ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
    try {
      await BillingExportService.exportClientToExcel(
        group,
        DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        currency,
        externalDisplayName: 'admin.finance.billing_group_external'.tr(),
        labels: _buildExcelLabels(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.finance.billing_export_excel_success'.tr()),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.generic_error_user_friendly'.tr())),
        );
      }
    }
  }

  Future<void> _onLockMonthPressed(
    BuildContext context,
    List<BillingGroup> groups,
  ) async {
    final hasLockRisk = groups.any(
      (g) => g.tasks.any((t) => t.hasLockBillingRisk),
    );
    if (hasLockRisk) {
      final proceedDespiteRisk = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('admin.finance.billing_lock_risk_title'.tr()),
          content: Text('admin.finance.billing_lock_risk_body'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('admin.finance.billing_lock_risk_continue'.tr()),
            ),
          ],
        ),
      );
      if (proceedDespiteRisk != true) return;
      if (!context.mounted) return;
    }

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

    if (confirmed != true || !context.mounted) return;

    final tenantId = ref.read(authNotifierProvider).state.tenantId;
    final profileId = ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null ||
        tenantId.isEmpty ||
        profileId == null ||
        profileId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.finance.billing_lock_missing_auth'.tr()),
          ),
        );
      }
      return;
    }

    try {
      final currency =
          ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
      await BillingActionService.lockBillingMonth(
        groups,
        DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        tenantId,
        profileId,
        currency,
      );
      ref.invalidate(
        billingReportProvider(
          BillingMonthParam(
            year: _selectedMonth.year,
            month: _selectedMonth.month,
          ),
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.finance.billing_lock_success'.tr())),
        );
        if (widget.inDialog) Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.generic_error_user_friendly'.tr())),
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.finance.billing_empty'.tr())),
          );
        }
        return;
      }
      final currency =
          ref.read(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
      try {
        await BillingExportService.exportAllToExcel(
          groups,
          DateTime(_selectedMonth.year, _selectedMonth.month, 1),
          currency,
          externalDisplayName: 'admin.finance.billing_group_external'.tr(),
          labels: _buildExcelLabels(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin.finance.billing_export_excel_success'.tr()),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('common.generic_error_user_friendly'.tr())),
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
        ref.invalidate(
          billingReportProvider(
            BillingMonthParam(
              year: _selectedMonth.year,
              month: _selectedMonth.month,
            ),
          ),
        );
        ref.invalidate(reportsDataProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final param = BillingMonthParam(
      year: _selectedMonth.year,
      month: _selectedMonth.month,
    );
    final asyncReport = ref.watch(billingReportProvider(param));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hlavička – titul, Export menu, volitelně tlačítko zavřít
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'admin.finance.billing_placeholder_title'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Material(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: AppSpacing.xxl,
                      color: context.colors.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'common.generic_error_user_friendly'.tr(),
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium,
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
                      margin: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: context.customColors.warning.withValues(
                          alpha: 0.18,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.sm + AppSpacing.xs,
                        ),
                        border: Border.all(
                          color: context.customColors.warning,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: context.customColors.warning,
                            size: AppSpacing.lg,
                          ),
                          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'admin.finance.billing_month_locked_banner'.tr(),
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.customColors.onWarning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: groups.isEmpty
                        ? AppEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'admin.finance.billing_empty'.tr(),
                          )
                        : _BillingGroupsList(
                            groups: groups,
                            formatAmount: (v) =>
                                formatTaskAmount(context, ref, v),
                            selectedMonth: DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month,
                              1,
                            ),
                            currency:
                                ref
                                    .read(currentTenantCurrencyProvider)
                                    .valueOrNull ??
                                'EUR',
                            externalDisplayName:
                                'admin.finance.billing_group_external'.tr(),
                            onClientExportExcel: (group) =>
                                _onClientExportExcel(context, group),
                            onClientExportPdf: (group) =>
                                _onClientExportPdf(context, group),
                            onTaskTap: (taskId) =>
                                _onBillingTaskTap(context, taskId),
                            tenantId: ref
                                .read(authNotifierProvider)
                                .tenantIdForData,
                            onShortfallResolved: () {
                              ref.invalidate(
                                billingReportProvider(
                                  BillingMonthParam(
                                    year: _selectedMonth.year,
                                    month: _selectedMonth.month,
                                  ),
                                ),
                              );
                              ref.invalidate(cashShortfallsCountProvider);
                            },
                            // PROČ: Účetní potřebuje nad seskupením podle klientů ještě jeden agregovaný
                            // pohled na celý měsíc – stejná čísla jako součty per klient, ale s vysvětlením
                            // (tooltip) a rozpisem položek bez nutnosti rozklikávat každou skupinu.
                            accountantHeader: _BillingAccountantMonthOverview(
                              groups: groups,
                              formatAmount: (v) =>
                                  formatTaskAmount(context, ref, v),
                              externalDisplayName:
                                  'admin.finance.billing_group_external'.tr(),
                            ),
                          ),
                  ),
                  if (groups.isNotEmpty && !data.isLocked)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _onLockMonthPressed(context, groups),
                          icon: const Icon(Icons.lock_outline),
                          label: Text(
                            'admin.finance.billing_lock_month_btn'.tr(),
                          ),
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

/// Řádek měsíčního souhrnu s ikonou nápovědy – účetní si vysvětlí složení částky bez přetížení UI.
///
/// PROČ: Agregáty napříč klienty (obrat, hotovost od hostů, náklady) nejsí z názvu vždy zřejmé;
/// [Tooltip] na ikoně (hover na webu, dlouhý stisk na mobilu) doplňuje kontext dle i18n.
Widget _billingAggregatedMetricRow(
  BuildContext context, {
  required String labelKey,
  required String tooltipKey,
  required double amount,
  required String Function(num) formatAmount,
  bool emphasize = false,
}) {
  final theme = Theme.of(context);
  final valueStyle =
      (emphasize ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
          ?.copyWith(
            fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
            color: emphasize ? theme.colorScheme.primary : null,
          );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  labelKey.tr(),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: tooltipKey.tr(),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: Text(
            formatAmount(amount),
            style: valueStyle,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Rozbalovací blok v sekci „Rozpad položek“ – uvnitř omezený scroll, aby ExpansionTile v hlavním scrollu neřezala obsah.
///
/// PROČ: Stejný problém jako u karet klientů: mnoho řádků bez vnitřního scrollu ořízne spodek na webu i v tabu.
Widget _billingBreakdownExpansion(
  BuildContext context, {
  required String titleKey,
  required String emptyKey,
  required String countLabelKey,
  required double maxHeight,
  required int itemCount,
  required Widget Function(int index) itemBuilder,
}) {
  return ExpansionTile(
    title: Text(
      titleKey.tr(),
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      itemCount == 0
          ? emptyKey.tr()
          : countLabelKey.tr(namedArgs: {'count': itemCount.toString()}),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
    children: [
      if (itemCount == 0)
        const SizedBox(height: AppSpacing.xs)
      else
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: itemCount,
            itemBuilder: (context, index) => itemBuilder(index),
          ),
        ),
    ],
  );
}

/// Měsíční pohled pro účetní: součty přes všechny [BillingGroup] a rozpad úkolů / výdajů / paušálů / převodů.
///
/// PROČ: [billingReportProvider] už dodává seskupená data; zde je pouze sumarizace a plošší výpis,
/// aby nebylo nutné ručně sčítat hodnoty z hlaviček karet klientů.
class _BillingAccountantMonthOverview extends StatelessWidget {
  const _BillingAccountantMonthOverview({
    required this.groups,
    required this.formatAmount,
    required this.externalDisplayName,
  });

  final List<BillingGroup> groups;
  final String Function(num) formatAmount;
  final String externalDisplayName;

  String _clientLabel(BillingGroup g) {
    if (g.groupKey == 'external') return externalDisplayName;
    final n = g.groupName.trim();
    return n.isEmpty ? 'common.unknown'.tr() : n;
  }

  @override
  Widget build(BuildContext context) {
    var sumTurnover = 0.0;
    var sumGuest = 0.0;
    var sumExp = 0.0;
    var sumFee = 0.0;
    var sumFinal = 0.0;
    var sumShortfall = 0.0;
    for (final g in groups) {
      sumTurnover += g.totalToInvoice;
      sumGuest += g.totalPaidByGuest;
      sumExp += g.totalExpenses;
      sumFee += g.monthlyManagementFee;
      sumFinal += g.finalToInvoice;
      sumShortfall += g.totalShortfallTransfers;
    }

    final allTasks = <({String client, BillingTaskItem task})>[];
    final allExpenses = <({String client, BillingExpenseItem e})>[];
    final flatShortfalls =
        <({String client, BillingShortfallTransferItem t})>[];
    for (final g in groups) {
      final c = _clientLabel(g);
      for (final t in g.tasks) {
        allTasks.add((client: c, task: t));
      }
      for (final e in g.expenses) {
        allExpenses.add((client: c, e: e));
      }
      for (final sf in g.shortfallTransfers) {
        flatShortfalls.add((client: c, t: sf));
      }
    }
    final groupsWithMonthlyFee = groups
        .where((g) => g.monthlyManagementFee > 0)
        .toList();

    final dateFmt = DateFormat.yMd(context.locale.toString());
    final maxListH = MediaQuery.sizeOf(context).height * 0.42;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        premiumCardShell(
          context,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'admin.finance.billing_accountant_summary_title'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                _billingAggregatedMetricRow(
                  context,
                  labelKey: 'admin.finance.billing_total_turnover',
                  tooltipKey:
                      'admin.finance.billing_tooltip_aggregate_turnover',
                  amount: sumTurnover,
                  formatAmount: formatAmount,
                ),
                _billingAggregatedMetricRow(
                  context,
                  labelKey: 'admin.finance.billing_paid_by_guests',
                  tooltipKey:
                      'admin.finance.billing_tooltip_aggregate_guest_paid',
                  amount: sumGuest,
                  formatAmount: formatAmount,
                ),
                _billingAggregatedMetricRow(
                  context,
                  labelKey: 'admin.finance.billing_expenses_to_reimburse',
                  tooltipKey:
                      'admin.finance.billing_tooltip_aggregate_expenses',
                  amount: sumExp,
                  formatAmount: formatAmount,
                ),
                if (sumFee > 0)
                  _billingAggregatedMetricRow(
                    context,
                    labelKey: 'admin.finance.billing_monthly_management_fee',
                    tooltipKey:
                        'admin.finance.billing_tooltip_aggregate_monthly_fees',
                    amount: sumFee,
                    formatAmount: formatAmount,
                  ),
                if (sumShortfall > 0)
                  _billingAggregatedMetricRow(
                    context,
                    labelKey:
                        'admin.finance.billing_shortfall_transfers_section',
                    tooltipKey:
                        'admin.finance.billing_tooltip_aggregate_shortfall_transfers',
                    amount: sumShortfall,
                    formatAmount: formatAmount,
                  ),
                const Divider(height: AppSpacing.lg),
                _billingAggregatedMetricRow(
                  context,
                  labelKey: 'admin.finance.billing_final_owner_pay',
                  tooltipKey:
                      'admin.finance.billing_tooltip_aggregate_final_due',
                  amount: sumFinal,
                  formatAmount: formatAmount,
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        premiumCardShell(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  'admin.finance.billing_accountant_breakdown_title'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _billingBreakdownExpansion(
                context,
                titleKey: 'admin.finance.billing_breakdown_section_tasks',
                emptyKey: 'admin.finance.billing_breakdown_no_tasks',
                countLabelKey: 'admin.finance.billing_breakdown_item_count',
                maxHeight: maxListH,
                itemCount: allTasks.length,
                itemBuilder: (i) {
                  final row = allTasks[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      'admin.finance.billing_breakdown_task_line'.tr(
                        namedArgs: {
                          'client': row.client,
                          'title': row.task.title,
                        },
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      formatAmount(row.task.chargedPrice),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
              _billingBreakdownExpansion(
                context,
                titleKey: 'admin.finance.billing_breakdown_section_wallet',
                emptyKey: 'admin.finance.billing_breakdown_no_expenses',
                countLabelKey: 'admin.finance.billing_breakdown_item_count',
                maxHeight: maxListH,
                itemCount: allExpenses.length,
                itemBuilder: (i) {
                  final row = allExpenses[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      row.e.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${row.client} · ${dateFmt.format(row.e.date.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Text(
                      formatAmount(row.e.amount),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
              _billingBreakdownExpansion(
                context,
                titleKey: 'admin.finance.billing_breakdown_section_monthly',
                emptyKey: 'admin.finance.billing_breakdown_no_monthly',
                countLabelKey: 'admin.finance.billing_breakdown_item_count',
                maxHeight: maxListH,
                itemCount: groupsWithMonthlyFee.length,
                itemBuilder: (i) {
                  final g = groupsWithMonthlyFee[i];
                  return ListTile(
                    dense: true,
                    title: Text(_clientLabel(g)),
                    trailing: Text(
                      formatAmount(g.monthlyManagementFee),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
              _billingBreakdownExpansion(
                context,
                titleKey: 'admin.finance.billing_breakdown_section_shortfall',
                emptyKey: 'admin.finance.billing_breakdown_no_shortfalls',
                countLabelKey: 'admin.finance.billing_breakdown_item_count',
                maxHeight: maxListH,
                itemCount: flatShortfalls.length,
                itemBuilder: (i) {
                  final row = flatShortfalls[i];
                  final desc = row.t.description?.trim().isNotEmpty == true
                      ? row.t.description!.trim()
                      : 'admin.finance.billing_shortfall_transfer_description'
                            .tr();
                  return ListTile(
                    dense: true,
                    title: Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      row.client,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Text(
                      formatAmount(row.t.amount),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ListView skupin – ExpansionTile v [premiumCardShell] pro každou BillingGroup (klienta).
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
    this.tenantId,
    this.onShortfallResolved,
    this.accountantHeader,
  });

  final List<BillingGroup> groups;
  final String Function(num) formatAmount;
  final DateTime selectedMonth;
  final String currency;
  final String externalDisplayName;
  final void Function(BillingGroup group) onClientExportExcel;
  final void Function(BillingGroup group) onClientExportPdf;
  final void Function(String taskId)? onTaskTap;
  final String? tenantId;
  final VoidCallback? onShortfallResolved;

  /// Volitelný blok „souhrn + rozpad“ pro účetní – vložen jako první sliver nad kartami klientů.
  final Widget? accountantHeader;

  @override
  Widget build(BuildContext context) {
    // PROČ: CustomScrollView spojí horní souhrnné karty s listem skupin do jednoho scrollu,
    // aby účetní nemusel řešit vnořené scroll view a pořadí zůstalo: měsíční agregace → klienti.
    return CustomScrollView(
      slivers: [
        if (accountantHeader != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, AppSpacing.sm),
            sliver: SliverToBoxAdapter(child: accountantHeader!),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final group = groups[index];
              return _buildGroupCard(context, group);
            }, childCount: groups.length),
          ),
        ),
      ],
    );
  }

  /// Jedna karta klienta – dříve přímo v itemBuilder; vyčleněno kvůli CustomScrollView.
  Widget _buildGroupCard(BuildContext context, BillingGroup group) {
    final displayName = group.groupKey == 'external'
        ? externalDisplayName
        : (group.groupName.trim().isEmpty
              ? 'common.unknown'.tr()
              : group.groupName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: premiumCardShell(
        context,
        child: ExpansionTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (group.hasUnresolvedShortfalls) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'admin.finance.has_unresolved_shortfalls'.tr(),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: context.colors.error,
                    size: AppSpacing.md + AppSpacing.xs,
                  ),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  formatAmount(group.finalToInvoice),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.download,
                  size: AppSpacing.md + AppSpacing.xs,
                  color: context.colors.onSurfaceVariant,
                ),
                padding: const EdgeInsets.all(AppSpacing.xs),
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
                    child: Text(
                      'admin.finance.billing_export_client_excel'.tr(),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Text('admin.finance.billing_export_client_pdf'.tr()),
                  ),
                ],
              ),
            ],
          ),
          // PROČ: ExpansionTile skládá děti do Column bez vlastního scrollu. Při více
          // pobytech (bloky podle reservationId) přesáhne obsah výšku karty / viewportu
          // v TabBarView → spodní bloky se oříznou (na webu často bez žlutého overflow).
          // PDF z téhož BillingGroup vykreslí vše na stránky. Omezíme výšku a scrollujeme.
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final maxH = MediaQuery.sizeOf(context).height * 0.58;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    maxHeight: maxH,
                  ),
                  child: SingleChildScrollView(
                    primary: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: _buildGroupChildren(
                        context,
                        group,
                        onTaskTap,
                        tenantId: tenantId,
                        onShortfallResolved: onShortfallResolved,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Sestaví hierarchii: bloky rezervací, pak samostatné úkoly, nakonec souhrn.
  List<Widget> _buildGroupChildren(
    BuildContext context,
    BillingGroup group,
    void Function(String taskId)? onTaskTap, {
    String? tenantId,
    VoidCallback? onShortfallResolved,
  }) {
    String formatDate(d) => DateFormat.yMd(context.locale.toString()).format(d);
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

    // Měsíční paušál za správu – zobrazen nad sekcí úkolů, pokud je > 0
    if (group.monthlyManagementFee > 0) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'admin.finance.billing_monthly_management_fee'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                formatAmount(group.monthlyManagementFee),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
      children.add(const Divider(height: 16));
    }

    // A) Bloky pro rezervace
    final resIds = tasksWithRes.keys.toList()..sort();
    final dateFormatShort = DateFormat('dd.MM.yyyy', context.locale.toString());
    for (final resId in resIds) {
      final tasks = tasksWithRes[resId]!;
      final first = tasks.first;
      final guestName = first.guestName;
      final shortId = resId.length > 8 ? resId.substring(0, 8) : resId;
      final baseTitle = guestName != null && guestName.isNotEmpty
          ? 'admin.finance.billing_host_label'.tr(
              namedArgs: {'name': guestName},
            )
          : 'admin.finance.billing_reservation_label'.tr(
              namedArgs: {'id': shortId},
            );
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
                color: context.colors.onSurfaceVariant,
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
            groupKey: group.groupKey,
            tenantId: tenantId,
            onShortfallResolved: onShortfallResolved,
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
                color: context.colors.onSurfaceVariant,
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
            groupKey: group.groupKey,
            tenantId: tenantId,
            onShortfallResolved: onShortfallResolved,
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
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
      for (final exp in group.expenses) {
        children.add(
          ListTile(
            leading: Icon(
              Icons.receipt,
              color: context.colors.onSurfaceVariant,
              size: 24,
            ),
            title: Text(
              exp.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              formatDate(exp.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatAmount(exp.amount),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (exp.mediaUrls.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.photo_camera,
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    // Cb) Nedoplatky převedené na majitele – řádky z „Vyřešit nedoplatek“ → Přenést na majitele
    if (group.shortfallTransfers.isNotEmpty) {
      children.add(const Divider(height: 24));
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'admin.finance.billing_shortfall_transfers_section'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
      for (final st in group.shortfallTransfers) {
        children.add(
          ListTile(
            leading: Icon(
              Icons.warning_amber_rounded,
              color: context.customColors.warning,
              size: AppSpacing.lg,
            ),
            title: Text(
              st.description?.trim().isNotEmpty == true
                  ? st.description!
                  : 'admin.finance.billing_shortfall_transfers_section'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            trailing: Text(
              formatAmount(st.amount),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
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
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
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
                valueColor: context.colors.error,
              ),
            if (group.totalExpenses > 0)
              _SummaryRow(
                label: 'admin.finance.billing_expenses_to_reimburse'.tr(),
                value: '+${formatAmount(group.totalExpenses)}',
              ),
            if (group.monthlyManagementFee > 0)
              _SummaryRow(
                label: 'admin.finance.billing_monthly_management_fee'.tr(),
                value: '+${formatAmount(group.monthlyManagementFee)}',
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
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: larger
                ? tt.titleMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w600 : null,
                  )
                : tt.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w600 : null,
                  ),
          ),
          Text(
            value,
            style: larger
                ? tt.titleLarge?.copyWith(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: valueColor,
                  )
                : tt.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: valueColor,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Pro úkol s plátcem host a vyřešeným nedoplatkem zobrazí rozpis: Cena / Host zaplatil / Doplatek.
/// Jinak vrátí jen jednu částku (chargedPrice).
Widget _buildTaskPriceTrailing(
  BuildContext context,
  BillingTaskItem task,
  String Function(num) formatAmount,
) {
  final isGuestWithResolvedShortfall =
      task.payerType == 'guest' &&
      task.isShortfallResolved &&
      task.cashShortfallMissingAmount != null &&
      task.cashShortfallMissingAmount! > 0;
  if (!isGuestWithResolvedShortfall) {
    return Text(
      formatAmount(task.chargedPrice),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
    );
  }
  final paid = task.chargedPrice - task.cashShortfallMissingAmount!;
  final due = task.cashShortfallMissingAmount!;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        '${'admin.finance.billing_task_price_label'.tr()}: ${formatAmount(task.chargedPrice)}',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 2),
      Text(
        '${'admin.finance.billing_task_guest_paid_label'.tr()}: ${formatAmount(paid)} → ${'admin.finance.billing_task_shortfall_due_label'.tr()}: ${formatAmount(due)}',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    ],
  );
}

/// Jedna položka úkolu v detailu skupiny – title, datum, štítek plátce (Payer), cena, ikona fotodokumentace.
/// Zobrazuje nedoplatek z peněženky (červeně/zeleně) a tlačítko „Vyřešit nedoplatek“.
class _BillingTaskTile extends StatelessWidget {
  const _BillingTaskTile({
    required this.task,
    required this.formatAmount,
    required this.formatDate,
    this.onTaskTap,
    this.groupKey,
    this.tenantId,
    this.onShortfallResolved,
  });

  final BillingTaskItem task;
  final String Function(num) formatAmount;
  final String Function(DateTime) formatDate;
  final void Function(String taskId)? onTaskTap;
  final String? groupKey;
  final String? tenantId;
  final VoidCallback? onShortfallResolved;

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
        : 'common.placeholder_dash'.tr();
    final done = task.completedAt != null
        ? fmt.format(task.completedAt!)
        : 'common.placeholder_dash'.tr();
    return 'admin.finance.billing_times_line'.tr(
      namedArgs: {'plan': plan, 'done': done},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnerOrClient =
        task.payerType == 'owner' || task.payerType == 'client';
    final hasShortfall =
        task.cashShortfallTransactionId != null &&
        task.cashShortfallMissingAmount != null &&
        task.cashShortfallMissingAmount! > 0;
    final shortfallStatus = task.isShortfallResolved
        ? 'admin.finance.billing_shortfall_status_resolved'.tr()
        : 'admin.finance.billing_shortfall_status_pending'.tr();
    final shortfallStatusColor = task.isShortfallResolved
        ? context.customColors.success
        : context.colors.error;

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
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              if (task.completedAt != null) const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOwnerOrClient
                      ? context.colors.tertiaryContainer
                      : context.colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                ),
                child: Text(
                  _payerLabel(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isOwnerOrClient
                        ? context.colors.onTertiaryContainer
                        : context.colors.onPrimaryContainer,
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
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: context.colors.onSurfaceVariant,
                ),
                Text(
                  _formatTimesLine(context),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (hasShortfall) ...[
            const SizedBox(height: 6),
            Text(
              'admin.finance.billing_shortfall_missing'.tr(
                namedArgs: {
                  'amount': task.cashShortfallMissingAmount!.toStringAsFixed(2),
                  'status': shortfallStatus,
                },
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: shortfallStatusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (task.cashShortfallNote != null &&
                task.cashShortfallNote!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                task.cashShortfallNote!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: context.colors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (!task.isShortfallResolved &&
                tenantId != null &&
                tenantId!.isNotEmpty &&
                onShortfallResolved != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _showShortfallResolveDialog(
                  context,
                  task: task,
                  groupKey: groupKey,
                  tenantId: tenantId!,
                  formatAmount: formatAmount,
                  onResolved: onShortfallResolved!,
                ),
                icon: Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text('admin.finance.billing_shortfall_resolve_btn'.tr()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTaskPriceTrailing(context, task, formatAmount),
          if (task.mediaUrls.isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.photo_camera,
              size: 18,
              color: context.colors.onSurfaceVariant,
            ),
          ],
          if (onTaskTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.edit_outlined,
              size: 18,
              color: context.colors.onSurfaceVariant,
            ),
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

/// Otevře dialog výběru způsobu vyřešení nedoplatku a po provedení invaliduje data.
void _showShortfallResolveDialog(
  BuildContext context, {
  required BillingTaskItem task,
  required String tenantId,
  required String Function(num) formatAmount,
  required VoidCallback onResolved,
  String? groupKey,
}) {
  final missing = task.cashShortfallMissingAmount ?? 0.0;
  final txId = task.cashShortfallTransactionId ?? '';
  if (txId.isEmpty) return;

  final canTransferToOwner =
      groupKey != null && groupKey.isNotEmpty && groupKey != 'external';

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('admin.finance.billing_shortfall_dialog_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'admin.finance.billing_shortfall_missing'.tr(
                namedArgs: {
                  'amount': missing.toStringAsFixed(2),
                  'status': 'admin.finance.billing_shortfall_status_pending'
                      .tr(),
                },
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (canTransferToOwner)
              ListTile(
                leading: const Icon(Icons.business_center_outlined),
                title: Text(
                  'admin.finance.billing_shortfall_option_transfer'.tr(
                    namedArgs: {'amount': missing.toStringAsFixed(2)},
                  ),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await resolveBillingShortfall(
                      tenantId: tenantId,
                      cashTransactionId: txId,
                      resolutionType: 'transfer_to_owner',
                      transferClientId: groupKey,
                      transferAmount: missing,
                      transferDescription:
                          'admin.finance.billing_shortfall_transfer_description'
                              .tr(),
                      taskId: task.taskId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'admin.finance.billing_shortfall_success'.tr(),
                          ),
                        ),
                      );
                      onResolved();
                    }
                  } catch (e) {
                    // PROČ: Technické detaily výjimky neukazujeme uživateli – pouze debug log.
                    if (kDebugMode) debugPrint('billing_shortfall: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'common.generic_error_user_friendly'.tr(),
                          ),
                          backgroundColor: context.colors.error,
                        ),
                      );
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.trending_down),
              title: Text(
                'admin.finance.billing_shortfall_option_writeoff'.tr(),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await resolveBillingShortfall(
                    tenantId: tenantId,
                    cashTransactionId: txId,
                    resolutionType: 'write_off',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'admin.finance.billing_shortfall_success'.tr(),
                        ),
                      ),
                    );
                    onResolved();
                  }
                } catch (e) {
                  if (kDebugMode) debugPrint('billing_shortfall write_off: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'common.generic_error_user_friendly'.tr(),
                        ),
                        backgroundColor: context.colors.error,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_outlined),
              title: Text('admin.finance.billing_shortfall_option_other'.tr()),
              onTap: () {
                Navigator.of(ctx).pop();
                _showShortfallOtherNoteDialog(
                  context: context,
                  tenantId: tenantId,
                  txId: txId,
                  onResolved: onResolved,
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('common.cancel'.tr()),
        ),
      ],
    ),
  );
}

/// Dialog pro „Jinak (Poznámka)“ – textové pole a uložení s resolutionType = other.
void _showShortfallOtherNoteDialog({
  required BuildContext context,
  required String tenantId,
  required String txId,
  required VoidCallback onResolved,
}) {
  final noteController = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('admin.finance.billing_shortfall_option_other'.tr()),
      content: TextField(
        controller: noteController,
        decoration: InputDecoration(
          labelText: 'admin.finance.billing_shortfall_note_hint'.tr(),
          border: const OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () async {
            final note = noteController.text.trim();
            Navigator.of(ctx).pop();
            try {
              await resolveBillingShortfall(
                tenantId: tenantId,
                cashTransactionId: txId,
                resolutionType: 'other',
                resolutionNote: note.isNotEmpty ? note : null,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'admin.finance.billing_shortfall_success'.tr(),
                    ),
                  ),
                );
                onResolved();
              }
            } catch (e) {
              if (kDebugMode) debugPrint('billing_shortfall other: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('common.generic_error_user_friendly'.tr()),
                    backgroundColor: context.colors.error,
                  ),
                );
              }
            }
          },
          child: Text('common.save'.tr()),
        ),
      ],
    ),
  );
}
