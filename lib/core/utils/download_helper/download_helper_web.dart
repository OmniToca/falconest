// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementace stahování souboru – používá Blob + AnchorElement.
///
/// PROČ: FilePicker.platform.saveFile na Webu vyhazuje UnimplementedError.
/// Tento soubor se kompiluje pouze pro dart:html (web), nikdy pro mobil.
///
/// [bytes] – binární obsah (XLSX, CSV, …). Pro XLSX používáme MIME application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.
Future<void> downloadBytesAsFile(List<int> bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final anchor = html.AnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
