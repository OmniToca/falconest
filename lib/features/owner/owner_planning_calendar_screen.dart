import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/calendar/widgets/planning_grid_slot_widgets.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_planning_calendar_apartment_filter_provider.dart';
import 'package:falconest/features/owner/providers/owner_planning_calendar_events_provider.dart';
import 'package:falconest/features/owner/providers/owner_reservations_provider.dart';
import 'package:falconest/features/owner/widgets/owner_task_detail_dialog.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/utils/task_visuals.dart';

/// Plánovací kalendář pro Klientský portál (majitel bytu).
///
/// UI: Kalendář je striktně read-only, bez Drag&Drop interakcí.
/// Zobrazuje úkoly pouze pro vlastněné byty; návrhy a jména personálu skryty.
const int _gridStartHour = 0;
const int _gridEndHour = 24;
const int _slotMinutes = 15;
const double _slotHeight = kPlanningGridSlotHeight;
const double _timeColumnWidth = 48;
const double _dayHeaderHeight = 32;

/// Výška řádku All-Day hlavičky pro rezervace (obsazenost bytu).
const double _allDayHeaderHeight = 44;

int get _slotsPerHour => 60 ~/ _slotMinutes;
int get _totalSlots => (_gridEndHour - _gridStartHour) * _slotsPerHour;
double _totalGridHeight() => _totalSlots * _slotHeight;

const List<String> _dayKeys = [
  'planning_calendar.mon',
  'planning_calendar.tue',
  'planning_calendar.wed',
  'planning_calendar.thu',
  'planning_calendar.fri',
  'planning_calendar.sat',
  'planning_calendar.sun',
];

/// Horní lišta: výběr bytu pro zúžení dat v kalendáři (stejný týden, méně událostí v síti).
///
/// PROČ: Při více bytech majitele skrývá vizuální šum; `null` = všechny vlastněné jednotky.
class _OwnerCalendarApartmentFilterBar extends ConsumerWidget {
  const _OwnerCalendarApartmentFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartmentsAsync = ref.watch(ownerApartmentsProvider);
    return apartmentsAsync.when(
      data: (apartments) {
        if (apartments.length < 2) {
          return const SizedBox.shrink();
        }
        final filter = ref.watch(ownerPlanningCalendarApartmentFilterProvider);
        final effective = (filter == null || apartments.any((a) => a.id == filter))
            ? filter
            : null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'owner.calendar_filter_label'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                isDense: true,
                value: effective,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('owner.calendar_filter_all_apartments'.tr()),
                  ),
                  ...apartments.map(
                    (a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(a.name),
                    ),
                  ),
                ],
                onChanged: (v) {
                  ref.read(ownerPlanningCalendarApartmentFilterProvider.notifier).state = v;
                },
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (Object e, StackTrace st) => const SizedBox.shrink(),
    );
  }
}

/// Obrazovka plánovacího kalendáře pro majitele – týdenní pohled, read-only.
class OwnerPlanningCalendarScreen extends ConsumerStatefulWidget {
  const OwnerPlanningCalendarScreen({super.key});

  @override
  ConsumerState<OwnerPlanningCalendarScreen> createState() =>
      _OwnerPlanningCalendarScreenState();
}

class _OwnerPlanningCalendarScreenState
    extends ConsumerState<OwnerPlanningCalendarScreen> {
  late DateTime _weekStart;
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _weekStart = _getMonday(DateTime.now());
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  static DateTime _getMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  void _prevWeek() =>
      setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() =>
      setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

  void _jumpToToday() {
    setState(() => _weekStart = _getMonday(DateTime.now()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_verticalScrollController.hasClients) return;
      final now = DateTime.now();
      final minutesFromMidnight = now.hour * 60 + now.minute;
      final offset = (minutesFromMidnight / _slotMinutes) * _slotHeight;
      final maxExtent = _verticalScrollController.position.maxScrollExtent;
      _verticalScrollController.jumpTo(offset.clamp(0.0, maxExtent));
    });
  }

  /// Zobrazí read-only detail úkolu – sdílený dialog s popisem a fotkami.
  void _showReadOnlyDetail(PlanningTask task) {
    OwnerTaskDetailDialog.show(
      context,
      OwnerTaskDetailData(
        title: task.title,
        taskType: task.taskType,
        apartmentName: task.apartmentName,
        scheduledStart: task.scheduledStart,
        status: task.status ?? 'pending',
        description: task.description.trim().isEmpty ? null : task.description,
        mediaUrls: task.mediaUrls,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(
      ownerPlanningCalendarEventsProvider(_weekStart),
    );
    final categoriesByCode =
        ref.watch(taskCategoriesProvider).valueOrNull ?? {};
    final locale = context.locale.toString();
    final dateFormat = DateFormat('d.M.', locale);

    return Scaffold(
      appBar: AppBar(title: Text('owner.calendar_title'.tr())),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _OwnerCalendarApartmentFilterBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  onPressed: _prevWeek,
                  icon: const Icon(Icons.chevron_left, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${dateFormat.format(_weekStart)} – ${dateFormat.format(_weekStart.add(const Duration(days: 6)))}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _nextWeek,
                  icon: const Icon(Icons.chevron_right, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _jumpToToday,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: Text('planning_calendar.today'.tr()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final dayColumnWidth = ((w - _timeColumnWidth) / 7).clamp(
                    80.0,
                    double.infinity,
                  );
                  final totalWidth = _timeColumnWidth + 7 * dayColumnWidth;
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Hlavička s názvy dnů
                        _DayHeaderRow(
                          weekStart: _weekStart,
                          dayColumnWidth: dayColumnWidth,
                          dateFormat: dateFormat,
                        ),
                        // 2. All-Day hlavička + časová mřížka: MUSÍ být v Expanded, aby měly ohraničenou výšku a mřížka mohla scrollovat.
                        Expanded(
                          child: eventsAsync.when(
                            data: (events) {
                              final reservationEvents = events
                                  .where((e) => e.isReservation)
                                  .toList();
                              final taskEvents = events
                                  .where((e) => !e.isReservation)
                                  .toList();
                              final tasks = taskEvents
                                  .map((e) => e.task!)
                                  .toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _OwnerAllDayHeader(
                                    weekStart: _weekStart,
                                    dayColumnWidth: dayColumnWidth,
                                    reservationEvents: reservationEvents,
                                  ),
                                  Expanded(
                                    child: _OwnerWeekGridBody(
                                      weekStart: _weekStart,
                                      tasks: tasks,
                                      categoriesByCode: categoriesByCode,
                                      onTaskTap: _showReadOnlyDetail,
                                      dayColumnWidth: dayColumnWidth,
                                      totalWidth: totalWidth,
                                      verticalScrollController:
                                          _verticalScrollController,
                                    ),
                                  ),
                                ],
                              );
                            },
                            loading: () => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _OwnerAllDayHeader(
                                  weekStart: _weekStart,
                                  dayColumnWidth: dayColumnWidth,
                                  reservationEvents: [],
                                ),
                                const Expanded(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ],
                            ),
                            error: (e, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _OwnerAllDayHeader(
                                  weekStart: _weekStart,
                                  dayColumnWidth: dayColumnWidth,
                                  reservationEvents: [],
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'owner.calendar_error'.tr(
                                        namedArgs: {'error': '$e'},
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({
    required this.weekStart,
    required this.dayColumnWidth,
    required this.dateFormat,
  });

  final DateTime weekStart;
  final double dayColumnWidth;
  final DateFormat dateFormat;

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = Colors.grey.withValues(alpha: 0.25);
    return Row(
      children: [
        SizedBox(
          width: _timeColumnWidth,
          height: _dayHeaderHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                right: BorderSide(color: lineColor),
                bottom: BorderSide(color: lineColor),
              ),
            ),
          ),
        ),
        ...List.generate(7, (i) {
          final day = weekStart.add(Duration(days: i));
          final isToday = _isToday(day);
          return Container(
            width: dayColumnWidth,
            height: _dayHeaderHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? Colors.blue.shade50 : Colors.grey.shade50,
              border: Border(
                right: BorderSide(color: lineColor),
                bottom: BorderSide(color: lineColor),
              ),
            ),
            child: isToday
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade600,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${_dayKeys[i].tr()} ${dateFormat.format(day)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '${_dayKeys[i].tr()} ${dateFormat.format(day)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          );
        }),
      ],
    );
  }
}

/// All-Day hlavička: zobrazuje rezervace (obsazenost bytu) jako bloky v každém dni.
/// Rezervace mají jinou barvu než úkoly (modrá/tyrkysová), aby na první pohled
/// bylo zřejmé „tady bydlí host“. Jedna rezervace = jeden blok přes celý sloupec dne.
class _OwnerAllDayHeader extends StatelessWidget {
  const _OwnerAllDayHeader({
    required this.weekStart,
    required this.dayColumnWidth,
    required this.reservationEvents,
  });

  final DateTime weekStart;
  final double dayColumnWidth;
  final List<OwnerCalendarEvent> reservationEvents;

  @override
  Widget build(BuildContext context) {
    final lineColor = Colors.grey.withValues(alpha: 0.25);
    final weekStartNorm = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    return Row(
      children: [
        SizedBox(
          width: _timeColumnWidth,
          height: _allDayHeaderHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                right: BorderSide(color: lineColor),
                bottom: BorderSide(color: lineColor),
              ),
            ),
            child: Center(
              child: Text(
                'owner.calendar_all_day'.tr(),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        ...List.generate(7, (dayIndex) {
          final day = weekStartNorm.add(Duration(days: dayIndex));
          final forDay = reservationEvents.where((e) {
            final d = e.start;
            return d.year == day.year &&
                d.month == day.month &&
                d.day == day.day;
          }).toList();

          return Container(
            width: dayColumnWidth,
            height: _allDayHeaderHeight,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                right: BorderSide(color: lineColor),
                bottom: BorderSide(color: lineColor),
              ),
            ),
            child: ListView.builder(
              itemCount: forDay.length,
              itemBuilder: (context, i) {
                final ev = forDay[i];
                final r = ev.reservation!;
                final label = _reservationLabel(r);
                final chipBg = Colors.blue.withValues(alpha: 0.2);
                final chipBorder = Colors.blue.shade400.withValues(alpha: 0.6);
                final chipFg = Colors.blue.shade800;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: chipBorder, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: chipFg,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  /// Text bloku: jména hostů nebo „Rezervace“ + název bytu.
  static String _reservationLabel(OwnerReservation r) {
    if (r.guestName != null && r.guestName!.trim().isNotEmpty) {
      return r.guestName!.trim();
    }
    return 'owner.calendar_reservation'.tr();
  }
}

/// Tělo mřížky – horizontální a vertikální scroll, read-only karty.
/// POUZE úkoly: pozicování přes getProcessedTasksForWeek zůstává beze změny.
class _OwnerWeekGridBody extends StatefulWidget {
  const _OwnerWeekGridBody({
    required this.weekStart,
    required this.tasks,
    required this.categoriesByCode,
    required this.onTaskTap,
    required this.dayColumnWidth,
    required this.totalWidth,
    required this.verticalScrollController,
  });

  final DateTime weekStart;
  final List<PlanningTask> tasks;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final ValueChanged<PlanningTask> onTaskTap;
  final double dayColumnWidth;
  final double totalWidth;
  final ScrollController verticalScrollController;

  @override
  State<_OwnerWeekGridBody> createState() => _OwnerWeekGridBodyState();
}

class _OwnerWeekGridBodyState extends State<_OwnerWeekGridBody> {
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialScrollDone) return;
      if (!widget.verticalScrollController.hasClients) return;
      final offset = 8 * _slotsPerHour * _slotHeight;
      final maxExtent =
          widget.verticalScrollController.position.maxScrollExtent;
      widget.verticalScrollController.jumpTo(offset.clamp(0.0, maxExtent));
      if (mounted) setState(() => _initialScrollDone = true);
    });
  }

  Widget _buildCurrentTimeIndicator(double gridHeight) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStartNorm = DateTime(
      widget.weekStart.year,
      widget.weekStart.month,
      widget.weekStart.day,
    );
    final dayIndex = today.difference(weekStartNorm).inDays;
    if (dayIndex < 0 || dayIndex > 6) return const SizedBox.shrink();
    final minutesFromMidnight = now.hour * 60 + now.minute;
    final top = (minutesFromMidnight / _slotMinutes) * _slotHeight;
    if (top < 0 || top >= gridHeight) return const SizedBox.shrink();
    return Positioned(
      left: _timeColumnWidth + dayIndex * widget.dayColumnWidth,
      top: top,
      width: widget.dayColumnWidth,
      height: 2,
      child: Container(color: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final processed = getProcessedTasksForWeek(
      widget.tasks,
      widget.weekStart,
      _gridStartHour,
    );
    final gridHeight = _totalGridHeight();

    return SingleChildScrollView(
      controller: widget.verticalScrollController,
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: widget.totalWidth,
          height: gridHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _timeColumnWidth,
                    height: gridHeight,
                    child: Column(
                      children: List<Widget>.generate(_totalSlots, (i) {
                        final totalMinutes =
                            _gridStartHour * 60 + i * _slotMinutes;
                        final h = totalMinutes ~/ 60;
                        final m = totalMinutes % 60;
                        if (m != 0) return const PlanningGridTimeEmptySlot();
                        return PlanningGridTimeLabeledSlot(hour: h, minute: m);
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 7 * widget.dayColumnWidth,
                    height: gridHeight,
                    child: Row(
                      children: List<Widget>.generate(
                        7,
                        (_) => PlanningGridDayColumn(
                          width: widget.dayColumnWidth,
                          slotCount: _totalSlots,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ...processed.map((p) {
                final backgroundColor = TaskVisuals.getBackgroundColor(
                  p.task.taskType,
                  categoriesByCode: widget.categoriesByCode.isNotEmpty
                      ? widget.categoriesByCode
                      : null,
                );
                final borderColor = TaskVisuals.getBorderColor(
                  p.task.taskType,
                  categoriesByCode: widget.categoriesByCode.isNotEmpty
                      ? widget.categoriesByCode
                      : null,
                );
                final startMinutes =
                    p.task.scheduledStart.hour * 60 +
                    p.task.scheduledStart.minute -
                    _gridStartHour * 60;
                if (startMinutes < 0) return const SizedBox.shrink();
                final durationMinutes = planningTaskBlockDurationMinutes(
                  p.task,
                );
                final top = (startMinutes / _slotMinutes) * _slotHeight + 1;
                final height =
                    (durationMinutes / _slotMinutes) * _slotHeight - 2;
                if (height < 20) return const SizedBox.shrink();
                final cellW = widget.dayColumnWidth - 2;
                final left =
                    _timeColumnWidth +
                    p.dayIndex * widget.dayColumnWidth +
                    1 +
                    (p.colIndex / p.totalCols) * cellW;
                final width = (1 / p.totalCols) * cellW;

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _OwnerTaskCard(
                        task: p.task,
                        categoriesByCode: widget.categoriesByCode,
                        backgroundColor: backgroundColor,
                        borderColor: borderColor,
                        onTap: () => widget.onTaskTap(p.task),
                      ),
                    ),
                  ),
                );
              }),
              _buildCurrentTimeIndicator(gridHeight),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karta úkolu – typ, apartmán; místo jména personálu generický text.
class _OwnerTaskCard extends StatelessWidget {
  const _OwnerTaskCard({
    required this.task,
    required this.categoriesByCode,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final PlanningTask task;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textSecondary = Color(0xFF6B6B6B);

  @override
  Widget build(BuildContext context) {
    final rawCode = task.taskType.trim().isEmpty
        ? 'other'
        : task.taskType.toLowerCase().trim();
    final code = rawCode.replaceAll('-', '_');
    final categoryLabel = 'admin.task_type_$code'.tr();
    final apartmentLabel = task.apartmentName ?? task.title;

    return Padding(
      padding: const EdgeInsets.all(1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: backgroundColor,
              border: Border(left: BorderSide(color: borderColor, width: 4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      TaskVisuals.getIcon(
                        task.taskType,
                        categoriesByCode: categoriesByCode.isNotEmpty
                            ? categoriesByCode
                            : null,
                      ),
                      size: 12,
                      color: _textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        categoryLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  apartmentLabel,
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'owner.tasks_staff_label'.tr(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: _textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
