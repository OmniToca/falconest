/// Mobilní implementace WorkerSyncService – Isar offline-first.
///
/// Kompiluje se pouze pro dart:io. Stahuje úkoly ze Supabase do Isaru,
/// odesílá pending změny na server. Používá path_provider a Isar.
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:isar/isar.dart';

import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/apartment_local.dart';
import 'package:falconest/core/database/models/reservation_local.dart';
import 'package:falconest/core/database/models/sync_status.dart';
import 'package:falconest/core/database/models/task_local.dart';
import 'package:falconest/core/services/supabase_service.dart';

class WorkerSyncService {
  WorkerSyncService._();

  static Future<void> syncTasksFromSupabase(
    String workerId,
    String tenantId, {
    void Function(String)? onSyncError,
  }) async {
    try {
      if (workerId.isEmpty || tenantId.isEmpty) return;

      await pushPendingUpdates(tenantId, onSyncError: onSyncError);

      final now = DateTime.now().toUtc();
      final pastLimit = now.subtract(const Duration(days: 7)).toIso8601String();
      final futureLimit = now.add(const Duration(days: 14)).toIso8601String();

      // Kritická pojistka: Pracovník nesmí do mobilu stáhnout úkoly ve stavu 'pending' (návrhy).
      final tasksData = await SupabaseService.client
          .from('tasks')
          .select('id, tenant_id, apartment_id, reservation_id, assigned_to, title, description, task_type, scheduled_start, status, photo_url, metadata, started_at, completed_at')
          .eq('tenant_id', tenantId)
          .eq('assigned_to', workerId)
          .neq('status', 'pending')
          .isFilter('deleted_at', null)
          .gte('scheduled_start', pastLimit)
          .lte('scheduled_start', futureLimit)
          .order('scheduled_start', ascending: true);

      final tasksList = tasksData is List ? List<dynamic>.from(tasksData) : <dynamic>[];
      if (tasksList.isEmpty) {
        await _clearWorkerTasksAndWrite(tenantId, workerId, [], [], []);
        return;
      }

      final apartmentIds = <String>{};
      final reservationIds = <String>{};
      for (final t in tasksList) {
        final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
        final aptId = map['apartment_id']?.toString().trim();
        if (aptId != null && aptId.isNotEmpty) apartmentIds.add(aptId);
        final resId = map['reservation_id']?.toString().trim();
        if (resId != null && resId.isNotEmpty) reservationIds.add(resId);
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

      List<dynamic> reservationsData = [];
      if (reservationIds.isNotEmpty) {
        reservationsData = await SupabaseService.client
            .from('reservations')
            .select('id, tenant_id, status')
            .inFilter('id', reservationIds.toList())
            .isFilter('deleted_at', null);
        reservationsData = reservationsData is List ? List<dynamic>.from(reservationsData) : [];
      }

      await _clearWorkerTasksAndWrite(tenantId, workerId, tasksList, apartmentsData, reservationsData);
    } catch (e, st) {
      onSyncError?.call(e.toString());
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
    List<dynamic> reservationsData,
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

      for (final r in reservationsData) {
        final map = r is Map<String, dynamic> ? Map<String, dynamic>.from(r) : <String, dynamic>{};
        if (map.isEmpty) continue;
        final res = ReservationLocal.fromMap(map);
        final supabaseId = res.supabaseId;
        if (supabaseId == null || supabaseId.isEmpty) continue;
        final existing = await isar.reservationLocals
            .filter()
            .tenantIdEqualTo(tenantId)
            .supabaseIdEqualTo(supabaseId)
            .findFirst();
        if (existing != null && existing.syncStatus == SyncStatus.pending) continue;
        if (existing != null) res.id = existing.id;
        res.syncStatus = SyncStatus.synced;
        await isar.reservationLocals.put(res);
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

  static Future<void> pushPendingUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
  }) async {
    debugPrint('🔄 SYNC: Spouštím pushPendingUpdates...');
    if (tenantId.isEmpty) return;

    await pushPendingReservationUpdates(tenantId, onSyncError: onSyncError);

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
        final updates = <String, dynamic>{'status': task.status};
        if (task.startedAt != null) updates['started_at'] = task.startedAt!.toUtc().toIso8601String();
        if (task.completedAt != null) updates['completed_at'] = task.completedAt!.toUtc().toIso8601String();
        if (task.metadataJson != null && task.metadataJson!.trim().isNotEmpty) {
          try {
            final parsed = _parseMetadataForSync(task.metadataJson!);
            if (parsed != null && parsed.isNotEmpty) updates['metadata'] = parsed;
          } catch (_) {}
        }
        await SupabaseService.client
            .from('tasks')
            .update(updates)
            .eq('id', supabaseId);
        debugPrint('✅ SYNC ÚSPĚCH: Úkol ${task.supabaseId} byl odeslán.');
      } catch (e, st) {
        onSyncError?.call(e.toString());
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

  /// Odešle lokální změny rezervací (status checked_in při Check-inu) na Supabase.
  static Future<void> pushPendingReservationUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
  }) async {
    if (tenantId.isEmpty) return;

    Isar isar;
    try {
      isar = IsarService.instance;
    } on StateError {
      return;
    }

    final pending = isar.reservationLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .syncStatusEqualTo(SyncStatus.pending)
        .findAllSync();

    for (final res in pending) {
      final supabaseId = res.supabaseId;
      if (supabaseId == null || supabaseId.isEmpty) continue;

      debugPrint('🔄 SYNC: Rezervace ${res.supabaseId} → status: ${res.status}');
      try {
        await SupabaseService.client
            .from('reservations')
            .update({'status': res.status})
            .eq('id', supabaseId)
            .eq('tenant_id', tenantId);
        debugPrint('✅ SYNC ÚSPĚCH: Rezervace ${res.supabaseId} byla odeslána.');
      } catch (e, st) {
        onSyncError?.call(e.toString());
        debugPrint('❌ SYNC CHYBA (Rezervace): $e');
        if (kDebugMode) {
          // ignore: avoid_print
          print('WorkerSyncService.pushPendingReservationUpdates: $supabaseId: $e');
          // ignore: avoid_print
          print(st);
        }
        continue;
      }

      await isar.writeTxn(() async {
        res.syncStatus = SyncStatus.synced;
        res.lastUpdated = DateTime.now().toUtc();
        await isar.reservationLocals.put(res);
      });
    }
  }

  /// Vrací počet záznamů (úkoly + rezervace) čekajících na odeslání do Supabase.
  /// Používá se pro UI indikaci – pracovník vidí, že má lokální změny.
  static Future<int> getPendingSyncCount(String tenantId) async {
    if (tenantId.isEmpty) return 0;
    Isar isar;
    try {
      isar = IsarService.instance;
    } on StateError {
      return 0;
    }
    final pendingTasks = isar.taskLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .syncStatusEqualTo(SyncStatus.pending)
        .countSync();
    final pendingRes = isar.reservationLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .syncStatusEqualTo(SyncStatus.pending)
        .countSync();
    return pendingTasks + pendingRes;
  }

  static Map<String, dynamic>? _parseMetadataForSync(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
