import 'package:flutter/foundation.dart';

/// Jednotné místo pro logování chyb z catch bloků (nahrazuje tiché `catch (_) {}`).
///
/// PROČ: Tiché polykání výjimek znemožňuje diagnostiku v QA i produkci. Pro začátek
/// používáme [debugPrint] (v release buildu často potlačený / omezený); později lze
/// metodu napojit na Sentry, Crashlytics nebo strukturovaný log bez změny volajících míst.
class AppLogger {
  AppLogger._();

  /// Dočasné diagnostické logy (např. dvojnásobný „Dostupný zůstatek“) – v release buildu typicky potlačeno.
  static void debug(String message) {
    debugPrint('[FalcoNest][DEBUG] $message');
  }

  /// Zaloguje chybu s kontextem. [error] a [stackTrace] jsou volitelné (např. z `catch (e, st)`).
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[FalcoNest][ERROR] $message');
    if (error != null) {
      debugPrint('[FalcoNest][ERROR] detail: $error');
    }
    if (stackTrace != null) {
      debugPrint('[FalcoNest][ERROR] stack:\n$stackTrace');
    }
  }
}
