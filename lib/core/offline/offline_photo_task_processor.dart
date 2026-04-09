import 'dart:io';

import 'package:falconest/core/database/drift/repositories/drift_task_repository.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Modul pro Supabase Storage – tasks (fotky dokončení úkolu).
const _storageModuleTasks = 'tasks';

/// Zpracuje frontovaný offline task complete with photos z MutationQueueService.
///
/// PROČ: Pracovník mohl dokončit úkol s fotkami bez připojení. Lokální soubory
/// byly zkopírovány do getApplicationDocumentsDirectory/offline_task_photos.
/// Při processQueue (už online) nahrajeme fotky na Storage, sloučíme s existujícími
/// URL a provedeme Supabase update na tasks. Poté smažeme lokální soubory.
Future<void> processOfflineTaskCompleteWithPhotos(
  Map<String, dynamic> payload, {
  DriftTaskRepository? driftTaskRepository,
}) async {
  final taskId = payload['task_id']?.toString();
  final tenantId = payload['tenant_id']?.toString();
  final newStatus = payload['new_status']?.toString();
  // PROČ: Bez identifikace úkolu/tenanta nelze bezpečně synchronizovat – mutace zůstane ve frontě.
  if (taskId == null || taskId.isEmpty || tenantId == null || tenantId.isEmpty) {
    throw Exception(
      'processOfflineTaskCompleteWithPhotos: chybí task_id nebo tenant_id',
    );
  }
  if (newStatus == null || newStatus.isEmpty) {
    throw Exception('processOfflineTaskCompleteWithPhotos: chybí new_status');
  }

  final localPathsRaw = payload['local_photo_paths'];
  final localPaths = <String>[];
  if (localPathsRaw is List) {
    for (final p in localPathsRaw) {
      final s = p?.toString().trim();
      if (s != null && s.isNotEmpty) localPaths.add(s);
    }
  }

  final existingUrlsRaw = payload['existing_media_urls'];
  final existingUrls = <String>[];
  if (existingUrlsRaw is List) {
    for (final u in existingUrlsRaw) {
      final s = u?.toString().trim();
      if (s != null && s.isNotEmpty) existingUrls.add(s);
    }
  }

  final List<String> allMediaUrls = List.from(existingUrls);

  for (final path in localPaths) {
    final file = File(path);
    // PROČ: Očekávaný soubor musí existovat – jinak nesmíme mutaci označit za úspěšnou.
    if (!await file.exists()) {
      throw Exception(
        'processOfflineTaskCompleteWithPhotos: chybí lokální soubor path=$path',
      );
    }
    try {
      final url = await MediaService.instance.uploadMedia(
        file,
        tenantId: tenantId,
        moduleName: _storageModuleTasks,
      );
      if (url == null || url.isEmpty) {
        throw Exception(
          'processOfflineTaskCompleteWithPhotos: upload vrátil prázdnou URL (path=$path)',
        );
      }
      allMediaUrls.add(url);
      await file.delete();
    } catch (_) {
      rethrow;
    }
  }

  final updates = <String, dynamic>{
    'status': newStatus,
    'media_urls': allMediaUrls,
  };

  final startedAt = payload['started_at']?.toString();
  if (startedAt != null && startedAt.isNotEmpty) {
    updates['started_at'] = startedAt;
  }
  final completedAt = payload['completed_at']?.toString();
  if (completedAt != null && completedAt.isNotEmpty) {
    updates['completed_at'] = completedAt;
  }

  final metadataOverlay = payload['metadata_overlay'];
  if (metadataOverlay != null && metadataOverlay is Map) {
    final map = Map<String, dynamic>.from(metadataOverlay);
    if (map.isNotEmpty) {
      final res = await SupabaseService.safeFrom('tasks', tenantId)
          .select('metadata')
          .eq('id', taskId)
          .maybeSingle();
      final existing = res != null
          ? Map<String, dynamic>.from(res['metadata'] as Map)
          : <String, dynamic>{};
      updates['metadata'] = {...existing, ...map};
    }
  }

  await SupabaseService.safeFrom('tasks', tenantId).update(updates).eq('id', taskId);

  // Drift: označíme úkol jako synced, aby WorkerSyncService neposílal redundantní update.
  if (driftTaskRepository != null) {
    try {
      await driftTaskRepository.markTaskSyncedBySupabaseId(tenantId, taskId);
    } catch (e, st) {
      AppLogger.error('offline_photo_task_processor: markTaskSyncedBySupabaseId po uploadu fotek selhalo', e, st);
    }
  }
}
