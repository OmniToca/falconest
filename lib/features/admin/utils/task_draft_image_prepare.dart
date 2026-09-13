import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:falconest/core/utils/app_logger.dart';

/// Příprava screenshotu pro Edge `parse-task-draft` (komprese + Base64).
///
/// PROČ: Gemini payload a Edge limity – zmenšíme dlouhé WhatsApp screenshoty
/// na JPEG ~1280px / quality 70, max cca 900 KB binárně.
class TaskDraftImagePayload {
  const TaskDraftImagePayload({
    required this.base64,
    required this.mimeType,
    required this.previewBytes,
  });

  final String base64;
  final String mimeType;

  /// Byty pro náhled v UI (stejný JPEG po kompresi).
  final Uint8List previewBytes;
}

class TaskDraftImagePrepare {
  TaskDraftImagePrepare._();

  static const int maxLongEdgePx = 1280;
  static const int jpegQuality = 70;
  static const int maxBytes = 900 * 1024;

  /// Komprimuje bajty obrázku a vrátí Base64 payload pro Edge Function.
  static Future<TaskDraftImagePayload> prepare(Uint8List sourceBytes) async {
    if (sourceBytes.isEmpty) {
      throw StateError('empty image');
    }

    Uint8List out = sourceBytes;
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        sourceBytes,
        minWidth: maxLongEdgePx,
        minHeight: maxLongEdgePx,
        quality: jpegQuality,
        format: CompressFormat.jpeg,
      );
      if (compressed.isNotEmpty) {
        out = Uint8List.fromList(compressed);
      }
    } catch (e, st) {
      AppLogger.error(
        'TaskDraftImagePrepare: komprese selhala – použiji originál',
        e,
        st,
      );
    }

    // Druhý pokus při stále velkém souboru.
    if (out.lengthInBytes > maxBytes) {
      try {
        final tighter = await FlutterImageCompress.compressWithList(
          out,
          minWidth: 960,
          minHeight: 960,
          quality: 55,
          format: CompressFormat.jpeg,
        );
        if (tighter.isNotEmpty) {
          out = Uint8List.fromList(tighter);
        }
      } catch (e, st) {
        AppLogger.error(
          'TaskDraftImagePrepare: druhá komprese selhala',
          e,
          st,
        );
      }
    }

    if (out.lengthInBytes > maxBytes) {
      throw StateError('image_too_large');
    }

    return TaskDraftImagePayload(
      base64: base64Encode(out),
      mimeType: 'image/jpeg',
      previewBytes: out,
    );
  }
}
