import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/owner/providers/owner_task_checklist_photos_provider.dart';

/// DTO pro read-only detail úkolu – nezávislý na [PlanningTask] i [TaskRow].
///
/// Kalendář předává data z PlanningTask, seznam úkolů z TaskRow.
/// [taskId]: pokud je vyplněno, načtou se fotky z checklistu (Klientský portál).
class OwnerTaskDetailData {
  const OwnerTaskDetailData({
    this.taskId,
    required this.title,
    required this.taskType,
    this.apartmentName,
    this.scheduledStart,
    required this.status,
    this.description,
    this.mediaUrls = const [],
  });

  /// ID úkolu v Supabase – pro načtení [task_checklist_items.photo_url].
  final String? taskId;
  final String title;
  final String taskType;
  final String? apartmentName;
  final DateTime? scheduledStart;
  final String status;
  final String? description;
  final List<String> mediaUrls;
}

/// Jedna položka ve fotodokumentaci (URL + popisek pod fotkou).
class _PhotoDocEntry {
  const _PhotoDocEntry({required this.url, required this.caption});

  final String url;
  final String caption;
}

/// Read-only dialog s detailem úkolu pro majitele.
///
/// Zobrazuje stav, popis a sjednocenou galerii [tasks.media_urls] + fotky z checklistu.
class OwnerTaskDetailDialog extends ConsumerStatefulWidget {
  const OwnerTaskDetailDialog({super.key, required this.data});

  final OwnerTaskDetailData data;

  static Future<void> show(BuildContext context, OwnerTaskDetailData data) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => OwnerTaskDetailDialog(data: data),
    );
  }

  @override
  ConsumerState<OwnerTaskDetailDialog> createState() => _OwnerTaskDetailDialogState();
}

class _OwnerTaskDetailDialogState extends ConsumerState<OwnerTaskDetailDialog> {
  /// Galerie: přílohy úkolu + (pokud je [taskId]) fotky z checklistu.
  Widget _buildPhotoDocumentation(BuildContext context, String? taskId) {
    if (taskId != null && taskId.isNotEmpty) {
      final checklistAsync = ref.watch(ownerTaskChecklistPhotosProvider(taskId));
      return checklistAsync.when(
        data: (checklistPhotos) => _photoDocColumn(context, _mergePhotoEntries(checklistPhotos)),
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => _photoDocColumn(context, _mergePhotoEntries(const [])),
      );
    }
    return _photoDocColumn(context, _mergePhotoEntries(const []));
  }

  Widget _photoDocColumn(BuildContext context, List<_PhotoDocEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'owner.task_detail_photo_documentation'.tr(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _LabeledPhotoTile(entry: e),
          ),
        ),
      ],
    );
  }

  static String _taskTypeLabelKey(String taskType) {
    final code =
        (taskType.trim().isEmpty ? 'other' : taskType.toLowerCase()).replaceAll('-', '_');
    return 'admin.task_type_$code';
  }

  static String _statusLabel(String? status) {
    if (status == null || status.trim().isEmpty) return 'task_status.assigned'.tr();
    final s = status.trim().toLowerCase();
    if (s == 'in_progress' || s == 'probíhá') return 'task_status.in_progress'.tr();
    if (s == 'completed' || s == 'done' || s == 'hotovo') return 'task_status.completed'.tr();
    if (s == 'problem' || s == 'problém') return 'task_status.problem'.tr();
    if (s == 'pending') return 'owner.task_status_new'.tr();
    return 'task_status.assigned'.tr();
  }

  static Color _statusColor(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'in_progress' || s == 'probíhá') return const Color(0xFF1565C0);
    if (s == 'problem' || s == 'problém') return const Color(0xFFC62828);
    if (s == 'completed' || s == 'done' || s == 'hotovo') return const Color(0xFF2E7D32);
    return const Color(0xFF757575);
  }

  List<_PhotoDocEntry> _mergePhotoEntries(List<OwnerTaskChecklistPhoto> checklistPhotos) {
    final entries = <_PhotoDocEntry>[];
    final taskCaption = 'owner.task_detail_photo_task_attachment'.tr();
    for (final url in widget.data.mediaUrls) {
      final u = url.trim();
      if (u.isEmpty) continue;
      entries.add(_PhotoDocEntry(url: u, caption: taskCaption));
    }
    for (final p in checklistPhotos) {
      entries.add(_PhotoDocEntry(url: p.photoUrl, caption: p.title));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final theme = Theme.of(context);
    final statusColor = _statusColor(data.status);
    final dateTimeStr = data.scheduledStart != null
        ? '${DateFormat('d.M.yyyy', context.locale.toString()).format(data.scheduledStart!)} '
            '${data.scheduledStart!.hour.toString().padLeft(2, '0')}:${data.scheduledStart!.minute.toString().padLeft(2, '0')}'
        : null;

    final taskId = data.taskId?.trim();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'owner.task_detail_title'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.title.trim().isEmpty ? 'admin.task_no_title'.tr() : data.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.category_outlined, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _taskTypeLabelKey(data.taskType).tr(),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusLabel(data.status),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (data.apartmentName != null && data.apartmentName!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailRow(
                label: 'owner.task_detail_apartment'.tr(),
                value: data.apartmentName!,
              ),
            ],
            if (dateTimeStr != null) ...[
              const SizedBox(height: 8),
              _DetailRow(
                label: 'owner.task_detail_date'.tr(),
                value: dateTimeStr,
              ),
            ],
            const SizedBox(height: 8),
            _DetailRow(
              label: 'owner.task_detail_staff'.tr(),
              value: 'owner.tasks_staff_label'.tr(),
            ),
            if (data.description != null && data.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'owner.task_detail_description_label'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  data.description!.trim(),
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ],
            _buildPhotoDocumentation(context, taskId),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.close'.tr()),
        ),
      ],
    );
  }
}

class _LabeledPhotoTile extends StatelessWidget {
  const _LabeledPhotoTile({required this.entry});

  final _PhotoDocEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => _showFullScreenPhoto(context, entry.url),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                entry.url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade200,
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade600, size: 40),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          entry.caption,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  void _showFullScreenPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.grey.shade800,
                    child: Icon(Icons.broken_image_outlined, size: 64, color: Colors.grey.shade400),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton.filled(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

