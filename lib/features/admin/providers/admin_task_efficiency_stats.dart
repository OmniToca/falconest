import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';

/// **Omezení zdroje dat:** volá se nad seznamem z [adminDashboardTasksProvider], tedy úkoly s plánem
/// (`scheduled_start`) v **aktuálním a příštím kalendářním měsíci**. Dokončené úklidy,
/// jejichž plán leží mimo tento řez, se v metrikách neobjeví (bez nového dotazu do DB dle zadání).
///
/// Výchozí odhad délky úklidu v minutách, pokud v úkolech chybí `metadata.estimated_minutes`.
///
/// PROČ: Bez změny schématu DB používáme odhad z metadat úkolů; konstanta je bezpečný fallback pro prázdná data.
const int kAdminDefaultEstimatedCleaningMinutes = 60;

/// Jedna denní „přihrádka“ pro graf (posledních 7 kalendářních dní včetně dneška).
///
/// PROČ: Agregujeme dokončené úklidy podle **data dokončení** (`completed_at`), ne podle plánu – reflektuje skutečně odvedenou práci.
class AdminTaskEfficiencyDayBucket {
  const AdminTaskEfficiencyDayBucket({
    required this.dayLocalMidnight,
    required this.averageActualMinutes,
    required this.sampleCount,
  });

  /// Lokální půlnoc daného dne (začátek dne).
  final DateTime dayLocalMidnight;
  final double? averageActualMinutes;
  final int sampleCount;
}

/// Souhrn metrik efektivity pro kartu na nástěnce (Data Insights).
///
/// PROČ: Čistá funkce nad [TaskRow] – stejná data jako [adminDashboardTasksProvider], bez nových dotazů do DB.
class AdminTaskEfficiencySummary {
  const AdminTaskEfficiencySummary({
    required this.days,
    required this.estimatedMinutesBaseline,
    required this.averageStartDelayMinutes,
    required this.delaySampleCount,
    required this.durationSampleCountTotal,
  });

  final List<AdminTaskEfficiencyDayBucket> days;
  final int estimatedMinutesBaseline;
  final double? averageStartDelayMinutes;
  final int delaySampleCount;
  final int durationSampleCountTotal;

  bool get hasAnyDurationInChart => days.any((d) => d.sampleCount > 0);
  bool get hasDelayData => delaySampleCount > 0;
}

/// Heuristika typu úklid (shodná logika jako u stavu apartmánů v repozitáři).
bool adminTaskEfficiencyIsCleaningTask(TaskRow t) {
  final raw = t.taskType.toLowerCase().trim();
  return raw == 'cleaning' ||
      raw.contains('cleaning') ||
      raw.contains('úklid') ||
      raw.contains('uklid');
}

int? _estimatedMinutesFromMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  final v = metadata['estimated_minutes'];
  if (v is int) return v;
  if (v is num) return v.round();
  return null;
}

DateTime _localDateOnly(DateTime dt) {
  final l = dt.toLocal();
  return DateTime(l.year, l.month, l.day);
}

bool _sameLocalDate(DateTime a, DateTime dayMidnightLocal) {
  final la = _localDateOnly(a);
  return la.year == dayMidnightLocal.year &&
      la.month == dayMidnightLocal.month &&
      la.day == dayMidnightLocal.day;
}

/// Agreguje metriky z úkolů načtených pro nástěnku.
///
/// **Zpoždění zahájení:** `started_at` − `scheduled_start` (jen nezáporné minuty = opravdové zpoždění).
/// **Délka práce:** `completed_at` − `started_at` u dokončených úklidů v daném dni.
AdminTaskEfficiencySummary computeAdminTaskEfficiencySummary(List<TaskRow> tasks) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final windowStart = todayStart.subtract(const Duration(days: 6));

  bool completedInLast7Days(DateTime? completedAt) {
    if (completedAt == null) return false;
    final d = _localDateOnly(completedAt);
    return !d.isBefore(windowStart) && !d.isAfter(todayStart);
  }

  final estimates = <int>[];
  for (final t in tasks) {
    if (!adminTaskEfficiencyIsCleaningTask(t)) continue;
    final em = _estimatedMinutesFromMetadata(t.metadata);
    if (em != null && em > 0 && em <= 24 * 60) estimates.add(em);
  }
  estimates.sort();
  final baseline = estimates.isEmpty
      ? kAdminDefaultEstimatedCleaningMinutes
      : estimates[estimates.length ~/ 2];

  final delaySamples = <double>[];
  for (final t in tasks) {
    if (!adminTaskEfficiencyIsCleaningTask(t)) continue;
    if (!completedInLast7Days(t.completedAt)) continue;
    final sched = t.scheduledStart;
    final started = t.startedAt;
    if (sched == null || started == null) continue;
    final delayMin = started.difference(sched).inMinutes;
    if (delayMin >= 0) delaySamples.add(delayMin.toDouble());
  }

  final dayList = <DateTime>[
    for (var i = 6; i >= 0; i--) todayStart.subtract(Duration(days: i)),
  ];

  final buckets = <AdminTaskEfficiencyDayBucket>[];
  var durationTotal = 0;
  for (final day in dayList) {
    final durations = <double>[];
    for (final t in tasks) {
      if (!adminTaskEfficiencyIsCleaningTask(t)) continue;
      final completed = t.completedAt;
      final started = t.startedAt;
      if (completed == null || started == null) continue;
      if (!_sameLocalDate(completed, day)) continue;
      if (!completed.isAfter(started)) continue;
      final mins = completed.difference(started).inMinutes.toDouble();
      if (mins <= 0 || mins > 12 * 60) continue;
      durations.add(mins);
    }
    durationTotal += durations.length;
    buckets.add(
      AdminTaskEfficiencyDayBucket(
        dayLocalMidnight: day,
        averageActualMinutes: durations.isEmpty
            ? null
            : durations.reduce((a, b) => a + b) / durations.length,
        sampleCount: durations.length,
      ),
    );
  }

  final avgDelay = delaySamples.isEmpty
      ? null
      : delaySamples.reduce((a, b) => a + b) / delaySamples.length;

  return AdminTaskEfficiencySummary(
    days: buckets,
    estimatedMinutesBaseline: baseline,
    averageStartDelayMinutes: avgDelay,
    delaySampleCount: delaySamples.length,
    durationSampleCountTotal: durationTotal,
  );
}
