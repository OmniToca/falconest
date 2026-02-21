import 'package:flutter/foundation.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/module_model.dart';

/// Služba pro akce vyhrazené Super Adminovi – správa tenantů a jejich modulů.
///
/// Pouze Super Admin má oprávnění volat tyto operace (RLS na backendu to vynucuje).
/// Tabulka: [tenant_modules] – tenant_id (UUID), module_id (UUID) -> references modules.id.
/// Tabulka: [modules] – CRUD pro katalog modulů (createModule, updateModule, deleteModule).
class SuperAdminService {
  SuperAdminService._();

  /// Vytvoří nový modul v katalogu [modules].
  /// Cena se posílá POUZE jako [price_eur]. Nepoužívat klíče 'price' ani 'monthly_price'.
  static Future<void> createModule(ModuleModel module) async {
    if (module.key.trim().isEmpty || module.name.trim().isEmpty) {
      throw ArgumentError('key a name musí být vyplněny');
    }
    final payload = <String, dynamic>{
      'key': module.key,
      'name': module.name,
      'price_eur': module.price ?? 0,
      'pricing_type': module.pricingType,
      'order_index': module.orderIndex,
      'show_in_menu': module.showInMenu,
      'parent_module_key': module.parentModuleKey,
    };
    if (module.description != null && module.description!.isNotEmpty) {
      payload['description'] = module.description;
    }
    await SupabaseService.client.from('modules').insert(payload);
  }

  /// Aktualizuje existující modul (podle module.id). Key neměnit.
  /// Cena se posílá POUZE jako [price_eur]. Nepoužívat 'price' ani 'monthly_price'.
  static Future<void> updateModule(ModuleModel module) async {
    if (module.id.isEmpty) throw ArgumentError('module.id je povinný pro update');
    final payload = <String, dynamic>{
      'name': module.name,
      'price_eur': module.price ?? 0, // POVINNĚ price_eur – DB nemá sloupec 'price'
      'pricing_type': module.pricingType,
      'order_index': module.orderIndex,
      'show_in_menu': module.showInMenu,
      'parent_module_key': module.parentModuleKey,
    };
    if (module.description != null && module.description!.isNotEmpty) {
      payload['description'] = module.description;
    }
    await SupabaseService.client
        .from('modules')
        .update(payload)
        .eq('id', module.id);
  }

  /// Smaže modul z katalogu. Pozor: může narušit vazby v tenant_modules (CASCADE podle schématu).
  static Future<void> deleteModule(String moduleId) async {
    if (moduleId.trim().isEmpty) throw ArgumentError('moduleId je povinný');
    await SupabaseService.client
        .from('modules')
        .delete()
        .eq('id', moduleId.trim());
  }

  /// Zapne nebo vypne modul pro daného tenanta.
  ///
  /// Používá standardizovaný Soft Delete (deleted_at) pro zachování fakturační historie
  /// – místo tvrdého DELETE se při vypnutí volá UPDATE deleted_at = now().
  ///
  /// - [moduleId]: UUID z tabulky [modules] (module.id) – NE string key.
  /// - ON: INSERT nebo UPSERT (obnoví soft-smazaný záznam nastavením deleted_at = null).
  /// - OFF: UPDATE deleted_at = now() místo DELETE – zachová Audit Log pro Stripe.
  static Future<void> toggleModule(
    String tenantId,
    String moduleId,
    bool isEnabled,
  ) async {
    if (tenantId.isEmpty || moduleId.trim().isEmpty) {
      throw ArgumentError('tenantId a moduleId musí být neprázdné');
    }
    final id = moduleId.trim();
    if (!_looksLikeUuid(id)) {
      throw ArgumentError(
        'moduleId musí být UUID z tabulky modules (máte pravděpodobně key: "$id")',
      );
    }

    try {
      if (isEnabled) {
        // UPSERT: vloží nový záznam nebo obnoví soft-smazaný (deleted_at = null).
        await SupabaseService.client.from('tenant_modules').upsert(
          {
            'tenant_id': tenantId,
            'module_id': id,
            'deleted_at': null,
          },
          onConflict: 'tenant_id,module_id',
        );
        if (kDebugMode) {
          debugPrint('[SuperAdminService] toggleModule ON: tenant=$tenantId module_id=$id');
        }
      } else {
        // Soft Delete: UPDATE deleted_at místo DELETE – zachová historii pro fakturaci.
        await SupabaseService.client
            .from('tenant_modules')
            .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
            .match({'tenant_id': tenantId, 'module_id': id});
        if (kDebugMode) {
          debugPrint('[SuperAdminService] toggleModule OFF (soft delete): tenant=$tenantId module_id=$id');
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SuperAdminService] toggleModule ERROR: $e');
        debugPrint('[SuperAdminService] stack: $st');
      }
      rethrow;
    }
  }

  static bool _looksLikeUuid(String s) =>
      s.length == 36 && s.contains('-') && s.split('-').length == 5;

  /// Aktualizuje trial a platnost modulu pro tenanta (tenant_modules.is_trial, trial_ends_at, valid_until).
  /// Volá se z ModuleSubscriptionDialog po uložení. Řádek musí existovat (modul musí být aktivní).
  static Future<void> updateTenantModuleTrial(
    String tenantId,
    String moduleId, {
    required bool isTrial,
    DateTime? trialEndsAt,
    DateTime? validUntil,
  }) async {
    if (tenantId.isEmpty || moduleId.trim().isEmpty) {
      throw ArgumentError('tenantId a moduleId musí být neprázdné');
    }
    final id = moduleId.trim();
    if (!_looksLikeUuid(id)) {
      throw ArgumentError('moduleId musí být UUID z tabulky modules');
    }
    final payload = <String, dynamic>{
      'is_trial': isTrial,
      'trial_ends_at': trialEndsAt?.toUtc().toIso8601String(),
      'valid_until': validUntil?.toUtc().toIso8601String(),
    };
    await SupabaseService.client
        .from('tenant_modules')
        .update(payload)
        .match({'tenant_id': tenantId, 'module_id': id});
    if (kDebugMode) {
      debugPrint('[SuperAdminService] updateTenantModuleTrial: tenant=$tenantId module_id=$id');
    }
  }
}
