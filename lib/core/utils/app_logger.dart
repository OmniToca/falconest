import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Jednotné místo pro logování chyb z catch bloků (nahrazuje tiché `catch (_) {}`).
///
/// PROČ: Tiché polykání výjimek znemožňuje diagnostiku v QA i produkci.
/// Na iOS/Android v release posíláme do Firebase Crashlytics; na webu a v debug
/// zůstává konzole (Crashlytics na webu Flutter SDK zatím nedává plnou paritu).
class AppLogger {
  AppLogger._();

  static bool _crashlyticsReady = false;

  /// Zapne sběr Crashlytics po [Firebase.initializeApp] (jen non-web, non-debug).
  ///
  /// PROČ volitelně: init nesmí shodit start aplikace, pokud Crashlytics není
  /// nakonfigurované v native projektu – chybu jen zalogujeme.
  static Future<void> initCrashlytics() async {
    if (kIsWeb) {
      _crashlyticsReady = false;
      return;
    }
    try {
      // V debug nezasypáváme Firebase – stačí konzole.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      _crashlyticsReady = !kDebugMode;
    } catch (e, st) {
      _crashlyticsReady = false;
      debugPrint('[FalcoNest][ERROR] Crashlytics init selhal: $e\n$st');
    }
  }

  /// Dočasné diagnostické logy – v release buildu typicky potlačeno frameworkem.
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

    if (!_crashlyticsReady) return;
    try {
      FirebaseCrashlytics.instance.recordError(
        error ?? message,
        stackTrace,
        reason: message,
        fatal: false,
      );
    } catch (_) {
      // Nikdy neshodit volající kód kvůli telemetrii.
    }
  }

  /// Fatální chyba frameworku / zone – Crashlytics + konzole.
  static void recordFlutterFatal(Object error, StackTrace stackTrace) {
    debugPrint('[FalcoNest][FATAL] $error\n$stackTrace');
    if (!_crashlyticsReady) return;
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    } catch (_) {}
  }
}
