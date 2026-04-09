import 'package:drift/drift.dart';

import 'package:falconest/core/database/drift/repositories/drift_pending_mutation_repository.dart';
import 'package:falconest/core/offline/network_error_helper.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest_drift/app_database.dart' as db;

/// Lokální CRUD nad `task_checklists` / `task_checklist_items` v Drift + sync ze Supabase.
///
/// PROČ: Worker musí checklisty řešit offline-first; [watchItemsForTask] napájí reaktivní UI,
/// změny se zapisují do SQLite a při síti (nebo do fronty při výpadku) na Supabase.
class DriftTaskChecklistRepository {
  DriftTaskChecklistRepository(this._db, [this._pendingRepo]);

  final db.AppDatabase _db;
  final DriftPendingMutationRepository? _pendingRepo;

  /// Sleduje položky checklistu pro úkol (UUID z `tasks.id` / `tasks.supabase_id`).
  ///
  /// PROČ: [innerJoin] spojuje instanci hlavičky (`task_checklists.supabase_id`) s řádky položek;
  /// při změně kterékoli tabulky se stream znovu vyemituje.
  Stream<List<db.TaskChecklistItem>> watchItemsForTask(String tenantId, String taskSupabaseId) {
    if (tenantId.isEmpty || taskSupabaseId.isEmpty) {
      return Stream<List<db.TaskChecklistItem>>.value(const []);
    }
    final q = _db.select(_db.taskChecklistItems).join([
      innerJoin(
        _db.taskChecklists,
        _db.taskChecklists.supabaseId.equalsExp(_db.taskChecklistItems.taskChecklistId),
      ),
    ])
      ..where(
        _db.taskChecklists.tenantId.equals(tenantId) &
            _db.taskChecklists.taskId.equals(taskSupabaseId) &
            _db.taskChecklists.supabaseId.isNotNull(),
      )
      ..orderBy([OrderingTerm.asc(_db.taskChecklistItems.sortOrder)]);

    return q.watch().map((rows) => rows.map((r) => r.readTable(_db.taskChecklistItems)).toList());
  }

  /// Smaže všechny lokální checklisty tenanta (před full replace při worker sync).
  Future<void> clearForTenant(String tenantId) async {
    if (tenantId.isEmpty) return;
    await (_db.delete(_db.taskChecklistItems)..where((i) => i.tenantId.equals(tenantId))).go();
    await (_db.delete(_db.taskChecklists)..where((c) => c.tenantId.equals(tenantId))).go();
  }

  /// Uloží hlavičku instance ze Supabase (worker pull).
  Future<void> upsertChecklistFromSupabaseMap(Map<String, dynamic> map) async {
    final sid = map['id']?.toString().trim();
    final tenantId = map['tenant_id']?.toString().trim();
    final taskId = map['task_id']?.toString().trim();
    if (sid == null || sid.isEmpty || tenantId == null || taskId == null) return;

    final templateId = map['template_id']?.toString().trim();
    final now = DateTime.now().toUtc();

    final existing = await (_db.select(_db.taskChecklists)
          ..where((c) => c.tenantId.equals(tenantId) & c.supabaseId.equals(sid)))
        .get();

    if (existing.isNotEmpty) {
      final cur = existing.first;
      await _db.update(_db.taskChecklists).replace(
            db.TaskChecklist(
              id: cur.id,
              supabaseId: sid,
              tenantId: tenantId,
              taskId: taskId,
              templateId: (templateId != null && templateId.isNotEmpty) ? templateId : null,
              localUpdatedAt: now,
              syncStatus: 0,
            ),
          );
    } else {
      await _db.into(_db.taskChecklists).insert(
            db.TaskChecklistsCompanion.insert(
              supabaseId: Value(sid),
              tenantId: tenantId,
              taskId: taskId,
              templateId: Value(
                (templateId != null && templateId.isNotEmpty) ? templateId : null,
              ),
              localUpdatedAt: now,
              syncStatus: const Value(0),
            ),
          );
    }
  }

  /// Uloží položku instance ze Supabase (worker pull).
  Future<void> upsertItemFromSupabaseMap(Map<String, dynamic> map) async {
    final sid = map['id']?.toString().trim();
    final tenantId = map['tenant_id']?.toString().trim();
    final taskChecklistId = map['task_checklist_id']?.toString().trim();
    if (sid == null || sid.isEmpty || tenantId == null || taskChecklistId == null) return;

    final title = (map['title']?.toString() ?? '').trim();
    final isPhotoRequired = map['is_photo_required'] == true;
    final sortOrder = (map['sort_order'] is int)
        ? map['sort_order'] as int
        : int.tryParse(map['sort_order']?.toString() ?? '') ?? 0;
    final isCompleted = map['is_completed'] == true;
    final completedAt = _parseDt(map['completed_at']);
    final completedBy = map['completed_by']?.toString().trim();
    final photoUrl = map['photo_url']?.toString().trim();
    final now = DateTime.now().toUtc();

    final existing = await (_db.select(_db.taskChecklistItems)
          ..where((i) => i.tenantId.equals(tenantId) & i.supabaseId.equals(sid)))
        .get();

    if (existing.isNotEmpty) {
      final cur = existing.first;
      await _db.update(_db.taskChecklistItems).replace(
            db.TaskChecklistItem(
              id: cur.id,
              supabaseId: sid,
              tenantId: tenantId,
              taskChecklistId: taskChecklistId,
              title: title,
              isPhotoRequired: isPhotoRequired,
              sortOrder: sortOrder,
              isCompleted: isCompleted,
              completedAt: completedAt,
              completedBy: (completedBy != null && completedBy.isNotEmpty) ? completedBy : null,
              photoUrl: (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : null,
              // PROČ: pull ze serveru nesmí smazat lokální stub/cestu, dokud worker neodešle reálnou URL.
              localPhotoPath: cur.localPhotoPath,
              localUpdatedAt: now,
              syncStatus: 0,
            ),
          );
    } else {
      await _db.into(_db.taskChecklistItems).insert(
            db.TaskChecklistItemsCompanion.insert(
              supabaseId: Value(sid),
              tenantId: tenantId,
              taskChecklistId: taskChecklistId,
              title: Value(title),
              isPhotoRequired: Value(isPhotoRequired),
              sortOrder: Value(sortOrder),
              isCompleted: Value(isCompleted),
              completedAt: Value(completedAt),
              completedBy: Value(
                (completedBy != null && completedBy.isNotEmpty) ? completedBy : null,
              ),
              photoUrl: Value(
                (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : null,
              ),
              localUpdatedAt: now,
              syncStatus: const Value(0),
            ),
          );
    }
  }

  DateTime? _parseDt(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    return null;
  }

  /// Přepne dokončení položky (checkbox) – SQLite + pokus o okamžitý push / fronta.
  Future<void> setItemCompleted({
    required int driftRowId,
    required bool completed,
    required String tenantId,
    String? completedByProfileId,
  }) async {
    final rows = await (_db.select(_db.taskChecklistItems)..where((i) => i.id.equals(driftRowId))).get();
    if (rows.isEmpty) return;
    final item = rows.first;
    if (item.supabaseId == null || item.supabaseId!.isEmpty) return;

    final now = DateTime.now().toUtc();
    final updated = db.TaskChecklistItem(
      id: item.id,
      supabaseId: item.supabaseId,
      tenantId: item.tenantId,
      taskChecklistId: item.taskChecklistId,
      title: item.title,
      isPhotoRequired: item.isPhotoRequired,
      sortOrder: item.sortOrder,
      isCompleted: completed,
      completedAt: completed ? now : null,
      completedBy: completed && completedByProfileId != null && completedByProfileId.isNotEmpty
          ? completedByProfileId
          : null,
      photoUrl: item.photoUrl,
      localPhotoPath: item.localPhotoPath,
      localUpdatedAt: now,
      syncStatus: 1,
    );
    await _db.update(_db.taskChecklistItems).replace(updated);
    await _pushItemToRemote(updated);
  }

  /// Přepne dokončení položky jen v SQLite a zařadí UPDATE do fronty mutací (`UPDATE_CHECKLIST_ITEM`).
  ///
  /// PROČ: Striktní offline-first – nečekáme na okamžitý HTTP úspěch; [DriftMutationQueueService] doručí později.
  Future<void> setItemCompletedQueued({
    required int driftRowId,
    required bool completed,
    required String tenantId,
    String? completedByProfileId,
  }) async {
    final rows = await (_db.select(_db.taskChecklistItems)..where((i) => i.id.equals(driftRowId))).get();
    if (rows.isEmpty) return;
    final item = rows.first;
    if (item.tenantId != tenantId) return;
    if (item.supabaseId == null || item.supabaseId!.isEmpty) return;

    final now = DateTime.now().toUtc();
    final updated = db.TaskChecklistItem(
      id: item.id,
      supabaseId: item.supabaseId,
      tenantId: item.tenantId,
      taskChecklistId: item.taskChecklistId,
      title: item.title,
      isPhotoRequired: item.isPhotoRequired,
      sortOrder: item.sortOrder,
      isCompleted: completed,
      completedAt: completed ? now : null,
      completedBy: completed && completedByProfileId != null && completedByProfileId.isNotEmpty
          ? completedByProfileId
          : null,
      photoUrl: item.photoUrl,
      localPhotoPath: item.localPhotoPath,
      localUpdatedAt: now,
      syncStatus: 1,
    );
    await _db.update(_db.taskChecklistItems).replace(updated);

    final payload = <String, dynamic>{
      'tenant_id': item.tenantId,
      'is_completed': completed,
      'completed_at': completed ? now.toUtc().toIso8601String() : null,
      'completed_by': completed && completedByProfileId != null && completedByProfileId.isNotEmpty
          ? completedByProfileId
          : null,
    };

    final pending = _pendingRepo;
    if (pending != null) {
      await pending.enqueue(
        table: 'task_checklist_items',
        action: 'UPDATE_CHECKLIST_ITEM',
        recordId: item.supabaseId,
        payload: payload,
      );
    } else {
      // PROČ: v testech nebo bez injektované fronty zůstane chování jako dříve (okamžitý push).
      await _pushItemToRemote(updated);
    }
  }

  /// Vrátí Drift PK položky podle Supabase UUID – potřebné pro volání z UI jen s `task_id` + `item_id`.
  Future<int?> resolveDriftRowIdForChecklistItem({
    required String tenantId,
    required String supabaseItemId,
  }) async {
    if (tenantId.isEmpty || supabaseItemId.isEmpty) return null;
    final rows = await (_db.select(_db.taskChecklistItems)
          ..where((i) => i.tenantId.equals(tenantId) & i.supabaseId.equals(supabaseItemId)))
        .get();
    if (rows.isEmpty) return null;
    return rows.first.id;
  }

  /// Zapíše reálnou cestu k offline souboru do SQLite (bez okamžitého uploadu).
  ///
  /// PROČ: Offline-first – UI čte náhled z disku; doručení na Storage řeší fronta [UPLOAD_CHECKLIST_PHOTO].
  Future<void> setItemLocalPhotoPath({
    required int driftRowId,
    required String tenantId,
    required String localPath,
  }) async {
    final rows = await (_db.select(_db.taskChecklistItems)..where((i) => i.id.equals(driftRowId))).get();
    if (rows.isEmpty) return;
    final item = rows.first;
    if (item.tenantId != tenantId) return;
    if (item.supabaseId == null || item.supabaseId!.isEmpty) return;

    final now = DateTime.now().toUtc();
    await _db.update(_db.taskChecklistItems).replace(
          db.TaskChecklistItem(
            id: item.id,
            supabaseId: item.supabaseId,
            tenantId: item.tenantId,
            taskChecklistId: item.taskChecklistId,
            title: item.title,
            isPhotoRequired: item.isPhotoRequired,
            sortOrder: item.sortOrder,
            isCompleted: item.isCompleted,
            completedAt: item.completedAt,
            completedBy: item.completedBy,
            photoUrl: item.photoUrl,
            localPhotoPath: localPath,
            localUpdatedAt: now,
            syncStatus: item.syncStatus,
          ),
        );
  }

  /// Po úspěšném uploadu z mutační fronty sjednotí Drift se serverem a zruší lokální cestu.
  ///
  /// PROČ: Stejný stav jako po pull ze Supabase – [photo_url] je zdroj pravdy, lokální kopie už nepotřebujeme.
  Future<void> applyChecklistItemPhotoFromUploadQueue({
    required String tenantId,
    required String itemSupabaseId,
    required String photoUrl,
  }) async {
    final rows = await (_db.select(_db.taskChecklistItems)
          ..where((i) => i.tenantId.equals(tenantId) & i.supabaseId.equals(itemSupabaseId)))
        .get();
    if (rows.isEmpty) return;
    final item = rows.first;
    final now = DateTime.now().toUtc();
    final trimmed = photoUrl.trim();
    if (trimmed.isEmpty) return;

    await _db.update(_db.taskChecklistItems).replace(
          db.TaskChecklistItem(
            id: item.id,
            supabaseId: item.supabaseId,
            tenantId: item.tenantId,
            taskChecklistId: item.taskChecklistId,
            title: item.title,
            isPhotoRequired: item.isPhotoRequired,
            sortOrder: item.sortOrder,
            isCompleted: item.isCompleted,
            completedAt: item.completedAt,
            completedBy: item.completedBy,
            photoUrl: trimmed,
            localPhotoPath: null,
            localUpdatedAt: now,
            syncStatus: 0,
          ),
        );
  }

  /// Uloží demo hodnotu do [TaskChecklistItems.localPhotoPath] (bez kamery, bez mutační fronty).
  ///
  /// PROČ: UX náhled „fotka přiložena“; reálný upload přijde později jako rozšíření stejného řádku.
  Future<void> setItemLocalPhotoStub({
    required int driftRowId,
    required String tenantId,
  }) async {
    final rows = await (_db.select(_db.taskChecklistItems)..where((i) => i.id.equals(driftRowId))).get();
    if (rows.isEmpty) return;
    final item = rows.first;
    if (item.tenantId != tenantId) return;

    final now = DateTime.now().toUtc();
    final stub = 'stub_photo_path_${item.id}_${now.millisecondsSinceEpoch}.jpg';
    await _db.update(_db.taskChecklistItems).replace(
          db.TaskChecklistItem(
            id: item.id,
            supabaseId: item.supabaseId,
            tenantId: item.tenantId,
            taskChecklistId: item.taskChecklistId,
            title: item.title,
            isPhotoRequired: item.isPhotoRequired,
            sortOrder: item.sortOrder,
            isCompleted: item.isCompleted,
            completedAt: item.completedAt,
            completedBy: item.completedBy,
            photoUrl: item.photoUrl,
            localPhotoPath: stub,
            localUpdatedAt: now,
            syncStatus: item.syncStatus,
          ),
        );
  }

  /// Nahraje URL fotky (nebo lokální cestu po offline kopii) a synchronizuje se serverem.
  Future<void> setItemPhotoUrl({
    required int driftRowId,
    required String tenantId,
    required String photoUrl,
  }) async {
    final rows = await (_db.select(_db.taskChecklistItems)..where((i) => i.id.equals(driftRowId))).get();
    if (rows.isEmpty) return;
    final item = rows.first;
    if (item.supabaseId == null || item.supabaseId!.isEmpty) return;

    final now = DateTime.now().toUtc();
    final updated = db.TaskChecklistItem(
      id: item.id,
      supabaseId: item.supabaseId,
      tenantId: item.tenantId,
      taskChecklistId: item.taskChecklistId,
      title: item.title,
      isPhotoRequired: item.isPhotoRequired,
      sortOrder: item.sortOrder,
      isCompleted: item.isCompleted,
      completedAt: item.completedAt,
      completedBy: item.completedBy,
      photoUrl: photoUrl,
      // PROČ: po úspěšném uploadu už držíme pravdivou URL na serveru – lokální placeholder mažeme.
      localPhotoPath: null,
      localUpdatedAt: now,
      syncStatus: 1,
    );
    await _db.update(_db.taskChecklistItems).replace(updated);
    await _pushItemToRemote(updated);
  }

  /// Odešle aktuální stav položky na Supabase; při síťové chybě zařadí UPDATE do fronty.
  ///
  /// PROČ: [photo_url] posíláme jen pokud jde o veřejnou URL (Storage). Lokální cesta z offline
  /// kopie by server odmítl nebo by znehodnotila data – dokončení úkolu ale lokálně povolíme.
  Future<void> _pushItemToRemote(db.TaskChecklistItem item) async {
    final sid = item.supabaseId;
    if (sid == null || sid.isEmpty) return;

    final updateMap = <String, dynamic>{
      'is_completed': item.isCompleted,
      'completed_at': item.completedAt?.toUtc().toIso8601String(),
      'completed_by': item.completedBy,
    };
    final pu = item.photoUrl?.trim();
    if (pu != null &&
        pu.isNotEmpty &&
        (pu.startsWith('http://') || pu.startsWith('https://'))) {
      updateMap['photo_url'] = pu;
    }

    final payload = <String, dynamic>{
      'tenant_id': item.tenantId,
      ...updateMap,
    };

    try {
      await SupabaseService.safeFrom('task_checklist_items', item.tenantId).update(updateMap).eq('id', sid);

      await _db.update(_db.taskChecklistItems).replace(
            db.TaskChecklistItem(
              id: item.id,
              supabaseId: item.supabaseId,
              tenantId: item.tenantId,
              taskChecklistId: item.taskChecklistId,
              title: item.title,
              isPhotoRequired: item.isPhotoRequired,
              sortOrder: item.sortOrder,
              isCompleted: item.isCompleted,
              completedAt: item.completedAt,
              completedBy: item.completedBy,
              photoUrl: item.photoUrl,
              localPhotoPath: item.localPhotoPath,
              localUpdatedAt: item.localUpdatedAt,
              syncStatus: 0,
            ),
          );
    } catch (e) {
      if (isNetworkError(e) && _pendingRepo != null) {
        await _pendingRepo.enqueue(
          table: 'task_checklist_items',
          action: 'UPDATE',
          recordId: sid,
          payload: payload,
        );
      } else {
        rethrow;
      }
    }
  }
}
