import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Klíč pro uložení 6místného PINu v secure storage.
const String _pinKey = 'falconest_app_pin';

/// Služba pro bezpečné uložení 6místného PINu na zařízení.
///
/// Používá flutter_secure_storage – data jsou šifrovaná. Pouze pro mobilní
/// aplikaci (iOS/Android); na webu se PIN nepoužívá.
class PinStorage {
  PinStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// Zkontroluje, zda má uživatel uložený PIN.
  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.length == 6;
  }

  /// Přečte uložený PIN. Vrací null, pokud není nastaven.
  static Future<String?> getPin() async {
    return _storage.read(key: _pinKey);
  }

  /// Uloží 6místný PIN. Očekává přesně 6 číslic.
  static Future<void> setPin(String pin) async {
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('PIN musí být přesně 6 číslic');
    }
    await _storage.write(key: _pinKey, value: pin);
  }

  /// Smaže uložený PIN (např. při "Přihlásit se e-mailem").
  static Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
  }
}
