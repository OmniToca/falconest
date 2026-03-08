import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';

/// Sada dat pro operativní Nástěnku (Action Strip + střední zóna + manažerské grafy).
///
/// PROČ: Centralizuje výpočty metrik potřebných pro varovný "Action Strip"
/// – návrhy ke schválení, problémy z terénu, nevybraná hotovost.
/// Navíc data pro prémiové grafy (Business Overview).
class DashboardSummary {
  const DashboardSummary({
    required this.pendingTasksCount,
    required this.problemTasksCount,
    required this.employeesWithCashCount,
    required this.totalUncollectedCash,
    required this.profileIdsWithCash,
    required this.tasksComposition,
    required this.reservationsTrend,
  });

  /// Počet úkolů se statusem 'pending' (Task Automator) pro dnešek a zítřek.
  /// PROČ: Dispečer musí schválit návrhy před jejich přiřazením.
  final int pendingTasksCount;

  /// Počet úkolů se statusem 'problem' – hlášení z terénu (i offline).
  /// PROČ: Vyžadují okamžitou reakci dispečera.
  final int problemTasksCount;

  /// Počet zaměstnanců s nevybranou hotovostí (balance > 0).
  /// PROČ: Kontrola Zaměstnanecké pokladny – kdo má u sebe peníze.
  final int employeesWithCashCount;

  /// Celková suma nevybrané hotovosti u všech zaměstnanců v EUR.
  /// PROČ: Přehled o objemu peněz v terénu.
  final double totalUncollectedCash;

  /// Profile ID zaměstnanců, kteří mají u sebe nevybranou hotovost (balance > 0).
  /// PROČ: Ikona peněženky u pracovníků v sekci „Kdo je v akci“.
  final Set<String> profileIdsWithCash;

  /// Rozdělení dnešních úkolů podle typu – klíč = kategorie (Úklidy, Transfery, …), hodnota = počet.
  /// PROČ: Prstencový graf „Dnešní skladba úkolů“.
  final Map<String, int> tasksComposition;

  /// Počet příjezdů (check-in) na posledních 7 dní + dnešek + příštích 6 dní = 14 hodnot.
  /// Index 0 = před 7 dny, index 7 = dnes, index 13 = za 6 dní.
  /// PROČ: Čárový graf „Vývoj rezervací (14 dní)“.
  final List<int> reservationsTrend;
}

/// Mapuje raw task_type na kategorii pro graf (Úklidy, Transfery, Příjezdy, Odjezdy, Údržba, Jiné).
String _taskTypeToCategory(String taskType) {
  final t = taskType.trim().toLowerCase();
  if (t.contains('cleaning') || t.contains('úklid')) return 'Úklidy';
  if (t.contains('transfer_in') || (t.contains('transfer') && t.contains('in'))) return 'Transfery';
  if (t.contains('transfer_out') || (t.contains('transfer') && t.contains('out'))) return 'Transfery';
  if (t.contains('transfer')) return 'Transfery';
  if (t.contains('check_in')) return 'Příjezdy';
  if (t.contains('check_out')) return 'Odjezdy';
  if (t.contains('issue') || t.contains('material') || t.contains('údržba') || t.contains('závada')) return 'Údržba';
  return 'Jiné';
}

/// Parsuje check_in string (DD.MM.YYYY nebo yyyy-MM-dd) na DateTime.
DateTime? _parseCheckInDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(s.trim());
  if (parsed != null) return parsed;
  try {
    final parts = s.trim().split(RegExp(r'[\.\-\s]'));
    if (parts.length < 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    if (d > 31 || m > 12) return null;
    return DateTime(y, m, d);
  } catch (_) {
    return null;
  }
}

/// Provider agregující data pro Nástěnku – úkoly, hotovost, rezervace.
///
/// Závisí na adminDashboardTasksProvider (zúžené časové okno), employeeCashWalletsProvider, adminReservationsProvider.
final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final tasksAsync = ref.watch(adminDashboardTasksProvider);
  final walletsAsync = ref.watch(employeeCashWalletsProvider);
  final reservationsAsync = ref.watch(adminReservationsProvider);

  final tasks = tasksAsync.valueOrNull ?? [];
  final wallets = walletsAsync.valueOrNull ?? [];
  final reservations = reservationsAsync.valueOrNull ?? [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrowEnd = today.add(const Duration(days: 2));

  // pendingTasksCount: úkoly se statusem 'pending' pro dnešek a zítřek
  final pendingTasksCount = tasks.where((t) {
    final status = (t.status.trim().toLowerCase());
    if (status != 'pending' && status != 'draft' && status != 'navrh') {
      return false;
    }
    final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
    final day = DateTime(local.year, local.month, local.day);
    return !day.isBefore(today) && day.isBefore(tomorrowEnd);
  }).length;

  // problemTasksCount: všechny úkoly se statusem 'problem'
  final problemTasksCount = tasks.where((t) {
    final s = t.status.trim().toLowerCase();
    return s == 'problem' || s == 'problém' || s == 'issue';
  }).length;

  // Hotovost: zaměstnanci s balance > 0 + set profileId pro ikony v týmu
  double totalUncollectedCash = 0;
  int employeesWithCashCount = 0;
  final profileIdsWithCash = <String>{};

  for (final w in wallets) {
    final balance = w.balance;
    if (balance > 0) {
      employeesWithCashCount++;
      totalUncollectedCash += balance;
      final pid = w.profileId.trim();
      if (pid.isNotEmpty) profileIdsWithCash.add(pid);
    }
  }

  // tasksComposition: dnešní úkoly podle kategorie
  final todayForTasks = DateTime(now.year, now.month, now.day);
  final todayEndTasks = todayForTasks.add(const Duration(days: 1));
  final tasksComposition = <String, int>{};
  for (final t in tasks) {
    final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
    final day = DateTime(local.year, local.month, local.day);
    if (!day.isBefore(todayForTasks) && day.isBefore(todayEndTasks)) {
      final cat = _taskTypeToCategory(t.taskType);
      tasksComposition[cat] = (tasksComposition[cat] ?? 0) + 1;
    }
  }

  // reservationsTrend: 14 dní (7 zpět + dnes + 6 dopředu)
  final reservationsTrend = List<int>.filled(14, 0);
  final firstDay = today.subtract(const Duration(days: 7));
  for (final r in reservations) {
    if (r.status == 'cancelled') continue;
    final checkInDt = _parseCheckInDate(r.checkIn);
    if (checkInDt == null) continue;
    final checkInDay = DateTime(checkInDt.year, checkInDt.month, checkInDt.day);
    for (var i = 0; i < 14; i++) {
      final targetDay = firstDay.add(Duration(days: i));
      if (checkInDay.year == targetDay.year &&
          checkInDay.month == targetDay.month &&
          checkInDay.day == targetDay.day) {
        reservationsTrend[i]++;
        break;
      }
    }
  }

  return DashboardSummary(
    pendingTasksCount: pendingTasksCount,
    problemTasksCount: problemTasksCount,
    employeesWithCashCount: employeesWithCashCount,
    totalUncollectedCash: totalUncollectedCash,
    profileIdsWithCash: profileIdsWithCash,
    tasksComposition: tasksComposition,
    reservationsTrend: reservationsTrend,
  );
});
