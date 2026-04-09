import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/features/worker/screens/photo_annotation_screen.dart';

/// Pořídí fotku a otevře obrazovku anotace (červené čáry); web jen [MediaService.pickAndCompressImage].
///
/// PROČ: Jednotný vstup pro hlášení závad a fotodokumentaci úkolu bez duplicity navigace.
/// Vrací null, pokud uživatel zruší výběr nebo zavře anotaci křížkem.
Future<File?> pickWorkerPhotoWithAnnotation(
  BuildContext context, {
  required ImageSource source,
}) async {
  if (kIsWeb) {
    return MediaService.instance.pickAndCompressImage(source: source);
  }
  final raw = await MediaService.instance.pickAndCompressImage(source: source);
  if (raw == null || !context.mounted) return null;
  final out = await Navigator.of(context).push<File?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => PhotoAnnotationScreen(imageFile: raw),
    ),
  );
  return out;
}
