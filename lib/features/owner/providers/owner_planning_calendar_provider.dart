import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_planning_calendar_apartment_filter_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';

/// Provider úkolů pro Plánovací kalendář v Klientském portálu.
///
/// SECURITY: Double Guard a filtrace draftů pro kalendář.
/// Stejná logika jako ownerTasksProvider – ownedApartmentIds, early exit,
/// .inFilter('apartment_id', ...). Nestahuje profiles (jména personálu).
final ownerPlanningCalendarTasksProvider =
    FutureProvider.autoDispose.family<List<PlanningTask>, DateTime>((ref, weekStart) async {
  // PROČ: Při změně filtru bytu znovu načteme úkoly pro stejný týden.
  ref.watch(ownerPlanningCalendarApartmentFilterProvider);

  final apartments = await ref.read(ownerApartmentsProvider.future);
  final ownedApartmentIds = apartments
      .map((a) => a.id)
      .where((id) => id.isNotEmpty)
      .toList();

  // Early exit: uživatel nevlastní žádný apartmán.
  if (ownedApartmentIds.isEmpty) return [];

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final filterApartmentId = ref.watch(ownerPlanningCalendarApartmentFilterProvider);
  final apartmentIdsForQuery =
      (filterApartmentId != null &&
              filterApartmentId.isNotEmpty &&
              ownedApartmentIds.contains(filterApartmentId))
          ? <String>[filterApartmentId]
          : ownedApartmentIds;

  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final weekEnd = start.add(const Duration(days: 7));

  try {
    // BUGFIX: Dvojitá ochrana – úkoly POUZE pro vlastněné byty.
    // Nestahujeme profiles – ochrana soukromí personálu.
    // PROČ: Archivace. Vyfakturované úkoly (invoiced_at != null) schováváme z aktivních pohledů.
    final res = await SupabaseService.safeFrom('tasks', tenantId)
        .select(
          'id, title, description, task_type, scheduled_start, due_date, status, '
          'assigned_to, apartment_id, metadata, media_urls, apartments(name)',
        )
        .inFilter('apartment_id', apartmentIdsForQuery)
        .isFilter('deleted_at', null)
        .isFilter('invoiced_at', null)
        .gte('scheduled_start', start.toUtc().toIso8601String())
        .lt('scheduled_start', weekEnd.toUtc().toIso8601String())
        .order('scheduled_start', ascending: true);

    final parsed = _parseTasksForOwner(res);

    // SECURITY: Odstranění interních návrhů z pohledu majitele.
    return parsed.where((t) => !_isDraftStatus(t.status)).toList();
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('OwnerCalendar: FETCH ERROR: $e');
    }
    return [];
  }
});

/// Parsuje odpověď z Supabase pro majitele – bez profiles (assignedUserName vždy null).
List<PlanningTask> _parseTasksForOwner(dynamic res) {
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

      String aptName = '';
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

      final rawTaskType = (map['task_type']?.toString() ?? '').trim();
      final taskType = rawTaskType.isEmpty ? 'other' : rawTaskType;

      DateTime? dueParsed;
      final dueRaw = map['due_date'];
      if (dueRaw != null) {
        dueParsed = dueRaw is DateTime
            ? dueRaw.toLocal()
            : (dueRaw is String ? DateTime.tryParse(dueRaw)?.toLocal() : null);
      }

      tasks.add(PlanningTask(
        id: idStr,
        title: (map['title']?.toString() ?? '').trim(),
        description: (map['description']?.toString() ?? '').trim(),
        taskType: taskType,
        scheduledStart: start,
        dueDate: dueParsed,
        assignedTo: (map['assigned_to']?.toString() ?? '').trim().isEmpty
            ? null
            : (map['assigned_to']?.toString() ?? '').trim(),
        apartmentId: (map['apartment_id']?.toString() ?? '').trim().isEmpty
            ? null
            : (map['apartment_id']?.toString() ?? '').trim(),
        status: ((map['status']?.toString() ?? '').trim()).isEmpty
            ? null
            : (map['status']?.toString() ?? '').trim(),
        assignedUserName: null, // Ochrana soukromí: jména personálu nenačítáme.
        apartmentName: aptName.isEmpty ? null : aptName,
        metadata: _parseMetadata(map['metadata']),
        mediaUrls: _parseMediaUrls(map['media_urls']),
      ));
    } catch (err) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('OwnerCalendar: SKIP corrupt task: $err');
      }
    }
  }
  return tasks;
}

Map<String, dynamic>? _parseMetadata(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

/// Parsuje media_urls (text[]) z PostgreSQL – stejná logika jako TaskRow.
List<String> _parseMediaUrls(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    final list = <String>[];
    for (final e in raw) {
      final s = e?.toString().trim();
      if (s != null && s.isNotEmpty) list.add(s);
    }
    return list;
  }
  return const [];
}

bool _isDraftStatus(String? status) {
  if (status == null || status.trim().isEmpty) return false;
  final lower = status.trim().toLowerCase();
  return lower == 'draft' ||
      lower == 'pending' ||
      lower == 'návrh' ||
      lower == 'navrh';
}
