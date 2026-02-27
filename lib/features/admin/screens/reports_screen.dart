// ARCHITEKTURA: Prémiový modul pro analytiku a grafy (výkonnost, ziskovost).
// Záměrně odděleno od Nástěnky pro zachování výkonu.
// Fáze 3: Dashboard s KPI kartami, grafy apartmánů a výkonností personálu.

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/reports_provider.dart';

/// Prémiový dashboard Reporty – KPI karty, graf ziskovosti bytů, výkonnost personálu.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('admin.menu_reports'.tr()),
      ),
      body: ref.watch(reportsDataProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
            data: (summary) => _ReportsDashboardContent(
              summary: summary,
              ref: ref,
            ),
          ),
    );
  }
}

/// Hlavní obsah dashboardu – měsíc, KPI, grafy. Přijímá [ref] pro formatTaskAmount a mapování ID.
class _ReportsDashboardContent extends ConsumerWidget {
  const _ReportsDashboardContent({
    required this.summary,
    required this.ref,
  });

  final ReportsSummary summary;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final totalTasks =
        summary.employeePerformances.fold<int>(0, (s, e) => s + e.taskCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthPicker(ref: ref),
          const SizedBox(height: 24),
          _KpiSection(
            totalRevenue: summary.totalMonthRevenue,
            totalTasks: totalTasks,
            ref: ref,
          ),
          const SizedBox(height: 24),
          _ApartmentRevenueChart(
            apartmentRevenues: summary.apartmentRevenues,
            ref: ref,
          ),
          const SizedBox(height: 24),
          _StaffPerformanceSection(
            employeePerformances: summary.employeePerformances,
            ref: ref,
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
      namedArgs: {
        'month': '${selected.month}',
        'year': '${selected.year}',
      },
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = DateTime(selected.year, selected.month - 1);
              ref.read(reportsMonthProvider.notifier).state = prev;
            },
          ),
          const SizedBox(width: 8),
          Text(
            monthYear,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
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
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
              child: AppCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.green.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.reports_total_revenue'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatTaskAmount(context, ref, totalRevenue),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
              child: AppCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.blue.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.reports_total_tasks'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      totalTasks.toString(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// BarChart ziskovosti apartmánů.
/// Překlad ID na název: [apartmentsProvider] dává Map id->name; fallback = zkrácené UUID.
/// Responsivita: výška 220px; při >10 bytech zobrazíme jen top 10 (největší tržby).
class _ApartmentRevenueChart extends ConsumerWidget {
  const _ApartmentRevenueChart({
    required this.apartmentRevenues,
    required this.ref,
  });

  final List<ApartmentRevenue> apartmentRevenues;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartments = ref.watch(apartmentsProvider).valueOrNull ?? [];
    final apartmentById = {for (final a in apartments) a.id: a.name};

    if (apartmentRevenues.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'admin.reports_no_data'.tr(),
            style: TextStyle(color: Colors.grey.shade600),
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
            color: Colors.blue.shade600,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.reports_apartment_profitability'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 1,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final rev = displayList[group.x.toInt()];
                      final name =
                          apartmentById[rev.apartmentId] ?? rev.apartmentId;
                      return BarTooltipItem(
                        '$name\n${formatTaskAmount(context, ref, rev.totalRevenue)}',
                        TextStyle(
                          color: Colors.white,
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
                          final name = apartmentById[rev.apartmentId] ??
                              rev.apartmentId.substring(0, 8);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              name.length > 12 ? '${name.substring(0, 12)}…' : name,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
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
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
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
                    color: Colors.grey.shade200,
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
    );
  }
}

/// Seznam výkonnosti personálu – jméno, počet úkolů, odpracované hodiny.
/// Překlad ID na jméno: [adminTeamProvider] mapuje profile.id->name; assigneeId="" → "Nepřiřazeno".
class _StaffPerformanceSection extends ConsumerWidget {
  const _StaffPerformanceSection({
    required this.employeePerformances,
    required this.ref,
  });

  final List<EmployeePerformance> employeePerformances;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(adminTeamProvider).valueOrNull ?? [];
    final nameByAssigneeId = <String, String>{};
    for (final m in team) {
      final id = m.profileId ?? m.id;
      if (id.isNotEmpty) nameByAssigneeId[id] = m.name;
    }

    if (employeePerformances.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'admin.reports_no_data'.tr(),
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.reports_staff_performance'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
          ),
          const SizedBox(height: 16),
          ...employeePerformances.map((e) {
            final name = e.assigneeId.isEmpty
                ? 'admin.reports_unassigned'.tr()
                : (nameByAssigneeId[e.assigneeId] ?? e.assigneeId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${e.taskCount}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.hoursWorked.toStringAsFixed(1)} ${'admin.reports_hours_short'.tr()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
