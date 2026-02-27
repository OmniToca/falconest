/// Implementace ITaskRepository pro mobilní/desktop platformy (iOS, Android, macOS, Windows).
///
/// Čte z lokální Isar databáze – offline-first. Tento soubor importuje Isar,
/// kompiluje se pouze pro dart:io (ne web).
import 'dart:convert';

import 'package:isar/isar.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/apartment_local.dart';
import 'package:falconest/core/database/models/client_local.dart';
import 'package:falconest/core/database/models/reservation_local.dart';
import 'package:falconest/core/database/models/sync_status.dart';
import 'package:falconest/core/database/models/task_local.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';

class TaskRepositoryMobile implements ITaskRepository {
  @override
  Future<List<WorkerTask>> getWorkerTasks(String tenantId, String workerId) async {
    final isar = IsarService.instance;
    final taskLocals = isar.taskLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .assignedUserSupabaseIdEqualTo(workerId)
        .findAllSync();

    // Dashboard zobrazuje jen assigned a in_progress – vyloučení pending (návrhů) i completed.
    final filtered = taskLocals.where((t) {
      final s = t.status.trim().toLowerCase();
      if (s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo') return false;
      if (s == 'pending' || s == 'draft' || s == 'nový' || s == 'new') return false;
      return true;
    }).toList();
    filtered.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    return _mapToWorkerTasks(isar, filtered);
  }

  List<WorkerTask> _mapToWorkerTasks(Isar isar, List<TaskLocal> taskLocals) {
    final result = <WorkerTask>[];
    for (final t in taskLocals) {
      final idStr = t.supabaseId ?? '';
      if (idStr.isEmpty) continue;

      String? aptName;
      String? aptAddress;
      if (t.apartmentSupabaseId != null && t.apartmentSupabaseId!.isNotEmpty) {
        final apt = isar.apartmentLocals
            .filter()
            .supabaseIdEqualTo(t.apartmentSupabaseId)
            .findFirstSync();
        if (apt != null) {
          aptName = apt.name.trim().isEmpty ? null : apt.name.trim();
          aptAddress = (apt.address?.trim().isEmpty ?? true) ? null : apt.address?.trim();
        }
      }

      final refNum = t.referenceNumber?.trim();
      result.add(WorkerTask(
        id: idStr,
        title: t.title.trim(),
        description: t.description.trim(),
        taskType: t.taskType.trim(),
        scheduledStart: t.scheduledStart.toLocal(),
        status: t.status.trim(),
        apartmentId: t.apartmentSupabaseId?.trim() ?? '',
        referenceNumber: (refNum != null && refNum.isNotEmpty) ? refNum : null,
        apartmentName: aptName,
        apartmentAddress: aptAddress,
      ));
    }
    return result;
  }

  @override
  Future<WorkerTaskDetail?> getWorkerTaskDetail(String tenantId, String taskId) async {
    final isar = IsarService.instance;
    final task = isar.taskLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .supabaseIdEqualTo(taskId)
        .findFirstSync();
    if (task == null) return null;
    ApartmentLocal? apt;
    if (task.apartmentSupabaseId != null && task.apartmentSupabaseId!.isNotEmpty) {
      apt = isar.apartmentLocals
          .filter()
          .supabaseIdEqualTo(task.apartmentSupabaseId)
          .findFirstSync();
    }
    // PROČ: Načtení guest_name a guest_phone z rezervace pro check-in/transfer (kontakt na hosta v terénu).
    String? guestName;
    String? guestPhone;
    if (task.reservationSupabaseId != null && task.reservationSupabaseId!.trim().isNotEmpty) {
      final res = isar.reservationLocals
          .filter()
          .tenantIdEqualTo(tenantId)
          .supabaseIdEqualTo(task.reservationSupabaseId!)
          .findFirstSync();
      if (res != null) {
        guestName = res.guestName?.trim().isEmpty == true ? null : res.guestName?.trim();
        guestPhone = res.guestPhone?.trim().isEmpty == true ? null : res.guestPhone?.trim();
      }
    }
    // PROČ: Načtení jména klienta z ClientLocal pro externí úkoly (ruční transfer bez rezervace).
    String? clientName;
    if (task.clientSupabaseId != null && task.clientSupabaseId!.trim().isNotEmpty) {
      final client = isar.clientLocals
          .filter()
          .tenantIdEqualTo(tenantId)
          .supabaseIdEqualTo(task.clientSupabaseId!)
          .findFirstSync();
      if (client != null && client.name.trim().isNotEmpty) {
        clientName = client.name.trim();
      }
    }
    final refNum = task.referenceNumber?.trim();
    return WorkerTaskDetail(
      id: task.supabaseId ?? taskId,
      title: task.title.trim(),
      referenceNumber: (refNum != null && refNum.isNotEmpty) ? refNum : null,
      description: task.description.trim(),
      taskType: task.taskType.trim(),
      scheduledStart: task.scheduledStart.toLocal(),
      status: task.status.trim(),
      apartmentId: task.apartmentSupabaseId?.trim() ?? '',
      apartmentName: apt != null && apt.name.trim().isNotEmpty ? apt.name.trim() : null,
      apartmentAddress: apt != null && (apt.address?.trim().isEmpty ?? true) == false ? apt.address!.trim() : null,
      customLocation: (task.customLocation?.trim().isEmpty ?? true) ? null : task.customLocation!.trim(),
      customTitle: (task.customTitle?.trim().isEmpty ?? true) ? null : task.customTitle!.trim(),
      clientName: clientName,
      keybox: apt != null && (apt.keybox?.trim().isEmpty ?? true) == false ? apt.keybox!.trim() : null,
      ownerNotes: apt != null && (apt.ownerNotes?.trim().isEmpty ?? true) == false ? apt.ownerNotes!.trim() : null,
      guestName: guestName,
      guestPhone: guestPhone,
      photoUrl: (task.photoUrl?.trim().isEmpty ?? true) ? null : task.photoUrl,
      mediaUrls: const [], // Isar TaskLocal nemá media_urls – získá se při pull ze Supabase
      metadata: _parseMetadata(task.metadataJson),
      startedAt: task.startedAt,
      completedAt: task.completedAt,
    );
  }

  /// Rozparsuje metadataJson string na Map (null-safe).
  static Map<String, dynamic>? _parseMetadata(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
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
  }) async {
    final isar = IsarService.instance;
    final task = isar.taskLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .supabaseIdEqualTo(taskId)
        .findFirstSync();
    if (task == null) return;

    // PROČ: Dokončení s fotkami vyžaduje síť (upload). Provedeme přímý Supabase update
    // včetně media_urls, aby se nevyužila Isar sync fronta (nemá media_urls).
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      final updates = <String, dynamic>{
        'status': status,
        'media_urls': mediaUrls,
      };
      if (startedAt != null) updates['started_at'] = startedAt.toUtc().toIso8601String();
      if (completedAt != null) updates['completed_at'] = completedAt.toUtc().toIso8601String();
      if (metadataOverlay != null && metadataOverlay.isNotEmpty) {
        final res = await SupabaseService.client
            .from('tasks')
            .select('metadata')
            .eq('id', taskId)
            .eq('tenant_id', tenantId)
            .maybeSingle();
        final existing = res != null && res is Map
            ? (res['metadata'] is Map ? Map<String, dynamic>.from(res['metadata'] as Map) : <String, dynamic>{})
            : <String, dynamic>{};
        updates['metadata'] = {...existing, ...metadataOverlay};
      }
      await SupabaseService.client
          .from('tasks')
          .update(updates)
          .eq('id', taskId)
          .eq('tenant_id', tenantId);
      // Aktualizace lokálního Isar záznamu – syncStatus=synced, aby sync znovu neposílal.
      isar.writeTxnSync(() {
        task.status = status.trim();
        task.localUpdatedAt = DateTime.now().toUtc();
        task.lastUpdated = DateTime.now().toUtc();
        task.lastSyncedAt = DateTime.now().toUtc();
        task.syncStatus = SyncStatus.synced;
        if (startedAt != null) task.startedAt = startedAt.toUtc();
        if (completedAt != null) task.completedAt = completedAt.toUtc();
        if (metadataOverlay != null && metadataOverlay.isNotEmpty) {
          final existing = _parseMetadata(task.metadataJson) ?? {};
          task.metadataJson = jsonEncode({...existing, ...metadataOverlay});
        }
        _applyReservationStatusOnComplete(isar, tenantId, task, status);
        isar.taskLocals.putSync(task);
      });
      return;
    }

    isar.writeTxnSync(() {
      task.status = status.trim();
      task.localUpdatedAt = DateTime.now().toUtc();
      task.lastUpdated = DateTime.now().toUtc();
      task.syncStatus = SyncStatus.pending;
      // Uložení přesného UTC času pro sledování reálné doby práce.
      if (startedAt != null) task.startedAt = startedAt.toUtc();
      if (completedAt != null) task.completedAt = completedAt.toUtc();
      if (metadataOverlay != null && metadataOverlay.isNotEmpty) {
        final existing = _parseMetadata(task.metadataJson) ?? {};
        final merged = Map<String, dynamic>.from(existing)..addAll(metadataOverlay);
        task.metadataJson = jsonEncode(merged);
      }
      _applyReservationStatusOnComplete(isar, tenantId, task, status);
      isar.taskLocals.putSync(task);
    });
  }

  /// Sdílená logika: změna statusu rezervace při dokončení Check-in/Check-out.
  static void _applyReservationStatusOnComplete(
    Isar isar,
    String tenantId,
    dynamic task,
    String status,
  ) {
    // Byznysové pravidlo: Jakmile pracovník fyzicky dokončí Check-in úkol, automaticky posouváme
      // celou rezervaci do stavu checked_in. Řešeno offline-first.
      final isCheckInComplete =
          status.trim().toLowerCase() == 'completed' &&
          (task.taskType.contains('check_in') || task.taskType.contains('check-in'));
      if (isCheckInComplete &&
          task.reservationSupabaseId != null &&
          task.reservationSupabaseId!.trim().isNotEmpty) {
        final res = isar.reservationLocals
            .filter()
            .tenantIdEqualTo(tenantId)
            .supabaseIdEqualTo(task.reservationSupabaseId!)
            .findFirstSync();
        if (res != null) {
          res.status = 'checked_in';
          res.localUpdatedAt = DateTime.now().toUtc();
          res.lastUpdated = DateTime.now().toUtc();
          res.syncStatus = SyncStatus.pending;
          isar.reservationLocals.putSync(res);
        }
      }

      // Byznysové pravidlo: Dokončením úkolu Check-out automaticky měníme stav celé rezervace
      // na checked_out. Synchronizováno offline-first.
      final isCheckOutComplete =
          status.trim().toLowerCase() == 'completed' &&
          (task.taskType.contains('check_out') || task.taskType.contains('checkout'));
      if (isCheckOutComplete &&
          task.reservationSupabaseId != null &&
          task.reservationSupabaseId!.trim().isNotEmpty) {
        final res = isar.reservationLocals
            .filter()
            .tenantIdEqualTo(tenantId)
            .supabaseIdEqualTo(task.reservationSupabaseId!)
            .findFirstSync();
        if (res != null) {
          res.status = 'checked_out';
          res.localUpdatedAt = DateTime.now().toUtc();
          res.lastUpdated = DateTime.now().toUtc();
          res.syncStatus = SyncStatus.pending;
          isar.reservationLocals.putSync(res);
        }
      }
  }
}

ITaskRepository getTaskRepository() => TaskRepositoryMobile();
