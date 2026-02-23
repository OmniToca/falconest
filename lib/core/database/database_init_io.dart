/// Inicializace Isar lokální databáze pro mobilní/desktop platformy (iOS, Android, macOS, Windows).
///
/// Tento soubor se kompiluje pouze při build pro dart:io (ne web).
/// Isar umožňuje offline-first režim – data se čtou lokálně a synchronizují na pozadí.
import 'package:falconest/core/database/isar_service.dart';

Future<void> initDatabase() async {
  await IsarService.init();
}
