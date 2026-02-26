import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Služba pro lokální cache profilu uživatele (offline-first záchranná síť).
///
/// PROČ EXISTUJE:
/// Při startu aplikace v režimu letadlo (bez internetu) AuthNotifier volá Supabase
/// pro načtení profilu (role, tenant_id). Síťový požadavek selže a uživatel vidí
/// "Chyba načtení profilu" místo toho, aby mohl pracovat s cachovanými daty.
/// Tato služba ukládá profil po úspěšném načtení a umožňuje fallback při síťové chybě.
///
/// BEZPEČNOST:
/// Cache je v SharedPreferences (plain text). Obsahuje pouze role, tenant_id,
/// profile_id – citlivá data (hesla, tokeny) se nikdy necachují. Supabase session
/// (refresh token) je v bezpečném storage Supabase klienta.
const String _cacheKey = 'falconest_profile_cache';

/// Model cachovaného profilu – minimální sada pro přihlášení do aplikace.
class CachedProfile {
  const CachedProfile({
    required this.authId,
    required this.role,
    required this.profileId,
    this.tenantId,
    this.languageCode,
    this.preferredCurrency,
    this.isTenantActive,
    this.paidUntil,
    required this.cachedAt,
  });

  final String authId;
  final String role;
  final String? profileId;
  final String? tenantId;
  final String? languageCode;
  final String? preferredCurrency;
  final bool? isTenantActive;
  final DateTime? paidUntil;
  final DateTime cachedAt;

  Map<String, dynamic> toJson() => {
        'auth_id': authId,
        'role': role,
        'profile_id': profileId,
        'tenant_id': tenantId,
        'language_code': languageCode,
        'preferred_currency': preferredCurrency,
        'is_tenant_active': isTenantActive,
        'paid_until': paidUntil?.toIso8601String(),
        'cached_at': cachedAt.toIso8601String(),
      };

  static CachedProfile? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final authId = map['auth_id']?.toString().trim();
    final role = map['role']?.toString().trim();
    if (authId == null || authId.isEmpty || role == null || role.isEmpty) {
      return null;
    }
    return CachedProfile(
      authId: authId,
      role: role,
      profileId: map['profile_id']?.toString().trim(),
      tenantId: map['tenant_id']?.toString().trim(),
      languageCode: map['language_code']?.toString().trim(),
      preferredCurrency: map['preferred_currency']?.toString().trim().toUpperCase(),
      isTenantActive: map['is_tenant_active'] as bool?,
      paidUntil: map['paid_until'] != null ? DateTime.tryParse(map['paid_until'].toString()) : null,
      cachedAt: DateTime.tryParse(map['cached_at']?.toString() ?? '') ?? DateTime.now().toUtc(),
    );
  }
}

/// Služba pro ukládání a načítání cachovaného profilu.
///
/// Offline-first: Po úspěšném síťovém načtení profilu uložíme ho sem.
/// Při síťové chybě (SocketException, timeout) zkusíme načíst z cache –
/// uživatel se dostane do aplikace s posledními známými daty.
class ProfileCacheService {
  ProfileCacheService._();

  /// Uloží profil do lokální cache. Volá se po úspěšném načtení z Supabase.
  ///
  /// PROČ: Příští start v offline režimu umožní načíst tato data místo zobrazení chyby.
  static Future<void> save(CachedProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(profile.toJson()));
    } catch (_) {
      // Nepřerušovat auth flow – cache je záchranná síť, ne kritická cesta
    }
  }

  /// Načte cachovaný profil pro daného uživatele (auth_id).
  ///
  /// Vrací null pokud: cache neexistuje, auth_id nesedí, nebo je cache neplatná.
  /// Volá se v AuthNotifier při síťové chybě – pokud vrátíme platný profil,
  /// uživatel pokračuje do aplikace bez "Chyba načtení profilu".
  static Future<CachedProfile?> load(String authId) async {
    if (authId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>?;
      final profile = CachedProfile.fromJson(map);
      if (profile == null || profile.authId != authId) return null;

      return profile;
    } catch (_) {
      return null;
    }
  }

  /// Smaže cache (např. při explicitním odhlášení).
  ///
  /// PROČ: Po odhlášení nesmí zůstat data předchozího uživatele v cache.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }
}
