import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/constants/apartment_rental_constants.dart';
import 'package:falconest/core/models/apartment_investment_metrics.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/owner/models/monthly_pnl_summary.dart';
import 'package:falconest/features/owner/providers/owner_apartment_detail_provider.dart';
import 'package:falconest/features/owner/providers/apartment_investment_metrics_provider.dart';
import 'package:falconest/features/owner/providers/apartment_investment_pnl_entries_provider.dart';
import 'package:falconest/features/owner/providers/owner_billing_provider.dart';
import 'package:falconest/features/owner/providers/owner_combined_pnl_provider.dart';
import 'package:falconest/features/owner/providers/owner_investment_roi_provider.dart';
import 'package:falconest/features/owner/repositories/owner_apartment_investment_metrics_repository.dart';
import 'package:falconest/features/owner/repositories/owner_apartment_pnl_repository.dart';
import 'package:falconest/features/owner/widgets/owner_portal_ui.dart';

/// Parsování částky z pole v majitelském portálu (čárka i tečka jako desetinný oddělovač).
double? ownerPortalParseAmount(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return 0;
  return double.tryParse(t);
}

MonthlyPnlSummary? _summaryForMonth(List<MonthlyPnlSummary> list, DateTime month) {
  final target = DateTime.utc(month.year, month.month, 1);
  for (final s in list) {
    final sm = DateTime.utc(s.month.year, s.month.month, 1);
    if (sm == target) return s;
  }
  return null;
}

double _monthIncome(List<MonthlyPnlSummary> list, DateTime month) =>
    _summaryForMonth(list, month)?.ownerIncome ?? 0;

double _monthExpense(List<MonthlyPnlSummary> list, DateTime month) =>
    _summaryForMonth(list, month)?.ownerExpense ?? 0;

double _monthAgency(List<MonthlyPnlSummary> list, DateTime month) =>
    _summaryForMonth(list, month)?.agencyCosts ?? 0;

String _formatAmountField(double v) {
  if (v == 0) return '';
  return v == v.roundToDouble() ? v.round().toString() : v.toString();
}

/// Přehled investičních čísel u bytu (vstupní náklady vs. odhad trhu) pro majitelský portál.
///
/// PROČ: Vizualně navazuje na gradientové karty z [OwnerDashboardScreen] (_OwnerAgencyCashCard);
/// data jdou z [apartmentInvestmentMetricsProvider], zápis přes upsert s RLS.
/// Po vykreslení invaliduje [ownerBillingSnapshotsProvider], aby se agenturní částky
/// dopočítaly z aktuálních uzamčených faktur (IndexedStack drží Fakturaci v paměti bez opakovaného fetch).
class OwnerInvestmentDashboard extends ConsumerStatefulWidget {
  const OwnerInvestmentDashboard({super.key, required this.apartmentId});

  final String apartmentId;

  static String _moneyLabel(BuildContext context, double value, String currencyCode) {
    final formatted = value.toStringAsFixed(2);
    return '$formatted $currencyCode';
  }

  static BoxDecoration _gradientCardDecoration(BuildContext context) {
    final c = context.colors;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(c.primaryContainer.withValues(alpha: 0.55), c.surface),
          Color.alphaBlend(c.tertiaryContainer.withValues(alpha: 0.35), c.surface),
        ],
      ),
      borderRadius: BorderRadius.circular(kOwnerPortalCardRadius),
      border: Border.all(color: c.outlineVariant.withValues(alpha: 0.45)),
    );
  }

  @override
  ConsumerState<OwnerInvestmentDashboard> createState() => _OwnerInvestmentDashboardState();
}

class _OwnerInvestmentDashboardState extends ConsumerState<OwnerInvestmentDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(ownerBillingSnapshotsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(apartmentInvestmentMetricsProvider(widget.apartmentId));
    final currencyAsync = ref.watch(currentTenantCurrencyProvider);
    final currency = currencyAsync.valueOrNull ?? 'EUR';

    return metricsAsync.when(
      data: (row) => _DashboardBody(
        apartmentId: widget.apartmentId,
        row: row,
        currencyCode: currency,
        gradientDecoration: OwnerInvestmentDashboard._gradientCardDecoration(context),
        moneyLabel: (v) => OwnerInvestmentDashboard._moneyLabel(context, v, currency),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(
        'common.generic_error_user_friendly'.tr(),
        style: context.textTheme.bodyMedium?.copyWith(color: context.colors.error),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.apartmentId,
    required this.row,
    required this.currencyCode,
    required this.gradientDecoration,
    required this.moneyLabel,
  });

  final String apartmentId;
  final ApartmentInvestmentMetrics? row;
  final String currencyCode;
  final BoxDecoration gradientDecoration;
  final String Function(double) moneyLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchase = row?.purchasePrice ?? 0;
    final renovation = row?.initialRenovationCost ?? 0;
    final market = row?.estimatedMarketPrice ?? 0;
    final updated = row?.marketPriceUpdatedAt;
    final combinedAsync = ref.watch(ownerCombinedPnlProvider(apartmentId));
    final detailAsync = ref.watch(ownerApartmentDetailProvider(apartmentId));
    final roiView = ref.watch(ownerInvestmentRoiProvider(apartmentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            final entryCard = _GradientMetricCard(
              decoration: gradientDecoration,
              icon: Icons.savings_outlined,
              title: 'owner.investment_card_entry_title'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _metricLine(
                    context,
                    'owner.investment_purchase_price'.tr(),
                    moneyLabel(purchase),
                  ),
                  const SizedBox(height: 10),
                  _metricLine(
                    context,
                    'owner.investment_renovation_cost'.tr(),
                    moneyLabel(renovation),
                  ),
                ],
              ),
            );
            final marketCard = _GradientMetricCard(
              decoration: gradientDecoration,
              icon: Icons.trending_up_rounded,
              title: 'owner.investment_card_market_title'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _metricLine(
                    context,
                    'owner.investment_estimated_value'.tr(),
                    moneyLabel(market),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    updated != null
                        ? 'owner.investment_market_updated'.tr(
                            namedArgs: {
                              'date': DateFormat.yMMMd(context.locale.toString()).format(updated.toLocal()),
                            },
                          )
                        : 'owner.investment_market_not_updated'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: entryCard),
                  const SizedBox(width: 12),
                  Expanded(child: marketCard),
                ],
              );
            }
            return Column(
              children: [
                entryCard,
                const SizedBox(height: 12),
                marketCard,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _OwnerInvestmentRoiCard(
          roiView: roiView,
          gradientDecoration: gradientDecoration,
          moneyLabel: moneyLabel,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            final saved = await showDialog<bool>(
              context: context,
              builder: (ctx) => _OwnerInvestmentEditDialog(
                apartmentId: apartmentId,
                initialPurchase: purchase,
                initialRenovation: renovation,
                initialMarket: market,
                currencyCode: currencyCode,
              ),
            );
            if (saved == true && context.mounted) {
              ref.invalidate(apartmentInvestmentMetricsProvider(apartmentId));
              ref.invalidate(ownerInvestmentRoiProvider(apartmentId));
            }
          },
          icon: const Icon(Icons.edit_outlined, size: 20),
          label: Text('owner.investment_edit_values'.tr()),
        ),
        const SizedBox(height: 24),
        Text(
          'owner.investment_monthly_balance_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        detailAsync.when(
          data: (detail) => combinedAsync.when(
            data: (summaries) => _OwnerMonthlyPnlBlock(
              apartmentId: apartmentId,
              currencyCode: currencyCode,
              summaries: summaries,
              moneyLabel: moneyLabel,
              rentalMode: detail?.rentalMode ?? kApartmentRentalModeShortTerm,
              rentCollectionMode: detail?.rentCollectionMode ?? kApartmentRentCollectionModeNotification,
              rentAmount: detail?.rentAmount ?? 0.0,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(
              'common.generic_error_user_friendly'.tr(),
              style: context.textTheme.bodySmall?.copyWith(color: context.colors.error),
            ),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(
            'common.generic_error_user_friendly'.tr(),
            style: context.textTheme.bodySmall?.copyWith(color: context.colors.error),
          ),
        ),
      ],
    );
  }

  static Widget _metricLine(BuildContext context, String label, String valueText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Karta „Celkový výnos investice“ – kombinace kapitálového zhodnocení a součtu měsíčních P&L.
class _OwnerInvestmentRoiCard extends StatelessWidget {
  const _OwnerInvestmentRoiCard({
    required this.roiView,
    required this.gradientDecoration,
    required this.moneyLabel,
  });

  final OwnerInvestmentRoiView roiView;
  final BoxDecoration gradientDecoration;
  final String Function(double) moneyLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: gradientDecoration,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: c.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'owner.investment_roi_total_title'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'owner.investment_roi_subtitle'.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: c.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (roiView.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (roiView.showDash || roiView.totalReturn == null)
            Text(
              '–',
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: c.onSurfaceVariant,
              ),
            )
          else
            Text(
              moneyLabel(roiView.totalReturn!),
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: c.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}

/// Měsíční bilance: formulář pro běžící měsíc, poznámka k agenturním nákladům, tabulka historie.
class _OwnerMonthlyPnlBlock extends ConsumerStatefulWidget {
  const _OwnerMonthlyPnlBlock({
    required this.apartmentId,
    required this.currencyCode,
    required this.summaries,
    required this.moneyLabel,
    required this.rentalMode,
    required this.rentCollectionMode,
    required this.rentAmount,
  });

  final String apartmentId;
  final String currencyCode;
  final List<MonthlyPnlSummary> summaries;
  final String Function(double) moneyLabel;
  /// Z [OwnerApartmentDetail] – řídí zobrazení ručního příjmu vs. dlouhodobý nájem.
  final String rentalMode;
  final String rentCollectionMode;
  final double rentAmount;

  @override
  ConsumerState<_OwnerMonthlyPnlBlock> createState() => _OwnerMonthlyPnlBlockState();
}

class _OwnerMonthlyPnlBlockState extends ConsumerState<_OwnerMonthlyPnlBlock> {
  late final TextEditingController _incomeCtrl;
  late final TextEditingController _expenseCtrl;
  bool _saving = false;
  bool _confirmingRent = false;

  bool get _isLongTerm => widget.rentalMode == kApartmentRentalModeLongTerm;

  @override
  void initState() {
    super.initState();
    final month = OwnerApartmentPnlRepository.firstDayOfMonthUtc(DateTime.now());
    final inc = _monthIncome(widget.summaries, month);
    final exp = _monthExpense(widget.summaries, month);
    _incomeCtrl = TextEditingController(text: _formatAmountField(inc));
    _expenseCtrl = TextEditingController(text: _formatAmountField(exp));
  }

  @override
  void didUpdateWidget(covariant _OwnerMonthlyPnlBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final month = OwnerApartmentPnlRepository.firstDayOfMonthUtc(DateTime.now());
    final inc = _monthIncome(widget.summaries, month);
    final exp = _monthExpense(widget.summaries, month);
    final oldInc = _monthIncome(oldWidget.summaries, month);
    final oldExp = _monthExpense(oldWidget.summaries, month);
    if (inc != oldInc || exp != oldExp) {
      if (!_isLongTerm) {
        _incomeCtrl.text = _formatAmountField(inc);
      }
      _expenseCtrl.text = _formatAmountField(exp);
    }
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _expenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmLongTermRentPayment() async {
    setState(() => _confirmingRent = true);
    try {
      final month = OwnerApartmentPnlRepository.firstDayOfMonthUtc(DateTime.now());
      await OwnerApartmentPnlRepository.upsertIncomeEntry(
        apartmentId: widget.apartmentId,
        entryMonthFirstDayUtc: month,
        amount: widget.rentAmount,
        description: OwnerApartmentPnlRepository.kDbDescriptionRentTransferConfirmed,
      );
      if (!mounted) return;
      ref.invalidate(apartmentInvestmentPnlEntriesProvider(widget.apartmentId));
      ref.invalidate(ownerCombinedPnlProvider(widget.apartmentId));
      ref.invalidate(ownerInvestmentRoiProvider(widget.apartmentId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.investment_long_term_rent_confirmed'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _confirmingRent = false);
    }
  }

  Future<void> _saveMonth() async {
    final expense = ownerPortalParseAmount(_expenseCtrl.text);
    if (expense == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.investment_invalid_number'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (expense < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.investment_negative_not_allowed'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    double income;
    if (_isLongTerm) {
      final month = OwnerApartmentPnlRepository.firstDayOfMonthUtc(DateTime.now());
      income = _monthIncome(widget.summaries, month);
    } else {
      final parsed = ownerPortalParseAmount(_incomeCtrl.text);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('owner.investment_invalid_number'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('owner.investment_negative_not_allowed'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      income = parsed;
    }

    setState(() => _saving = true);
    try {
      final month = OwnerApartmentPnlRepository.firstDayOfMonthUtc(DateTime.now());
      await OwnerApartmentPnlRepository.upsertMonthIncomeAndExpense(
        apartmentId: widget.apartmentId,
        entryMonthFirstDayUtc: month,
        incomeAmount: income,
        expenseAmount: expense,
      );
      if (!mounted) return;
      ref.invalidate(apartmentInvestmentPnlEntriesProvider(widget.apartmentId));
      ref.invalidate(ownerCombinedPnlProvider(widget.apartmentId));
      ref.invalidate(ownerInvestmentRoiProvider(widget.apartmentId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.investment_pnl_saved'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final currentMonthLabel = DateFormat.yMMMM(context.locale.toString()).format(now);
    final monthRow = OwnerApartmentPnlRepository.firstDayOfMonthUtc(now);
    final agencyCurrentMonth = _monthAgency(widget.summaries, monthRow);
    final pnlEntries = ref.watch(apartmentInvestmentPnlEntriesProvider(widget.apartmentId)).valueOrNull ?? [];
    final hasIncomeRowThisMonth = pnlEntries.any(
      (e) =>
          e.entryType == 'income' &&
          DateTime.utc(e.entryMonth.year, e.entryMonth.month, 1) ==
              DateTime.utc(monthRow.year, monthRow.month, 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: ownerPortalSectionDecoration(context),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'owner.investment_current_month_label'.tr(namedArgs: {'month': currentMonthLabel}),
                style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (!_isLongTerm) ...[
                TextField(
                  controller: _incomeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'owner.investment_pnl_field_income'.tr(),
                    hintText: 'owner.investment_pnl_hint_currency'.tr(
                      namedArgs: {'currency': widget.currencyCode},
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_isLongTerm && widget.rentCollectionMode == kApartmentRentCollectionModeNotification) ...[
                Text(
                  'owner.investment_long_term_expected_rent'.tr(
                    namedArgs: {'amount': widget.moneyLabel(widget.rentAmount)},
                  ),
                  style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                if (hasIncomeRowThisMonth)
                  Text(
                    'owner.investment_long_term_rent_paid'.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  FilledButton(
                    onPressed: _confirmingRent ? null : _confirmLongTermRentPayment,
                    child: _confirmingRent
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('owner.investment_long_term_confirm_transfer'.tr()),
                  ),
                const SizedBox(height: 12),
              ],
              if (_isLongTerm && widget.rentCollectionMode == kApartmentRentCollectionModeTask) ...[
                Text(
                  'owner.investment_long_term_cash_by_agency'.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(color: c.onSurfaceVariant, height: 1.35),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _expenseCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'owner.investment_pnl_field_expense'.tr(),
                  hintText: 'owner.investment_pnl_hint_currency'.tr(
                    namedArgs: {'currency': widget.currencyCode},
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _saveMonth,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('owner.investment_pnl_save_month'.tr()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'owner.investment_agency_costs_note'.tr(),
          style: context.textTheme.bodySmall?.copyWith(
            color: c.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'owner.investment_agency_costs_label'.tr(),
              style: context.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              widget.moneyLabel(agencyCurrentMonth),
              style: context.textTheme.bodySmall?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (widget.summaries.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'owner.investment_pnl_history_title'.tr(),
            style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              columns: [
                DataColumn(label: Text('owner.investment_pnl_col_month'.tr())),
                DataColumn(
                  label: Text('owner.investment_pnl_col_income'.tr()),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('owner.investment_pnl_col_own_expense'.tr()),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('owner.investment_pnl_col_agency'.tr()),
                  numeric: true,
                ),
              ],
              rows: [
                for (final s in widget.summaries)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          DateFormat.yMMM(context.locale.toString()).format(s.month),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(widget.moneyLabel(s.ownerIncome)),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(widget.moneyLabel(s.ownerExpense)),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(widget.moneyLabel(s.agencyCosts)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GradientMetricCard extends StatelessWidget {
  const _GradientMetricCard({
    required this.decoration,
    required this.icon,
    required this.title,
    required this.child,
  });

  final BoxDecoration decoration;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: c.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Jednoduchý dialog – tři částky, uložení přes upsert (INSERT/UPDATE dle RLS).
class _OwnerInvestmentEditDialog extends StatefulWidget {
  const _OwnerInvestmentEditDialog({
    required this.apartmentId,
    required this.initialPurchase,
    required this.initialRenovation,
    required this.initialMarket,
    required this.currencyCode,
  });

  final String apartmentId;
  final double initialPurchase;
  final double initialRenovation;
  final double initialMarket;
  final String currencyCode;

  @override
  State<_OwnerInvestmentEditDialog> createState() => _OwnerInvestmentEditDialogState();
}

class _OwnerInvestmentEditDialogState extends State<_OwnerInvestmentEditDialog> {
  late final TextEditingController _purchaseCtrl;
  late final TextEditingController _renovationCtrl;
  late final TextEditingController _marketCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _purchaseCtrl = TextEditingController(text: _formatInitial(widget.initialPurchase));
    _renovationCtrl = TextEditingController(text: _formatInitial(widget.initialRenovation));
    _marketCtrl = TextEditingController(text: _formatInitial(widget.initialMarket));
  }

  static String _formatInitial(double v) {
    if (v == 0) return '';
    return v == v.roundToDouble() ? v.round().toString() : v.toString();
  }

  @override
  void dispose() {
    _purchaseCtrl.dispose();
    _renovationCtrl.dispose();
    _marketCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = ownerPortalParseAmount(_purchaseCtrl.text);
    final r = ownerPortalParseAmount(_renovationCtrl.text);
    final m = ownerPortalParseAmount(_marketCtrl.text);
    if (p == null || r == null || m == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.investment_invalid_number'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (p < 0 || r < 0 || m < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.investment_negative_not_allowed'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await OwnerApartmentInvestmentMetricsRepository.upsertMetrics(
        apartmentId: widget.apartmentId,
        purchasePrice: p,
        initialRenovationCost: r,
        estimatedMarketPrice: m,
        marketPriceUpdatedAtUtc: DateTime.now().toUtc(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.investment_saved'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: Text('owner.investment_edit_dialog_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'owner.investment_edit_dialog_hint'.tr(
                namedArgs: {'currency': widget.currencyCode},
              ),
              style: context.textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _purchaseCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'owner.investment_purchase_price'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _renovationCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'owner.investment_renovation_cost'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _marketCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'owner.investment_estimated_value'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}
