import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:falconest/core/services/media_service.dart';

/// Znovupoužitelný widget pro pořízení a zobrazení fotek úkolu (např. stav apartmánu, pasy).
///
/// PROČ: DRY – logika pro výběr z kamery, miniatury a mazání sdílená s issue_reporter_dialog.
/// Slouží pro úkoly s requires_photo (katalog služeb). Callback [onFilesChanged] předává
/// aktuální seznam souborů rodiči – ten při Dokončit nahraje na Supabase a uloží URL do tasks.media_urls.
class TaskPhotoUploader extends StatefulWidget {
  const TaskPhotoUploader({
    super.key,
    required this.onFilesChanged,
    this.maxPhotos = 3,
    this.existingUrls = const [],
  });

  /// Volá se při každé změně seznamu (přidání/smazání). Rodič může číst soubory před dokončením.
  final ValueChanged<List<File>> onFilesChanged;

  /// Maximální počet nových fotek (existující URL se nepočítají – ty jsou jen na zobrazení).
  final int maxPhotos;

  /// Již nahrané URL – zobrazí se jako miniatury (bez mazání – nelze mazat serverová data z tohoto UI).
  final List<String> existingUrls;

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
    final file = await MediaService.instance.pickAndCompressImage(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                      errorBuilder: (_, __, ___) => Container(
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
