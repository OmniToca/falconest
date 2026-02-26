import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartment_status_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/utils/task_visuals.dart';

/// Administrativní nástěnka – analytický SaaS Dashboard s grafy (fl_chart), KPI kartami a operativou.
///
/// Tři řádky: 1) KPI karty, 2) Grafy (LineChart rezervací + PieChart úkolů), 3) Operativa (timeline, fleet, tým).
/// Zachovává čtení z providerů a 95 % šířku obrazovky.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(adminTasksStreamProvider);
    final reservationsAsync = ref.watch(adminReservationsProvider);
    final apartmentsAsync = ref.watch(apartmentsProvider);
    final teamAsync = ref.watch(adminTeamProvider);
    final reservationsTrends = ref.watch(adminReservationsTrendsProvider);
    final tasksTrend = ref.watch(adminTasksTrendProvider);

    if (tasksAsync.isLoading ||
        reservationsAsync.isLoading ||
        apartmentsAsync.isLoading ||
        teamAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (tasksAsync.hasError ||
        reservationsAsync.hasError ||
        apartmentsAsync.hasError ||
        teamAsync.hasError) {
      final msg = tasksAsync.hasError
          ? tasksAsync.error.toString()
          : reservationsAsync.hasError
              ? reservationsAsync.error.toString()
              : apartmentsAsync.hasError
                  ? apartmentsAsync.error.toString()
                  : teamAsync.error.toString();
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                const SizedBox(height: 16),
                Text(
                  'admin.dashboard_loading_error'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(msg, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
    }

    final tasks = tasksAsync.valueOrNull ?? [];
    final reservations = reservationsAsync.valueOrNull ?? [];
    final apartments = apartmentsAsync.valueOrNull ?? [];
    final teamMembers = teamAsync.valueOrNull ?? [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = today.add(const Duration(days: 1));

    final todayCheckIns = reservations.where((r) => _isCheckInOnDay(r.checkIn, today)).length;
    final todayCheckOuts = reservations.where((r) => _isCheckOutOnDay(r.checkOut, today)).length;

    final todayTasks = tasks.where((t) {
      final d = t.dueDate;
      return !d.isBefore(today) && d.isBefore(todayEnd);
    }).toList();

    const pendingStatuses = {'Návrh', 'Zadáno', 'Probíhá'};
    final remainingTodayTasks = todayTasks
        .where((t) =>
            pendingStatuses.contains(t.status) ||
            (t.status != 'Hotovo' && (t.status).toLowerCase() != 'completed'))
        .length;
    final criticalCount = todayTasks
        .where((t) =>
            t.status == 'Návrh' ||
            t.assignedTo == null ||
            (t.assignedTo != null && t.assignedTo!.trim().isEmpty))
        .length;

    final todayAssignedIds = todayTasks
        .map((t) => t.assignedTo)
        .where((id) => id != null && id.trim().isNotEmpty)
        .map((id) => id!)
        .toSet()
        .toList();
    final teamMembersToday = teamMembers
        .where((m) =>
            (m.profileId != null && todayAssignedIds.contains(m.profileId)) ||
            todayAssignedIds.contains(m.id))
        .toList();

    int countOccupied = 0, countToClean = 0, countClean = 0;
    for (final apt in apartments) {
      final status = getApartmentStatusForToday(reservations, tasks, apt.id);
      if (status == apartmentStatusOccupied) {
        countOccupied++;
      } else if (status == apartmentStatusNeedsCleaning) {
        countToClean++;
      } else {
        countClean++;
      }
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = constraints.maxWidth * 0.025;
          final double availableWidth = constraints.maxWidth - (horizontalPadding * 2);
          final bool isWide = constraints.maxWidth > 900;
          final bool kpiWide = constraints.maxWidth > 600;
          final double kpiCardWidth =
              kpiWide ? (availableWidth - 48) / 4 : (availableWidth - 16) / 2;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Řádek 1: Vylepšené KPI karty (prémiový vzhled)
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: kpiCardWidth,
                      child: _KpiCard(
                        title: 'admin.dashboard_card_today_checkins'.tr(),
                        value: todayCheckIns.toString(),
                        icon: Icons.flight_land,
                        color: Colors.green.shade700,
                        bgColor: Colors.green.shade50,
                        trendPercentage: reservationsTrends.checkInsTrend,
                        trendLabel: 'admin.dashboard_trend_yesterday'.tr(),
                      ),
                    ),
                    SizedBox(
                      width: kpiCardWidth,
                      child: _KpiCard(
                        title: 'admin.dashboard_card_today_checkouts'.tr(),
                        value: todayCheckOuts.toString(),
                        icon: Icons.flight_takeoff,
                        color: Colors.orange.shade700,
                        bgColor: Colors.orange.shade50,
                        trendPercentage: reservationsTrends.checkOutsTrend,
                        trendLabel: 'admin.dashboard_trend_yesterday'.tr(),
                      ),
                    ),
                    SizedBox(
                      width: kpiCardWidth,
                      child: _KpiCard(
                        title: 'admin.dashboard_card_pending_tasks'.tr(),
                        value: remainingTodayTasks.toString(),
                        icon: Icons.assignment_late,
                        color: Colors.blue.shade700,
                        bgColor: Colors.blue.shade50,
                        trendPercentage: tasksTrend,
                        trendLabel: 'admin.dashboard_trend_yesterday'.tr(),
                      ),
                    ),
                    SizedBox(
                      width: kpiCardWidth,
                      child: _KpiCard(
                        title: 'admin.dashboard_card_critical'.tr(),
                        value: criticalCount.toString(),
                        icon: Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        bgColor: Colors.red.shade50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Řádek 2: Analytika (grafy) – WOW efekt
                SizedBox(
                  height: 300,
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _ReservationsLineChart(
                                reservations: reservations,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: _TasksDonutChart(todayTasks: todayTasks),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: _ReservationsLineChart(
                                reservations: reservations,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _TasksDonutChart(todayTasks: todayTasks),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                // Řádek 3: Operativa – tři sloupce kompaktně (stejná výška kart díky IntrinsicHeight)
                isWide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                          Expanded(
                            child: _DashboardPlanSection(todayTasks: todayTasks),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ApartmentFleetSection(
                              countClean: countClean,
                              countToClean: countToClean,
                              countOccupied: countOccupied,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _TodaysTeamSection(
                              members: teamMembersToday,
                              todayTasks: todayTasks,
                            ),
                          ),
                        ],
                      ),
                    )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DashboardPlanSection(todayTasks: todayTasks),
                          const SizedBox(height: 16),
                          _ApartmentFleetSection(
                            countClean: countClean,
                            countToClean: countToClean,
                            countOccupied: countOccupied,
                          ),
                          const SizedBox(height: 16),
                          _TodaysTeamSection(
                            members: teamMembersToday,
                            todayTasks: todayTasks,
                          ),
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  static bool _isCheckInOnDay(String? checkIn, DateTime day) {
    final dt = _parseReservationCheckIn(checkIn);
    if (dt == null) return false;
    return dt.year == day.year && dt.month == day.month && dt.day == day.day;
  }

  static String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final first = parts.first;
    if (first.isEmpty) return '?';
    final firstLetter = first[0].toUpperCase();
    if (parts.length == 1) return firstLetter;
    final last = parts.last;
    if (last.isEmpty) return firstLetter;
    return '$firstLetter${last[0].toUpperCase()}';
  }

  static bool _isCheckOutOnDay(String? checkOut, DateTime day) {
    final dt = _parseReservationCheckOut(checkOut);
    if (dt == null) return false;
    return dt.year == day.year && dt.month == day.month && dt.day == day.day;
  }

  static DateTime? _parseReservationCheckIn(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final parts = s.trim().split(' ');
    final dParts = parts[0].split('.');
    if (dParts.length < 3) return null;
    try {
      int h = 15, min = 0;
      if (parts.length >= 2) {
        final tParts = parts[1].split(':');
        if (tParts.length >= 2) {
          h = int.parse(tParts[0]);
          min = int.parse(tParts[1]);
        }
      }
      return DateTime(
        int.parse(dParts[2]),
        int.parse(dParts[1]),
        int.parse(dParts[0]),
        h,
        min,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseReservationCheckOut(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final parts = s.trim().split(' ');
    final dParts = parts[0].split('.');
    if (dParts.length < 3) return null;
    try {
      int h = 10, min = 0;
      if (parts.length >= 2) {
        final tParts = parts[1].split(':');
        if (tParts.length >= 2) {
          h = int.parse(tParts[0]);
          min = int.parse(tParts[1]);
        }
      }
      return DateTime(
        int.parse(dParts[2]),
        int.parse(dParts[1]),
        int.parse(dParts[0]),
        h,
        min,
      );
    } catch (_) {
      return null;
    }
  }
}

/// KPI karta – profesionální Enterprise vzhled: bílá karta, jemný stín, ikona v rohu, volitelný trend.
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.trendPercentage,
    this.trendLabel,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final double? trendPercentage;
  final String? trendLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Obsah zarovnaný doleva
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (trendPercentage != null) ...[
                const SizedBox(height: 8),
                _TrendBadge(
                  trendPercentage: trendPercentage!,
                  trendLabel: trendLabel,
                ),
              ],
              const SizedBox(height: 2),
              Text(
                'admin.dashboard_kpi_hint_today'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          // Ikona v pravém horním rohu v jemně zabarveném kolečku
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Štítek trendu pod hodnotou KPI: šipka + procento + popisek (zelená/červená/šedá).
class _TrendBadge extends StatelessWidget {
  const _TrendBadge({
    required this.trendPercentage,
    this.trendLabel,
  });

  final double trendPercentage;
  final String? trendLabel;

  @override
  Widget build(BuildContext context) {
    final isPositive = trendPercentage > 0;
    final isZero = trendPercentage == 0;
    final Color trendColor = isZero
        ? Colors.grey.shade600
        : (isPositive ? Colors.green.shade700 : Colors.red.shade700);
    final Color bgColor = isZero
        ? Colors.grey.withValues(alpha: 0.1)
        : (isPositive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1));
    final IconData trendIcon = isZero
        ? Icons.trending_flat
        : (isPositive ? Icons.trending_up : Icons.trending_down);
    final String percentText = isZero
        ? '0 %'
        : '${isPositive ? '+' : ''}${trendPercentage.toStringAsFixed(1)} %';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 16, color: trendColor),
          const SizedBox(width: 4),
          Text(
            percentText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: trendColor,
            ),
          ),
          if (trendLabel != null && trendLabel!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              trendLabel!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// LineChart – vývoj rezervací (posledních 7 a příštích 7 dní). Plynulá křivka s gradientem pod čarou.
class _ReservationsLineChart extends StatelessWidget {
  const _ReservationsLineChart({required this.reservations});

  final List<ReservationRow> reservations;

  List<double> _computeReservationsPerDay() {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 7));
    final values = <double>[];
    for (var i = 0; i < 14; i++) {
      final day = start.add(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      var count = 0;
      for (final r in reservations) {
        final checkIn = AdminDashboardScreen._parseReservationCheckIn(r.checkIn);
        final checkOut = AdminDashboardScreen._parseReservationCheckOut(r.checkOut);
        if (checkIn == null || checkOut == null) continue;
        final rStart = DateTime(checkIn.year, checkIn.month, checkIn.day);
        final rEnd = DateTime(checkOut.year, checkOut.month, checkOut.day)
            .add(const Duration(days: 1));
        if (rStart.isBefore(dayEnd) && rEnd.isAfter(dayStart)) count++;
      }
      values.add(count.toDouble());
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final values = _computeReservationsPerDay();
    final hasData = values.any((v) => v > 0);
    final primary = Theme.of(context).colorScheme.primary;

    List<FlSpot> spots;
    double maxY;
    if (hasData) {
      maxY = values.reduce((a, b) => a > b ? a : b);
      if (maxY < 1) maxY = 1;
      spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    } else {
      // Mock data
      const mock = [2.0, 4.0, 3.0, 6.0, 8.0, 5.0, 7.0, 4.0, 6.0, 9.0, 7.0, 5.0, 8.0, 6.0];
      maxY = 10;
      spots = mock.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_chart_reservations_title'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child:               LineChart(
              LineChartData(
                minX: 0,
                maxX: 13,
                minY: 0,
                maxY: maxY + 1,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toInt()}',
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                    getTooltipColor: (_) => Colors.grey.shade800,
                    tooltipRoundedRadius: 6,
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 2,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primary.withValues(alpha: 0.3),
                          primary.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 350),
            ),
          ),
        ],
      ),
    );
  }
}

/// PieChart (donut) – skladba dnešních úkolů podle task_type.
class _TasksDonutChart extends StatelessWidget {
  const _TasksDonutChart({required this.todayTasks});

  final List<TaskRow> todayTasks;

  static Color _colorForTaskType(String type) {
    final t = type.toLowerCase();
    if (t.contains('cleaning') || t.contains('úklid')) return Colors.amber.shade600;
    if (t.contains('transfer')) return Colors.blue.shade600;
    if (t.contains('check_in')) return Colors.green.shade600;
    if (t.contains('check_out')) return Colors.orange.shade600;
    if (t.contains('issue') || t.contains('material')) return Colors.red.shade600;
    return Colors.grey.shade600;
  }

  static String _labelKeyForTaskType(String type) {
    final t = type.toLowerCase();
    if (t.contains('cleaning') || t.contains('úklid')) return 'admin.task_type_cleaning';
    if (t.contains('transfer_in')) return 'admin.task_type_transfer_in';
    if (t.contains('transfer_out')) return 'admin.task_type_transfer_out';
    if (t.contains('transfer')) return 'admin.task_type_transfer';
    if (t.contains('check_in')) return 'admin.task_type_check_in';
    if (t.contains('check_out')) return 'admin.task_type_check_out';
    if (t.contains('issue')) return 'admin.task_type_issue';
    if (t.contains('material')) return 'admin.task_type_material';
    return 'admin.task_type_other';
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, int>{};
    for (final t in todayTasks) {
      final key = t.taskType.trim().isEmpty ? 'other' : t.taskType;
      grouped[key] = (grouped[key] ?? 0) + 1;
    }

    final hasData = grouped.isNotEmpty;
    List<PieChartSectionData> sections;
    final legendItems = <({String labelKey, int count, Color color})>[];

    if (!hasData) {
      // Mock data s legendou při prázdných datech
      sections = [
        PieChartSectionData(
          value: 1,
          color: Colors.amber.shade600,
          title: '1',
          radius: 55,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        PieChartSectionData(
          value: 1,
          color: Colors.blue.shade600,
          title: '1',
          radius: 55,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        PieChartSectionData(
          value: 1,
          color: Colors.green.shade600,
          title: '1',
          radius: 55,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
      legendItems.addAll([
        (labelKey: 'admin.task_type_cleaning', count: 1, color: Colors.amber.shade600),
        (labelKey: 'admin.task_type_transfer', count: 1, color: Colors.blue.shade600),
        (labelKey: 'admin.task_type_check_in', count: 1, color: Colors.green.shade600),
      ]);
    } else {
      sections = grouped.entries.map((e) {
        final color = _colorForTaskType(e.key);
        legendItems.add((
          labelKey: _labelKeyForTaskType(e.key),
          count: e.value,
          color: color,
        ));
        return PieChartSectionData(
          value: e.value.toDouble(),
          color: color,
          title: '${e.value}',
          radius: 55,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      }).toList();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_chart_tasks_title'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 30, bottom: 8),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 50,
                              sections: sections,
                            ),
                            duration: const Duration(milliseconds: 350),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${todayTasks.length}',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'admin.dashboard_chart_total'.tr(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: legendItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${item.labelKey.tr()} (${item.count})',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
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
          ),
        ],
      ),
    );
  }
}

/// Sekce „Dnešní plán“ – scrollovací timeline úkolů.
class _DashboardPlanSection extends StatelessWidget {
  const _DashboardPlanSection({required this.todayTasks});

  final List<TaskRow> todayTasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.dashboard_plan_today'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 10),
          if (todayTasks.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'admin.dashboard_today_done_coffee'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: todayTasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = todayTasks[index];
                  final icon = TaskVisuals.getIconStatic(t.taskType);
                  final bgColor = TaskVisuals.getBackgroundColorStatic(t.taskType);
                  final iconColor = TaskVisuals.getBorderColorStatic(t.taskType);
                  final timeStr =
                      '${t.dueDate.hour.toString().padLeft(2, '0')}:${t.dueDate.minute.toString().padLeft(2, '0')}';
                  final hasAssignee = t.assignedToName != null && t.assignedToName!.trim().isNotEmpty;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final switchToTab = AdminTabScope.of(context);
                        if (switchToTab != null) switchToTab(adminTabIndexTasks);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, size: 20, color: iconColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${t.apartmentName ?? t.apartmentId} • $timeStr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (hasAssignee)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.purple.shade100,
                                  child: Text(
                                    AdminDashboardScreen._initialsFromName(t.assignedToName!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple.shade800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Sekce „Kdo je dnes v akci“ – avatary pracovníků s počtem úkolů.
class _TodaysTeamSection extends StatelessWidget {
  const _TodaysTeamSection({
    required this.members,
    required this.todayTasks,
  });

  final List<TeamMember> members;
  final List<TaskRow> todayTasks;

  @override
  Widget build(BuildContext context) {
    int taskCountFor(TeamMember m) {
      return todayTasks
          .where((t) =>
              (t.assignedTo == m.profileId || t.assignedTo == m.id) &&
              (t.assignedTo != null && t.assignedTo!.trim().isNotEmpty))
          .length;
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_todays_team'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            Expanded(
              child: Text(
                'admin.dashboard_no_shift_today'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: members.map((m) {
                final count = taskCountFor(m);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purple.shade100,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              AdminDashboardScreen._initialsFromName(m.name),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade800,
                              ),
                            ),
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(
                        m.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black87,
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// Sekce „Stav apartmánů“ – barevné pilulky.
class _ApartmentFleetSection extends StatelessWidget {
  const _ApartmentFleetSection({
    required this.countClean,
    required this.countToClean,
    required this.countOccupied,
  });

  final int countClean;
  final int countToClean;
  final int countOccupied;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_apartment_fleet'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FleetStatusBlock(
                  count: countClean,
                  labelKey: 'admin.dashboard_fleet_clean',
                  icon: Icons.check_circle_outline,
                  backgroundColor: Colors.green.shade50,
                  accentColor: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FleetStatusBlock(
                  count: countToClean,
                  labelKey: 'admin.dashboard_fleet_to_clean',
                  icon: Icons.cleaning_services_outlined,
                  backgroundColor: Colors.orange.shade50,
                  accentColor: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FleetStatusBlock(
                  count: countOccupied,
                  labelKey: 'admin.dashboard_fleet_occupied',
                  icon: Icons.people_outline,
                  backgroundColor: Colors.blue.shade50,
                  accentColor: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Moderní Status Block – čtvercová/obdélníková karta s číslem, ikonou a textem.
class _FleetStatusBlock extends StatelessWidget {
  const _FleetStatusBlock({
    required this.count,
    required this.labelKey,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
  });

  final int count;
  final String labelKey;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final labelText = labelKey.tr(namedArgs: {'count': '$count'});
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(height: 4),
          Text(
            labelText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
