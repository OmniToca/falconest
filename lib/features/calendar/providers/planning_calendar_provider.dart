import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';

/// Speciální ID pro řádek "Nepřiřazeno" – phantom profil.
const String kUnassignedResourceId = '__unassigned__';

/// Jeden řádek zdroje (personál) v kalendáři – včetně phantom "Nepřiřazeno".
class CalendarResource {
  const CalendarResource({required this.id, required this.displayName, this.avatarLetter});

  final String id;
  final String displayName;
  final String? avatarLetter;
}

/// Úkol pro plánovací kalendář – unified profiles.
class PlanningTask {
  const PlanningTask({
    required this.id,
    required this.title,
    required this.description,
    required this.taskType,
    required this.scheduledStart,
    this.assignedTo,
    this.apartmentId,
    this.status,
    this.assignedUserName,
    this.apartmentName,
    this.metadata,
  });

  final String id;
  final String title;
  final String description;
  final String taskType;
  final DateTime scheduledStart;
  final String? assignedTo;
  final String? apartmentId;
  final String? status;
  final String? assignedUserName;
  final String? apartmentName;
  /// JSONB metadata z tasks (custom_note, amount_to_collect, expected_audit_total, collection_breakdown).
  final Map<String, dynamic>? metadata;

  String get resourceId => assignedTo ?? kUnassignedResourceId;

  PlanningTask copyWith({String? assignedUserName, String? apartmentName}) =>
      PlanningTask(
        id: id,
        title: title,
        description: description,
        taskType: taskType,
        scheduledStart: scheduledStart,
        assignedTo: assignedTo,
        apartmentId: apartmentId,
        status: status,
        assignedUserName: assignedUserName ?? this.assignedUserName,
        apartmentName: apartmentName ?? this.apartmentName,
        metadata: metadata,
      );

  TaskRow toTaskRow({DateTime? roundedDueDate}) => TaskRow(
        id: id,
        apartmentId: apartmentId ?? '',
        assignedTo: assignedTo,
        title: title,
        description: description,
        status: status ?? 'Návrh',
        taskType: taskType,
        dueDate: roundedDueDate ?? scheduledStart,
        apartmentName: apartmentName,
        assignedToName: assignedUserName,
        metadata: metadata,
      );
}

/// Zaokrouhlí datum na nejbližší 15 minut (lokální čas).
DateTime roundToNearest15Minutes(DateTime dt) {
  final local = dt.isUtc ? dt.toLocal() : dt;
  final minutes = local.minute + local.hour * 60;
  final rounded = ((minutes / 15).round() * 15) % (24 * 60);
  final hour = rounded ~/ 60;
  final min = rounded % 60;
  return DateTime(local.year, local.month, local.day, hour, min);
}

int parseDurationMinutesFromDescription(String? description) {
  if (description == null || description.trim().isEmpty) return 60;
  final s = description.trim();
  int minutes = 0;
  final hodReg = RegExp(r'(\d+)\s*hod', caseSensitive: false);
  final minReg = RegExp(r'(\d+)\s*min', caseSensitive: false);
  if (hodReg.firstMatch(s) != null) {
    minutes += int.parse(hodReg.firstMatch(s)!.group(1) ?? '0') * 60;
  }
  if (minReg.firstMatch(s) != null) {
    minutes += int.parse(minReg.firstMatch(s)!.group(1) ?? '0');
  }
  return minutes > 0 ? minutes : 60;
}

/// Parsuje metadata z JSONB – může přijít jako Map nebo null.
Map<String, dynamic>? _parseMetadata(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

List<PlanningTask> _parseTasksFromResponse(dynamic res) {
  final list = res is List ? res : <dynamic>[];
  final tasks = <PlanningTask>[];

  for (final e in list) {
    try {
      final map = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};

      final raw = map['scheduled_start'] ?? map['due_date'];
      if (raw == null) continue;
      final start = raw is DateTime
          ? raw.toLocal()
          : (raw is String ? DateTime.tryParse(raw)?.toLocal() : null);
      if (start == null) continue;

      final idStr = (map['id']?.toString() ?? '').trim();
      if (idStr.isEmpty) continue;

      String workerName = 'Nepřiřazeno';
      // BUGFIX: PostgREST vrací profiles pod klíčem profiles!tasks_assigned_to_fkey při explicitním FK.
      final profile = map['profiles'] ?? map['profiles!tasks_assigned_to_fkey'];
      if (profile != null) {
        final p = profile is Map
            ? profile
            : (profile is List && profile.isNotEmpty ? profile[0] : null);
        if (p != null && p is Map) {
          final first = (p['first_name']?.toString() ?? '').trim();
          final last = (p['last_name']?.toString() ?? '').trim();
          workerName = '$first $last'.trim();
          if (workerName.isEmpty) workerName = (p['name']?.toString() ?? '').trim();
          if (workerName.isEmpty) workerName = 'Nepřiřazeno';
        }
      }

      String aptName = 'Neznámý';
      final apartment = map['apartments'];
      if (apartment != null) {
        final a = apartment is Map
            ? apartment
            : (apartment is List && apartment.isNotEmpty ? apartment[0] : null);
        if (a != null && a is Map) {
          final n = (a['name']?.toString() ?? '').trim();
          if (n.isNotEmpty) aptName = n;
        }
      }

      tasks.add(PlanningTask(
        id: idStr,
        title: (map['title']?.toString() ?? '').trim(),
        description: (map['description']?.toString() ?? '').trim(),
        taskType: (map['task_type']?.toString() ?? 'Jiné').trim(),
        scheduledStart: start,
        assignedTo: (map['assigned_to']?.toString() ?? '').trim().isEmpty
            ? null
            : (map['assigned_to']?.toString() ?? '').trim(),
        apartmentId: (map['apartment_id']?.toString() ?? '').trim().isEmpty
            ? null
            : (map['apartment_id']?.toString() ?? '').trim(),
        status: (map['status']?.toString() ?? '').trim().isEmpty
            ? null
            : (map['status']?.toString() ?? '').trim(),
        assignedUserName: workerName,
        apartmentName: aptName == 'Neznámý' ? null : aptName,
        metadata: _parseMetadata(map['metadata']),
      ));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Calendar: SKIP corrupt task: $e');
      }
    }
  }
  return tasks;
}

/// Pastelové barvy pro personál (CASE C – NORMAL).
final List<Color> _pastelColors = [
  Colors.blue.shade100,
  Colors.green.shade100,
  Colors.purple.shade100,
  Colors.teal.shade100,
  Colors.indigo.shade100,
  Colors.cyan.shade100,
  Colors.lime.shade100,
];

Color getPastelColorForResource(String resourceId, int index) {
  return _pastelColors[index % _pastelColors.length];
}

/// Zpracovaný úkol pro týdenní mřížku – den, sloupec a počet sloupců pro rozložení.
class WeekProcessedTask {
  const WeekProcessedTask({
    required this.task,
    required this.dayIndex,
    required this.colIndex,
    required this.totalCols,
  });

  final PlanningTask task;
  /// Index dne v týdnu: 0 = pondělí, 6 = neděle.
  final int dayIndex;
  final int colIndex;
  final int totalCols;
}

/// Vrací seznam úkolů s přiřazeným dayIndex, colIndex a totalCols pro týdenní pohled.
/// Překrývání se řeší po DNECH napříč VŠEMI úkoly (všechny zdroje dohromady), aby úkoly
/// různých lidí ve stejný čas byly vedle sebe (sdílení šířky sloupce), ne přes sebe.
List<WeekProcessedTask> getProcessedTasksForWeek(
  List<PlanningTask> tasks,
  DateTime weekStartMonday,
  int gridStartHour,
) {
  final weekStartNorm = DateTime(
    weekStartMonday.year,
    weekStartMonday.month,
    weekStartMonday.day,
  );
  final result = <WeekProcessedTask>[];
  final startMin = gridStartHour * 60;

  for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
    final dayStart = weekStartNorm.add(Duration(days: dayIndex));
    final dayTasks = tasks.where((t) {
      final td = DateTime(
        t.scheduledStart.year,
        t.scheduledStart.month,
        t.scheduledStart.day,
      );
      return td == dayStart;
    }).toList();
    if (dayTasks.isEmpty) continue;

    final events = dayTasks.map((t) {
      final m = t.scheduledStart.hour * 60 + t.scheduledStart.minute - startMin;
      final dur = parseDurationMinutesFromDescription(t.description);
      return (task: t, start: m.toDouble(), end: (m + dur).toDouble());
    }).where((e) => e.end > 0).toList();
    events.sort((a, b) => a.start.compareTo(b.start));

    final columns = <double>[];
    final processed = <({PlanningTask task, int colIndex})>[];
    for (final e in events) {
      var col = 0;
      while (col < columns.length && columns[col] > e.start) {
        col++;
      }
      if (col == columns.length) columns.add(0);
      columns[col] = e.end;
      processed.add((task: e.task, colIndex: col));
    }
    final totalCols = columns.length;
    for (final p in processed) {
      result.add(WeekProcessedTask(
        task: p.task,
        dayIndex: dayIndex,
        colIndex: p.colIndex,
        totalCols: totalCols,
      ));
    }
  }
  return result;
}

/// Detekce konfliktů: stejný assigned_to, překrývající se čas.
/// Vrací množinu ID úkolů, které jsou v konfliktu.
Set<String> detectConflicts(List<PlanningTask> tasks) {
  final conflicts = <String>{};
  final byResource = <String, List<PlanningTask>>{};
  for (final t in tasks) {
    byResource.putIfAbsent(t.resourceId, () => []).add(t);
  }
  for (final resourceTasks in byResource.values) {
    final byDay = <int, List<({PlanningTask task, double start, double end})>>{};
    for (final t in resourceTasks) {
      final dayKey = t.scheduledStart.year * 10000 + t.scheduledStart.month * 100 + t.scheduledStart.day;
      final startMin = t.scheduledStart.hour * 60 + t.scheduledStart.minute;
      final dur = parseDurationMinutesFromDescription(t.description);
      byDay.putIfAbsent(dayKey, () => []).add((
        task: t,
        start: startMin.toDouble(),
        end: (startMin + dur).toDouble(),
      ));
    }
    for (final dayEvents in byDay.values) {
      for (var i = 0; i < dayEvents.length; i++) {
        final a = dayEvents[i];
        for (var j = i + 1; j < dayEvents.length; j++) {
          final b = dayEvents[j];
          if (a.start < b.end && a.end > b.start) {
            conflicts.add(a.task.id);
            conflicts.add(b.task.id);
          }
        }
      }
    }
  }
  return conflicts;
}

/// Načte VŠECHNY úkoly pro týden.
final planningCalendarAllTasksProvider =
    FutureProvider.family<List<PlanningTask>, DateTime>((ref, weekStart) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final weekEnd = start.add(const Duration(days: 7));

  try {
    final res = await SupabaseService.client
        .from('tasks')
        .select(
            'id, title, description, task_type, scheduled_start, due_date, status, assigned_to, apartment_id, metadata, profiles!tasks_assigned_to_fkey(first_name, last_name, name), apartments(name)')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .gte('scheduled_start', start.toUtc().toIso8601String())
        .lt('scheduled_start', weekEnd.toUtc().toIso8601String())
        .order('scheduled_start', ascending: true);

    return _parseTasksFromResponse(res);
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Calendar: FETCH ERROR: $e');
    }
    return [];
  }
});

/// Načte VŠECHNY úkoly pro daný měsíc (pro TableCalendar měsíční pohled).
final planningCalendarAllTasksForMonthProvider =
    FutureProvider.family<List<PlanningTask>, DateTime>((ref, dayInMonth) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final start = DateTime(dayInMonth.year, dayInMonth.month, 1);
  final end = DateTime(dayInMonth.year, dayInMonth.month + 1, 1);

  try {
    final res = await SupabaseService.client
        .from('tasks')
        .select(
            'id, title, description, task_type, scheduled_start, due_date, status, assigned_to, apartment_id, metadata, profiles!tasks_assigned_to_fkey(first_name, last_name, name), apartments(name)')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .gte('scheduled_start', start.toUtc().toIso8601String())
        .lt('scheduled_start', end.toUtc().toIso8601String())
        .order('scheduled_start', ascending: true);

    return _parseTasksFromResponse(res);
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Calendar: FETCH ERROR: $e');
    }
    return [];
  }
});

/// Kombinovaná data: zdroje, úkoly, konflikty, mapy barev.
class PlanningCalendarData {
  const PlanningCalendarData({
    required this.resources,
    required this.tasks,
    required this.conflictIds,
    required this.pastelColorByResourceId,
  });

  final List<CalendarResource> resources;
  final List<PlanningTask> tasks;
  final Set<String> conflictIds;
  final Map<String, Color> pastelColorByResourceId;
}

/// Poskytuje zdroje, úkoly, detekci konfliktů a pastelové barvy.
final planningCalendarDataProvider =
    FutureProvider.family<PlanningCalendarData, DateTime>((ref, weekStart) async {
  final teamAsync = ref.watch(adminTeamProvider);
  final tasksAsync = ref.watch(planningCalendarAllTasksProvider(weekStart));

  final members = teamAsync.valueOrNull ?? [];
  final tasks = tasksAsync.valueOrNull ?? [];

  final conflictIds = detectConflicts(tasks);

  final resources = <CalendarResource>[
    const CalendarResource(id: kUnassignedResourceId, displayName: 'NEPŘIŘAZENO', avatarLetter: '?'),
    ...members.asMap().entries.map((e) {
      final m = e.value;
      final name = m.name.isNotEmpty ? m.name : (m.email ?? '?');
      final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
      return CalendarResource(
        id: m.dropdownId,
        displayName: name,
        avatarLetter: letter,
      );
    }),
  ];

  final pastelColorByResourceId = <String, Color>{};
  for (var i = 0; i < resources.length; i++) {
    if (resources[i].id != kUnassignedResourceId) {
      pastelColorByResourceId[resources[i].id] = getPastelColorForResource(resources[i].id, i - 1);
    }
  }

  return PlanningCalendarData(
    resources: resources,
    tasks: tasks,
    conflictIds: conflictIds,
    pastelColorByResourceId: pastelColorByResourceId,
  );
});

/// Data kalendáře pro celý měsíc – pro TableCalendar (zdroje + úkoly + konflikty + barvy).
final planningCalendarDataForMonthProvider =
    FutureProvider.family<PlanningCalendarData, DateTime>((ref, dayInMonth) async {
  final teamAsync = ref.watch(adminTeamProvider);
  final tasksAsync = ref.watch(planningCalendarAllTasksForMonthProvider(dayInMonth));

  final members = teamAsync.valueOrNull ?? [];
  final tasks = tasksAsync.valueOrNull ?? [];

  final conflictIds = detectConflicts(tasks);

  final resources = <CalendarResource>[
    const CalendarResource(id: kUnassignedResourceId, displayName: 'NEPŘIŘAZENO', avatarLetter: '?'),
    ...members.asMap().entries.map((e) {
      final m = e.value;
      final name = m.name.isNotEmpty ? m.name : (m.email ?? '?');
      final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
      return CalendarResource(
        id: m.dropdownId,
        displayName: name,
        avatarLetter: letter,
      );
    }),
  ];

  final pastelColorByResourceId = <String, Color>{};
  for (var i = 0; i < resources.length; i++) {
    if (resources[i].id != kUnassignedResourceId) {
      pastelColorByResourceId[resources[i].id] = getPastelColorForResource(resources[i].id, i - 1);
    }
  }

  return PlanningCalendarData(
    resources: resources,
    tasks: tasks,
    conflictIds: conflictIds,
    pastelColorByResourceId: pastelColorByResourceId,
  );
});
