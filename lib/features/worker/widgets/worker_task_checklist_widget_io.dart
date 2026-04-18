import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/worker/models/worker_task_checklist_line.dart';
import 'package:falconest/features/worker/providers/worker_task_checklist_ops_provider.dart';
import 'package:falconest/features/worker/providers/worker_task_checklist_provider.dart';
import 'package:falconest/features/worker/widgets/worker_checklist_image_preview.dart';

/// Sekce checklistu u úkolu – odškrtávání a povinné fotky z Driftu (offline-first).
///
/// PROČ: Dispečer může připnout šablonu; worker musí splnit všechny body před dokončením úkolu.
/// Tento soubor se kompiluje jen pro mobil (dart:io) – na webu se nepoužívá kvůli závislosti na SQLite.
///
/// **Viditelnost:** nesmí záviset na `task.status`. Pokud [workerTaskChecklistProvider] vrátí **prázdný** seznam
/// (žádná šablona / žádné řádky v Driftu), widget se **vůbec nevykreslí** – žádná karta „checklist prázdný“.
class WorkerTaskChecklistWidget extends ConsumerWidget {
  const WorkerTaskChecklistWidget({
    super.key,
    required this.taskId,
    this.readOnly = false,
  });

  final String taskId;
  /// Pokud true (úkol ještě neprobíhá nebo je hotový) – jen náhled bez zápisu do Driftu.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workerTaskChecklistProvider(taskId));
    return async.when(
      data: (lines) {
        // PROČ: Sekci skrýt jen když neexistují žádné položky a nic nečeká na splnění (pendingCount == 0).
        // Pokud jsou všechny body hotové, seznam není prázdný → hlavička „Checklist“ zůstane (náhled splnění).
        final pendingCount = lines.where((l) => !l.isCompleted).length;
        if (pendingCount == 0 && lines.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'tasks.worker_checklist_title'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WorkerChecklistRow(
                        taskId: taskId,
                        line: line,
                        readOnly: readOnly,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      // PROČ: Neblikat pruhem u úkolů bez checklistu – první emise dat bývá okamžitě prázdná.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _WorkerChecklistRow extends ConsumerStatefulWidget {
  const _WorkerChecklistRow({
    required this.taskId,
    required this.line,
    required this.readOnly,
  });

  final String taskId;
  final WorkerTaskChecklistLine line;
  final bool readOnly;

  @override
  ConsumerState<_WorkerChecklistRow> createState() => _WorkerChecklistRowState();
}

class _WorkerChecklistRowState extends ConsumerState<_WorkerChecklistRow> {
  bool _uploading = false;

  Future<void> _onToggle(bool? value) async {
    if (widget.readOnly || value == null) return;
    // PROČ: Checkbox vždy zařadí mutaci `UPDATE_CHECKLIST_ITEM` – konzistentní offline-first s frontou.
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    final profileId = ref.read(authNotifierProvider).profileId;
    try {
      await ref.read(workerTaskChecklistOpsControllerProvider).toggleItemCompletedQueued(
            driftRowId: widget.line.driftRowId,
            completed: value,
            tenantId: tenantId,
            completedByProfileId: profileId,
          );
    } catch (e, st) {
      // PROČ: Zápis do Driftu může selhat (disk plný, poškozená DB) — bez zpětné vazby by worker nevěděl, že stav neplatí.
      AppLogger.error('WorkerTaskChecklist: toggleItemCompletedQueued selhalo', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.checklist_update_failed'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final pu = line.photoUrl?.trim() ?? '';
    final lp = line.localPhotoPath?.trim() ?? '';
    final hasRemotePhoto = pu.isNotEmpty;
    final hasLocalAttachment = lp.isNotEmpty;
    final hasPhoto = hasRemotePhoto || hasLocalAttachment;
    final previewSource = hasRemotePhoto ? pu : lp;

    // PROČ: Obě větve používají stejný offline-first tok (kamera → disk → Drift → fronta uploadu).
    Widget? secondary;
    if (widget.readOnly) {
      if (hasPhoto && previewSource.isNotEmpty) {
        secondary = buildWorkerChecklistImagePreview(previewSource);
      }
    } else {
      secondary = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPhoto && previewSource.isNotEmpty)
            buildWorkerChecklistImagePreview(previewSource)
          else
            const SizedBox(width: 40, height: 40),
          const SizedBox(width: 4),
          if (line.isPhotoRequired)
            IconButton(
              tooltip: 'tasks.checklist_take_photo'.tr(),
              onPressed: _uploading ? null : () => _onChecklistPhotoPressed(context),
              icon: _uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      hasRemotePhoto ? Icons.edit_outlined : Icons.photo_camera_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            )
          else
            IconButton(
              tooltip: 'tasks.checklist_add_photo_stub'.tr(),
              onPressed: _uploading ? null : () => _onChecklistPhotoPressed(context),
              icon: Icon(
                hasLocalAttachment ? Icons.edit_outlined : Icons.photo_camera_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      );
    }

    final tile = CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(line.title, maxLines: 3, overflow: TextOverflow.ellipsis),
      value: line.isCompleted,
      onChanged: widget.readOnly ? null : _onToggle,
      secondary: secondary,
    );

    // PROČ: V terénu je těžké trefit malý checkbox; swipe vpravo dokončí stejně jako zaškrtnutí
    // (Dismissible nesmí řádek odstranit ze stromu — confirmDismiss vrací false).
    if (widget.readOnly) {
      return tile;
    }

    final itemKey = widget.line.supabaseItemId?.trim().isNotEmpty == true
        ? widget.line.supabaseItemId!
        : 'drift-${widget.line.driftRowId}';

    return Dismissible(
      key: ValueKey<String>('chk-$itemKey'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await _onToggle(!line.isCompleted);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.check_circle, color: Colors.white.withValues(alpha: 0.95), size: 32),
      ),
      child: tile,
    );
  }

  /// Společná obsluha kamery – lokální uložení + fronta [UPLOAD_CHECKLIST_PHOTO] v controlleru.
  Future<void> _onChecklistPhotoPressed(BuildContext context) async {
    if (widget.readOnly) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('tasks.checklist_photo_web_unavailable'.tr())),
      );
      return;
    }
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    final sid = widget.line.supabaseItemId?.trim();
    if (sid == null || sid.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('tasks.checklist_item_not_synced'.tr())),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final ok = await ref.read(workerTaskChecklistOpsControllerProvider).captureAndSavePhoto(
            widget.taskId,
            sid,
          );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('tasks.checklist_photo_upload_error'.tr()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('tasks.checklist_photo_upload_error'.tr()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
