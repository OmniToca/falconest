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

/// Posun okna při hledání volného místa – 60 minut dopředu.
const int _shiftMinutes = 60;

/// Rovnoměrné rozložení S KONTROLOU KOLIZÍ: z kandidátů vybere toho, kdo má v daný den nejméně práce
/// a zároveň nemá v časovém okně [taskStart, taskEnd] žádný jiný úkol (z existingTasksRaw ani toInsert).
///
/// Překryv: (taskStart < stávajícíKonec) && (taskEnd > stávajícíStart) → kandidát vyřazen.
/// Ze zbylých (volných) kandidátů vybere toho s minimálním počtem úkolů za daný den.
///
/// [deadline] – úkol nesmí končit po této chvíli; při kolizi se posouvá až do deadline.
/// [applyNightRest] – pokud true, úkol nesmí spadat do 20:00–07:00 (noční klid); při spadu se přesune na 7:00.
/// attempts < 100 – bezpečnostní pojistka proti zamrznutí UI.
({String? assignTo, DateTime start, DateTime end}) pickAssigneeWithCollisionAvoidance({
  required List<TeamMember> candidates,
  required DateTime taskStart,
  required DateTime taskEnd,
  required DateTime deadline,
  required bool applyNightRest,
  required List<dynamic> existingTasksRaw,
  required List<Map<String, dynamic>> toInsert,
  String? zoneId,
}) {
  if (candidates.isEmpty) {
    return (assignTo: null, start: taskStart, end: taskEnd);
  }

  final taskDuration = taskEnd.difference(taskStart);
  DateTime tryStart = taskStart;
  DateTime tryEnd = taskEnd;
  int attempts = 0;

  while (tryEnd.isBefore(deadline) && attempts < 100) {

    // Noční klid (20:00–07:00): úkoly mimo transfer/check-in/out se přesouvají na 7:00.
    if (applyNightRest) {
      if (tryStart.hour >= 20) {
        final nextDay = tryStart.add(const Duration(days: 1));
        tryStart = DateTime(nextDay.year, nextDay.month, nextDay.day, 7, 0, 0);
        tryEnd = tryStart.add(taskDuration);
      } else if (tryStart.hour < 7) {
        tryStart = DateTime(tryStart.year, tryStart.month, tryStart.day, 7, 0, 0);
        tryEnd = tryStart.add(taskDuration);
      }
    }

    // Pro každého kandidáta: zkontrolovat, zda má v okně [tryStart, tryEnd] nějaký úkol
    final freeCandidates = <TeamMember>[];
    for (final c in candidates) {
      final id = assignableId(c);
      if (id.isEmpty) continue;

      bool hasOverlap = false;

      // Kontrola existujících úkolů v DB
      for (final raw in existingTasksRaw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final assigned = map['assigned_to']?.toString().trim();
        if (assigned != id) continue;
        final exStart = parseTaskDateTime(map['scheduled_start']);
        final exEnd = parseTaskDateTime(map['due_date']);
        final exStartDt = exStart ?? exEnd;
        final exEndDt = exEnd ?? exStart;
        if (exStartDt == null || exEndDt == null) continue;
        if (_tasksOverlap(tryStart, tryEnd, exStartDt, exEndDt)) {
          hasOverlap = true;
          break;
        }
      }
      if (hasOverlap) continue;

      // Kontrola už naplánovaných úkolů v dávce k vložení
      for (final m in toInsert) {
        final assigned = m['assigned_to'] as String?;
        if (assigned != id) continue;
        final exStart = parseTaskDateTime(m['scheduled_start']);
        final exEnd = parseTaskDateTime(m['due_date']);
        final exStartDt = exStart ?? exEnd;
        final exEndDt = exEnd ?? exStart;
        if (exStartDt == null || exEndDt == null) continue;
        if (_tasksOverlap(tryStart, tryEnd, exStartDt, exEndDt)) {
          hasOverlap = true;
          break;
        }
      }
      if (!hasOverlap) freeCandidates.add(c);
    }

    if (freeCandidates.isNotEmpty) {
      // Denní a klouzavý týdenní rozsah pro Load Balancing
      final dayStart = DateTime(tryStart.year, tryStart.month, tryStart.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      // Klouzavý týden (3 dny zpět, 4 dny dopředu) – ochrana proti přetížení v okně ±3 dny
      final weekStart = dayStart.subtract(const Duration(days: 3));
      final weekEnd = dayStart.add(const Duration(days: 4));

      final dailyCounts = <String, int>{};
      final weeklyCounts = <String, int>{};
      for (final c in freeCandidates) {
        final id = assignableId(c);
        dailyCounts[id] = 0;
        weeklyCounts[id] = 0;
      }

      // Projdi existující úkoly a naplň denní a týdenní počítadla
      for (final raw in existingTasksRaw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final assigned = map['assigned_to']?.toString().trim();
        if (assigned == null || !dailyCounts.containsKey(assigned)) continue;
        final exStart = parseTaskDateTime(map['scheduled_start']);
        final exEnd = parseTaskDateTime(map['due_date']);
        final dt = exStart ?? exEnd;
        if (dt == null) continue;
        if (!dt.isBefore(dayStart) && dt.isBefore(dayEnd)) {
          dailyCounts[assigned] = dailyCounts[assigned]! + 1;
        }
        if (!dt.isBefore(weekStart) && dt.isBefore(weekEnd)) {
          weeklyCounts[assigned] = weeklyCounts[assigned]! + 1;
        }
      }
      for (final m in toInsert) {
        final aid = m['assigned_to'] as String?;
        if (aid == null || !dailyCounts.containsKey(aid)) continue;
        final dt = parseTaskDateTime(m['scheduled_start']) ?? parseTaskDateTime(m['due_date']);
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
      // Nastavení přísných tolerancí pro Load Balancing
      final maxDailyAllowed = minDaily + 2; // Denní limit: max +2 úkoly navíc
      final maxWeeklyAllowed = minWeekly + 3; // Týdenní limit: max +3 úkoly navíc

      freeCandidates.shuffle();
      freeCandidates.sort((a, b) {
        final dCountA = dailyCounts[assignableId(a)] ?? 0;
        final wCountA = weeklyCounts[assignableId(a)] ?? 0;
        final dCountB = dailyCounts[assignableId(b)] ?? 0;
        final wCountB = weeklyCounts[assignableId(b)] ?? 0;
        final isOverA = dCountA >= maxDailyAllowed || wCountA >= maxWeeklyAllowed;
        final isOverB = dCountB >= maxDailyAllowed || wCountB >= maxWeeklyAllowed;
        // 1. PRAVIDLO: Absolutní ochrana před přetížením (Denní i Týdenní)
        if (isOverA && !isOverB) return 1; // B vyhrává (A je přetížený)
        if (!isOverA && isOverB) return -1; // A vyhrává (B je přetížený)
        // 2. PRAVIDLO: Zónová priorita (Kdo je místní?)
        final zoneA = zonePreferencePriority(a, zoneId);
        final zoneB = zonePreferencePriority(b, zoneId);
        if (zoneA != zoneB) return zoneA.compareTo(zoneB);
        // 3. PRAVIDLO: Spravedlnost v daný den (kdo z místních má méně práce)
        return dCountA.compareTo(dCountB);
      });
      final winner = freeCandidates.first;
      return (assignTo: assignableId(winner), start: tryStart, end: tryEnd);
    }

    // Chytré posunutí: posunout okno o 60 min dopředu a zkusit znovu (až do deadline).
    tryStart = tryStart.add(const Duration(minutes: _shiftMinutes));
    tryEnd = tryStart.add(taskDuration);
    attempts++;
  }

  return (assignTo: null, start: taskStart, end: taskEnd);
}

// ============================================================================
// 🔒🔒🔒 END OF LOCKED CORE BUSINESS LOGIC 🔒🔒🔒
// ============================================================================
