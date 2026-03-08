/// Inicializace lokální databáze pro mobilní/desktop platformy (iOS, Android, macOS, Windows).
///
/// Isar byl odstraněn – nestabilní na iOS ("Collection id is invalid").
/// Drift (SQLite) se otevře při prvním přístupu přes driftDatabaseProvider.
/// Tento init pouze zajišťuje, že path_provider je připraven.
import 'package:path_provider/path_provider.dart';

Future<void> initDatabase() async {
  // Drift DB se otevře při prvním ref.watch(driftDatabaseProvider).
  // Předběžné volání getApplicationDocumentsDirectory zajistí připravenost path_provider.
  await getApplicationDocumentsDirectory();
}
