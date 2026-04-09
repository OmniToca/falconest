import 'dart:io';

import 'package:falconest/core/database/drift/repositories/drift_task_checklist_repository.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Modul Storage – shodně s [MediaService] uploadem z worker checklist helperu.
const _storageModuleChecklists = 'checklists';

/// Zpracuje mutaci [UPLOAD_CHECKLIST_PHOTO] – nahrání lokální fotky a zápis URL do Supabase + Drift.
///
/// PROČ: Worker nejdřív ukládá jen do SQLite a na disk; tato funkce doručí až online.
/// Po úspěchu smažeme lokální kopii, aby se neplnila paměť a při opakování fronty nedocházelo k duplicitám.
Future<void> processUploadChecklistPhoto(
  Map<String, dynamic> payload, {
  DriftTaskChecklistRepository? checklistRepo,
}) async {
  final tenantId = payload['tenant_id']?.toString().trim();
  final itemId = payload['item_id']?.toString().trim();
  final localPath = payload['local_path']?.toString().trim();
  // PROČ: Bez tenant/item/cesty nelze upload dokončit – mutace musí zůstat ve frontě.
  if (tenantId == null ||
      tenantId.isEmpty ||
      itemId == null ||
      itemId.isEmpty ||
      localPath == null ||
      localPath.isEmpty) {
    throw Exception(
      'processUploadChecklistPhoto: chybí tenant_id, item_id nebo local_path',
    );
  }

  final file = File(localPath);
  if (!await file.exists()) {
    // PROČ: Po částečném úspěchu mohl být soubor už smazán – dotáhneme stav ze serveru a srovnáme Drift.
    try {
      final row = await SupabaseService.safeFrom('task_checklist_items', tenantId)
          .select('photo_url')
          .eq('id', itemId)
          .maybeSingle();
      final remoteUrl = row?['photo_url']?.toString().trim();
      if (remoteUrl != null &&
          remoteUrl.isNotEmpty &&
          (remoteUrl.startsWith('http://') || remoteUrl.startsWith('https://'))) {
        await checklistRepo?.applyChecklistItemPhotoFromUploadQueue(
          tenantId: tenantId,
          itemSupabaseId: itemId,
          photoUrl: remoteUrl,
        );
        return;
      }
    } catch (_) {
      rethrow;
    }
    // PROČ: Lokální soubor chybí a na serveru není URL – operace není dokončená, mutaci nesmažeme.
    throw Exception(
      'processUploadChecklistPhoto: chybí lokální soubor a na serveru není photo_url (item_id=$itemId)',
    );
  }

  String? publicUrl;
  try {
    publicUrl = await MediaService.instance.uploadMedia(
      file,
      tenantId: tenantId,
      moduleName: _storageModuleChecklists,
    );
  } catch (e) {
    rethrow;
  }

  if (publicUrl == null || publicUrl.isEmpty) {
    throw StateError('Upload checklist photo: prázdná URL z MediaService');
  }

  await SupabaseService.safeFrom('task_checklist_items', tenantId).update({
    'photo_url': publicUrl,
  }).eq('id', itemId);

  await checklistRepo?.applyChecklistItemPhotoFromUploadQueue(
    tenantId: tenantId,
    itemSupabaseId: itemId,
    photoUrl: publicUrl,
  );

  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // PROČ: Smazání je úklid – nesmí zhatit úspěšný upload kvůli oprávněním na některých zařízeních.
  }
}
