import 'dart:io';

/// Mobilní/desktop implementace – čte soubor z cesty jako bajty.
///
/// Používá se jako fallback, když FilePicker vrátí path ale ne bytes (např. macOS).
Future<List<int>> readFileBytes(String path) async {
  return File(path).readAsBytes();
}
