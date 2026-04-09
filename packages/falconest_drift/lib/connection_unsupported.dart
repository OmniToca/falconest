import 'package:drift/drift.dart';

/// Spojení Drift na platformě bez FFI ani WASM (např. starší konfigurace).
///
/// PROČ: Dart2js ani některé embeddované cíle neumí [dart:ffi]; tento soubor se načte jen
/// když neplatí ani [dart.library.ffi], ani [dart.library.js_interop] pro web.
QueryExecutor connectFalconestDrift() {
  return LazyDatabase(() async {
    throw UnsupportedError(
      'FalcoNest Drift: lokální SQLite na této platformě není podporována '
      '(použijte iOS, Android, desktop nebo web s WASM sqlite3).',
    );
  });
}
