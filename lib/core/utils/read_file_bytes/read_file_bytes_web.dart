/// Web stub – na webu FilePicker typicky vrací bytes přímo.
/// Pokud bytes chybí, není fallback (web nemá přístup k souborové soustavě).
Future<List<int>> readFileBytes(String path) async {
  throw UnsupportedError('readFileBytes na webu není podporováno – použijte FilePicker s withData: true');
}
