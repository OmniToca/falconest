import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Model úkolu pro Worker Dashboard – načtený z Supabase (tasks + apartments).
class WorkerTask {
  const WorkerTask({
    required this.id,
    required this.title,
    required this.description,
    required this.taskType,
    required this.scheduledStart,
    required this.status,
    required this.apartmentId,
    this.apartmentName,
    this.apartmentAddress,
  });

  final String id;
  final String title;
  final String description;
  final String taskType;
  final DateTime scheduledStart;
  final String status;
  final String apartmentId;
  final String? apartmentName;
  final String? apartmentAddress;
}

/// Načte úkoly přiřazené aktuálnímu uživateli (Supabase).
///
/// Filtry: assigned_to == profile.id (na základě auth_id), status != 'done'.
/// Join s apartments pro name a address. Řazení podle scheduled_start asc.
final workerTasksProvider = FutureProvider<List<WorkerTask>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final user = SupabaseService.client.auth.currentUser;
  if (tenantId == null || tenantId.isEmpty || user == null) return [];

  try {
    final profileRes = await SupabaseService.client
        .from('profiles')
        .select('id')
        .eq('auth_id', user.id)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (profileRes == null) return [];
    final profileId = (profileRes['id'])?.toString();
    if (profileId == null || profileId.isEmpty) return [];

    final res = await SupabaseService.client
        .from('tasks')
        .select('id, title, description, task_type, scheduled_start, status, apartment_id, apartments(name, address)')
        .eq('tenant_id', tenantId)
        .eq('assigned_to', profileId)
        .isFilter('deleted_at', null)
        .neq('status', 'completed')
        .order('scheduled_start', ascending: true);

    return _parseTasks(res);
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('WorkerDashboard: FETCH ERROR: $e');
    }
    return [];
  }
});

List<WorkerTask> _parseTasks(dynamic res) {
  final list = res is List ? res : <dynamic>[];
  final tasks = <WorkerTask>[];

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
      String aptAddress = '';
      final apartment = map['apartments'];
      if (apartment != null) {
        final a = apartment is Map ? apartment : (apartment is List && apartment.isNotEmpty ? apartment[0] : null);
        if (a != null && a is Map) {
          aptName = (a['name']?.toString() ?? '').trim();
          aptAddress = (a['address']?.toString() ?? '').trim();
        }
      }

      tasks.add(WorkerTask(
        id: idStr,
        title: (map['title']?.toString() ?? '').trim(),
        description: (map['description']?.toString() ?? '').trim(),
        taskType: (map['task_type']?.toString() ?? 'Jiné').trim(),
        scheduledStart: start,
        status: (map['status']?.toString() ?? 'pending').trim(),
        apartmentId: (map['apartment_id']?.toString() ?? '').trim(),
        apartmentName: aptName.isEmpty ? null : aptName,
        apartmentAddress: aptAddress.isEmpty ? null : aptAddress,
      ));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('WorkerDashboard: SKIP task: $e');
      }
    }
  }
  return tasks;
}
