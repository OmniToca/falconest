import 'package:drift/drift.dart';

// PROČ podmíněné importy: web (dart2js) nepodporuje FFI – soubor s [sqlite3]/[dart:ffi]
// se nesmí analyzovat při `flutter build web`. Pořadí: nejdřív VM s FFI, pak prohlížeč s JS interop.
import 'connection_unsupported.dart'
    if (dart.library.ffi) 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';

/// Vrátí [QueryExecutor] pro [AppDatabase] podle cílové platformy kompilace.
QueryExecutor openFalcoNestDriftConnection() => connectFalconestDrift();
