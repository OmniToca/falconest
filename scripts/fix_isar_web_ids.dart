// Fix skript pro Isar schema ID – oprava pro Flutter web build
//
// Isar generator používá 64-bitová čísla pro CollectionSchema.id. JavaScript
// má bezpečný celočíselný rozsah jen ±2^53 (Number.MAX_SAFE_INTEGER), takže
// při flutter run -d web-server vznikne chyba "The integer literal can't be
// represented exactly in JavaScript." Tento skript nahradí tato schema ID
// web-safe hodnotami (1, 2, 3, …) v .g.dart souborech.
//
// DŮLEŽITÉ: Po každém spuštění build_runner znovu vygeneruje .g.dart s velkými
// ID. Před buildem pro web vždy spusť tento skript:
//
//   dart run build_runner build --delete-conflicting-outputs
//   dart run scripts/fix_isar_web_ids.dart
//   flutter run -d web-server

import 'dart:io';

/// Mapování problémových 64-bit schema ID (xxh3 z Isar generatoru)
/// na web-safe hodnoty (max ±2^53 v JavaScriptu).
///
/// PROČ: Flutter web kompiluje Dart do JavaScriptu. V JS je Number reprezentován
/// jako double; celá čísla jsou přesně reprezentovatelná jen v rozsahu ±2^53
/// (Number.MAX_SAFE_INTEGER). Isar generátor používá 64-bitová schema ID, která
/// tento rozsah překračují, což způsobuje chybu "The integer literal can't be
/// represented exactly in JavaScript." Tato náhrada zajistí, že .g.dart soubory
/// obsahují pouze 53-bit bezpečné literály a web build projde.
///
/// Při přidání nového Isar modelu doplň jeho vygenerované schema ID sem.
final Map<int, int> _idReplacements = {
  557933263205041222: 1,           // ApartmentLocal
  -9072514404709919410: 2,        // TaskLocal
  2346012127249937678: 3,         // PendingAuditAction
};

void main() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final projectRoot = scriptDir.parent;
  final modelsDir = '${projectRoot.path}/lib/core/database/models';

  final dir = Directory(modelsDir);
  if (!dir.existsSync()) {
    print('Adresář $modelsDir neexistuje.');
    exit(1);
  }

  int totalReplacements = 0;

  for (final entity in dir.listSync()) {
    if (entity is File && entity.path.endsWith('.g.dart')) {
      final content = entity.readAsStringSync();
      String newContent = content;

      for (final entry in _idReplacements.entries) {
        final oldId = entry.key;
        final newId = entry.value;

        // Hledáme pattern "id: <oldId>" v kontextu CollectionSchema
        final pattern = RegExp('id: $oldId');
        if (pattern.hasMatch(newContent)) {
          newContent = newContent.replaceAll(pattern, 'id: $newId');
          totalReplacements++;
          print('  ${entity.path.split(Platform.pathSeparator).last}: $oldId -> $newId');
        }
      }

      if (newContent != content) {
        entity.writeAsStringSync(newContent);
      }
    }
  }

  if (totalReplacements > 0) {
    print('Opraveno $totalReplacements schema ID pro Flutter web.');
  } else {
    print('Žádné problémové schema ID nenalezeno.');
  }
}
