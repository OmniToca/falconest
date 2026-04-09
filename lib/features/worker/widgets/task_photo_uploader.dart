import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:falconest/features/worker/utils/worker_photo_annotation_flow.dart';

/// Znovupoužitelný widget pro pořízení a zobrazení fotek úkolu (např. stav apartmánu, pasy).
///
/// PROČ: DRY – logika pro výběr z kamery, miniatury a mazání sdílená s issue_reporter_dialog.
/// Slouží pro úkoly s requires_photo i bez – sekce fotodokumentace je vždy dostupná.
/// Callback [onFilesChanged] předává aktuální seznam souborů rodiči – ten při Dokončit
/// nahraje na Supabase a uloží URL do tasks.media_urls.
class TaskPhotoUploader extends StatefulWidget {
  const TaskPhotoUploader({
    super.key,
    required this.onFilesChanged,
    this.maxPhotos = 3,
    this.existingUrls = const [],
    this.isRequired = false,
  });

  /// Volá se při každé změně seznamu (přidání/smazání). Rodič může číst soubory před dokončením.
  final ValueChanged<List<File>> onFilesChanged;

  /// Maximální počet nových fotek (existující URL se nepočítají – ty jsou jen na zobrazení).
  final int maxPhotos;

  /// Již nahrané URL – zobrazí se jako miniatury (bez mazání – nelze mazat serverová data z tohoto UI).
  final List<String> existingUrls;

  /// true = fotka je povinná k dokončení; false = volitelná dokumentace (škoda, stav).
  final bool isRequired;

  @override
  State<TaskPhotoUploader> createState() => _TaskPhotoUploaderState();
}

class _TaskPhotoUploaderState extends State<TaskPhotoUploader> {
  final List<File> _photoFiles = [];

  @override
  void initState() {
    super.initState();
    _notifyParent();
  }

  void _notifyParent() {
    widget.onFilesChanged(List.from(_photoFiles));
  }

  Future<void> _addPhoto() async {
    if (kIsWeb || _photoFiles.length >= widget.maxPhotos) return;
    final file = await pickWorkerPhotoWithAnnotation(
      context,
      source: ImageSource.camera,
    );
    if (file != null && mounted) {
      setState(() {
        _photoFiles.add(file);
        _notifyParent();
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoFiles.removeAt(index);
      _notifyParent();
    });
  }

  /// Vrací aktuální seznam nových souborů (pro upload při Dokončit).
  List<File> get files => List.unmodifiable(_photoFiles);

  @override
  Widget build(BuildContext context) {
    final canAdd = !kIsWeb && _photoFiles.length < widget.maxPhotos;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'worker.photo_section_title'.tr(),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        // PROČ: Povinná fotka musí být v UI na první pohled jiná než volitelná dokumentace — snižuje to omyl při dokončení.
        DecoratedBox(
          decoration: BoxDecoration(
            color: widget.isRequired
                ? cs.errorContainer.withValues(alpha: 0.45)
                : cs.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isRequired ? cs.error.withValues(alpha: 0.5) : cs.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.isRequired ? Icons.priority_high_rounded : Icons.add_photo_alternate_outlined,
                  size: 22,
                  color: widget.isRequired ? cs.error : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isRequired
                        ? 'worker.task_photo_required'.tr()
                        : 'worker.task_photo_optional'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: widget.isRequired ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isRequired ? cs.onErrorContainer : cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: canAdd ? _addPhoto : null,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text('worker.task_photo_uploader_add'.tr()),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (_photoFiles.isNotEmpty || widget.existingUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.existingUrls.length + _photoFiles.length,
              separatorBuilder: (context, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index < widget.existingUrls.length) {
                  final url = widget.existingUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade300,
                        child: Icon(Icons.broken_image, color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                final fileIndex = index - widget.existingUrls.length;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _photoFiles[fileIndex],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: IconButton.filled(
                        iconSize: 18,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(4),
                          minimumSize: const Size(28, 28),
                        ),
                        icon: const Icon(Icons.close),
                        onPressed: () => _removePhoto(fileIndex),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
