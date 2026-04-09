import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/core/offline/network_error_helper.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

const _storageModuleChecklists = 'checklists';

/// Mobil: výběr z kamery, upload do Storage nebo offline kopie do Documents.
///
/// PROČ: Stejný vzor jako dokončení úkolu – při síti URL, při výpadku lokální cesta pro validaci UI.
Future<String?> captureChecklistPhotoForWorker({
  required String taskId,
  required String tenantId,
}) async {
  final file = await MediaService.instance.pickAndCompressImage(source: ImageSource.camera);
  if (file == null || !await file.exists()) return null;

  String? url;
  try {
    url = await MediaService.instance.uploadMedia(
      file,
      tenantId: tenantId,
      moduleName: _storageModuleChecklists,
    );
  } catch (e) {
    if (!isNetworkError(e)) rethrow;
    url = null;
  }
  if (url != null && url.isNotEmpty) return url;

  return copyChecklistPhotoToOfflineDirectory(taskId, file);
}

/// Zkopíruje již vybraný/komprimovaný soubor do trvalého adresáře aplikace.
///
/// PROČ: Stejná cesta pro offline-first checklist (fronta `UPLOAD_CHECKLIST_PHOTO`) i pro
/// starší okamžitý upload s fallbackem při výpadku sítě – jeden zdroj pravdy pro umístění souborů.
/// [file] je typu [File] na IO; signatura je [dynamic] kvůli shodnému exportu se web stubem.
Future<String?> copyChecklistPhotoToOfflineDirectory(String taskId, dynamic file) async {
  final f = file is File ? file : null;
  if (f == null || !await f.exists()) return null;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final sub = Directory('${dir.path}/offline_checklist_photos');
    if (!await sub.exists()) await sub.create(recursive: true);
    final name = '${taskId}_${const Uuid().v4()}.jpg';
    final target = File('${sub.path}/$name');
    await f.copy(target.path);
    return target.path;
  } catch (e, st) {
    AppLogger.error('copyChecklistPhotoToOfflineDirectory: kopie do Documents selhala', e, st);
    return null;
  }
}
