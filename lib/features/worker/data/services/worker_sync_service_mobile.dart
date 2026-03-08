/// Mobilní implementace WorkerSyncService – čte/zapisuje výhradně do Drift (SQLite).
///
/// Isar byl kompletně odstraněn – nestabilní na iOS ("Collection id is invalid").
/// Všechna data pro Worker UI jsou nyní v relační SQLite databázi.
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:falconest/core/database/drift/database_provider.dart' show DriftSyncRepos;
import 'package:falconest/core/services/supabase_service.dart';

class WorkerSyncService {
  WorkerSyncService._();

  static Future<void> syncTasksFromSupabase(
    String workerId,
    String tenantId, {
    void Function(String)? onSyncError,
    DriftSyncRepos? driftRepos,
  }) async {
    try {
      if (workerId.isEmpty || tenantId.isEmpty) return;

      await pushPendingUpdates(tenantId, onSyncError: onSyncError, driftRepos: driftRepos);

      if (driftRepos == null) return;

      // PROČ: Stahujeme měnu tenanta – Worker UI ji potřebuje offline (formátování hotovosti).
      await _syncTenant(tenantId, driftRepos);

      // PROČ: Modul Communication – šablony zpráv pro řidiče. Full Replace.
      await _syncMessageTemplates(tenantId, driftRepos);

      final now = DateTime.now().toUtc();
      final pastLimit = now.subtract(const Duration(days: 7)).toIso8601String();
      final futureLimit = now.add(const Duration(days: 14)).toIso8601String();

      // PROČ: Worker vidí úkol, pokud je v assigned_to NEBO v assigned_user_ids.
      final tasksData = await SupabaseService.client
          .from('tasks')
          .select('id, tenant_id, apartment_id, client_id, custom_location, custom_title, reference_number, reservation_id, assigned_to, assigned_user_ids, title, description, task_type, scheduled_start, status, photo_url, metadata, started_at, completed_at, invoiced_at')
          .eq('tenant_id', tenantId)
          .or('assigned_to.eq.$workerId,assigned_user_ids.cs.{$workerId}')
          .neq('status', 'pending')
          .isFilter('deleted_at', null)
          .isFilter('invoiced_at', null)
          .gte('scheduled_start', pastLimit)
          .lte('scheduled_start', futureLimit)
          .order('scheduled_start', ascending: true);

      final tasksList = tasksData is List ? List<dynamic>.from(tasksData) : <dynamic>[];
      if (tasksList.isEmpty) {
        await _clearAndWrite(tenantId, workerId, [], [], [], [], driftRepos);
        return;
      }

      final apartmentIds = <String>{};
      final reservationIds = <String>{};
      final clientIds = <String>{};
      for (final t in tasksList) {
        final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
        final aptId = map['apartment_id']?.toString().trim();
        if (aptId != null && aptId.isNotEmpty) apartmentIds.add(aptId);
        final resId = map['reservation_id']?.toString().trim();
        if (resId != null && resId.isNotEmpty) reservationIds.add(resId);
        final cId = map['client_id']?.toString().trim();
        if (cId != null && cId.isNotEmpty) clientIds.add(cId);
      }

      List<dynamic> apartmentsData = [];
      if (apartmentIds.isNotEmpty) {
        apartmentsData = await SupabaseService.client
            .from('apartments')
            .select('id, tenant_id, name, address, code, keybox, owner_notes')
            .inFilter('id', apartmentIds.toList())
            .isFilter('deleted_at', null);
        apartmentsData = apartmentsData is List ? List<dynamic>.from(apartmentsData) : [];
      }

      List<dynamic> reservationsData = [];
      if (reservationIds.isNotEmpty) {
        reservationsData = await SupabaseService.client
            .from('reservations')
            .select('id, tenant_id, reference_number, status, guest_name, guest_phone')
            .inFilter('id', reservationIds.toList())
            .isFilter('deleted_at', null);
        reservationsData = reservationsData is List ? List<dynamic>.from(reservationsData) : [];
      }

      List<dynamic> clientsData = [];
      if (clientIds.isNotEmpty) {
        clientsData = await SupabaseService.client
            .from('clients')
            .select('id, tenant_id, name, phone')
            .inFilter('id', clientIds.toList())
            .isFilter('deleted_at', null);
        clientsData = clientsData is List ? List<dynamic>.from(clientsData) : [];
      }

      await _clearAndWrite(
        tenantId,
        workerId,
        tasksList,
        apartmentsData,
        reservationsData,
        clientsData,
        driftRepos,
      );
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

  static Future<void> _syncTenant(String tenantId, DriftSyncRepos driftRepos) async {
    if (tenantId.isEmpty) return;
    try {
      final tenantRes = await SupabaseService.client
          .from('tenants')
          .select('id, currency')
          .eq('id', tenantId)
          .maybeSingle();
      if (tenantRes == null || tenantRes is! Map) return;
      final map = Map<String, dynamic>.from(tenantRes as Map);
      if (map.isEmpty) return;
      await driftRepos.tenant.upsertFromSupabaseMap(map);
    } catch (_) {}
  }

  static Future<void> _syncMessageTemplates(String tenantId, DriftSyncRepos driftRepos) async {
    if (tenantId.isEmpty) return;
    try {
      final templatesData = await SupabaseService.client
          .from('tenant_message_templates')
          .select('id, tenant_id, key, name, body, channel, language_code, trigger_context, order_index')
          .eq('tenant_id', tenantId)
          .isFilter('deleted_at', null)
          .order('order_index', ascending: true);

      final templatesList = templatesData is List ? List<dynamic>.from(templatesData) : <dynamic>[];

      await driftRepos.messageTemplate.clearForTenant(tenantId);
      for (final raw in templatesList) {
        final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        if (map.isEmpty) continue;
        final supabaseId = map['id']?.toString().trim();
        if (supabaseId == null || supabaseId.isEmpty) continue;
        await driftRepos.messageTemplate.upsertFromSupabaseMap(map);
      }
    } catch (_) {}
  }

  static Future<void> _clearAndWrite(
    String tenantId,
    String workerId,
    List<dynamic> tasksList,
    List<dynamic> apartmentsData,
    List<dynamic> reservationsData,
    List<dynamic> clientsData,
    DriftSyncRepos driftRepos,
  ) async {
    await driftRepos.task.clearTasksForWorker(tenantId, workerId);

    for (final a in apartmentsData) {
      final map = a is Map<String, dynamic> ? Map<String, dynamic>.from(a) : <String, dynamic>{};
      if (map.isEmpty) continue;
      await driftRepos.apartment.upsertFromSupabaseMap(map);
    }

    for (final r in reservationsData) {
      final map = r is Map<String, dynamic> ? Map<String, dynamic>.from(r) : <String, dynamic>{};
      if (map.isEmpty) continue;
      final supabaseId = map['id']?.toString().trim();
      if (supabaseId == null || supabaseId.isEmpty) continue;
      await driftRepos.reservation.upsertFromSupabaseMap(map);
    }

    for (final c in clientsData) {
      final map = c is Map<String, dynamic> ? Map<String, dynamic>.from(c) : <String, dynamic>{};
      if (map.isEmpty) continue;
      final supabaseId = map['id']?.toString().trim();
      if (supabaseId == null || supabaseId.isEmpty) continue;
      await driftRepos.client.upsertFromSupabaseMap(map);
    }

    for (final t in tasksList) {
      final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
      if (map.isEmpty) continue;
      await driftRepos.task.upsertTaskFromSupabaseMap(map);
    }
  }

  /// Push pending úkolů na Supabase s Timestamp Merging (Smart Merge).
  ///
  /// PROČ TIMESTAMP MERGING: Bez něj by platilo "Last-write-wins" – mobilní aplikace
  /// by po připojení přepsala změny, které mezitím udělal administrátor na webu.
  /// Timestamp Merging před odesláním lokální mutace:
  /// 1) Stáhne aktuální verzi úkolu ze serveru (updated_at, status, description, metadata, …).
  /// 2) Pokud je server.updated_at novější než lokální last_synced_at → konflikt.
  /// 3) Při konfliktu aplikuje byznysová pravidla (Smart Merge), odešle sloučený stav
  ///    na Supabase a zapíše ho i do lokální Drift DB.
  ///
  /// BYZNYSOVÁ PRAVIDLA (PROČ takto):
  /// - PRAVIDLO 1 (Status): Lokální změna statusu pracovníkem má přednost – pracovník byl
  ///   na místě a práci dokončil; přepisovat jeho "completed" administrátorskou úpravou
  ///   by bylo chybné.
  /// - PRAVIDLO 2 (Poznámky): Pokud se změnily poznámky na serveru i lokálně, texty se
  ///   nesmí přepsat, ale spojí se (append): "[Admin]: text ze serveru \n [Worker]: lokální text",
  ///   aby se neztratila ani administrátorská ani terénní informace.
  /// - PRAVIDLO 3 (Ostatní): U dat, která pracovník typicky nemění (termín úkolu, cena,
  ///   název, typ úkolu), má vždy přednost novější verze ze serveru – zdroj pravdy je admin.
  static Future<void> pushPendingUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
    DriftSyncRepos? driftRepos,
  }) async {
    debugPrint('🔄 SYNC: Spouštím pushPendingUpdates...');
    if (tenantId.isEmpty) return;

    await pushPendingReservationUpdates(tenantId, onSyncError: onSyncError, driftRepos: driftRepos);

    if (driftRepos == null) return;

    final pending = await driftRepos.task.getPendingTasks(tenantId);
    if (pending.isEmpty) return;

    for (final task in pending) {
      final supabaseId = task.supabaseId;
      if (supabaseId == null || supabaseId.isEmpty) continue;

      debugPrint('🔄 SYNC: Pokus o odeslání úkolu s ID: $supabaseId, nový status: ${task.status}');
      try {
        // ---------- KROK 1: Před odesláním stáhnout aktuální verzi úkolu ze serveru ----------
        // PROČ: Abychom mohli detekovat konflikt (admin mezitím upravil úkol) a aplikovat Smart Merge.
        final serverRow = await _fetchCurrentTaskFromServer(supabaseId, tenantId);

        // ---------- KROK 2: Detekce konfliktu a sestavení sloučeného payloadu ----------
        final serverUpdatedAt = serverRow != null ? _parseServerUpdatedAt(serverRow) : null;
        final lastSynced = task.lastSyncedAt;
        final hasConflict = serverUpdatedAt != null &&
            (lastSynced == null || serverUpdatedAt.isAfter(lastSynced));

        final Map<String, dynamic> updates;
        String mergedStatus = task.status;
        String? mergedDescription;
        String? mergedMetadataJson;
        String? serverTitle;
        String? serverTaskType;
        DateTime? serverScheduledStart;

        if (hasConflict && serverRow != null) {
          // Smart Merge: aplikace byznysových pravidel.
          mergedStatus = task.status; // PRAVIDLO 1: status má vždy lokální (worker).
          mergedDescription = _mergeNotes(
            serverNotes: serverRow['description']?.toString().trim(),
            localNotes: task.description.trim(),
          );
          final serverMeta = _parseMetadataFromDynamic(serverRow['metadata']);
          final localMeta = _parseMetadataForSync(task.metadataJson ?? '{}');
          final mergedMeta = _mergeMetadataMap(serverMeta ?? {}, localMeta);
          mergedMetadataJson = mergedMeta.isEmpty ? null : jsonEncode(mergedMeta);

          serverTitle = serverRow['title']?.toString().trim();
          serverTaskType = serverRow['task_type']?.toString().trim();
          final ss = serverRow['scheduled_start'];
          if (ss != null) serverScheduledStart = DateTime.tryParse(ss.toString())?.toUtc();

          updates = <String, dynamic>{
            'status': mergedStatus,
            'description': mergedDescription,
          };
          if (serverTitle != null && serverTitle.isNotEmpty) updates['title'] = serverTitle;
          if (serverTaskType != null && serverTaskType.isNotEmpty) updates['task_type'] = serverTaskType;
          if (serverScheduledStart != null) {
            updates['scheduled_start'] = serverScheduledStart.toIso8601String();
          }
          if (mergedMeta.isNotEmpty) updates['metadata'] = mergedMeta;
        } else {
          // Žádný konflikt: odesíláme jen lokální změny (status, časy, metadata).
          updates = <String, dynamic>{'status': task.status};
          mergedDescription = task.description;
          mergedMetadataJson = task.metadataJson;
        }

        if (task.startedAt != null) {
          updates['started_at'] = task.startedAt!.toUtc().toIso8601String();
        }
        if (task.completedAt != null) {
          updates['completed_at'] = task.completedAt!.toUtc().toIso8601String();
        }
        if (!hasConflict &&
            task.metadataJson != null &&
            task.metadataJson!.trim().isNotEmpty) {
          try {
            final parsed = _parseMetadataForSync(task.metadataJson!);
            if (parsed != null && parsed.isNotEmpty) updates['metadata'] = parsed;
          } catch (_) {}
        }

        await SupabaseService.client.from('tasks').update(updates).eq('id', supabaseId).eq('tenant_id', tenantId);
        debugPrint('✅ SYNC ÚSPĚCH: Úkol $supabaseId byl odeslán.');

        if (hasConflict) {
          await driftRepos.task.applyMergedTaskAndMarkSynced(
            task,
            mergedStatus: mergedStatus,
            mergedDescription: mergedDescription,
            mergedMetadataJson: mergedMetadataJson,
            title: serverTitle,
            taskType: serverTaskType,
            scheduledStart: serverScheduledStart,
          );
        } else {
          await driftRepos.task.markTaskSynced(task);
        }
      } catch (e) {
        onSyncError?.call(e.toString());
        debugPrint('❌ SYNC CHYBA (Supabase): $e');
        if (kDebugMode) {
          // ignore: avoid_print
          print('WorkerSyncService.pushPendingUpdates: update failed for $supabaseId: $e');
        }
        continue;
      }
    }
  }

  /// Stáhne aktuální řádek úkolu ze Supabase (pro Timestamp Merging).
  static Future<Map<String, dynamic>?> _fetchCurrentTaskFromServer(String taskId, String tenantId) async {
    try {
      final res = await SupabaseService.client
          .from('tasks')
          .select('id, updated_at, status, description, metadata, scheduled_start, title, task_type')
          .eq('id', taskId)
          .eq('tenant_id', tenantId)
          .maybeSingle();
      if (res == null || res is! Map) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseServerUpdatedAt(Map<String, dynamic> serverRow) {
    final v = serverRow['updated_at'];
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    final parsed = DateTime.tryParse(v.toString());
    return parsed?.toUtc();
  }

  /// Sloučí poznámky při konfliktu: "[Admin]: text ze serveru \n [Worker]: lokální text".
  static String _mergeNotes({String? serverNotes, String? localNotes}) {
    final server = (serverNotes ?? '').trim();
    final local = (localNotes ?? '').trim();
    if (server.isEmpty) return local;
    if (local.isEmpty) return server;
    return '[Admin]: $server\n[Worker]: $local';
  }

  static Map<String, dynamic>? _parseMetadataFromDynamic(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  /// Sloučí metadata: klíče ze serveru + klíče z lokálu (lokální přepíše při duplicitě).
  static Map<String, dynamic> _mergeMetadataMap(Map<String, dynamic> server, Map<String, dynamic>? local) {
    final out = Map<String, dynamic>.from(server);
    if (local != null && local.isNotEmpty) {
      for (final e in local.entries) {
        out[e.key] = e.value;
      }
    }
    return out;
  }


  static Future<void> pushPendingReservationUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
    DriftSyncRepos? driftRepos,
  }) async {
    if (tenantId.isEmpty) return;
    if (driftRepos == null) return;

    final pending = await driftRepos.reservation.getPendingReservations(tenantId);

    for (final res in pending) {
      final supabaseId = res.supabaseId;
      if (supabaseId == null || supabaseId.isEmpty) continue;

      debugPrint('🔄 SYNC: Rezervace $supabaseId → status: ${res.status}');
      try {
        await SupabaseService.client
            .from('reservations')
            .update({'status': res.status})
            .eq('id', supabaseId)
            .eq('tenant_id', tenantId);
        debugPrint('✅ SYNC ÚSPĚCH: Rezervace $supabaseId byla odeslána.');

        await driftRepos.reservation.markReservationSynced(res);
      } catch (e) {
        onSyncError?.call(e.toString());
        debugPrint('❌ SYNC CHYBA (Rezervace): $e');
        if (kDebugMode) {
          // ignore: avoid_print
          print('WorkerSyncService.pushPendingReservationUpdates: $supabaseId: $e');
        }
        continue;
      }
    }
  }

  static Future<int> getPendingSyncCount(String tenantId, {DriftSyncRepos? driftRepos}) async {
    if (tenantId.isEmpty) return 0;
    if (driftRepos == null) return 0;

    final pendingTasks = await driftRepos.task.getPendingTasks(tenantId);
    final pendingRes = await driftRepos.reservation.getPendingReservations(tenantId);
    return pendingTasks.length + pendingRes.length;
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
