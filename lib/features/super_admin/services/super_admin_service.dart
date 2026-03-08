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
  /// VYPÍNÁNÍ: Odložené zrušení modulu na konec zúčtovacího období (Anti-churn ochrana).
  /// Místo deleted_at = now() se nastaví cancel_at_period_end = true – modul funguje do konce měsíce.
  /// ZAPÍNÁNÍ: Obnoví záznam (deleted_at = null) a zruší výpověď (cancel_at_period_end = false).
  ///
  /// - [moduleId]: UUID z tabulky [modules] (module.id) – NE string key.
  /// - ON: INSERT nebo UPDATE s deleted_at = null, cancel_at_period_end = false.
  /// - OFF: UPDATE cancel_at_period_end = true (deleted_at zůstává null).
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
        // Bezpečný upsert: Silent fail pro záznamy, které ještě v DB neexistují.
        // Upsert s onConflict někdy u nových řádků selhává tiše (0 řádků ovlivněno).
        // Proto nejdříve select – existuje-li řádek, UPDATE; jinak INSERT.
        final existing = await SupabaseService.client
            .from('tenant_modules')
            .select('id')
            .eq('tenant_id', tenantId)
            .eq('module_id', id)
            .maybeSingle();

        if (existing != null) {
          // Obnovení: deleted_at = null, cancel_at_period_end = false (zrušení výpovědi, pokud si to klient rozmyslel).
          await SupabaseService.client
              .from('tenant_modules')
              .update({'deleted_at': null, 'cancel_at_period_end': false})
              .eq('tenant_id', tenantId)
              .eq('module_id', id)
              .select();
        } else {
          // INSERT nového záznamu – cancel_at_period_end = false pro čerstvě zapnutý modul.
          await SupabaseService.client
              .from('tenant_modules')
              .insert({
                'tenant_id': tenantId,
                'module_id': id,
                'deleted_at': null,
                'cancel_at_period_end': false,
              })
              .select();
        }
        if (kDebugMode) {
          debugPrint('[SuperAdminService] toggleModule ON: tenant=$tenantId module_id=$id');
        }
      } else {
        // Odložené zrušení modulu na konec zúčtovacího období (Anti-churn ochrana).
        // Místo deleted_at nastavíme cancel_at_period_end = true – modul zůstává aktivní do konce měsíce.
        await SupabaseService.client
            .from('tenant_modules')
            .update({'cancel_at_period_end': true})
            .match({'tenant_id': tenantId, 'module_id': id})
            .select();
        if (kDebugMode) {
          debugPrint('[SuperAdminService] toggleModule OFF (cancel_at_period_end): tenant=$tenantId module_id=$id');
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

  /// Aktualizuje konec zkušební doby tenanta (tenants.trial_ends_at, sloupec typu date).
  static Future<void> updateTenantTrialDate(String tenantId, DateTime? date) async {
    if (tenantId.isEmpty) throw ArgumentError('tenantId musí být neprázdný');
    final d = date?.toUtc();
    final dateStr = d != null ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' : null;
    await SupabaseService.client
        .from('tenants')
        .update({'trial_ends_at': dateStr})
        .eq('id', tenantId)
        .select();
    if (kDebugMode) {
      debugPrint('[SuperAdminService] updateTenantTrialDate: tenant=$tenantId date=$date');
    }
  }

  /// Aktualizuje datum "Zaplaceno do" (tenants.paid_until) – Kill Switch pro přístup po nezaplacení faktury.
  static Future<void> updateTenantPaidUntil(String tenantId, DateTime? date) async {
    if (tenantId.isEmpty) throw ArgumentError('tenantId musí být neprázdný');
    await SupabaseService.client
        .from('tenants')
        .update({'paid_until': date?.toUtc().toIso8601String()})
        .eq('id', tenantId)
        .select();
    if (kDebugMode) {
      debugPrint('[SuperAdminService] updateTenantPaidUntil: tenant=$tenantId date=$date');
    }
  }

  /// Nastaví Lovec (tenants.acquired_by) – volá se z dropdownu v detailu tenanta; null vymaže přiřazení.
  static Future<void> updateTenantAcquiredBy(String tenantId, String? acquiredBy) async {
    if (tenantId.isEmpty) throw ArgumentError('tenantId musí být neprázdný');
    await SupabaseService.client
        .from('tenants')
        .update({'acquired_by': acquiredBy?.trim().isEmpty == true ? null : acquiredBy})
        .eq('id', tenantId)
        .select();
    if (kDebugMode) {
      debugPrint('[SuperAdminService] updateTenantAcquiredBy: tenant=$tenantId acquiredBy=$acquiredBy');
    }
  }

  /// Nastaví Farmář (tenants.managed_by) – volá se z dropdownu v detailu tenanta; null vymaže přiřazení.
  static Future<void> updateTenantManagedBy(String tenantId, String? managedBy) async {
    if (tenantId.isEmpty) throw ArgumentError('tenantId musí být neprázdný');
    await SupabaseService.client
        .from('tenants')
        .update({'managed_by': managedBy?.trim().isEmpty == true ? null : managedBy})
        .eq('id', tenantId)
        .select();
    if (kDebugMode) {
      debugPrint('[SuperAdminService] updateTenantManagedBy: tenant=$tenantId managedBy=$managedBy');
    }
  }

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
