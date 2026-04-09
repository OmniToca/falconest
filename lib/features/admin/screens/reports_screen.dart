// ARCHITEKTURA: Prémiový modul pro analytiku a grafy (výkonnost, ziskovost).
// Záměrně odděleno od Nástěnky pro zachování výkonu.
// Fáze 3: Dashboard s KPI kartami, grafy apartmánů a výkonností personálu.
//
// PROČ jména bytů/personálu v [ReportsSummary]: grafy a personál nesmí ref.watch(team/apartments),
// jinak by se při úpravě CRM přestavovaly BarChart animace bez změny reportového měsíce.

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/widgets/app_empty_state.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/providers/reports_provider.dart';

/// Prémiový dashboard Reporty – KPI karty, graf ziskovosti bytů, výkonnost personálu.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('admin.menu_reports'.tr())),
      body: ref
          .watch(reportsDataProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) {
              debugPrint('Reports load error: $err');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: AppSpacing.xxl,
                        color: context.colors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'admin.reports_load_error'.tr(),
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
            data: (summary) =>
                _ReportsDashboardContent(summary: summary, ref: ref),
          ),
    );
  }
}

/// Hlavní obsah dashboardu – měsíc, KPI, grafy. [ref] jen pro měnu a měsíční picker.
class _ReportsDashboardContent extends ConsumerWidget {
  const _ReportsDashboardContent({required this.summary, required this.ref});

  final ReportsSummary summary;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final totalTasks = summary.employeePerformances.fold<int>(
      0,
      (s, e) => s + e.taskCount,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthPicker(ref: ref),
          const SizedBox(height: AppSpacing.lg),
          _KpiSection(
            totalRevenue: summary.totalMonthRevenue,
            totalTasks: totalTasks,
            ref: ref,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ClientRevenueChart(clientRevenues: summary.clientRevenues, ref: ref),
          const SizedBox(height: AppSpacing.lg),
          _ApartmentRevenueChart(
            apartmentRevenues: summary.apartmentRevenues,
            ref: ref,
          ),
          const SizedBox(height: AppSpacing.lg),
          _StaffPerformanceSection(
            employeePerformances: summary.employeePerformances,
          ),
        ],
      ),
    );
  }
}

/// Interaktivní výběr měsíce – šipky vlevo/vpravo mění [reportsMonthProvider].
class _MonthPicker extends ConsumerWidget {
  const _MonthPicker({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final selected = ref.watch(reportsMonthProvider);
    final monthYear = 'admin.reports_month_format'.tr(
      namedArgs: {'month': '${selected.month}', 'year': '${selected.year}'},
    );

    return premiumCardShell(
      context,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final prev = DateTime(selected.year, selected.month - 1);
                ref.read(reportsMonthProvider.notifier).state = prev;
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                monthYear,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final now = DateTime.now();
                final next = DateTime(selected.year, selected.month + 1);
                if (next.year < now.year ||
                    (next.year == now.year && next.month <= now.month)) {
                  ref.read(reportsMonthProvider.notifier).state = next;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// KPI karty: Celkový obrat a Celkem úkolů. Částka přes [formatTaskAmount].
class _KpiSection extends ConsumerWidget {
  const _KpiSection({
    required this.totalRevenue,
    required this.totalTasks,
    required this.ref,
  });

  final double totalRevenue;
  final int totalTasks;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: isWide
                  ? (constraints.maxWidth - AppSpacing.md) / 2
                  : constraints.maxWidth,
              child: premiumCardShell(
                context,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'admin.reports_total_revenue'.tr(),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        formatTaskAmount(context, ref, totalRevenue),
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.customColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: isWide
                  ? (constraints.maxWidth - AppSpacing.md) / 2
                  : constraints.maxWidth,
              child: premiumCardShell(
                context,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'admin.reports_total_tasks'.tr(),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        totalTasks.toString(),
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// BarChart ziskovosti klientů (CRM).
/// Zobrazuje tržby podle klienta – majitele (z apartment_owners) nebo externího (task.client_id).
/// Klíče 'external' a 'unknown' se překládají přes i18n.
class _ClientRevenueChart extends ConsumerWidget {
  const _ClientRevenueChart({required this.clientRevenues, required this.ref});

  final List<ClientRevenue> clientRevenues;
  final WidgetRef ref;

  String _displayName(ClientRevenue rev) {
    if (rev.clientId == 'external') {
      return 'admin.reports_external_services'.tr();
    }
    if (rev.clientId == 'unknown') {
      return 'admin.reports_unknown_client'.tr();
    }
    return rev.clientName.isNotEmpty ? rev.clientName : rev.clientId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (clientRevenues.isEmpty) {
      return premiumCardShell(
        context,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'admin.reports_no_data'.tr(),
          ),
        ),
      );
    }

    final maxRevenue = clientRevenues
        .map((a) => a.totalRevenue)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final displayList = clientRevenues.length > 10
        ? clientRevenues.sublist(0, 10)
        : clientRevenues;

    final barGroups = displayList.asMap().entries.map((e) {
      final i = e.key;
      final rev = e.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: maxRevenue > 0 ? rev.totalRevenue : 0,
            color: context.colors.tertiary,
            width: AppSpacing.lg,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.xs),
            ),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();

    return premiumCardShell(
      context,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin.reports_client_profitability'.tr(),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: AppSpacing.lg * 9 + AppSpacing.sm,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 1,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final rev = displayList[group.x.toInt()];
                        final name = _displayName(rev);
                        return BarTooltipItem(
                          '$name\n${formatTaskAmount(context, ref, rev.totalRevenue)}',
                          TextStyle(
                            color: context.colors.onTertiary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < displayList.length) {
                            final rev = displayList[value.toInt()];
                            final name = _displayName(rev);
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Text(
                                name.length > 12
                                    ? '${name.substring(0, 12)}…'
                                    : name,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 32,
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.colors.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
                duration: const Duration(milliseconds: 300),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// BarChart ziskovosti apartmánů. Názvy dodává [reportsDataProvider] ([ApartmentRevenue.displayName]).
class _ApartmentRevenueChart extends StatelessWidget {
  const _ApartmentRevenueChart({
    required this.apartmentRevenues,
    required this.ref,
  });

  final List<ApartmentRevenue> apartmentRevenues;
  final WidgetRef ref;

  String _axisLabel(BuildContext context, ApartmentRevenue rev) {
    if (rev.apartmentId == 'external') {
      return 'admin.reports_external_services'.tr();
    }
    final name = rev.displayName;
    return name.length > 12 ? '${name.substring(0, 12)}…' : name;
  }

  String _tooltipLabel(BuildContext context, ApartmentRevenue rev) {
    if (rev.apartmentId == 'external') {
      return 'admin.reports_external_services'.tr();
    }
    return rev.displayName;
  }

  @override
  Widget build(BuildContext context) {
    if (apartmentRevenues.isEmpty) {
      return premiumCardShell(
        context,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'admin.reports_no_data'.tr(),
          ),
        ),
      );
    }

    final maxRevenue = apartmentRevenues
        .map((a) => a.totalRevenue)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final displayList = apartmentRevenues.length > 10
        ? apartmentRevenues.sublist(0, 10)
        : apartmentRevenues;

    final barGroups = displayList.asMap().entries.map((e) {
      final i = e.key;
      final rev = e.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: maxRevenue > 0 ? rev.totalRevenue : 0,
            color: context.colors.primary,
            width: AppSpacing.lg,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.xs),
            ),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();

    return premiumCardShell(
      context,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin.reports_apartment_profitability'.tr(),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: AppSpacing.lg * 9 + AppSpacing.sm,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 1,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final rev = displayList[group.x.toInt()];
                        final name = _tooltipLabel(context, rev);
                        return BarTooltipItem(
                          '$name\n${formatTaskAmount(context, ref, rev.totalRevenue)}',
                          TextStyle(
                            color: context.colors.onPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < displayList.length) {
                            final rev = displayList[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Text(
                                _axisLabel(context, rev),
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 32,
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.colors.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
                duration: const Duration(milliseconds: 300),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seznam výkonnosti personálu – jména z [EmployeePerformance.memberDisplayName] (snapshot z reportu).
class _StaffPerformanceSection extends StatelessWidget {
  const _StaffPerformanceSection({required this.employeePerformances});

  final List<EmployeePerformance> employeePerformances;

  String _rowLabel(BuildContext context, EmployeePerformance e) {
    if (e.assigneeId.isEmpty) {
      return 'admin.reports_unassigned'.tr();
    }
    final n = e.memberDisplayName;
    if (n != null && n.isNotEmpty) return n;
    return 'common.removed_user'.tr();
  }

  @override
  Widget build(BuildContext context) {
    if (employeePerformances.isEmpty) {
      return premiumCardShell(
        context,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.groups_outlined,
            title: 'admin.reports_no_data'.tr(),
          ),
        ),
      );
    }

    return premiumCardShell(
      context,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin.reports_staff_performance'.tr(),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...employeePerformances.map((e) {
              final name = _rowLabel(context, e);
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.sm + AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        name,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: context.colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '${e.taskCount}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${e.hoursWorked.toStringAsFixed(1)} ${'admin.reports_hours_short'.tr()}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
