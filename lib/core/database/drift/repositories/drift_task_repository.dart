import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:falconest/core/database/drift/repositories/drift_apartment_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_client_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_pending_mutation_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_reservation_repository.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';
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
    } catch (_) {}
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
      } catch (_) {
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
      mediaUrls: const [],
      metadata: _parseMetadata(task.metadataJson),
      startedAt: task.startedAt,
      completedAt: task.completedAt,
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
            status: status.trim(),
            photoUrl: task.photoUrl,
            localUpdatedAt: now,
            lastSyncedAt: task.lastSyncedAt,
            syncStatus: 1, // pending
            lastUpdated: now,
            metadataJson: newMetadataJson,
            startedAt: startedAt?.toUtc() ?? task.startedAt,
            completedAt: completedAt?.toUtc() ?? task.completedAt,
            invoicedAt: task.invoicedAt,
          ),
        );

    // POZNÁMKA: Změna statusu rezervace (check-in/check-out) vyžaduje tabulku
    // Reservations v Drift – zatím vynecháno, doplníme v další fázi.
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
        } catch (_) {
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
                status: task.status,
                photoUrl: task.photoUrl,
                localUpdatedAt: task.localUpdatedAt,
                lastSyncedAt: task.lastSyncedAt,
                syncStatus: task.syncStatus,
                lastUpdated: task.lastUpdated,
                metadataJson: task.metadataJson,
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
              status: task.status,
              photoUrl: Value(task.photoUrl),
              localUpdatedAt: task.localUpdatedAt,
              lastSyncedAt: Value(task.lastSyncedAt),
              syncStatus: Value(task.syncStatus),
              lastUpdated: task.lastUpdated,
              metadataJson: Value(task.metadataJson),
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
    final rawStart = map['scheduled_start'] ?? map['due_date'];
    DateTime scheduledStart;
    if (rawStart is DateTime) {
      scheduledStart = rawStart.toUtc();
    } else if (rawStart is String) {
      scheduledStart = DateTime.tryParse(rawStart)?.toUtc() ?? now;
    } else {
      scheduledStart = now;
    }

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
      status: (map['status']?.toString() ?? 'pending').trim(),
      photoUrl: opt('photo_url'),
      localUpdatedAt: now,
      lastSyncedAt: now,
      syncStatus: 0, // synced
      lastUpdated: now,
      metadataJson: metadataJson,
      startedAt: parseDt(map['started_at']),
      completedAt: parseDt(map['completed_at']),
      invoicedAt: parseDt(map['invoiced_at']),
    );
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
      } catch (_) {}
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
            status: task.status,
            photoUrl: task.photoUrl,
            localUpdatedAt: task.localUpdatedAt,
            lastSyncedAt: now,
            syncStatus: 0, // synced
            lastUpdated: now,
            metadataJson: task.metadataJson,
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
            status: mergedStatus,
            photoUrl: task.photoUrl,
            localUpdatedAt: task.localUpdatedAt,
            lastSyncedAt: now,
            syncStatus: 0,
            lastUpdated: now,
            metadataJson: mergedMetadataJson ?? task.metadataJson,
            startedAt: task.startedAt,
            completedAt: task.completedAt,
            invoicedAt: task.invoicedAt,
          ),
        );
  }
}
