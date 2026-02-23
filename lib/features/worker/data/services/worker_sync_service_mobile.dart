/// Mobilní implementace WorkerSyncService – Isar offline-first.
///
/// Kompiluje se pouze pro dart:io. Stahuje úkoly ze Supabase do Isaru,
/// odesílá pending změny na server. Používá path_provider a Isar.
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:isar/isar.dart';

import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/apartment_local.dart';
import 'package:falconest/core/database/models/sync_status.dart';
import 'package:falconest/core/database/models/task_local.dart';
import 'package:falconest/core/services/supabase_service.dart';

class WorkerSyncService {
  WorkerSyncService._();

  static Future<void> syncTasksFromSupabase(String workerId, String tenantId) async {
    try {
      if (workerId.isEmpty || tenantId.isEmpty) return;

      await pushPendingUpdates(tenantId);

      final now = DateTime.now().toUtc();
      final pastLimit = now.subtract(const Duration(days: 7)).toIso8601String();
      final futureLimit = now.add(const Duration(days: 14)).toIso8601String();

      final tasksData = await SupabaseService.client
          .from('tasks')
          .select('id, tenant_id, apartment_id, assigned_to, title, description, task_type, scheduled_start, status, photo_url, metadata')
          .eq('tenant_id', tenantId)
          .eq('assigned_to', workerId)
          .isFilter('deleted_at', null)
          .gte('scheduled_start', pastLimit)
          .lte('scheduled_start', futureLimit)
          .order('scheduled_start', ascending: true);

      final tasksList = tasksData is List ? List<dynamic>.from(tasksData) : <dynamic>[];
      if (tasksList.isEmpty) {
        await _clearWorkerTasksAndWrite(tenantId, workerId, [], []);
        return;
      }

      final apartmentIds = <String>{};
      for (final t in tasksList) {
        final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
        final aptId = map['apartment_id']?.toString().trim();
        if (aptId != null && aptId.isNotEmpty) apartmentIds.add(aptId);
      }

      List<dynamic> apartmentsData = [];
      if (apartmentIds.isNotEmpty) {
        apartmentsData = await SupabaseService.client
            .from('apartments')
            .select('id, tenant_id, name, address, keybox, owner_notes')
            .inFilter('id', apartmentIds.toList())
            .isFilter('deleted_at', null);
        apartmentsData = apartmentsData is List ? List<dynamic>.from(apartmentsData) : [];
      }

      await _clearWorkerTasksAndWrite(tenantId, workerId, tasksList, apartmentsData);
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('WorkerSyncService.syncTasksFromSupabase ERROR: $e');
        // ignore: avoid_print
        print(st);
      }
    }
  }

  static Future<void> _clearWorkerTasksAndWrite(
    String tenantId,
    String workerId,
    List<dynamic> tasksList,
    List<dynamic> apartmentsData,
  ) async {
    Isar isar;
    try {
      isar = IsarService.instance;
    } on StateError {
      return;
    }

    await isar.writeTxn(() async {
      final downloadedIds = <String>{};
      for (final t in tasksList) {
        final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
        final id = map['id']?.toString().trim();
        if (id != null && id.isNotEmpty) downloadedIds.add(id);
      }
      final syncedToRemove = await isar.taskLocals
          .filter()
          .tenantIdEqualTo(tenantId)
          .assignedUserSupabaseIdEqualTo(workerId)
          .syncStatusEqualTo(SyncStatus.synced)
          .findAll();
      for (final t in syncedToRemove) {
        if (t.supabaseId != null && !downloadedIds.contains(t.supabaseId)) {
          await isar.taskLocals.delete(t.id);
        }
      }

      for (final a in apartmentsData) {
        final map = a is Map<String, dynamic> ? Map<String, dynamic>.from(a) : <String, dynamic>{};
        if (map.isEmpty) continue;
        final apt = ApartmentLocal.fromMap(map);
        apt.syncStatus = SyncStatus.synced;
        final existing = await isar.apartmentLocals.filter().supabaseIdEqualTo(apt.supabaseId).findFirst();
        if (existing != null) apt.id = existing.id;
        await isar.apartmentLocals.put(apt);
      }

      for (final t in tasksList) {
        final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
        if (map.isEmpty) continue;
        final task = TaskLocal.fromMap(map);
        final supabaseId = task.supabaseId;
        if (supabaseId == null || supabaseId.isEmpty) continue;

        final existingTask = await isar.taskLocals
            .filter()
            .supabaseIdEqualTo(supabaseId)
            .findFirst();
        if (existingTask != null && existingTask.syncStatus == SyncStatus.pending) continue;

        if (existingTask != null) task.id = existingTask.id;
        task.syncStatus = SyncStatus.synced;
        await isar.taskLocals.put(task);
      }
    });
  }

  static Future<void> pushPendingUpdates(String tenantId) async {
    debugPrint('🔄 SYNC: Spouštím pushPendingUpdates...');
    if (tenantId.isEmpty) return;

    Isar isar;
    try {
      isar = IsarService.instance;
    } on StateError {
      return;
    }

    final pending = isar.taskLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .syncStatusEqualTo(SyncStatus.pending)
        .findAllSync();

    if (pending.isEmpty) return;

    for (final task in pending) {
      final supabaseId = task.supabaseId;
      if (supabaseId == null || supabaseId.isEmpty) continue;

      debugPrint('🔄 SYNC: Pokus o odeslání úkolu s ID: ${task.supabaseId}, nový status: ${task.status}');
      try {
        await SupabaseService.client
            .from('tasks')
            .update({'status': task.status})
            .eq('id', supabaseId);
        debugPrint('✅ SYNC ÚSPĚCH: Úkol ${task.supabaseId} byl odeslán.');
      } catch (e, st) {
        debugPrint('❌ SYNC CHYBA (Supabase): $e');
        debugPrint('❌ SYNC StackTrace: $st');
        if (kDebugMode) {
          // ignore: avoid_print
          print('WorkerSyncService.pushPendingUpdates: update failed for $supabaseId: $e');
        }
        continue;
      }

      await isar.writeTxn(() async {
        task.syncStatus = SyncStatus.synced;
        task.lastSyncedAt = DateTime.now().toUtc();
        task.lastUpdated = DateTime.now().toUtc();
        await isar.taskLocals.put(task);
      });
    }
  }
}
