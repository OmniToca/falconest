import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/owner/providers/owner_cost_breakdown_provider.dart';
import 'package:falconest/features/owner/widgets/owner_portal_ui.dart';

/// Prémiový donut graf rozpadu nákladů majitele (nástěnka portálu).
///
/// PROČ: Data z [ownerCostBreakdownProvider] – poslední uzamčené vyúčtování + nevyúčtované výdaje;
/// vizuál sjednocený s [ownerPortalSectionDecoration].
class OwnerCostBreakdownDashboardCard extends ConsumerWidget {
  const OwnerCostBreakdownDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerCostBreakdownProvider);
    final currency = ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';

    return async.when(
      data: (data) => OwnerCostBreakdownChartContent(data: data, currency: currency),
      loading: () => _OwnerCostBreakdownLoadingShell(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Obsah karty (lze testovat s mock daty).
class OwnerCostBreakdownChartContent extends StatelessWidget {
  const OwnerCostBreakdownChartContent({
    super.key,
    required this.data,
    required this.currency,
  });

  final OwnerCostBreakdownData data;
  final String currency;

  static const double _chartSize = 200;
  static const double _centerHole = 52;

  String _bucketLabel(OwnerCostBucketType b) {
    switch (b) {
      case OwnerCostBucketType.cleaning:
        return 'owner.stats.cost_cat_cleaning'.tr();
      case OwnerCostBucketType.maintenance:
        return 'owner.stats.cost_cat_maintenance'.tr();
      case OwnerCostBucketType.management:
        return 'owner.stats.cost_cat_management'.tr();
      case OwnerCostBucketType.otherServices:
        return 'owner.stats.cost_cat_other_services'.tr();
      case OwnerCostBucketType.pendingUninvoiced:
        return 'owner.stats.cost_cat_pending'.tr();
    }
  }

  Color _bucketColor(BuildContext context, OwnerCostBucketType b) {
    final cs = Theme.of(context).colorScheme;
    switch (b) {
      case OwnerCostBucketType.cleaning:
        return cs.primary;
      case OwnerCostBucketType.maintenance:
        return cs.tertiary;
      case OwnerCostBucketType.management:
        return cs.secondary;
      case OwnerCostBucketType.otherServices:
        return cs.primaryContainer;
      case OwnerCostBucketType.pendingUninvoiced:
        return cs.errorContainer;
    }
  }

  String _formatMoney(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (data.total <= 0 || data.slices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: ownerPortalSectionDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'owner.stats.cost_chart_title'.tr(),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'owner.stats.cost_chart_subtitle'.tr(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            _OwnerCostEmptyIllustration(),
          ],
        ),
      );
    }

    final sorted = [...data.slices]..sort((a, b) => b.amount.compareTo(a.amount));
    final sections = <PieChartSectionData>[];
    for (final sl in sorted) {
      sections.add(
        PieChartSectionData(
          value: sl.amount,
          color: _bucketColor(context, sl.bucket),
          radius: 28,
          title: '',
        ),
      );
    }

    final periodText = data.referenceMonth != null
        ? 'owner.stats.cost_period_locked'.tr(namedArgs: {
            'month': DateFormat.yMMMM(
              context.locale.toString(),
            ).format(data.referenceMonth!.toLocal()),
          })
        : 'owner.stats.cost_period_pending_only'.tr();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ownerPortalSectionDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'owner.stats.cost_chart_title'.tr(),
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'owner.stats.cost_chart_subtitle'.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            periodText,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _chartSize,
                height: _chartSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: _centerHole,
                        sections: sections,
                        pieTouchData: PieTouchData(
                          enabled: true,
                          touchCallback: (_, _) {},
                        ),
                      ),
                      duration: const Duration(milliseconds: 350),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'owner.stats.cost_center_total'.tr(),
                          textAlign: TextAlign.center,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatMoney(data.total)} $currency',
                          textAlign: TextAlign.center,
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sorted.map((sl) {
                    final pct = data.total > 0 ? (sl.amount / data.total * 100) : 0.0;
                    final c = _bucketColor(context, sl.bucket);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _bucketLabel(sl.bucket),
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_formatMoney(sl.amount)} $currency · ${pct.toStringAsFixed(0)}%',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerCostBreakdownLoadingShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ownerPortalSectionDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'owner.stats.cost_chart_title'.tr(),
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

/// Prázdný stav – ilustrace + text (žádné výdaje k zobrazení).
class _OwnerCostEmptyIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.savings_outlined,
            size: 40,
            color: context.colors.primary.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'owner.stats.cost_empty_title'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'owner.stats.cost_empty_body'.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    height: 1.4,
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
