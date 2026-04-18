import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';

bool _isCompletedStatus(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  return s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo';
}

DateTime? _parseDt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Web: dotaz na Supabase – nedávná dokončení + filtr na aktuální kalendářní měsíc v lokálním čase (shodně s Driftem).
///
/// PROČ: Stejná business logika jako [DriftTaskRepository.watchMonthlyMotivationStats]; přiřazení jako [TaskRepositoryWeb].
Future<WorkerMonthMotivationStats> _fetchMonthlyMotivationFromSupabase({
  required String tenantId,
  required String workerId,
}) async {
  final now = DateTime.now();
  // Ořez jen podle UTC měsíce by mohl vynechat dokončení u hranic časových pásem; stáhneme krátkou historii a filtrujeme lokální měsíc jako Drift.
  final qFrom = now.subtract(const Duration(days: 45)).toUtc();

  final data = await SupabaseService.safeFrom('tasks', tenantId)
      .select('status, scheduled_start, started_at, completed_at')
      .or('assigned_to.eq.$workerId,assigned_user_ids.cs.{$workerId}')
      .isFilter('deleted_at', null)
      .not('completed_at', 'is', null)
      .gte('completed_at', qFrom.toIso8601String());

  final list = data is List ? List<dynamic>.from(data) : <dynamic>[];

  final monthStartLocal = DateTime(now.year, now.month, 1);
  final monthEndExclusiveLocal = DateTime(now.year, now.month + 1, 1);

  var completedCount = 0;
  var workedMinutesTotal = 0.0;
  var onTimeCount = 0;
  var onTimeEligible = 0;

  for (final row in list) {
    final m = row is Map<String, dynamic> ? Map<String, dynamic>.from(row) : <String, dynamic>{};
    if (!_isCompletedStatus(m['status']?.toString())) continue;

    final ca = _parseDt(m['completed_at']);
    if (ca == null) continue;
    final localDone = ca.toLocal();
    if (localDone.isBefore(monthStartLocal) || !localDone.isBefore(monthEndExclusiveLocal)) {
      continue;
    }

    completedCount++;

    final sa = _parseDt(m['started_at']);
    if (sa != null) {
      final dur = ca.difference(sa);
      if (dur.inMinutes > 0 && dur.inHours <= 16) {
        workedMinutesTotal += dur.inMinutes.toDouble();
      }
    }

    final sched = _parseDt(m['scheduled_start']);
    if (sched == null) continue;
    onTimeEligible++;
    final sd = DateTime(sched.toLocal().year, sched.toLocal().month, sched.toLocal().day);
    final dd = DateTime(localDone.year, localDone.month, localDone.day);
    if (sd == dd) {
      onTimeCount++;
    }
  }

  return WorkerMonthMotivationStats(
    completedCount: completedCount,
    workedHours: workedMinutesTotal / 60.0,
    onTimeCount: onTimeCount,
    onTimeEligibleCount: onTimeEligible,
  );
}

/// Webová varianta – [FutureProvider], obnoví se při invalidaci (pull-to-refresh na dashboardu).
final workerMotivationStatsProvider =
    FutureProvider.autoDispose<WorkerMonthMotivationStats>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final workerId = ref.watch(authNotifierProvider).profileId;
  if (tenantId == null ||
      tenantId.isEmpty ||
      workerId == null ||
      workerId.isEmpty) {
    return const WorkerMonthMotivationStats(
      completedCount: 0,
      workedHours: 0,
      onTimeCount: 0,
      onTimeEligibleCount: 0,
    );
  }
  return _fetchMonthlyMotivationFromSupabase(tenantId: tenantId, workerId: workerId);
});
