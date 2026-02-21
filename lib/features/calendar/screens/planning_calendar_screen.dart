import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/admin_reservations_screen.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/utils/task_visuals.dart';
import 'package:falconest/widgets/task_legend.dart';

/// Stav vizuálního managementu události (CASE A/B/C).
enum _CardVisualState { critical, conflict, normal }

/// Konstanty týdenní mřížky: 15min sloty, pondělí–neděle, plný 24h rozsah (noční směny).
const int _gridStartHour = 0;
const int _gridEndHour = 24;
const int _slotMinutes = 15;
/// Výška jednoho 15min slotu – kompaktní, méně scrollování.
const double _slotHeight = 18;
const double _timeColumnWidth = 48;
const double _dayHeaderHeight = 32;

int get _slotsPerHour => 60 ~/ _slotMinutes;
int get _totalSlots => (_gridEndHour - _gridStartHour) * _slotsPerHour;
double totalGridHeight(double slotHeight) => _totalSlots * slotHeight;

/// Klíče pro zkratky dnů (Po–Ne) – pro vícejazyčnost.
const List<String> _dayKeys = [
  'planning_calendar.mon',
  'planning_calendar.tue',
  'planning_calendar.wed',
  'planning_calendar.thu',
  'planning_calendar.fri',
  'planning_calendar.sat',
  'planning_calendar.sun',
];

/// Obrazovka plánovacího kalendáře – týdenní pohled s 15min sloty, dropdown, legenda.
class PlanningCalendarScreen extends ConsumerStatefulWidget {
  const PlanningCalendarScreen({super.key});

  @override
  ConsumerState<PlanningCalendarScreen> createState() => _PlanningCalendarScreenState();
}

class _PlanningCalendarScreenState extends ConsumerState<PlanningCalendarScreen> {
  late DateTime _weekStart;
  String? _selectedFilterId;
  final ScrollController _verticalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _weekStart = _getMonday(DateTime.now());
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  static DateTime _getMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  void _prevWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

  /// Přepne na aktuální týden a posune scroll na aktuální čas (nebo 08:00 když je před 08:00).
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

  void _openEditTask(PlanningTask task) {
    // PRAVIDLO: Při úpravě existujícího úkolu vždy předáváme čas Z ÚKOLU (task.scheduledStart).
    // Nikdy nepoužíváme čas z tapu/pozice – kalendář nemá CalendarTapDetails, tap je vždy na kartu úkolu.
    // Předání zaokrouhleného času nebo details.date by způsobilo „phantom time shift“ při uložení.
    final taskRow = task.toTaskRow(roundedDueDate: task.scheduledStart);
    AdminTasksScreen.showEditTaskDialog(
      context,
      ref,
      taskRow,
      onReservationTap: taskRow.reservationId != null && taskRow.reservationId!.isNotEmpty
          ? (id) => _navigateToReservation(context, ref, id)
          : null,
      onSaved: () {
        ref.invalidate(planningCalendarAllTasksProvider);
        ref.invalidate(planningCalendarDataProvider);
      },
    );
  }

  /// Zavře dialog úkolu, přepne na záložku Rezervace a otevře detail dané rezervace.
  void _navigateToReservation(BuildContext context, WidgetRef ref, String reservationId) {
    Navigator.of(context).pop();
    final reservations = ref.read(adminReservationsProvider).valueOrNull ?? [];
    final reservation = reservations.where((r) => r.id == reservationId).firstOrNull;
    if (reservation != null) {
      AdminTabScope.of(context)?.call(adminTabIndexReservations);
      AdminReservationsScreen.showEditReservationDialog(context, ref, reservation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(planningCalendarDataProvider(_weekStart));
    final locale = context.locale.toString();
    final dateFormat = DateFormat('d.M.', locale);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Řádek 1: Titulek + vyhledávání (stejný layout a padding jako Úkoly – viz _TopActionBar)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Text(
                  'planning_calendar.title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'admin.tasks_search_hint'.tr(),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Řádek 2: navigace týdne, tlačítko Dnes, legenda, dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
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
                            letterSpacing: 0.2,
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
                Expanded(
                  child: Center(
                    child: TaskLegend(),
                  ),
                ),
                dataAsync.when(
                  data: (data) => SizedBox(
                    width: 200,
                    child: _FilterDropdown(
                      resources: data.resources,
                      selectedId: _selectedFilterId,
                      onChanged: (id) => setState(() => _selectedFilterId = id),
                    ),
                  ),
                  loading: () => const SizedBox(width: 200, height: 48),
                  error: (_, _) => const SizedBox(width: 200, height: 48),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Kalendář v bílém kontejneru – sticky hlavička dnů, scroll jen tělo mřížky
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
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        _DayHeaderRow(
                          weekStart: _weekStart,
                          dayColumnWidth: dayColumnWidth,
                          dateFormat: dateFormat,
                        ),
                        Expanded(
                          child: dataAsync.when(
                            data: (data) => _WeekGridScrollBody(
                              weekStart: _weekStart,
                              data: data,
                              categoriesByCode: ref.watch(taskCategoriesProvider).valueOrNull ?? {},
                              selectedFilterId: _selectedFilterId,
                              searchQuery: _searchController.text.trim(),
                              onTaskTap: _openEditTask,
                              dayColumnWidth: dayColumnWidth,
                              totalWidth: totalWidth,
                              verticalScrollController: _verticalScrollController,
                            ),
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(
                              child: Text(
                                'planning_calendar.error'.tr(namedArgs: {'error': '$e'}),
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

/// Dropdown filtr – Zobrazit vše, Nepřiřazeno, členové týmu (i18n).
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.resources,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CalendarResource> resources;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          hint: Text(
            'planning_calendar.show_all'.tr(),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('planning_calendar.show_all'.tr()),
            ),
            DropdownMenuItem<String?>(
              value: kUnassignedResourceId,
              child: Text('⚠️ ${'planning_calendar.unassigned_row'.tr()}'),
            ),
            ...resources
                .where((r) => r.id != kUnassignedResourceId)
                .map((r) => DropdownMenuItem<String?>(
                      value: r.id,
                      child: Text(r.displayName),
                    )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Lepený řádek hlaviček dnů (Po 16.2. …) – zůstává nahoře při scrollování.
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
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
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

/// Scrollovatelné tělo mřížky – pouze časové sloty a karty (hlavička dnů je sticky výše).
/// Po prvním sestavení posune viewport na 08:00 (začátek pracovní doby).
class _WeekGridScrollBody extends StatefulWidget {
  const _WeekGridScrollBody({
    required this.weekStart,
    required this.data,
    required this.categoriesByCode,
    required this.selectedFilterId,
    required this.searchQuery,
    required this.onTaskTap,
    required this.dayColumnWidth,
    required this.totalWidth,
    required this.verticalScrollController,
  });

  final DateTime weekStart;
  final PlanningCalendarData data;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final String? selectedFilterId;
  final String searchQuery;
  final ValueChanged<PlanningTask> onTaskTap;
  final double dayColumnWidth;
  final double totalWidth;
  final ScrollController verticalScrollController;

  @override
  State<_WeekGridScrollBody> createState() => _WeekGridScrollBodyState();
}

class _WeekGridScrollBodyState extends State<_WeekGridScrollBody> {
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

  List<PlanningTask> _filteredTasks() {
    var list = widget.data.tasks;
    if (widget.selectedFilterId != null) {
      list = list.where((t) => t.resourceId == widget.selectedFilterId).toList();
    }
    if (widget.searchQuery.isEmpty) return list;
    final q = widget.searchQuery.toLowerCase();
    return list.where((t) {
      final title = (t.title).toLowerCase();
      final apartment = (t.apartmentName ?? '').toLowerCase();
      final assignee = (t.assignedUserName ?? '').toLowerCase();
      return title.contains(q) || apartment.contains(q) || assignee.contains(q);
    }).toList();
  }

  _CardVisualState _visualState(PlanningTask task) {
    if (task.assignedTo == null) return _CardVisualState.critical;
    if (widget.data.conflictIds.contains(task.id)) return _CardVisualState.conflict;
    return _CardVisualState.normal;
  }

  /// Barva pozadí karty – vždy pastelová pro kontrast s tmavým textem.
  Color _backgroundColorFor(_CardVisualState state, PlanningTask task) {
    switch (state) {
      case _CardVisualState.critical:
        return Colors.red.shade100;
      case _CardVisualState.conflict:
        return Colors.orange.shade100;
      case _CardVisualState.normal:
        return TaskVisuals.getBackgroundColor(
          task.taskType,
          categoriesByCode: widget.categoriesByCode.isNotEmpty ? widget.categoriesByCode : null,
        );
    }
  }

  /// Barva levého akcentu (border) – sytá pro unassigned/conflict, tmavší pastel pro normal.
  Color _borderColorFor(_CardVisualState state, PlanningTask task) {
    switch (state) {
      case _CardVisualState.critical:
        return Colors.red;
      case _CardVisualState.conflict:
        return Colors.orange;
      case _CardVisualState.normal:
        return TaskVisuals.getBorderColor(
          task.taskType,
          categoriesByCode: widget.categoriesByCode.isNotEmpty ? widget.categoriesByCode : null,
        );
    }
  }

  /// Červená čára „teď“ (jako v Google Calendar) – zobrazí se jen když zobrazený týden obsahuje dnes.
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
      child: Container(
        color: Colors.red,
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks();
    final processed = getProcessedTasksForWeek(tasks, widget.weekStart, _gridStartHour);
    final lineColor = Colors.grey.withValues(alpha: 0.25);
    final gridHeight = totalGridHeight(_slotHeight);

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
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
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
                            border: Border(
                              right: BorderSide(color: lineColor),
                            ),
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
                final state = _visualState(p.task);
                final backgroundColor = _backgroundColorFor(state, p.task);
                final borderColor = _borderColorFor(state, p.task);
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

                final category = TaskVisuals.resolveCategory(p.task.taskType, widget.categoriesByCode);
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
                      child: _TaskCard(
                        task: p.task,
                        category: category,
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

/// Karta úkolu v mřížce – čistý design: ikona + název kategorie, apartmán, přiřazení.
/// Category-driven UI: nepoužíváme task.title jako hlavní text, ale i18n název kategorie.
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.category,
    required this.categoriesByCode,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final PlanningTask task;
  final TaskCategoryModel? category;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textSecondary = Color(0xFF6B6B6B);

  @override
  Widget build(BuildContext context) {
    final rawCode = category?.code ?? (task.taskType.trim().isEmpty ? 'other' : task.taskType.toLowerCase().trim());
    // Normalizace: DB/formulář může mít "check-in", JSON má "check_in" – pomlčka -> podtržítko.
    final code = rawCode.replaceAll('-', '_');
    final categoryLabel = 'admin.task_type_$code'.tr();
    final apartmentLabel = task.apartmentName ?? task.title;
    final assigneeLabel = task.assignedUserName != null &&
            (task.assignedUserName!.trim().isNotEmpty)
        ? task.assignedUserName!
        : 'planning_calendar.unassigned_row'.tr();

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
                      TaskVisuals.getIcon(task.taskType, categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  assigneeLabel,
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
