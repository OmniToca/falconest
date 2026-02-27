/// Rozcestník pro stahování souborů – web vs. mobil/desktop.
///
/// Společný rozhraní bez přímého importu dart:html – podmíněný export
/// vybere správnou implementaci podle platformy.
///
/// - Web (dart.library.html): Blob + AnchorElement pro browser download.
/// - IO (mobil, desktop): FilePicker save dialog + File.writeAsBytes.
/// Volání: downloadBytesAsFile(bytes, 'soubor.xlsx')
export 'download_helper_io.dart' if (dart.library.html) 'download_helper_web.dart';
