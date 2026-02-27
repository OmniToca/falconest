import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Režim zobrazení UI pro Adminy a Manažery.
///
/// Uživatelé s rolí admin/manager mohou být přesměrováni buď na desktopové
/// rozhraní administrace (/admin) nebo na mobilní rozhraní pracovníků (/worker).
/// Tento enum určuje, které rozhraní zobrazit.
enum AdminUiMode {
  /// Automaticky: nativní mobilní aplikace → /worker, web (prohlížeč) → /admin.
  /// PROČ: Na mobilu v prohlížeči dostanou zmenšenou desktopovou administraci.
  /// S `auto` na nativním mobilu (iOS/Android) rovnou dostanou mobilní UI.
  /// Na PC v prohlížeči zůstanou na plné administraci.
  auto,

  /// Vždy mobilní rozhraní (/worker) – bez ohledu na platformu.
  /// Užitečné např. když admin otevře web na telefonu a chce mobilní UI.
  forceMobile,

  /// Vždy desktopové rozhraní (/admin) – bez ohledu na platformu.
  /// Užitečné např. když admin používá mobilní aplikaci ale chce plnou administraci.
  forceDesktop,
}

const String _storageKey = 'falconest_admin_ui_mode';

/// Notifier spravující režim zobrazení UI pro Adminy/Manažery.
///
/// Hodnota se ukládá do SharedPreferences a přežívá restart aplikace.
/// Router při změně režimu znovu vyhodnotí redirect a případně přesměruje.
class UiModeNotifier extends ChangeNotifier {
  UiModeNotifier() {
    _loadSaved();
  }

  AdminUiMode _mode = AdminUiMode.auto;

  /// Aktuální režim zobrazení.
  AdminUiMode get mode => _mode;

  /// Načte uloženou hodnotu ze SharedPreferences (asynchronně).
  /// Při startu aplikace může krátce platit výchozí [auto], dokud se hodnota nenačte.
  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      final parsed = _parse(saved);
      if (parsed != _mode) {
        _mode = parsed;
        notifyListeners();
      }
    } catch (_) {
      // Při chybě zůstane výchozí auto
    }
  }

  /// Nastaví režim a uloží do SharedPreferences.
  /// Volání [notifyListeners] spustí v routeru nové vyhodnocení redirectu.
  Future<void> setMode(AdminUiMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, mode.name);
    } catch (_) {
      // Uložení selhalo, ale stav v paměti je aktualizován
    }
    notifyListeners();
  }

  static AdminUiMode _parse(String? value) {
    if (value == null) return AdminUiMode.auto;
    switch (value) {
      case 'forceMobile':
        return AdminUiMode.forceMobile;
      case 'forceDesktop':
        return AdminUiMode.forceDesktop;
      default:
        return AdminUiMode.auto;
    }
  }
}

/// Provider vrací singleton [UiModeNotifier].
/// Používej pro [refreshListenable] v GoRouter a pro volání [setMode].
final uiModeNotifierProvider =
    Provider<UiModeNotifier>((ref) => UiModeNotifier());
