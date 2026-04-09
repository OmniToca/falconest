// FalcoNest – Drift Web Worker (WASM SQLite).
//
// PROČ: Tento soubor se kompiluje do `drift_worker.dart.js` a spouští se v dedicovaném
// Web Workeru prohlížeče (oddělené vlákno od hlavního „main isolate“ Flutter webu).
// Databázové operace přes SQLite/WASM tak neblokují vykreslování UI a Drift může bezpečně
// komunikovat s hlavní aplikací přes MessageChannel (viz `WasmDatabase.open` v balíčku drift).
//
// POZNÁMKA: Starší varianta `package:drift/web/worker.dart` + `driftWorkerMain` je u Driftu
// označená jako zastaralá; pro `WasmDatabase.open` je správný vstupní bod `workerMainForOpen`
// z `package:drift/wasm.dart` (stejně jako v oficiálním příkladu examples/app/web/worker.dart).

import 'package:drift/wasm.dart';

void main() {
  WasmDatabase.workerMainForOpen();
}
