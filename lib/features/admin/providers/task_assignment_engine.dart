// ============================================================================
// 🔒🔒🔒 LOCKED CORE BUSINESS LOGIC - DO NOT TOUCH 🔒🔒🔒
// CZECH COMMENT: TOTO JE KRITICKÉ JÁDRO SYSTÉMU (LOAD BALANCING, ZÓNY, ČASOVÁNÍ).
// AI STRICT RULE: ABSOLUTNÍ ZÁKAZ MĚNIT TENTO SOUBOR BEZ EXPLICITNÍHO POVOLENÍ!
// ============================================================================

import 'dart:math';

import 'package:falconest/features/admin/providers/admin_team_provider.dart';

/// ID pro přiřazení do úkolu: u aktivních profileId, u čekajících na přihlášení id z invitations.
String assignableId(TeamMember m) => m.profileId ?? m.id;

/// Vrací prioritu zóny pro řazení kandidátů. 1 = nejraději, 2–5 = dojedu, chybí = 99 (Nouzová záchrana).
/// Čím nižší číslo, tím vyšší priorita. Používá se pro weighted sorting.
int zonePreferencePriority(TeamMember m, String? zoneId) {
  if (zoneId == null || zoneId.isEmpty) return 99;
  final prefs = m.zonePreferences;
  if (prefs == null || prefs.isEmpty) return 99;
  final val = prefs[zoneId];
  if (val == null) return 99;
  if (val >= 1 && val <= 5) return val;
  return 99;
}

/// Parsuje datum z raw hodnoty (DateTime, String ISO) – pro čtení scheduled_start/due_date z úkolů.
DateTime? parseTaskDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw.trim());
  return null;
}

/// Parsuje datum a VŽDY vrací DateTime v UTC – pro spolehlivou detekci kolizí (bez mixu lokál/UTC).
/// Podporuje DateTime, String (ISO), int (epoch ms). Externí volající používají [parseTaskDateTime].
DateTime? _parseTaskDateTimeUtc(dynamic raw) {
  if (raw == null) return null;
  DateTime? dt;
  if (raw is DateTime) {
    dt = raw;
  } else if (raw is String) {
    dt = DateTime.tryParse(raw.trim());
  } else if (raw is int) {
    dt = DateTime.fromMillisecondsSinceEpoch(raw);
  }
  if (dt != null) {
    return dt.isUtc ? dt : dt.toUtc();
  }
  return null;
}

/// Chytrý výpočet trvání blokace úkolu v minutách podle typu služby.
/// Pro úklid striktně sčítáme čistý čas úklidu apartmánu a časovou rezervu ze služby (vata).
/// U ostatních služeb bereme jen čas služby (fallback 60 min).
int taskBlockDurationMinutes({
  required String serviceType,
  required int apartmentStandardCleaning,
  required int serviceDurationMinutes,
}) {
  if (serviceType.toLowerCase() == 'cleaning') {
    return apartmentStandardCleaning + serviceDurationMinutes;
  }
  return serviceDurationMinutes > 0 ? serviceDurationMinutes : 60;
}

/// Kontrola časového překryvu dvou intervalů.
/// Překryv platí: (novýStart < stávajícíKonec) && (novýKonec > stávajícíStart).
bool _tasksOverlap(
    DateTime newStart, DateTime newEnd, DateTime existingStart, DateTime existingEnd) {
  return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
}

/// Rovnoměrné rozložení S KONTROLOU KOLIZÍ: z kandidátů vybere toho, kdo má v daný den nejméně práce
/// a zároveň nemá v časovém okně [taskStart, taskEnd] žádný jiný úkol (z existingTasksRaw ani toInsert).
///
/// Překryv: (taskStart < stávajícíKonec) && (taskEnd > stávajícíStart) → kandidát vyřazen.
/// Ze zbylých (volných) kandidátů vybere toho s minimálním počtem úkolů za daný den.
///
/// [isSacredTask] – Svaté úkoly (check-in, check-out, transfery) NESMÍ být posouvány v čase.
/// Při kolizi všech kandidátů vrací Nepřiřazeno. Flexibilní úkoly (úklid, údržba) hledají volný slot
/// v dynamickém okně mezi odjezdem hosta a příjezdem dalšího (deadline), max 100 iterací po 30 min.
/// [applyNightRest] – pokud true, respektuje pracovní dobu 07:00–19:00; mimo ni přesouvá na 7:00.
({String? assignTo, DateTime start, DateTime end}) pickAssigneeWithCollisionAvoidance({
  required List<TeamMember> candidates,
  required DateTime taskStart,
  required DateTime taskEnd,
  required DateTime deadline,
  required bool applyNightRest,
  required List<dynamic> existingTasksRaw,
  required List<Map<String, dynamic>> toInsert,
  String? zoneId,
  bool isSacredTask = false,
}) {
  if (candidates.isEmpty) {
    return (assignTo: null, start: taskStart.toLocal(), end: taskEnd.toLocal());
  }

  // Normalizace vstupů na UTC – všechny porovnávání kolizí probíhá v jednom časovém systému.
  var taskStartUtc = taskStart.toUtc();
  var taskEndUtc = taskEnd.toUtc();
  final deadlineUtc = deadline.toUtc();

  final taskDuration = taskEndUtc.difference(taskStartUtc);
  /// Posun v minutách při kolizi – pouze pro flexibilní úkoly (úklid, údržba).
  const int shiftMinutes = 30;
  /// Štědrý limit iterací pro dlouhé úklidy (až 5 h) – hledání volného slotu v okně do deadline.
  const int maxShiftIterations = 100;

  for (int shiftAttempt = 0; shiftAttempt < (isSacredTask ? 1 : maxShiftIterations); shiftAttempt++) {
    DateTime tryStart = taskStartUtc.add(Duration(minutes: shiftAttempt * shiftMinutes));
    DateTime tryEnd = tryStart.add(taskDuration);

    // Kontrola deadline: pokud by posunutý úklid skončil až po příjezdu dalšího hosta, ukonči hledání.
    if (tryEnd.isAfter(deadlineUtc)) break;

    // Pracovní doba 07:00–19:00 (v lokálním čase pro výpočet okna): úkoly s applyNightRest nesmí spadat mimo toto okno.
    if (applyNightRest) {
      var tryStartLocal = tryStart.toLocal();
      if (tryStartLocal.hour < 7) {
        final atSeven = DateTime(tryStartLocal.year, tryStartLocal.month, tryStartLocal.day, 7, 0, 0);
        tryStart = atSeven.toUtc();
        tryEnd = tryStart.add(taskDuration);
        tryStartLocal = tryStart.toLocal();
      }
      final workDayEnd = DateTime(tryStartLocal.year, tryStartLocal.month, tryStartLocal.day, 19, 0, 0);
      if (tryStartLocal.isAfter(workDayEnd)) {
        // Následující kalendářní den v lokálním čase, pak 07:00 a převod do UTC.
        final nextLocalDay = DateTime(tryStartLocal.year, tryStartLocal.month, tryStartLocal.day).add(const Duration(days: 1));
        tryStart = DateTime(nextLocalDay.year, nextLocalDay.month, nextLocalDay.day, 7, 0, 0).toUtc();
        tryEnd = tryStart.add(taskDuration);
      }
    }

    if (tryEnd.isAfter(deadlineUtc)) break;

    // Pro každého kandidáta: zkontrolovat, zda má v okně [tryStart, tryEnd] nějaký úkol (vše v UTC).
    final freeCandidates = <TeamMember>[];
    for (final c in candidates) {
      final id = assignableId(c);
      if (id.isEmpty) continue;

      bool hasOverlap = false;

      // Kontrola existujících úkolů v DB – parsování v UTC + pojistka start <= end.
      for (final raw in existingTasksRaw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final assigned = map['assigned_to']?.toString().trim();
        if (assigned != id) continue;
        var exStartDt = _parseTaskDateTimeUtc(map['scheduled_start']);
        var exEndDt = _parseTaskDateTimeUtc(map['due_date']);
        exStartDt = exStartDt ?? exEndDt;
        exEndDt = exEndDt ?? exStartDt;
        if (exStartDt == null || exEndDt == null) continue;
        if (exStartDt.isAfter(exEndDt)) {
          final temp = exStartDt;
          exStartDt = exEndDt;
          exEndDt = temp;
        }
        if (_tasksOverlap(tryStart, tryEnd, exStartDt, exEndDt)) {
          hasOverlap = true;
          break;
        }
      }
      if (hasOverlap) continue;

      // Kontrola už naplánovaných úkolů v dávce k vložení – parsování v UTC + pojistka start <= end.
      for (final m in toInsert) {
        final assigned = m['assigned_to']?.toString().trim();
        if (assigned != id) continue;
        var exStartDt = _parseTaskDateTimeUtc(m['scheduled_start']);
        var exEndDt = _parseTaskDateTimeUtc(m['due_date']);
        exStartDt = exStartDt ?? exEndDt;
        exEndDt = exEndDt ?? exStartDt;
        if (exStartDt == null || exEndDt == null) continue;
        if (exStartDt.isAfter(exEndDt)) {
          final temp = exStartDt;
          exStartDt = exEndDt;
          exEndDt = temp;
        }
        if (_tasksOverlap(tryStart, tryEnd, exStartDt, exEndDt)) {
          hasOverlap = true;
          break;
        }
      }
      if (!hasOverlap) freeCandidates.add(c);
    }

    if (freeCandidates.isNotEmpty) {
      // Denní a klouzavý týdenní rozsah pro Load Balancing (v UTC, aby odpovídal parsovaným dt).
      final dayStart = DateTime.utc(tryStart.year, tryStart.month, tryStart.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final weekStart = dayStart.subtract(const Duration(days: 3));
      final weekEnd = dayStart.add(const Duration(days: 4));

      final dailyCounts = <String, int>{};
      final weeklyCounts = <String, int>{};
      for (final c in freeCandidates) {
        final id = assignableId(c);
        dailyCounts[id] = 0;
        weeklyCounts[id] = 0;
      }

      // Projdi existující úkoly a naplň denní a týdenní počítadla (dt v UTC z _parseTaskDateTimeUtc).
      for (final raw in existingTasksRaw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final assigned = map['assigned_to']?.toString().trim();
        if (assigned == null || !dailyCounts.containsKey(assigned)) continue;
        final dt = _parseTaskDateTimeUtc(map['scheduled_start']) ?? _parseTaskDateTimeUtc(map['due_date']);
        if (dt == null) continue;
        if (!dt.isBefore(dayStart) && dt.isBefore(dayEnd)) {
          dailyCounts[assigned] = dailyCounts[assigned]! + 1;
        }
        if (!dt.isBefore(weekStart) && dt.isBefore(weekEnd)) {
          weeklyCounts[assigned] = weeklyCounts[assigned]! + 1;
        }
      }
      for (final m in toInsert) {
        final aid = m['assigned_to']?.toString().trim();
        if (aid == null || !dailyCounts.containsKey(aid)) continue;
        final dt = _parseTaskDateTimeUtc(m['scheduled_start']) ?? _parseTaskDateTimeUtc(m['due_date']);
        if (dt == null) continue;
        if (!dt.isBefore(dayStart) && dt.isBefore(dayEnd)) {
          dailyCounts[aid] = dailyCounts[aid]! + 1;
        }
        if (!dt.isBefore(weekStart) && dt.isBefore(weekEnd)) {
          weeklyCounts[aid] = weeklyCounts[aid]! + 1;
        }
      }

      final minDaily = dailyCounts.values.isEmpty ? 0 : dailyCounts.values.reduce(min);
      final minWeekly = weeklyCounts.values.isEmpty ? 0 : weeklyCounts.values.reduce(min);
      final maxDailyAllowed = minDaily + 2;
      final maxWeeklyAllowed = minWeekly + 3;

      freeCandidates.shuffle();
      freeCandidates.sort((a, b) {
        final dCountA = dailyCounts[assignableId(a)] ?? 0;
        final wCountA = weeklyCounts[assignableId(a)] ?? 0;
        final dCountB = dailyCounts[assignableId(b)] ?? 0;
        final wCountB = weeklyCounts[assignableId(b)] ?? 0;
        final isOverA = dCountA >= maxDailyAllowed || wCountA >= maxWeeklyAllowed;
        final isOverB = dCountB >= maxDailyAllowed || wCountB >= maxWeeklyAllowed;
        if (isOverA && !isOverB) return 1;
        if (!isOverA && isOverB) return -1;
        final zoneA = zonePreferencePriority(a, zoneId);
        final zoneB = zonePreferencePriority(b, zoneId);
        if (zoneA != zoneB) return zoneA.compareTo(zoneB);
        return dCountA.compareTo(dCountB);
      });
      final winner = freeCandidates.first;
      return (assignTo: assignableId(winner), start: tryStart.toLocal(), end: tryEnd.toLocal());
    }
    if (isSacredTask) break;
  }

  return (assignTo: null, start: taskStartUtc.toLocal(), end: taskEndUtc.toLocal());
}

// ============================================================================
// 🔒🔒🔒 END OF LOCKED CORE BUSINESS LOGIC 🔒🔒🔒
// ============================================================================
