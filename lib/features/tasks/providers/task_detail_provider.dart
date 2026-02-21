import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/apartment_local.dart';
import 'package:falconest/core/database/models/sync_status.dart';
import 'package:falconest/core/database/models/task_local.dart';

/// Výsledek načtení detailu úkolu – úkol + případně byt (pokud má apartmentSupabaseId).
typedef TaskDetailData = ({TaskLocal task, ApartmentLocal? apartment});

/// Provider načítající detail úkolu podle Isar ID.
///
/// Vrací [TaskLocal] a příslušný [ApartmentLocal] (podle apartmentSupabaseId).
/// Na webu Isar není dostupný – vrací null.
final taskDetailProvider = FutureProvider.family<TaskDetailData?, int>((
  ref,
  taskId,
) async {
  if (kIsWeb) return null;

  try {
    final isar = IsarService.instance;

    final task = isar.taskLocals.getSync(taskId);
    if (task == null) return null;

    ApartmentLocal? apartment;
    if (task.apartmentSupabaseId != null) {
      apartment = isar.apartmentLocals
          .where()
          .anyId()
          .filter()
          .supabaseIdEqualTo(task.apartmentSupabaseId)
          .findFirstSync();
    }

    return (task: task, apartment: apartment);
  } catch (_) {
    return null;
  }
});

/// Aktualizuje stav úkolu v Isar.
///
/// Nastaví [status], [syncStatus] na pending a [lastUpdated] na aktuální čas.
/// Pro offline-first: změny se uloží lokálně a sync vrstva je pošle na pozadí.
Future<void> updateTaskStatus({
  required int taskId,
  required String status,
}) async {
  if (kIsWeb) return;

  final isar = IsarService.instance;
  final task = isar.taskLocals.getSync(taskId);
  if (task == null) return;

  task.status = status;
  task.syncStatus = SyncStatus.pending;
  task.lastUpdated = DateTime.now().toUtc();
  task.localUpdatedAt = DateTime.now().toUtc();

  await isar.writeTxn(() async {
    await isar.taskLocals.put(task);
  });
}

/// Uloží cestu k lokální fotce do úkolu v Isar.
///
/// Pole [photoUrl] uchovává buď lokální cestu (před sync) nebo URL z Supabase
/// (po sync). Sync vrstva při odeslání nahraje soubor a doplní photoUrl.
Future<void> saveTaskPhotoPath({
  required int taskId,
  required String photoPath,
}) async {
  if (kIsWeb) return;

  final isar = IsarService.instance;
  final task = isar.taskLocals.getSync(taskId);
  if (task == null) return;

  task.photoUrl = photoPath;
  task.syncStatus = SyncStatus.pending;
  task.lastUpdated = DateTime.now().toUtc();
  task.localUpdatedAt = DateTime.now().toUtc();

  await isar.writeTxn(() async {
    await isar.taskLocals.put(task);
  });
}
