/// Implementace ITaskRepository pro webovou platformu.
///
/// Web je vždy online – data se čtou přímo ze Supabase.
/// ŽÁDNÝ import isar ani .g.dart – tento soubor se kompiluje pro dart:html.
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';

class TaskRepositoryWeb implements ITaskRepository {
  @override
  Future<List<WorkerTask>> getWorkerTasks(String tenantId, String workerId) async {
    final now = DateTime.now().toUtc();
    final pastLimit = now.subtract(const Duration(days: 7)).toIso8601String();
    final futureLimit = now.add(const Duration(days: 14)).toIso8601String();

    final tasksData = await SupabaseService.client
        .from('tasks')
        .select(
          'id, tenant_id, apartment_id, assigned_to, title, description, task_type, scheduled_start, status, photo_url',
        )
        .eq('tenant_id', tenantId)
        .eq('assigned_to', workerId)
        .isFilter('deleted_at', null)
        .gte('scheduled_start', pastLimit)
        .lte('scheduled_start', futureLimit)
        .order('scheduled_start', ascending: true);

    final tasksList = tasksData is List ? List<dynamic>.from(tasksData) : <dynamic>[];

    final apartmentIds = <String>{};
    for (final t in tasksList) {
      final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
      final aptId = map['apartment_id']?.toString().trim();
      if (aptId != null && aptId.isNotEmpty) apartmentIds.add(aptId);
    }

    Map<String, ({String? name, String? address})> apartmentById = {};
    if (apartmentIds.isNotEmpty) {
      final aptData = await SupabaseService.client
          .from('apartments')
          .select('id, name, address')
          .inFilter('id', apartmentIds.toList())
          .isFilter('deleted_at', null);
      final aptList = aptData is List ? List<dynamic>.from(aptData) : <dynamic>[];
      for (final a in aptList) {
        final m = a is Map<String, dynamic> ? Map<String, dynamic>.from(a) : <String, dynamic>{};
        final id = m['id']?.toString().trim();
        if (id != null) {
          apartmentById[id] = (
            name: (m['name'] as String?)?.trim(),
            address: (m['address'] as String?)?.trim(),
          );
        }
      }
    }

    final result = <WorkerTask>[];
    for (final t in tasksList) {
      final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
      if (map.isEmpty) continue;
      final id = map['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      final status = (map['status'] as String?)?.trim() ?? '';
      if (status == 'completed') continue;

      final aptId = map['apartment_id']?.toString().trim() ?? '';
      final apt = apartmentById[aptId];

      final rawStart = map['scheduled_start'];
      DateTime scheduledStart;
      if (rawStart is DateTime) {
        scheduledStart = rawStart;
      } else if (rawStart is String) {
        scheduledStart = DateTime.tryParse(rawStart) ?? DateTime.now();
      } else {
        scheduledStart = DateTime.now();
      }

      result.add(WorkerTask(
        id: id,
        title: (map['title'] as String?)?.trim() ?? '',
        description: (map['description'] as String?)?.trim() ?? '',
        taskType: (map['task_type'] as String?)?.trim() ?? '',
        scheduledStart: scheduledStart.toLocal(),
        status: status,
        apartmentId: aptId,
        apartmentName: apt?.name,
        apartmentAddress: apt?.address,
      ));
    }
    result.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return result;
  }

  @override
  Future<WorkerTaskDetail?> getWorkerTaskDetail(String tenantId, String taskId) async {
    try {
      final res = await SupabaseService.client
          .from('tasks')
          .select('id, title, description, task_type, scheduled_start, status, apartment_id, photo_url')
          .eq('tenant_id', tenantId)
          .eq('id', taskId)
          .maybeSingle();
      if (res == null) return null;
      final map = Map<String, dynamic>.from(res as Map);
      final aptId = map['apartment_id']?.toString().trim();
      String? aptName;
      String? aptAddress;
      String? keybox;
      String? ownerNotes;
      if (aptId != null && aptId.isNotEmpty) {
        final aptRes = await SupabaseService.client
            .from('apartments')
            .select('name, address, keybox, owner_notes')
            .eq('id', aptId)
            .maybeSingle();
        if (aptRes != null) {
          final a = Map<String, dynamic>.from(aptRes as Map);
          aptName = (a['name'] as String?)?.trim();
          aptAddress = (a['address'] as String?)?.trim();
          keybox = (a['keybox'] as String?)?.trim();
          ownerNotes = (a['owner_notes'] as String?)?.trim();
        }
      }
      final rawStart = map['scheduled_start'];
      DateTime start;
      if (rawStart is DateTime) {
        start = rawStart;
      } else if (rawStart is String) {
        start = DateTime.tryParse(rawStart) ?? DateTime.now();
      } else {
        start = DateTime.now();
      }
      return WorkerTaskDetail(
        id: taskId,
        title: (map['title'] as String?)?.trim() ?? '',
        description: (map['description'] as String?)?.trim() ?? '',
        taskType: (map['task_type'] as String?)?.trim() ?? '',
        scheduledStart: start.toLocal(),
        status: (map['status'] as String?)?.trim() ?? '',
        apartmentId: aptId ?? '',
        apartmentName: aptName,
        apartmentAddress: aptAddress,
        keybox: keybox?.isEmpty ?? true ? null : keybox,
        ownerNotes: ownerNotes?.isEmpty ?? true ? null : ownerNotes,
        photoUrl: (map['photo_url'] as String?)?.trim().isEmpty ?? true ? null : (map['photo_url'] as String?)?.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateTaskStatus(String tenantId, String taskId, String status) async {
    await SupabaseService.client
        .from('tasks')
        .update({'status': status})
        .eq('id', taskId)
        .eq('tenant_id', tenantId);
  }
}

ITaskRepository getTaskRepository() => TaskRepositoryWeb();
