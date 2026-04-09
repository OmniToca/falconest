// Agregované statistiky týdne – typ sdílený mezi mobilním (Drift) a webovým providerem.

/// Agregované statistiky úkolů pro aktuální kalendářní týden (po–ne).
class WeeklyStats {
  const WeeklyStats({
    required this.totalTasks,
    required this.totalEstimatedMinutes,
  });

  final int totalTasks;
  final int totalEstimatedMinutes;

  /// Hodiny pro zobrazení (minuty / 60, zaokrouhleno na 1 des. místo).
  double get totalHours => totalEstimatedMinutes / 60.0;
}

/// Vrátí začátek aktuálního týdne (pondělí 00:00) v lokálním čase.
/// PROČ: ISO 8601 týden začíná pondělím – konzistentní s evropským kalendářem.
DateTime weeklyStatsStartOfWeek(DateTime now) {
  final daysFromMonday = now.weekday - 1;
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromMonday));
}

/// Vrátí konec aktuálního týdne (neděle 23:59:59.999) v lokálním čase.
DateTime weeklyStatsEndOfWeek(DateTime now) {
  final start = weeklyStatsStartOfWeek(now);
  return start.add(const Duration(
    days: 6,
    hours: 23,
    minutes: 59,
    seconds: 59,
    milliseconds: 999,
  ));
}

/// Filtruje úkoly, jejichž scheduledStart spadá do aktuálního kalendářního týdne.
bool weeklyStatsIsScheduledInCurrentWeek(DateTime scheduledStart) {
  final now = DateTime.now();
  final start = weeklyStatsStartOfWeek(now);
  final end = weeklyStatsEndOfWeek(now);
  return !scheduledStart.isBefore(start) && !scheduledStart.isAfter(end);
}
