/// Stub inicializace databáze pro web.
///
/// Na webu Isar neběží (dart:html/JS nedokáže zpracovat 64-bit inty v Isar).
/// Tento soubor NEOBSAHUJE žádný import Isaru – používá se při kompilaci pro web.
/// Volání init() je no-op, aby aplikace nebortla.
Future<void> initDatabase() async {
  // Web je vždy online – lokální Isar databáze není potřeba.
}
