import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web implementace stahování souboru – používá Blob + AnchorElement přes package:web.
///
/// PROČ: FilePicker.platform.saveFile na Webu vyhazuje UnimplementedError.
/// Tento soubor se kompiluje pouze pro web (conditional export v download_helper.dart),
/// nikdy pro mobil – iOS/Android používají download_helper_io.dart.
///
/// Migrace z dart:html na package:web umožňuje kompilaci do WebAssembly (Wasm).
///
/// [bytes] – binární obsah (XLSX, CSV, PDF, …). Pro XLSX používáme MIME
/// application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.
Future<void> downloadBytesAsFile(List<int> bytes, String fileName) async {
  final blob = _createBlob(bytes, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = web.URL.createObjectURL(blob);
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

/// Vytvoří Blob z bajtů pomocí package:web (dart:js_interop).
web.Blob _createBlob(List<int> bytes, String mimeType) {
  final data = Uint8List.fromList(bytes).buffer.toJS;
  return web.Blob([data].toJS, web.BlobPropertyBag(type: mimeType));
}
