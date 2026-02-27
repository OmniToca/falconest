import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Mobilní/desktop implementace stahování – FilePicker save dialog + zápis do souboru.
///
/// PROČ: Na Webu FilePicker.platform.saveFile nefunguje (UnimplementedError).
/// Tento soubor se kompiluje pro dart:io (mobil, Windows, macOS, Linux).
///
/// [bytes] – binární obsah (XLSX, CSV, …).
Future<void> downloadBytesAsFile(List<int> bytes, String fileName) async {
  final path = await FilePicker.platform.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
  );
  if (path != null && path.trim().isNotEmpty) {
    await File(path).writeAsBytes(bytes);
  }
}
