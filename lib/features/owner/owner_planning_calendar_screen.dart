import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/owner/providers/owner_planning_calendar_provider.dart';
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
const double _slotHeight = 18;
const double _timeColumnWidth = 48;
const double _dayHeaderHeight = 32;

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

  void _prevWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

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

  /// Zobrazí read-only detail úkolu – bez editace, bez jmen personálu.
  void _showReadOnlyDetail(PlanningTask task) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _OwnerTaskDetailDialog(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(ownerPlanningCalendarTasksProvider(_weekStart));
    final categoriesByCode = ref.watch(taskCategoriesProvider).valueOrNull ?? {};
    final locale = context.locale.toString();
    final dateFormat = DateFormat('d.M.', locale);

    return Scaffold(
      appBar: AppBar(
        title: Text('owner.calendar_title'.tr()),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  final dayColumnWidth = ((w - _timeColumnWidth) / 7).clamp(80.0, double.infinity);
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
                        _DayHeaderRow(
                          weekStart: _weekStart,
                          dayColumnWidth: dayColumnWidth,
                          dateFormat: dateFormat,
                        ),
                        Expanded(
                          child: tasksAsync.when(
                            data: (tasks) => _OwnerWeekGridBody(
                              weekStart: _weekStart,
                              tasks: tasks,
                              categoriesByCode: categoriesByCode,
                              onTaskTap: _showReadOnlyDetail,
                              dayColumnWidth: dayColumnWidth,
                              totalWidth: totalWidth,
                              verticalScrollController: _verticalScrollController,
                            ),
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(
                              child: Text(
                                'owner.calendar_error'.tr(namedArgs: {'error': '$e'}),
                                textAlign: TextAlign.center,
                              ),
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

/// Tělo mřížky – horizontální a vertikální scroll, read-only karty.
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
      final maxExtent = widget.verticalScrollController.position.maxScrollExtent;
      widget.verticalScrollController.jumpTo(offset.clamp(0.0, maxExtent));
      if (mounted) setState(() => _initialScrollDone = true);
    });
  }

  Widget _buildCurrentTimeIndicator(double gridHeight) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStartNorm = DateTime(widget.weekStart.year, widget.weekStart.month, widget.weekStart.day);
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
    final lineColor = Colors.grey.withValues(alpha: 0.25);
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
                      children: List.generate(_totalSlots, (i) {
                        final totalMinutes = _gridStartHour * 60 + i * _slotMinutes;
                        final h = totalMinutes ~/ 60;
                        final m = totalMinutes % 60;
                        final showLabel = m == 0;
                        return SizedBox(
                          height: _slotHeight,
                          child: showLabel
                              ? Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4, top: 0),
                                    child: Text(
                                      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ),
                                )
                              : null,
                        );
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 7 * widget.dayColumnWidth,
                    height: gridHeight,
                    child: Row(
                      children: List.generate(7, (dayIndex) {
                        return Container(
                          width: widget.dayColumnWidth,
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: lineColor)),
                          ),
                          child: Column(
                            children: List.generate(
                              _totalSlots,
                              (_) => Container(
                                height: _slotHeight,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: lineColor.withValues(alpha: 0.6),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              ...processed.map((p) {
                final backgroundColor = TaskVisuals.getBackgroundColor(
                  p.task.taskType,
                  categoriesByCode: widget.categoriesByCode.isNotEmpty ? widget.categoriesByCode : null,
                );
                final borderColor = TaskVisuals.getBorderColor(
                  p.task.taskType,
                  categoriesByCode: widget.categoriesByCode.isNotEmpty ? widget.categoriesByCode : null,
                );
                final startMinutes = p.task.scheduledStart.hour * 60 +
                    p.task.scheduledStart.minute -
                    _gridStartHour * 60;
                if (startMinutes < 0) return const SizedBox.shrink();
                final durationMinutes = parseDurationMinutesFromDescription(p.task.description);
                final top = (startMinutes / _slotMinutes) * _slotHeight + 1;
                final height = (durationMinutes / _slotMinutes) * _slotHeight - 2;
                if (height < 20) return const SizedBox.shrink();
                final cellW = widget.dayColumnWidth - 2;
                final left = _timeColumnWidth +
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
    final rawCode = task.taskType.trim().isEmpty ? 'other' : task.taskType.toLowerCase().trim();
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
              border: Border(
                left: BorderSide(color: borderColor, width: 4),
              ),
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
                        categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null,
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

/// Read-only dialog s detailem úkolu – bez editace, bez jmen personálu.
class _OwnerTaskDetailDialog extends StatelessWidget {
  const _OwnerTaskDetailDialog({required this.task});

  final PlanningTask task;

  static String _taskTypeLabelKey(String taskType) {
    final code = (taskType.trim().isEmpty ? 'other' : taskType.toLowerCase()).replaceAll('-', '_');
    return 'admin.task_type_$code';
  }

  static String _statusLabel(String? status) {
    if (status == null || status.trim().isEmpty) return 'task_status.assigned'.tr();
    final s = status.trim().toLowerCase();
    if (s == 'in_progress' || s == 'probíhá') return 'task_status.in_progress'.tr();
    if (s == 'completed' || s == 'done' || s == 'hotovo') return 'task_status.completed'.tr();
    if (s == 'problem' || s == 'problém') return 'task_status.problem'.tr();
    return 'task_status.assigned'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = '${task.scheduledStart.hour.toString().padLeft(2, '0')}:${task.scheduledStart.minute.toString().padLeft(2, '0')}';
    final dateStr = DateFormat('d.M.yyyy', context.locale.toString()).format(task.scheduledStart);

    return AlertDialog(
      title: Text('owner.task_detail_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'owner.task_detail_type'.tr(), value: _taskTypeLabelKey(task.taskType).tr()),
            _DetailRow(label: 'owner.task_detail_title_label'.tr(), value: task.title),
            _DetailRow(label: 'owner.task_detail_apartment'.tr(), value: task.apartmentName ?? '–'),
            _DetailRow(label: 'owner.task_detail_staff'.tr(), value: 'owner.tasks_staff_label'.tr()),
            _DetailRow(label: 'owner.task_detail_date'.tr(), value: '$dateStr $timeStr'),
            _DetailRow(label: 'owner.task_detail_status'.tr(), value: _statusLabel(task.status)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
