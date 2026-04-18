import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/admin_reservations_screen.dart';
// Sdílená komponenta pro zobrazení financí a poznámek z rezervace je v dialogu úpravy úkolu (AdminTasksScreen).
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/calendar/widgets/planning_grid_slot_widgets.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/utils/task_visuals.dart';
import 'package:falconest/widgets/task_legend.dart';

/// Načte jednu rezervaci z DB, pokud ji ještě nemáme v paměti streamu (kalendář → detail).
///
/// PROČ: Stream rezervací může mít limit / filtr bytů; odkaz z úkolu musí fungovat i pro řádek mimo cache.
Future<ReservationRow?> _fetchReservationRowForPlanning(
  WidgetRef ref,
  String reservationId,
) async {
  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return null;
  final res = await SupabaseService.safeFrom('reservations', tenantId)
      .select(
          'id, apartment_id, reference_number, guest_name, guest_phone, guest_language, reservation_source, start_date, end_date, status, guest_adults, guest_children, arrival_time, departure_time, internal_note, special_requests, needs_transfer, deleted_at, last_communication_template_context, last_communication_at, last_communication_template_id, created_at, apartments(name)')
      .eq('id', reservationId)
      .isFilter('deleted_at', null)
      .maybeSingle();
  if (res == null) return null;
  final map = Map<String, dynamic>.from(res as Map);
  if (map['apartments'] == null) {
    final aptId = map['apartment_id']?.toString();
    if (aptId != null && aptId.isNotEmpty) {
      final apts = ref.read(apartmentsFullListProvider).valueOrNull;
      if (apts != null) {
        for (final a in apts) {
          if (a.id == aptId) {
            map['apartments'] = {'name': a.name};
            break;
          }
        }
      }
    }
  }
  return ReservationRow.fromJson(map);
}

/// Stav vizuálního managementu události (CASE A/B/C).
enum _CardVisualState { critical, conflict, normal }

/// Konstanty týdenní mřížky: 15min sloty, pondělí–neděle, plný 24h rozsah (noční směny).
const int _gridStartHour = 0;
const int _gridEndHour = 24;
const int _slotMinutes = 15;

/// Výška jednoho 15min slotu – sdílená s [kPlanningGridSlotHeight] (const pozadí mřížky).
const double _slotHeight = kPlanningGridSlotHeight;
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
  ConsumerState<PlanningCalendarScreen> createState() =>
      _PlanningCalendarScreenState();
}

class _PlanningCalendarScreenState
    extends ConsumerState<PlanningCalendarScreen> {
  late DateTime _weekStart;
  String? _selectedFilterId;
  final ScrollController _verticalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  /// PROČ debounce: každý znak dřív spustil [setState] a přestavěl stovky buněk mřížky.
  Timer? _searchDebounce;

  /// Hodnota předávaná do mřížky až po 300 ms klidu v poli vyhledávání.
  String _debouncedSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _weekStart = _getMonday(DateTime.now());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Naplánuje aktualizaci filtru vyhledávání po 300 ms bez dalšího vstupu.
  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = _searchController.text.trim();
      if (q == _debouncedSearchQuery) return;
      setState(() => _debouncedSearchQuery = q);
    });
  }

  static DateTime _getMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  void _prevWeek() =>
      setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() =>
      setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

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

  Future<void> _openEditTask(PlanningTask task) async {
    // PROČ: Kalendář používá odlehčený PlanningTask. Pro editaci musíme vždy načíst plný TaskRow,
    // jinak chybí service_id/reservation_id/client_id a dialog zobrazuje nekompletní data.
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final fullTaskRow = await ref.read(taskByIdProvider(task.id).future);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (fullTaskRow == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('task_detail.not_found'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      AdminTasksScreen.showEditTaskDialog(
        context,
        ref,
        fullTaskRow,
        onReservationTap:
            fullTaskRow.reservationId != null &&
                fullTaskRow.reservationId!.isNotEmpty
            ? (id) => unawaited(_navigateToReservation(context, ref, id))
            : null,
        onSaved: () {
          ref.invalidate(adminTasksProvider);
          ref.invalidate(adminTasksStreamProvider);
          invalidatePlanningCalendarCaches(ref);
        },
      );
    } catch (e, st) {
      AppLogger.error('PlanningCalendarScreen: načtení úkolu pro editaci selhalo', e, st);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.calendar_task_load_failed'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Zavře dialog úkolu, přepne na záložku Rezervace a otevře detail dané rezervace.
  ///
  /// PROČ: Rezervace nemusí být v aktuálním snapshotu streamu – při chybě nesmí spadnout celá aplikace.
  Future<void> _navigateToReservation(
    BuildContext context,
    WidgetRef ref,
    String reservationId,
  ) async {
    Navigator.of(context).pop();
    if (!context.mounted) return;
    try {
      final reservations = ref.read(adminReservationsProvider).valueOrNull ?? [];
      ReservationRow? reservation;
      for (final r in reservations) {
        if (r.id == reservationId) {
          reservation = r;
          break;
        }
      }
      reservation ??= await _fetchReservationRowForPlanning(ref, reservationId);

      if (!context.mounted) return;
      if (reservation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.calendar_reservation_load_failed'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
      AdminTabScope.of(context)?.call(adminTabIndexReservations);
      if (!context.mounted) return;
      AdminReservationsScreen.showEditReservationDialog(
        context,
        ref,
        reservation,
      );
    } catch (e, st) {
      AppLogger.error('PlanningCalendarScreen: navigace na rezervaci z kalendáře selhala', e, st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.calendar_reservation_load_failed'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
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
                    onChanged: (_) => _onSearchTextChanged(),
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
          // Řádek 2: kompaktní hlavička – navigace + dropdown vlevo, horizontálně scrollovatelná legenda vpravo.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Levé křídlo: navigace týdne + tlačítko Dnes + dropdown zaměstnanců.
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        foregroundColor: Colors.grey.shade800,
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: Text('planning_calendar.today'.tr()),
                    ),
                    const SizedBox(width: 16),
                    dataAsync.when(
                      data: (data) => SizedBox(
                        width: 160,
                        child: _FilterDropdown(
                          resources: data.resources,
                          selectedId: _selectedFilterId,
                          onChanged: (id) =>
                              setState(() => _selectedFilterId = id),
                        ),
                      ),
                      loading: () => const SizedBox(width: 160, height: 40),
                      error: (_, _) => const SizedBox(width: 160, height: 40),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Pravé křídlo: legenda scrolluje horizontálně, nezalamuje se.
                Expanded(child: TaskLegend(scrollHorizontally: true)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Kalendář v bílém kontejneru – Expanded zabere zbývající místo, mřížka scrolluje vertikálně.
          // Bottom overflow fix: vnitřek musí být v SingleChildScrollView, ne expandovat mimo obrazovku.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final dayColumnWidth = ((w - _timeColumnWidth) / 7).clamp(
                    80.0,
                    double.infinity,
                  );
                  final totalWidth = _timeColumnWidth + 7 * dayColumnWidth;
                  return SizedBox(
                    width: w,
                    height: h,
                    child: Container(
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
                              data: (data) {
                                final weekNorm = DateTime(
                                  _weekStart.year,
                                  _weekStart.month,
                                  _weekStart.day,
                                );
                                final layoutKey = PlanningWeekGridLayoutKey(
                                  weekMonday: weekNorm,
                                  selectedResourceFilterId: _selectedFilterId,
                                  searchQuery: _debouncedSearchQuery,
                                  taskDataFingerprint:
                                      PlanningWeekGridLayoutKey.computeTaskDataFingerprint(
                                    data.tasks,
                                  ),
                                );
                                final processed = ref.watch(
                                  planningWeekGridProcessedProvider(layoutKey),
                                );
                                return _WeekGridScrollBody(
                                  weekStart: _weekStart,
                                  data: data,
                                  processedTasks: processed,
                                  categoriesByCode:
                                      ref
                                          .watch(taskCategoriesProvider)
                                          .valueOrNull ??
                                      {},
                                  onTaskTap: _openEditTask,
                                  dayColumnWidth: dayColumnWidth,
                                  totalWidth: totalWidth,
                                  verticalScrollController:
                                      _verticalScrollController,
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, _) => Center(
                                child: Text(
                                  'planning_calendar.error'.tr(
                                    namedArgs: {'error': '$e'},
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                .map(
                  (r) => DropdownMenuItem<String?>(
                    value: r.id,
                    child: Text(r.displayName),
                  ),
                ),
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

/// Scrollovatelné tělo mřížky – pouze časové sloty a karty (hlavička dnů je sticky výše).
/// Po prvním sestavení posune viewport na 08:00 (začátek pracovní doby).
class _WeekGridScrollBody extends StatefulWidget {
  const _WeekGridScrollBody({
    required this.weekStart,
    required this.data,
    required this.processedTasks,
    required this.categoriesByCode,
    required this.onTaskTap,
    required this.dayColumnWidth,
    required this.totalWidth,
    required this.verticalScrollController,
  });

  final DateTime weekStart;
  final PlanningCalendarData data;
  /// Předpočítané pozice karet z [planningWeekGridProcessedProvider] – nepočítáme znovu v každém [build].
  final List<WeekProcessedTask> processedTasks;
  final Map<String, TaskCategoryModel> categoriesByCode;
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
      final maxExtent =
          widget.verticalScrollController.position.maxScrollExtent;
      widget.verticalScrollController.jumpTo(offset.clamp(0.0, maxExtent));
      if (mounted) setState(() => _initialScrollDone = true);
    });
  }

  _CardVisualState _visualState(PlanningTask task) {
    if (task.assignedTo == null) return _CardVisualState.critical;
    if (widget.data.conflictIds.contains(task.id)) {
      return _CardVisualState.conflict;
    }
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
          categoriesByCode: widget.categoriesByCode.isNotEmpty
              ? widget.categoriesByCode
              : null,
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
          categoriesByCode: widget.categoriesByCode.isNotEmpty
              ? widget.categoriesByCode
              : null,
        );
    }
  }

  /// Červená čára „teď“ (jako v Google Calendar) – zobrazí se jen když zobrazený týden obsahuje dnes.
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
      child: Container(color: Colors.red, child: const SizedBox.expand()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final processed = widget.processedTasks;
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
                final state = _visualState(p.task);
                final backgroundColor = _backgroundColorFor(state, p.task);
                final borderColor = _borderColorFor(state, p.task);
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

                final category = TaskVisuals.resolveCategory(
                  p.task.taskType,
                  widget.categoriesByCode,
                );
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
///
/// PROČ ochrana layoutu: u krátkých časových slotů je výška z [Positioned] malá; původní
/// [Column] s [mainAxisSize.min] měla intrinsickou výšku větší než constraint → RenderFlex overflow.
/// Řešení: [clipBehavior] + [ClipRect], prahy podle dostupné výšky (mikro/kompaktní/plná karta)
/// a u plné verze [FittedBox.scaleDown] pro druhé dva řádky, aby se vešly bez přetékání.
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

  /// Pod tuto výšku (po vnitřním paddingu) kreslíme jen ikonu – detail by stejně nebyl čitelný.
  static const double _microCardMaxHeight = 45;

  /// Mezi mikro a plnou kartou: jeden řádek ikona + kategorie (bez apartmánu a assignee).
  static const double _compactCardMaxHeight = 58;

  @override
  Widget build(BuildContext context) {
    final rawCode =
        category?.code ??
        (task.taskType.trim().isEmpty
            ? 'other'
            : task.taskType.toLowerCase().trim());
    // Normalizace: DB/formulář může mít "check-in", JSON má "check_in" – pomlčka -> podtržítko.
    final code = rawCode.replaceAll('-', '_');
    final categoryLabel = 'admin.task_type_$code'.tr();
    final apartmentLabel = task.apartmentName ?? task.title;
    final assigneeLabel =
        task.assignedUserName != null &&
            (task.assignedUserName!.trim().isNotEmpty)
        ? task.assignedUserName!
        : 'planning_calendar.unassigned_row'.tr();

    final taskIcon = TaskVisuals.getIcon(
      task.taskType,
      categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null,
    );
    final tooltipLines = <String>[
      categoryLabel,
      apartmentLabel,
      assigneeLabel,
    ].join('\n');

    return Padding(
      padding: const EdgeInsets.all(1),
      child: Tooltip(
        message: tooltipLines,
        waitDuration: const Duration(milliseconds: 500),
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
              clipBehavior: Clip.hardEdge,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxH = constraints.maxHeight;
                  final maxW = constraints.maxWidth;
                  final pad = maxH < _microCardMaxHeight ? 3.0 : 6.0;

                  if (maxH < _microCardMaxHeight) {
                    final iconSize = math.max(
                      10.0,
                      math.min(16.0, maxH - pad * 2),
                    );
                    return Padding(
                      padding: EdgeInsets.all(pad),
                      child: ClipRect(
                        child: Center(
                          child: Icon(
                            taskIcon,
                            size: iconSize,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                    );
                  }

                  if (maxH < _compactCardMaxHeight) {
                    return Padding(
                      padding: EdgeInsets.all(pad),
                      child: ClipRect(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(taskIcon, size: 11, color: _textPrimary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                categoryLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.all(pad),
                    child: ClipRect(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(taskIcon, size: 12, color: _textPrimary),
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
                          Expanded(
                            child: ClipRect(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: math.max(0, maxW - pad * 2),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
