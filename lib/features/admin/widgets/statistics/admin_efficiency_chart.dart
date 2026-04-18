import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/admin_task_efficiency_stats.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';

/// Karta „Data Insights“ – průměrná délka úklidu (7 dní) vs. odhad a průměrné zpoždění Startu.
///
/// PROČ: Využívá stejná data jako nástěnka ([adminDashboardTasksProvider] → předaný seznam [TaskRow]),
/// mapuje DB sloupce `scheduled_start`, `started_at`, `completed_at` (v zadání označené jako plán / Start / Dokončit).
class AdminTaskEfficiencyInsightsCard extends StatelessWidget {
  const AdminTaskEfficiencyInsightsCard({super.key, required this.tasks});

  final List<TaskRow> tasks;

  static const double _chartHeight = 196;

  @override
  Widget build(BuildContext context) {
    final summary = computeAdminTaskEfficiencySummary(tasks);
    final empty = !summary.hasAnyDurationInChart && !summary.hasDelayData;

    if (empty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: premiumCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin.stats.efficiency_card_title'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _EfficiencyCompactEmpty(
              icon: Icons.bar_chart_outlined,
              title: 'admin.stats.efficiency_no_data'.tr(),
            ),
          ],
        ),
      );
    }

    final baselineY = summary.estimatedMinutesBaseline.toDouble();
    double maxVal = baselineY;
    for (final d in summary.days) {
      final a = d.averageActualMinutes;
      if (a != null && a > maxVal) maxVal = a;
    }
    final maxY = maxVal > 0 ? maxVal * 1.2 : 60.0;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < summary.days.length; i++) {
      final bucket = summary.days[i];
      final actual = bucket.averageActualMinutes ?? 0;
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 6,
          barRods: [
            BarChartRodData(
              toY: bucket.sampleCount == 0 ? 0 : actual,
              color: context.colors.primary,
              width: 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: baselineY,
              color: context.colors.onSurfaceVariant.withValues(alpha: 0.45),
              width: 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    final localeCode = context.locale.languageCode;
    String dayLabel(DateTime day) {
      try {
        return DateFormat.E(localeCode).format(day);
      } catch (_) {
        return '${day.day}.${day.month}.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: premiumCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.stats.efficiency_card_title'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'admin.stats.efficiency_chart_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LegendDot(
                color: context.colors.primary,
                label: 'admin.stats.efficiency_legend_actual'.tr(),
              ),
              _LegendDot(
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.45),
                label: 'admin.stats.efficiency_legend_estimate'.tr(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: _chartHeight,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 90 ? 30 : (maxY > 45 ? 15 : 10),
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: context.colors.outlineVariant.withValues(alpha: 0.35),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: maxY > 90 ? 30 : (maxY > 45 ? 15 : 10),
                      getTitlesWidget: (value, meta) {
                        if (value > maxY + 0.01) return const SizedBox.shrink();
                        return Text(
                          '${value.round()}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= summary.days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dayLabel(summary.days[i].dayLocalMidnight),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: groups,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.inverseSurface.withValues(alpha: 0.94),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final bucket = summary.days[group.x.toInt()];
                      final isActual = rodIndex == 0;
                      if (isActual) {
                        if (bucket.sampleCount == 0) {
                          return BarTooltipItem(
                            'admin.stats.efficiency_tooltip_no_samples'.tr(),
                            TextStyle(
                              color: Theme.of(context).colorScheme.onInverseSurface,
                              fontSize: 12,
                            ),
                          );
                        }
                        return BarTooltipItem(
                          'admin.stats.efficiency_tooltip_actual'.tr(namedArgs: {
                            'minutes': (bucket.averageActualMinutes ?? 0).round().toString(),
                            'count': bucket.sampleCount.toString(),
                          }),
                          TextStyle(
                            color: Theme.of(context).colorScheme.onInverseSurface,
                            fontSize: 12,
                          ),
                        );
                      }
                      return BarTooltipItem(
                        'admin.stats.efficiency_tooltip_estimate'.tr(namedArgs: {
                          'minutes': summary.estimatedMinutesBaseline.toString(),
                        }),
                        TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'admin.stats.efficiency_baseline_hint'.tr(namedArgs: {
              'minutes': summary.estimatedMinutesBaseline.toString(),
            }),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Text(
            'admin.stats.efficiency_avg_delay_label'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.hasDelayData
                ? 'admin.stats.efficiency_avg_delay_value'.tr(namedArgs: {
                      'minutes': summary.averageStartDelayMinutes!.round().toString(),
                    })
                : 'admin.stats.efficiency_avg_delay_no_data'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Kompaktní prázdný stav (stejný účel jako na nástěnce – bez závislosti na private widgetu z jiné knihovny).
class _EfficiencyCompactEmpty extends StatelessWidget {
  const _EfficiencyCompactEmpty({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.88),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
