import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider pro stav odemknutí PINem v rámci aktuální session.
///
/// Když uživatel zadá správný PIN na mobilu, nastaví se na true. Při odhlášení
/// nebo při "Přihlásit se e-mailem" se resetuje. Pouze pro mobil – na webu
/// se PIN nepoužívá.
final pinUnlockedProvider = StateProvider<bool>((ref) => false);
