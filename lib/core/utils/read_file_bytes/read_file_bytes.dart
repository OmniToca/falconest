/// Čte soubor z cesty jako bajty. Na webu není podporováno.
export 'read_file_bytes_io.dart' if (dart.library.html) 'read_file_bytes_web.dart';
