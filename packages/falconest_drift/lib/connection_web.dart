import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web: SQLite přes WASM worker (bez [dart:ffi]).
///
/// PROČ: Na webu musí být veškerá práce s nativním SQLite v odděleném souboru pod
/// [dart.library.js_interop], jinak kompilátor stáhne FFI větev [sqlite3] a build spadne.
/// Soubory `sqlite3.wasm` a worker skript je potřeba doplnit do `web/` dle dokumentace Driftu.
QueryExecutor connectFalconestDrift() {
  return LazyDatabase(() async {
    final opened = await WasmDatabase.open(
      databaseName: 'falconest_drift',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return opened.resolvedExecutor;
  });
}
