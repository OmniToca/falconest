import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/offline/mutation_queue_service_mobile.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/features/worker/widgets/worker_checklist_photo_helper.dart';

/// Orchestrace zápisů checklistu z Worker UI.
///
/// PROČ: Oddělujeme Riverpod vrstvu od repozitáře – checkbox vždy projde přes frontu mutací,
/// fotky jdou nejdřív na disk + Drift a upload dorazí přes [UPLOAD_CHECKLIST_PHOTO].
class WorkerTaskChecklistOpsController {
  WorkerTaskChecklistOpsController(this._ref);

  final Ref _ref;

  /// Přepíše `is_completed` v Driftu a zařadí `UPDATE_CHECKLIST_ITEM` do pending mutací.
  Future<void> toggleItemCompletedQueued({
    required int driftRowId,
    required bool completed,
    required String tenantId,
    String? completedByProfileId,
  }) async {
    await _ref.read(driftTaskChecklistRepositoryProvider).setItemCompletedQueued(
          driftRowId: driftRowId,
          completed: completed,
          tenantId: tenantId,
          completedByProfileId: completedByProfileId,
        );
  }

  /// Pořídí fotku z kamery, uloží ji lokálně, zapíše cestu do Driftu a zařadí upload do fronty.
  ///
  /// [taskId] = Supabase UUID úkolu (stejné jako v [workerTaskChecklistProvider]).
  /// [itemId] = Supabase UUID řádku `task_checklist_items.id`.
  ///
  /// PROČ: Striktní offline-first – UI okamžitě ukáže náhled z disku; síť řeší [DriftMutationQueueService].
  /// Vrací `true` při úspěchu (včetně zařazení mutace), `false` při zrušení nebo chybě před zápisem.
  Future<bool> captureAndSavePhoto(String taskId, String itemId) async {
    final tenantId = _ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return false;
    if (taskId.trim().isEmpty || itemId.trim().isEmpty) return false;

    final repo = _ref.read(driftTaskChecklistRepositoryProvider);
    final driftRowId = await repo.resolveDriftRowIdForChecklistItem(
      tenantId: tenantId,
      supabaseItemId: itemId.trim(),
    );
    if (driftRowId == null) return false;

    final picked = await MediaService.instance.pickAndCompressImage(source: ImageSource.camera);
    if (picked == null) return false;

    final localPath = await copyChecklistPhotoToOfflineDirectory(taskId.trim(), picked);
    if (localPath == null || localPath.isEmpty) return false;

    await repo.setItemLocalPhotoPath(
      driftRowId: driftRowId,
      tenantId: tenantId,
      localPath: localPath,
    );

    await _ref.read(mutationQueueServiceProvider).enqueueMutation(
          table: 'task_checklist_items',
          action: 'UPLOAD_CHECKLIST_PHOTO',
          recordId: itemId.trim(),
          payload: <String, dynamic>{
            'tenant_id': tenantId,
            'task_id': taskId.trim(),
            'item_id': itemId.trim(),
            'local_path': localPath,
          },
        );

    return true;
  }

  /// Zachováno pro zpětnou kompatibilitu – nové UI volá [captureAndSavePhoto].
  Future<void> attachStubPhoto({
    required int driftRowId,
    required String tenantId,
  }) async {
    await _ref.read(driftTaskChecklistRepositoryProvider).setItemLocalPhotoStub(
          driftRowId: driftRowId,
          tenantId: tenantId,
        );
  }
}

/// Jedna instance controlleru na scope – drží jen [Ref], žádný vlastní stav.
final workerTaskChecklistOpsControllerProvider =
    Provider<WorkerTaskChecklistOpsController>((ref) => WorkerTaskChecklistOpsController(ref));
