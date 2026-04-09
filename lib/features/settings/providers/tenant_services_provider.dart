import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/settings/models/tenant_service_model.dart';

/// Načte aktivní služby katalogu agentury (tenant_services) pro aktuálního tenanta.
/// Filtruje deleted_at IS NULL a řadí podle order_index. Pro neaktivního tenanta vrací [].
final tenantServicesProvider = FutureProvider<List<TenantServiceModel>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];
  return TenantServicesRepository.fetchList(tenantId);
});

/// Repository pro CRUD nad tenant_services. Volá Supabase; RLS na backendu vynucuje tenant_id.
class TenantServicesRepository {
  TenantServicesRepository._();

  /// Načte seznam aktivních služeb (deleted_at IS NULL) seřazených podle order_index.
  static Future<List<TenantServiceModel>> fetchList(String tenantId) async {
    final res = await SupabaseService.safeFrom('tenant_services', tenantId)
        .select()
        .isFilter('deleted_at', null)
        .order('order_index', ascending: true);
    final list = res as List;
    return list
        .map((e) => TenantServiceModel.fromJson(e as Map<String, dynamic>))
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  /// Vloží novou službu. [model.tenantId] musí odpovídat aktuálnímu tenantu (kontroluje RLS).
  static Future<void> insert(TenantServiceModel model) async {
    if (model.name.trim().isEmpty) throw ArgumentError('Název služby je povinný');
    await SupabaseService.safeFrom('tenant_services', model.tenantId)
        .insert(SupabaseService.safeInsertPayload(model.tenantId, model.toJson()));
  }

  /// Aktualizuje existující službu (podle model.id). Soft delete se dělá přes [softDelete].
  static Future<void> update(TenantServiceModel model) async {
    if (model.id.isEmpty) throw ArgumentError('id je povinný pro update');
    final payload = <String, dynamic>{
      'name': model.name.trim(),
      'service_type': model.serviceType,
      'is_active': model.isActive,
      'order_index': model.orderIndex,
    };
    if (model.description != null && model.description!.isNotEmpty) {
      payload['description'] = model.description;
    } else {
      payload['description'] = null;
    }
    payload['default_price'] = model.defaultPrice;
    payload['required_role'] = model.requiredRole ?? 'any';
    payload['duration_minutes'] = model.durationMinutes;
    payload['requires_photo'] = model.requiresPhoto;
    await SupabaseService.safeFrom('tenant_services', model.tenantId)
        .update(payload)
        .eq('id', model.id);
  }

  /// Měkké smazání: nastaví deleted_at = now(). Záznam zůstane v DB, v seznamu se neukáže.
  static Future<void> softDelete(String tenantId, String serviceId) async {
    if (tenantId.trim().isEmpty) throw ArgumentError('tenantId je povinný');
    if (serviceId.trim().isEmpty) throw ArgumentError('serviceId je povinný');
    await SupabaseService.safeFrom('tenant_services', tenantId)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', serviceId.trim());
  }
}
