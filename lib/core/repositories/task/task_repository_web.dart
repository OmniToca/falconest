/// Implementace ITaskRepository pro webovou platformu.
///
/// Web je vždy online – data se čtou přímo ze Supabase.
/// ŽÁDNÝ import isar ani .g.dart – tento soubor se kompiluje pro dart:html.
library;
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';

class TaskRepositoryWeb implements ITaskRepository {
  @override
  Future<List<WorkerTask>> getWorkerTasks(String tenantId, String workerId) async {
    final now = DateTime.now().toUtc();
    final pastLimit = now.subtract(const Duration(days: 7)).toIso8601String();
    final futureLimit = now.add(const Duration(days: 14)).toIso8601String();

    // PROČ: Archivace. Vyfakturované úkoly (invoiced_at != null) schováváme z aktivních pohledů.
    // Worker vidí úkol, pokud je v assigned_to NEBO v assigned_user_ids.
    final tasksData = await SupabaseService.safeFrom('tasks', tenantId)
        .select(
          'id, tenant_id, apartment_id, assigned_to, assigned_user_ids, title, description, task_type, scheduled_start, status, photo_url, reference_number',
        )
        .or('assigned_to.eq.$workerId,assigned_user_ids.cs.{$workerId}')
        .isFilter('deleted_at', null)
        .isFilter('invoiced_at', null)
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
      final aptData = await SupabaseService.safeFrom('apartments', tenantId)
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

      final refNum = (map['reference_number'] as String?)?.trim();
      result.add(WorkerTask(
        id: id,
        title: (map['title'] as String?)?.trim() ?? '',
        description: (map['description'] as String?)?.trim() ?? '',
        taskType: (map['task_type'] as String?)?.trim() ?? '',
        scheduledStart: scheduledStart.toLocal(),
        status: status,
        apartmentId: aptId,
        referenceNumber: (refNum != null && refNum.isNotEmpty) ? refNum : null,
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
      final res = await SupabaseService.safeFrom('tasks', tenantId)
          .select('id, title, description, task_type, scheduled_start, status, apartment_id, client_id, custom_location, custom_title, reservation_id, photo_url, metadata, media_urls, started_at, completed_at, reference_number')
          .eq('id', taskId)
          .maybeSingle();
      if (res == null) return null;
      final map = Map<String, dynamic>.from(res as Map);
      final aptId = map['apartment_id']?.toString().trim();
      final resId = map['reservation_id']?.toString().trim();
      String? aptName;
      String? aptAddress;
      String? keybox;
      String? ownerNotes;
      if (aptId != null && aptId.isNotEmpty) {
        final aptRes = await SupabaseService.safeFrom('apartments', tenantId)
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
      String? clientName;
      String? clientPhone;
      final clientId = map['client_id']?.toString().trim();
      if (clientId != null && clientId.isNotEmpty) {
        final clientRes = await SupabaseService.safeFrom('clients', tenantId)
            .select('name, phone')
            .eq('id', clientId)
            .isFilter('deleted_at', null)
            .maybeSingle();
        if (clientRes != null) {
          final cMap = Map<String, dynamic>.from(clientRes as Map);
          final n = (cMap['name'] as String?)?.trim();
          if (n != null && n.isNotEmpty) clientName = n;
          final p = (cMap['phone'] as String?)?.trim();
          if (p != null && p.isNotEmpty) clientPhone = p;
        }
      }
      String? guestName;
      String? guestPhone;
      if (resId != null && resId.isNotEmpty) {
        final resRes = await SupabaseService.safeFrom('reservations', tenantId)
            .select('guest_name, guest_phone')
            .eq('id', resId)
            .maybeSingle();
        if (resRes != null) {
          final r = Map<String, dynamic>.from(resRes as Map);
          guestName = (r['guest_name'] as String?)?.trim();
          guestPhone = (r['guest_phone'] as String?)?.trim();
          if (guestName != null && guestName.isEmpty) guestName = null;
          if (guestPhone != null && guestPhone.isEmpty) guestPhone = null;
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
      final rawMeta = map['metadata'];
      Map<String, dynamic>? metadata;
      if (rawMeta != null) {
        metadata = Map<String, dynamic>.from(rawMeta as Map);
      }
      final mediaUrls = _parseMediaUrls(map['media_urls']);

      final customLoc = (map['custom_location'] as String?)?.trim();
      final customTtl = (map['custom_title'] as String?)?.trim();

      final refNum = (map['reference_number'] as String?)?.trim();
      return WorkerTaskDetail(
        id: taskId,
        title: (map['title'] as String?)?.trim() ?? '',
        referenceNumber: (refNum != null && refNum.isNotEmpty) ? refNum : null,
        description: (map['description'] as String?)?.trim() ?? '',
        taskType: (map['task_type'] as String?)?.trim() ?? '',
        scheduledStart: start.toLocal(),
        status: (map['status'] as String?)?.trim() ?? '',
        apartmentId: aptId ?? '',
        apartmentName: aptName,
        apartmentAddress: aptAddress,
        customLocation: customLoc?.isEmpty ?? true ? null : customLoc,
        customTitle: customTtl?.isEmpty ?? true ? null : customTtl,
        clientName: clientName,
        clientPhone: clientPhone,
        keybox: keybox?.isEmpty ?? true ? null : keybox,
        ownerNotes: ownerNotes?.isEmpty ?? true ? null : ownerNotes,
        guestName: guestName,
        guestPhone: guestPhone,
        photoUrl: (map['photo_url'] as String?)?.trim().isEmpty ?? true ? null : (map['photo_url'] as String?)?.trim(),
        mediaUrls: mediaUrls,
        metadata: metadata,
        startedAt: _parseOptDateTime(map['started_at']),
        completedAt: _parseOptDateTime(map['completed_at']),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateTaskStatus(
    String tenantId,
    String taskId,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadataOverlay,
    List<String>? mediaUrls,
    List<String>? localPhotoPaths,
    List<String>? existingMediaUrls,
  }) async {
    final updates = <String, dynamic>{'status': status};
    if (startedAt != null) updates['started_at'] = startedAt.toUtc().toIso8601String();
    if (completedAt != null) updates['completed_at'] = completedAt.toUtc().toIso8601String();
    if (mediaUrls != null) updates['media_urls'] = mediaUrls;

    if (metadataOverlay != null && metadataOverlay.isNotEmpty) {
      final res = await SupabaseService.safeFrom('tasks', tenantId)
          .select('metadata')
          .eq('id', taskId)
          .maybeSingle();
      final existing = res != null
          ? Map<String, dynamic>.from(res['metadata'] as Map)
          : <String, dynamic>{};
      final merged = Map<String, dynamic>.from(existing)..addAll(metadataOverlay);
      updates['metadata'] = merged;
    }

    await SupabaseService.safeFrom('tasks', tenantId)
        .update(updates)
        .eq('id', taskId);
  }

  static DateTime? _parseOptDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static List<String> _parseMediaUrls(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return const [];
  }
}

ITaskRepository getTaskRepository() => TaskRepositoryWeb();
