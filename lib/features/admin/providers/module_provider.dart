import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/module_model.dart';

/// Načte VŠECHNY moduly z tabulky [modules] – žádný hardcoded seznam.
/// Pouze reálný dotaz na DB; prázdný výsledek nebo chyba vrací [] (sidebar má vlastní fallback pro zobrazení).
/// Důležité: [ModuleModel.id] musí být UUID z DB, aby toggle v Tenant Detail fungoval.
final allModulesProvider = FutureProvider<List<ModuleModel>>((ref) async {
  try {
    final res = await SupabaseService.client
        .from('modules')
        .select()
        .order('order_index', ascending: true);
    final list = res as List;
    return list
        .map((e) => ModuleModel.fromJson(e as Map<String, dynamic>))
        .where((m) => m.key.isNotEmpty && m.id.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
});

/// Množina klíčů modulů aktivních pro aktuálního tenanta (z [tenant_modules] join [modules]).
/// Schema: tenant_modules.module_id (UUID) -> modules.id; pro sidebar potřebujeme klíče (key).
final activeModuleKeysProvider = FutureProvider<Set<String>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return {};
  return _fetchActiveModuleKeysForTenant(tenantId);
});

/// Množina UUID modulů aktivních pro konkrétního tenanta (pro Super Admin – detail agentury).
/// Schema: tenant_modules má sloupce tenant_id, module_id (UUID). Používáme pro přepínače v UI.
final tenantActiveModuleIdsProvider =
    FutureProvider.family<Set<String>, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return {};
  return _fetchActiveModuleIdsForTenant(tenantId);
});

/// Načte aktivní moduly tenanta a vrátí jejich klíče (join s [modules] pro key).
///
/// Filtruje: deleted_at IS NULL (soft delete), valid_until v budoucnosti nebo null,
/// trial_ends_at v budoucnosti nebo null – modul je aktivní POUZE pokud splňuje všechny podmínky.
Future<Set<String>> _fetchActiveModuleKeysForTenant(String tenantId) async {
  try {
    final res = await SupabaseService.client
        .from('tenant_modules')
        .select('module_id, modules(key), valid_until, trial_ends_at')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null);
    final list = res as List;
    final now = DateTime.now().toUtc();
    final keys = <String>{};
    for (final e in list) {
      final map = e is Map ? e as Map<String, dynamic> : null;
      if (map == null) continue;
      if (!_isModuleValidNow(map['valid_until'], map['trial_ends_at'], now)) {
        continue;
      }
      final modules = map['modules'];
      final key = (modules is Map ? modules['key'] : null)?.toString().trim();
      if (key != null && key.isNotEmpty) keys.add(key);
    }
    return keys;
  } catch (_) {
    return {};
  }
}

/// Vrátí true, pokud modul má platnost (valid_until a trial_ends_at nevypršely).
bool _isModuleValidNow(Object? validUntilRaw, Object? trialEndsAtRaw, DateTime now) {
  final validUntil = _parseOptionalDateTime(validUntilRaw);
  final trialEndsAt = _parseOptionalDateTime(trialEndsAtRaw);
  if (validUntil != null && validUntil.isBefore(now)) return false;
  if (trialEndsAt != null && trialEndsAt.isBefore(now)) return false;
  return true;
}

DateTime? _parseOptionalDateTime(Object? value) {
  if (value == null) return null;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Načte množinu UUID modulů aktivních pro tenanta (pro detail obrazovku – přepínače podle module.id).
///
/// Stejná logika jako _fetchActiveModuleKeysForTenant: filtr deleted_at + platnost valid_until/trial_ends_at.
Future<Set<String>> _fetchActiveModuleIdsForTenant(String tenantId) async {
  try {
    final res = await SupabaseService.client
        .from('tenant_modules')
        .select('module_id, valid_until, trial_ends_at')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null);
    final list = res as List;
    final now = DateTime.now().toUtc();
    final ids = <String>{};
    for (final e in list) {
      final map = e is Map ? e as Map<String, dynamic> : null;
      if (map == null) continue;
      if (!_isModuleValidNow(map['valid_until'], map['trial_ends_at'], now)) {
        continue;
      }
      final id = (map['module_id']?.toString().trim());
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids;
  } catch (_) {
    return {};
  }
}

/// Vrací true, pokud je modul [moduleKey] pro aktuální kontext aktivní.
/// Super Admin vidí všechny moduly jako aktivní (unlocked). Ostatní jen ty z [tenant_modules].
bool isModuleActive(WidgetRef ref, String moduleKey) {
  final isSuperAdmin = ref.read(authNotifierProvider).state.role == 'super_admin';
  if (isSuperAdmin) return true;

  final activeKeys = ref.read(activeModuleKeysProvider).valueOrNull;
  if (activeKeys == null) return false;
  return activeKeys.contains(moduleKey);
}
