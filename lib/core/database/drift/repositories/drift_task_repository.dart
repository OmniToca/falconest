import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:falconest/core/database/drift/repositories/drift_apartment_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_client_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_pending_mutation_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_reservation_repository.dart';
import 'package:falconest/core/offline/network_error_helper.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest_drift/app_database.dart' as db;

/// Drift implementace [ITaskRepository] – čte/zapisuje z SQLite místo Isar.
///
/// Paralelní implementace pro plný přechod na offline-first relační databázi.
/// Důvod: Isar 3.x na iOS vykazuje nestabilitu ("Collection id is invalid").
/// SQLite zajišťuje 100 % spolehlivý běh na všech platformách.
///
/// [apartmentName], [apartmentAddress], [clientName], [guestName], [guestPhone]
/// se doplňují z Drift repozitářů Apartments, Clients, Reservations (pokud předány).
class DriftTaskRepository implements ITaskRepository {
  DriftTaskRepository(
    this._db, [
    DriftPendingMutationRepository? pendingRepo,
    DriftApartmentRepository? apartmentRepo,
    DriftClientRepository? clientRepo,
    DriftReservationRepository? reservationRepo,
  ])  : _pendingRepo = pendingRepo,
        _apartmentRepo = apartmentRepo,
        _clientRepo = clientRepo,
        _reservationRepo = reservationRepo;

  final db.AppDatabase _db;
  final DriftPendingMutationRepository? _pendingRepo;
  final DriftApartmentRepository? _apartmentRepo;
  final DriftClientRepository? _clientRepo;
  final DriftReservationRepository? _reservationRepo;

  /// Parsuje metadataJson string na Map. PROČ: SQLite ukládá JSON jako text,
  /// při čtení musíme dekódovat pro doménové modely (WorkerTask, WorkerTaskDetail).
  static Map<String, dynamic>? _parseMetadata(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e, st) {
      AppLogger.error('DriftTaskRepository: parsování metadataJson (_parseMetadata) selhalo', e, st);
    }
    return null;
  }

  /// Dekóduje JSON pole URL z Drift sloupce `media_urls` (Fáze 2 – offline fotky úkolu).
  static List<String> _mediaUrlsFromJsonColumn(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString().trim())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (e, st) {
      AppLogger.error('DriftTaskRepository: parsování media_urls JSON sloupce selhalo', e, st);
    }
    return const [];
  }

  /// Supabase vrací `media_urls` jako pole – ukládáme jako JSON text do SQLite.
  static String? _encodeMediaUrlsForDrift(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      final list = raw
          .map((e) => e?.toString().trim())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      if (list.isEmpty) return null;
      return jsonEncode(list);
    }
    return null;
  }

  @override
  Future<List<WorkerTask>> getWorkerTasks(String tenantId, String workerId) async {
    // PROČ: Worker vidí úkol, pokud je v assigned_to NEBO v assigned_user_ids.
    final byPrimary = await (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.assignedUserSupabaseId.equals(workerId)))
        .get();

    final bySecondary = await (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.assignedUserIdsJson.isNotNull()))
        .get();

    final secondaryFiltered = bySecondary.where((t) {
      final json = t.assignedUserIdsJson;
      if (json == null || json.isEmpty) return false;
      try {
        final list = jsonDecode(json);
        if (list is! List) return false;
        return list.any((e) => (e?.toString().trim() ?? '') == workerId);
      } catch (e, st) {
        AppLogger.error('DriftTaskRepository: parsování assigned_user_ids JSON (getWorkerTasks) selhalo', e, st);
        return false;
      }
    }).toList();

    final allById = <String, db.Task>{};
    for (final t in byPrimary) {
      final id = t.supabaseId ?? '';
      if (id.isNotEmpty) allById[id] = t;
    }
    for (final t in secondaryFiltered) {
      final id = t.supabaseId ?? '';
      if (id.isNotEmpty) allById[id] = t;
    }
    final rows = allById.values.toList();

    // Dashboard zobrazuje jen assigned a in_progress – vyloučení pending i completed.
    // PROČ: Ochrana před chybami při přepnutí jazyka. Databázový status musí být vždy v angličtině,
    // lokalizovat se smí až v UI. Porovnáváme striktně s hodnotami z Supabase (completed, pending, draft).
    final filtered = rows.where((t) {
      final s = t.status.trim().toLowerCase();
      if (s == 'completed' || s == 'done') return false;
      if (s == 'pending' || s == 'draft') return false;
      return true;
    }).toList();
    filtered.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    // Batch lookup apartmánů a klientů pro obohacení WorkerTask (apartmentName, clientName).
    Map<String, db.Apartment> aptMap = {};
    Map<String, db.Client> clientMap = {};
    if (_apartmentRepo != null || _clientRepo != null) {
      final aptIds = filtered
          .map((t) => t.apartmentSupabaseId?.trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final clientIds = filtered
          .map((t) => t.clientSupabaseId?.trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      if (_apartmentRepo != null && aptIds.isNotEmpty) {
        final apartmentRepo = _apartmentRepo;
        final apts = await Future.wait(
            aptIds.map((id) => apartmentRepo.getBySupabaseId(id)));
        var i = 0;
        for (final id in aptIds) {
          final apt = apts[i++];
          if (apt != null) aptMap[id] = apt;
        }
      }
      if (_clientRepo != null && clientIds.isNotEmpty) {
        final clientRepo = _clientRepo;
        final clients = await Future.wait(clientIds
            .map((id) => clientRepo.getBySupabaseId(tenantId, id)));
        var i = 0;
        for (final id in clientIds) {
          final c = clients[i++];
          if (c != null) clientMap[id] = c;
        }
      }
    }

    return filtered
        .map((t) => _taskToWorkerTask(t, aptMap: aptMap, clientMap: clientMap))
        .toList();
  }

  WorkerTask _taskToWorkerTask(
    db.Task t, {
    Map<String, db.Apartment>? aptMap,
    Map<String, db.Client>? clientMap,
  }) {
    final idStr = t.supabaseId ?? '';
    if (idStr.isEmpty) {
      throw StateError('Task without supabaseId');
    }
    final refNum = t.referenceNumber?.trim();
    String? aptName;
    String? aptAddress;
    final aptId = t.apartmentSupabaseId?.trim();
    if (aptMap != null && aptId != null && aptId.isNotEmpty) {
      final apt = aptMap[aptId];
      if (apt != null) {
        aptName = apt.name.trim().isEmpty ? null : apt.name.trim();
        aptAddress = (apt.address?.trim().isEmpty ?? true) ? null : apt.address?.trim();
      }
    }
    String? clientName;
    final cId = t.clientSupabaseId?.trim();
    if (clientMap != null && cId != null && cId.isNotEmpty) {
      final c = clientMap[cId];
      if (c != null && c.name.trim().isNotEmpty) {
        clientName = c.name.trim();
      }
    }
    return WorkerTask(
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
      clientName: clientName,
      customLocation:
          (t.customLocation?.trim().isEmpty ?? true) ? null : t.customLocation!.trim(),
      customTitle:
          (t.customTitle?.trim().isEmpty ?? true) ? null : t.customTitle!.trim(),
      metadata: _parseMetadata(t.metadataJson),
      // PROČ: Drift tabulky Tasks/Apartments zatím nemají sloupec geo_location – GPS z API sem nepřiteče,
      // dokud nepřidáme migraci + sync. Worker na mobilu offline tedy zůstává u textové adresy v mapách.
      latitude: null,
      longitude: null,
    );
  }

  @override
  Future<WorkerTaskDetail?> getWorkerTaskDetail(String tenantId, String taskId) async {
    final rows = await (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.supabaseId.equals(taskId)))
        .get();

    final task = rows.isNotEmpty ? rows.first : null;
    if (task == null) return null;

    // Lookup apartment, client, reservation pro obohacení detailu.
    db.Apartment? apt;
    db.Client? client;
    db.Reservation? res;
    final aptId = task.apartmentSupabaseId?.trim();
    final apartmentRepo = _apartmentRepo;
    if (apartmentRepo != null && aptId != null && aptId.isNotEmpty) {
      apt = await apartmentRepo.getBySupabaseId(aptId);
    }
    final clientId = task.clientSupabaseId?.trim();
    final clientRepo = _clientRepo;
    if (clientRepo != null && clientId != null && clientId.isNotEmpty) {
      client = await clientRepo.getBySupabaseId(tenantId, clientId);
    }
    final resId = task.reservationSupabaseId?.trim();
    final reservationRepo = _reservationRepo;
    if (reservationRepo != null && resId != null && resId.isNotEmpty) {
      res = await reservationRepo.getBySupabaseId(tenantId, resId);
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
      apartmentName: apt != null && apt.name.trim().isNotEmpty
          ? apt.name.trim()
          : null,
      apartmentAddress: apt != null && (apt.address?.trim().isEmpty ?? true) == false
          ? apt.address!.trim()
          : null,
      customLocation:
          (task.customLocation?.trim().isEmpty ?? true) ? null : task.customLocation!.trim(),
      customTitle:
          (task.customTitle?.trim().isEmpty ?? true) ? null : task.customTitle!.trim(),
      clientName: client != null && client.name.trim().isNotEmpty
          ? client.name.trim()
          : null,
      clientPhone: client?.phone?.trim().isEmpty == true
          ? null
          : client?.phone?.trim(),
      keybox: apt?.keybox?.trim().isEmpty == true ? null : apt?.keybox?.trim(),
      ownerNotes:
          apt?.ownerNotes?.trim().isEmpty == true ? null : apt?.ownerNotes?.trim(),
      guestName: res?.guestName?.trim().isEmpty == true
          ? null
          : res?.guestName?.trim(),
      guestPhone: res?.guestPhone?.trim().isEmpty == true
          ? null
          : res?.guestPhone?.trim(),
      photoUrl: (task.photoUrl?.trim().isEmpty ?? true) ? null : task.photoUrl,
      mediaUrls: _mediaUrlsFromJsonColumn(task.mediaUrlsJson),
      metadata: _parseMetadata(task.metadataJson),
      startedAt: task.startedAt,
      completedAt: task.completedAt,
      specialRequests: res?.specialRequests?.trim().isEmpty ?? true
          ? null
          : res?.specialRequests?.trim(),
      apartmentCheckInTime: apt?.checkInTime?.trim().isEmpty ?? true
          ? null
          : apt?.checkInTime?.trim(),
      apartmentCheckOutTime: apt?.checkOutTime?.trim().isEmpty ?? true
          ? null
          : apt?.checkOutTime?.trim(),
      apartmentZoneId:
          apt?.zoneId?.trim().isEmpty ?? true ? null : apt?.zoneId?.trim(),
      parkingInstructions: () {
        final p = apt?.parkingInstructions;
        if (p == null) return null;
        final t = p.trim();
        return t.isEmpty ? null : t;
      }(),
      dueDate: task.dueDate?.toLocal(),
      unassignedInfo: () {
        final u = task.unassignedInfo;
        if (u == null) return null;
        final t = u.trim();
        return t.isEmpty ? null : t;
      }(),
      guestLanguage: () {
        final g = res?.guestLanguage;
        if (g == null) return null;
        final t = g.trim();
        return t.isEmpty ? null : t;
      }(),
      hasLinkedReservation: res != null,
      // Stejně jako u [_taskToWorkerTask]: bez geo sloupců v Drift zde GPS nedoplňujeme.
      latitude: null,
      longitude: null,
    );
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
    final rows = await (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.supabaseId.equals(taskId)))
        .get();

    if (rows.isEmpty) return;

    final task = rows.first;
    final now = DateTime.now().toUtc();

    // Offline flow s lokálními fotkami – enqueue do fronty mutací.
    if (localPhotoPaths != null && localPhotoPaths.isNotEmpty && _pendingRepo != null) {
      await _pendingRepo.enqueue(
        table: 'tasks',
        action: 'OFFLINE_TASK_COMPLETE_WITH_PHOTOS',
        payload: {
          'task_id': taskId,
          'tenant_id': tenantId,
          'new_status': status,
          'local_photo_paths': localPhotoPaths,
          if (startedAt != null) 'started_at': startedAt.toUtc().toIso8601String(),
          if (completedAt != null) 'completed_at': completedAt.toUtc().toIso8601String(),
          if (metadataOverlay != null && metadataOverlay.isNotEmpty)
            'metadata_overlay': metadataOverlay,
          'existing_media_urls': existingMediaUrls ?? [],
        },
      );
    }

    // Sestavení merged metadata pro Timestamp Merging.
    String? newMetadataJson = task.metadataJson;
    if (metadataOverlay != null && metadataOverlay.isNotEmpty) {
      final existing = _parseMetadata(task.metadataJson) ?? {};
      newMetadataJson = jsonEncode({...existing, ...metadataOverlay});
    }

    // PROČ: Po nahrání fotek online má lokální řádek obsahovat nové URL (offline náhled do dalšího pullu).
    String? newMediaUrlsJson = task.mediaUrlsJson;
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      final existing = _mediaUrlsFromJsonColumn(task.mediaUrlsJson);
      final seen = existing.toSet();
      final merged = List<String>.from(existing);
      for (final u in mediaUrls) {
        final trimmed = u.trim();
        if (trimmed.isEmpty || seen.contains(trimmed)) continue;
        seen.add(trimmed);
        merged.add(trimmed);
      }
      newMediaUrlsJson = merged.isEmpty ? null : jsonEncode(merged);
    }

    await _db.update(_db.tasks).replace(
          db.Task(
            id: task.id,
            supabaseId: task.supabaseId,
            tenantId: task.tenantId,
            apartmentSupabaseId: task.apartmentSupabaseId,
            clientSupabaseId: task.clientSupabaseId,
            customLocation: task.customLocation,
            customTitle: task.customTitle,
            reservationSupabaseId: task.reservationSupabaseId,
            assignedUserSupabaseId: task.assignedUserSupabaseId,
            assignedUserIdsJson: task.assignedUserIdsJson,
            referenceNumber: task.referenceNumber,
            title: task.title,
            description: task.description,
            taskType: task.taskType,
            scheduledStart: task.scheduledStart,
            dueDate: task.dueDate,
            status: status.trim(),
            photoUrl: task.photoUrl,
            localUpdatedAt: now,
            lastSyncedAt: task.lastSyncedAt,
            syncStatus: 1, // pending
            lastUpdated: now,
            metadataJson: newMetadataJson,
            unassignedInfo: task.unassignedInfo,
            serviceId: task.serviceId,
            mediaUrlsJson: newMediaUrlsJson,
            startedAt: startedAt?.toUtc() ?? task.startedAt,
            completedAt: completedAt?.toUtc() ?? task.completedAt,
            invoicedAt: task.invoicedAt,
          ),
        );

    // POZNÁMKA: Změna statusu rezervace (check-in/check-out) vyžaduje tabulku
    // Reservations v Drift – zatím vynecháno, doplníme v další fázi.
  }

  @override
  Future<void> appendWorkerQuickNote(
    String tenantId,
    String taskId,
    String appendedLine,
  ) async {
    final tid = tenantId.trim();
    final id = taskId.trim();
    final line = appendedLine.trim();
    if (tid.isEmpty || id.isEmpty || line.isEmpty) return;

    final rows = await (_db.select(_db.tasks)
          ..where((t) => t.tenantId.equals(tid) & t.supabaseId.equals(id)))
        .get();
    if (rows.isEmpty) return;

    final task = rows.first;
    final oldDesc = task.description.trim();
    final merged = oldDesc.isEmpty ? line : '$oldDesc\n$line';
    final now = DateTime.now().toUtc();

    await _db.update(_db.tasks).replace(
          db.Task(
            id: task.id,
            supabaseId: task.supabaseId,
            tenantId: task.tenantId,
            apartmentSupabaseId: task.apartmentSupabaseId,
            clientSupabaseId: task.clientSupabaseId,
            customLocation: task.customLocation,
            customTitle: task.customTitle,
            reservationSupabaseId: task.reservationSupabaseId,
            assignedUserSupabaseId: task.assignedUserSupabaseId,
            assignedUserIdsJson: task.assignedUserIdsJson,
            referenceNumber: task.referenceNumber,
            title: task.title,
            description: merged,
            taskType: task.taskType,
            scheduledStart: task.scheduledStart,
            dueDate: task.dueDate,
            status: task.status,
            photoUrl: task.photoUrl,
            localUpdatedAt: now,
            lastSyncedAt: task.lastSyncedAt,
            syncStatus: 1,
            lastUpdated: now,
            metadataJson: task.metadataJson,
            unassignedInfo: task.unassignedInfo,
            serviceId: task.serviceId,
            mediaUrlsJson: task.mediaUrlsJson,
            startedAt: task.startedAt,
            completedAt: task.completedAt,
            invoicedAt: task.invoicedAt,
          ),
        );

    try {
      await SupabaseService.safeFrom('tasks', tid)
          .update(<String, dynamic>{'description': merged})
          .eq('id', id);
      final synced = await (_db.select(_db.tasks)
            ..where((t) => t.id.equals(task.id)))
          .get();
      if (synced.isNotEmpty) {
        await markTaskSynced(synced.first);
      }
    } catch (e) {
      final pending = _pendingRepo;
      if (isNetworkError(e) && pending != null) {
        await pending.enqueue(
          table: 'tasks',
          action: 'UPDATE',
          recordId: id,
          payload: <String, dynamic>{
            'tenant_id': tid,
            'description': merged,
          },
        );
      } else {
        rethrow;
      }
    }
  }

  /// Stream úkolů pro reaktivní UI (watch).
  /// PROČ: Zahrnuje úkoly kde worker je v assigned_to NEBO v assigned_user_ids.
  Stream<List<WorkerTask>> watchWorkerTasks(String tenantId, String workerId) {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              (t.assignedUserSupabaseId.equals(workerId) |
                  t.assignedUserIdsJson.isNotNull())))
        .watch()
        .asyncMap((rows) async {
      final forWorker = rows.where((t) {
        if (t.assignedUserSupabaseId == workerId) return true;
        final json = t.assignedUserIdsJson;
        if (json == null || json.isEmpty) return false;
        try {
          final list = jsonDecode(json);
          if (list is! List) return false;
          return list.any((e) => (e?.toString().trim() ?? '') == workerId);
        } catch (e, st) {
          AppLogger.error('DriftTaskRepository: parsování assigned_user_ids JSON (watchWorkerTasks) selhalo', e, st);
          return false;
        }
      });
      final filtered = forWorker.where((t) {
        final s = t.status.trim().toLowerCase();
        if (s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo') {
          return false;
        }
        if (s == 'pending' || s == 'draft' || s == 'nový' || s == 'new') {
          return false;
        }
        return true;
      }).toList();
      filtered.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

      Map<String, db.Apartment> aptMap = {};
      Map<String, db.Client> clientMap = {};
      if (_apartmentRepo != null || _clientRepo != null) {
        final aptIds = filtered
            .map((t) => t.apartmentSupabaseId?.trim())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
        final clientIds = filtered
            .map((t) => t.clientSupabaseId?.trim())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
        if (_apartmentRepo != null && aptIds.isNotEmpty) {
          final apartmentRepo = _apartmentRepo;
          final apts = await Future.wait(
              aptIds.map((id) => apartmentRepo.getBySupabaseId(id)));
          var i = 0;
          for (final id in aptIds) {
            final apt = apts[i++];
            if (apt != null) aptMap[id] = apt;
          }
        }
        if (_clientRepo != null && clientIds.isNotEmpty) {
          final clientRepo = _clientRepo;
          final clients = await Future.wait(clientIds
              .map((id) => clientRepo.getBySupabaseId(tenantId, id)));
          var i = 0;
          for (final id in clientIds) {
            final c = clients[i++];
            if (c != null) clientMap[id] = c;
          }
        }
      }
      return filtered
          .map((t) => _taskToWorkerTask(t, aptMap: aptMap, clientMap: clientMap))
          .toList();
    });
  }

  /// Statistiky týdne z lokálních úkolů: dokončené v aktuálním kalendářním týdnu (Po–Ne, lokální čas).
  ///
  /// PROČ: [watchWorkerTasks] úmyslně skrývá hotové úkoly; drawer „Tento týden“ má ale počítat
  /// dokončenou práci podle `completed_at`, ne podle plánovaného termínu.
  Stream<WorkerWeekTaskStats> watchWeeklyCompletedTaskStats(String tenantId, String workerId) {
    if (tenantId.isEmpty || workerId.isEmpty) {
      return Stream.value(const WorkerWeekTaskStats(totalTasks: 0, totalEstimatedMinutes: 0));
    }
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              (t.assignedUserSupabaseId.equals(workerId) | t.assignedUserIdsJson.isNotNull())))
        .watch()
        .map((rows) {
      final forWorker = rows.where((t) {
        if (t.assignedUserSupabaseId == workerId) return true;
        final json = t.assignedUserIdsJson;
        if (json == null || json.isEmpty) return false;
        try {
          final list = jsonDecode(json);
          if (list is! List) return false;
          return list.any((e) => (e?.toString().trim() ?? '') == workerId);
        } catch (e, st) {
          AppLogger.error('DriftTaskRepository: parsování assigned_user_ids JSON (watchWeeklyCompletedTaskStats) selhalo', e, st);
          return false;
        }
      });

      final now = DateTime.now();
      final weekStart = _weekStartLocal(now);
      final weekEnd = _weekEndLocal(now);
      var totalTasks = 0;
      var totalMin = 0;

      for (final t in forWorker) {
        if (!_isCompletedTaskStatus(t.status)) continue;
        final ca = t.completedAt;
        if (ca == null) continue;
        final localDone = ca.toLocal();
        if (localDone.isBefore(weekStart) || localDone.isAfter(weekEnd)) continue;
        totalTasks++;
        totalMin += _estimateMinutesFromTaskRow(t);
      }

      return WorkerWeekTaskStats(totalTasks: totalTasks, totalEstimatedMinutes: totalMin);
    });
  }

  /// Měsíční motivační statistiky – dokončené úkoly podle `completed_at` v aktuálním kalendářním měsíci (lokální čas).
  ///
  /// PROČ: [watchWorkerTasks] neukazuje hotové řádky v seznamu; karta úspěchů potřebuje stejný filtr pracovníka
  /// jako týdenní statistiky a pole `started_at` / `completed_at` z tabulky `tasks` (parita s DB).
  Stream<WorkerMonthMotivationStats> watchMonthlyMotivationStats(String tenantId, String workerId) {
    if (tenantId.isEmpty || workerId.isEmpty) {
      return Stream.value(
        const WorkerMonthMotivationStats(
          completedCount: 0,
          workedHours: 0,
          onTimeCount: 0,
          onTimeEligibleCount: 0,
        ),
      );
    }
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              (t.assignedUserSupabaseId.equals(workerId) | t.assignedUserIdsJson.isNotNull())))
        .watch()
        .map((rows) {
      final forWorker = rows.where((t) {
        if (t.assignedUserSupabaseId == workerId) return true;
        final json = t.assignedUserIdsJson;
        if (json == null || json.isEmpty) return false;
        try {
          final list = jsonDecode(json);
          if (list is! List) return false;
          return list.any((e) => (e?.toString().trim() ?? '') == workerId);
        } catch (e, st) {
          AppLogger.error('DriftTaskRepository: parsování assigned_user_ids JSON (watchMonthlyMotivationStats) selhalo', e, st);
          return false;
        }
      });

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEndExclusive = DateTime(now.year, now.month + 1, 1);

      var completedCount = 0;
      var workedMinutesTotal = 0.0;
      var onTimeCount = 0;
      var onTimeEligible = 0;

      for (final t in forWorker) {
        if (!_isCompletedTaskStatus(t.status)) continue;
        final ca = t.completedAt;
        if (ca == null) continue;
        final localDone = ca.toLocal();
        if (localDone.isBefore(monthStart) || !localDone.isBefore(monthEndExclusive)) continue;

        completedCount++;

        final sa = t.startedAt;
        if (sa != null) {
          final dur = ca.difference(sa);
          if (dur.inMinutes > 0 && dur.inHours <= 16) {
            workedMinutesTotal += dur.inMinutes.toDouble();
          }
        }

        final sched = t.scheduledStart;
        onTimeEligible++;
        final sd = DateTime(sched.toLocal().year, sched.toLocal().month, sched.toLocal().day);
        final dd = DateTime(localDone.year, localDone.month, localDone.day);
        if (sd == dd) {
          onTimeCount++;
        }
      }

      return WorkerMonthMotivationStats(
        completedCount: completedCount,
        workedHours: workedMinutesTotal / 60.0,
        onTimeCount: onTimeCount,
        onTimeEligibleCount: onTimeEligible,
      );
    });
  }

  /// Začátek týdne (pondělí 00:00) v lokálním čase – shodně s původním weekly stats UI.
  DateTime _weekStartLocal(DateTime now) {
    final daysFromMonday = now.weekday - 1;
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromMonday));
  }

  /// Konec týdne (neděle 23:59:59.999) v lokálním čase.
  DateTime _weekEndLocal(DateTime now) {
    final start = _weekStartLocal(now);
    return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
  }

  bool _isCompletedTaskStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo';
  }

  /// Parita s [parseTaskEstimateMinutes] ve worker widgetu – bez importu UI vrstvy.
  int _estimateMinutesFromTaskRow(db.Task t) {
    try {
      final j = t.metadataJson;
      if (j != null && j.trim().isNotEmpty) {
        final decoded = jsonDecode(j);
        if (decoded is Map<String, dynamic>) {
          final fromMeta = decoded['estimated_minutes'] ?? decoded['estimate_minutes'];
          if (fromMeta != null) {
            final m = fromMeta is int ? fromMeta : int.tryParse(fromMeta.toString());
            if (m != null && m > 0) return m;
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('DriftTaskRepository: čtení estimated_minutes z metadataJson selhalo', e, st);
    }
    final desc = t.description.trim();
    if (desc.isEmpty) return 0;
    final match = RegExp(r'(?:Odhad|Estimate|Estimación)[:\s]*(\d+)\s*min|(\d+)\s*min')
        .firstMatch(desc);
    if (match == null) return 0;
    final a = int.tryParse(match.group(1) ?? '');
    final b = int.tryParse(match.group(2) ?? '');
    return (a ?? b) ?? 0;
  }

  /// Uloží nebo aktualizuje úkol (např. ze sync). Používá [localUpdatedAt] pro Timestamp Merging.
  Future<void> upsertTask(db.Task task) async {
    final existing = await (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(task.tenantId) &
              t.supabaseId.equals(task.supabaseId ?? '')))
        .get();

    if (existing.isNotEmpty) {
      final current = existing.first;
      // Timestamp Merging: přepíšeme jen pokud je novější
      if (task.localUpdatedAt.isAfter(current.localUpdatedAt)) {
        await _db.update(_db.tasks).replace(
              db.Task(
                id: current.id,
                supabaseId: task.supabaseId,
                tenantId: task.tenantId,
                apartmentSupabaseId: task.apartmentSupabaseId,
                clientSupabaseId: task.clientSupabaseId,
                customLocation: task.customLocation,
                customTitle: task.customTitle,
                reservationSupabaseId: task.reservationSupabaseId,
                assignedUserSupabaseId: task.assignedUserSupabaseId,
                assignedUserIdsJson: task.assignedUserIdsJson,
                referenceNumber: task.referenceNumber,
                title: task.title,
                description: task.description,
                taskType: task.taskType,
                scheduledStart: task.scheduledStart,
                dueDate: task.dueDate,
                status: task.status,
                photoUrl: task.photoUrl,
                localUpdatedAt: task.localUpdatedAt,
                lastSyncedAt: task.lastSyncedAt,
                syncStatus: task.syncStatus,
                lastUpdated: task.lastUpdated,
                metadataJson: task.metadataJson,
                unassignedInfo: task.unassignedInfo,
                serviceId: task.serviceId,
                mediaUrlsJson: task.mediaUrlsJson,
                startedAt: task.startedAt,
                completedAt: task.completedAt,
                invoicedAt: task.invoicedAt,
              ),
            );
      }
    } else {
      await _db.into(_db.tasks).insert(
            db.TasksCompanion.insert(
              supabaseId: Value(task.supabaseId),
              tenantId: task.tenantId,
              apartmentSupabaseId: Value(task.apartmentSupabaseId),
              clientSupabaseId: Value(task.clientSupabaseId),
              customLocation: Value(task.customLocation),
              customTitle: Value(task.customTitle),
              reservationSupabaseId: Value(task.reservationSupabaseId),
              assignedUserSupabaseId: Value(task.assignedUserSupabaseId),
              assignedUserIdsJson: Value(task.assignedUserIdsJson),
              referenceNumber: Value(task.referenceNumber),
              title: Value(task.title),
              description: Value(task.description),
              taskType: Value(task.taskType),
              scheduledStart: task.scheduledStart,
              dueDate: Value(task.dueDate),
              status: task.status,
              photoUrl: Value(task.photoUrl),
              localUpdatedAt: task.localUpdatedAt,
              lastSyncedAt: Value(task.lastSyncedAt),
              syncStatus: Value(task.syncStatus),
              lastUpdated: task.lastUpdated,
              metadataJson: Value(task.metadataJson),
              unassignedInfo: Value(task.unassignedInfo),
              serviceId: Value(task.serviceId),
              mediaUrlsJson: Value(task.mediaUrlsJson),
              startedAt: Value(task.startedAt),
              completedAt: Value(task.completedAt),
              invoicedAt: Value(task.invoicedAt),
            ),
          );
    }
  }

  /// Uloží nebo aktualizuje úkol z mapy ze Supabase (sync).
  ///
  /// PROČ: WorkerSyncService stahuje úkoly jako List<Map> – tato metoda převádí
  /// na db.Task a volá upsertTask. Klíče odpovídají Supabase sloupcům.
  Future<void> upsertTaskFromSupabaseMap(Map<String, dynamic> map) async {
    final task = _supabaseMapToDriftTask(map);
    if (task == null) return;
    await upsertTask(task);
  }

  /// JSON-encoduje assigned_user_ids pro ukládání do SQLite.
  static String? _encodeAssignedUserIds(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      final list = raw
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
      if (list.isEmpty) return null;
      return jsonEncode(list);
    }
    return null;
  }

  /// Převod Supabase mapy na db.Task. Vrací null pokud chybí id nebo tenant_id.
  static db.Task? _supabaseMapToDriftTask(Map<String, dynamic> map) {
    final idRaw = map['id']?.toString().trim();
    if (idRaw == null || idRaw.isEmpty) return null;
    final tenantId = (map['tenant_id']?.toString() ?? '').trim();
    if (tenantId.isEmpty) return null;

    final now = DateTime.now().toUtc();
    final dueParsed = _parseOptionalDateTime(map['due_date']);
    final scheduledParsed = _parseOptionalDateTime(map['scheduled_start']);
    // PROČ: scheduled_start je na serveru povinný; due_date držíme zvlášť pro zobrazení termínu splnění.
    final scheduledStart = scheduledParsed ?? dueParsed ?? now;

    String? metadataJson;
    final rawMeta = map['metadata'];
    if (rawMeta != null) {
      if (rawMeta is Map) {
        metadataJson = jsonEncode(Map<String, dynamic>.from(rawMeta));
      } else if (rawMeta is String && rawMeta.trim().isNotEmpty) {
        metadataJson = rawMeta.trim();
      }
    }

    String? opt(dynamic key) {
      final v = map[key]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }
    DateTime? parseDt(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc();
      return null;
    }

    return db.Task(
      id: 0,
      supabaseId: idRaw,
      tenantId: tenantId,
      apartmentSupabaseId: opt('apartment_id'),
      clientSupabaseId: opt('client_id'),
      customLocation: opt('custom_location'),
      customTitle: opt('custom_title'),
      reservationSupabaseId: opt('reservation_id'),
      assignedUserSupabaseId: opt('assigned_to'),
      assignedUserIdsJson: _encodeAssignedUserIds(map['assigned_user_ids']),
      referenceNumber: opt('reference_number'),
      title: (map['title']?.toString() ?? '').trim(),
      description: (map['description']?.toString() ?? '').trim(),
      taskType: (map['task_type']?.toString() ?? 'Jiné').trim(),
      scheduledStart: scheduledStart,
      dueDate: dueParsed,
      status: (map['status']?.toString() ?? 'pending').trim(),
      photoUrl: opt('photo_url'),
      localUpdatedAt: now,
      lastSyncedAt: now,
      syncStatus: 0, // synced
      lastUpdated: now,
      metadataJson: metadataJson,
      unassignedInfo: _encodeUnassignedInfo(map['unassigned_info']),
      serviceId: opt('service_id'),
      mediaUrlsJson: _encodeMediaUrlsForDrift(map['media_urls']),
      startedAt: parseDt(map['started_at']),
      completedAt: parseDt(map['completed_at']),
      invoicedAt: parseDt(map['invoiced_at']),
    );
  }

  /// ISO / PostgreSQL date / text `due_date` → UTC; null při neplatné hodnotě (sync nesmí spadnout).
  static DateTime? _parseOptionalDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return parsed.toUtc();
    final head = s.split('T').first;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(head);
    if (m != null) {
      final y = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final d = int.tryParse(m.group(3)!);
      if (y != null && mo != null && d != null) {
        return DateTime.utc(y, mo, d);
      }
    }
    return null;
  }

  /// `unassigned_info` jsonb z API → jeden textový řádek JSON pro SQLite.
  static String? _encodeUnassignedInfo(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      try {
        return jsonEncode(Map<String, dynamic>.from(raw));
      } catch (e, st) {
        AppLogger.error('DriftTaskRepository._encodeUnassignedInfo: jsonEncode mapy selhalo', e, st);
        return null;
      }
    }
    if (raw is String) {
      final t = raw.trim();
      return t.isEmpty ? null : t;
    }
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Smaže všechny úkoly tenanta a pracovníka (např. před sync).
  /// PROČ: Maže i úkoly kde worker je v assigned_user_ids.
  Future<void> clearTasksForWorker(String tenantId, String workerId) async {
    await (_db.delete(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.assignedUserSupabaseId.equals(workerId)))
        .go();

    final withSecondary = await (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.assignedUserIdsJson.isNotNull()))
        .get();
    for (final t in withSecondary) {
      final json = t.assignedUserIdsJson;
      if (json == null || json.isEmpty) continue;
      try {
        final list = jsonDecode(json);
        if (list is! List) continue;
        final contains = list.any((e) => e?.toString().trim() == workerId);
        if (contains) {
          await (_db.delete(_db.tasks)..where((ta) => ta.id.equals(t.id))).go();
        }
      } catch (e, st) {
        AppLogger.error('DriftTaskRepository: parsování assignedUserIdsJson při mazání úkolů selhalo', e, st);
      }
    }
  }

  /// Načte úkol podle lokálního (Drift) ID. Pro task_detail_screen (deprecated).
  Future<db.Task?> getTaskById(int id) async {
    final rows = await (_db.select(_db.tasks)..where((t) => t.id.equals(id))).get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Načte úkoly se syncStatus=pending pro push na Supabase (WorkerSyncService).
  Future<List<db.Task>> getPendingTasks(String tenantId) async {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.syncStatus.equals(1)))
        .get();
  }

  /// Označí úkol (podle tenantId + supabaseId) jako synchronizovaný.
  /// Používá offline_photo_task_processor po úspěšném uploadu fotek na Supabase.
  Future<void> markTaskSyncedBySupabaseId(String tenantId, String taskId) async {
    final rows = await (_db.select(_db.tasks)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.supabaseId.equals(taskId)))
        .get();
    if (rows.isEmpty) return;
    await markTaskSynced(rows.first);
  }

  /// Označí úkol jako synchronizovaný po úspěšném push na Supabase.
  Future<void> markTaskSynced(db.Task task) async {
    final now = DateTime.now().toUtc();
    await _db.update(_db.tasks).replace(
          db.Task(
            id: task.id,
            supabaseId: task.supabaseId,
            tenantId: task.tenantId,
            apartmentSupabaseId: task.apartmentSupabaseId,
            clientSupabaseId: task.clientSupabaseId,
            customLocation: task.customLocation,
            customTitle: task.customTitle,
            reservationSupabaseId: task.reservationSupabaseId,
            assignedUserSupabaseId: task.assignedUserSupabaseId,
            assignedUserIdsJson: task.assignedUserIdsJson,
            referenceNumber: task.referenceNumber,
            title: task.title,
            description: task.description,
            taskType: task.taskType,
            scheduledStart: task.scheduledStart,
            dueDate: task.dueDate,
            status: task.status,
            photoUrl: task.photoUrl,
            localUpdatedAt: task.localUpdatedAt,
            lastSyncedAt: now,
            syncStatus: 0, // synced
            lastUpdated: now,
            metadataJson: task.metadataJson,
            unassignedInfo: task.unassignedInfo,
            serviceId: task.serviceId,
            mediaUrlsJson: task.mediaUrlsJson,
            startedAt: task.startedAt,
            completedAt: task.completedAt,
            invoicedAt: task.invoicedAt,
          ),
        );
  }

  /// Po úspěšném Smart Merge (Timestamp Merging) na Supabase: zapíše do lokální
  /// Drift DB sloučený stav úkolu a označí ho jako synchronizovaný.
  ///
  /// PROČ: Aby lokální kopie odpovídala tomu, co je na serveru po merge (status
  /// z pracovníka, poznámky sloučené, ostatní pole ze serveru při konfliktu).
  Future<void> applyMergedTaskAndMarkSynced(
    db.Task task, {
    required String mergedStatus,
    String? mergedDescription,
    String? mergedMetadataJson,
    String? title,
    String? taskType,
    DateTime? scheduledStart,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.update(_db.tasks).replace(
          db.Task(
            id: task.id,
            supabaseId: task.supabaseId,
            tenantId: task.tenantId,
            apartmentSupabaseId: task.apartmentSupabaseId,
            clientSupabaseId: task.clientSupabaseId,
            customLocation: task.customLocation,
            customTitle: task.customTitle,
            reservationSupabaseId: task.reservationSupabaseId,
            assignedUserSupabaseId: task.assignedUserSupabaseId,
            assignedUserIdsJson: task.assignedUserIdsJson,
            referenceNumber: task.referenceNumber,
            title: title ?? task.title,
            description: mergedDescription ?? task.description,
            taskType: taskType ?? task.taskType,
            scheduledStart: scheduledStart ?? task.scheduledStart,
            dueDate: task.dueDate,
            status: mergedStatus,
            photoUrl: task.photoUrl,
            localUpdatedAt: task.localUpdatedAt,
            lastSyncedAt: now,
            syncStatus: 0,
            lastUpdated: now,
            metadataJson: mergedMetadataJson ?? task.metadataJson,
            unassignedInfo: task.unassignedInfo,
            serviceId: task.serviceId,
            mediaUrlsJson: task.mediaUrlsJson,
            startedAt: task.startedAt,
            completedAt: task.completedAt,
            invoicedAt: task.invoicedAt,
          ),
        );
  }
}
