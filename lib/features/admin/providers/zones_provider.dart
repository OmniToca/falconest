import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/zone_model.dart';

/// Provider pro načtení seznamu oblastí aktuálního tenanta.
/// RLS na backendu vynucuje tenant_id – aplikace filtruje pro jistotu.
final zonesProvider = FutureProvider<List<ZoneRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];
  return ZonesRepository.fetchList(tenantId);
});

/// Repository pro CRUD nad tabulkou zones.
/// Všechny operace filtrují podle tenant_id (RLS na DB).
class ZonesRepository {
  ZonesRepository._();

  /// Načte seznam aktivních oblastí (deleted_at IS NULL) tenant_id, seřazené podle názvu.
  /// Soft delete: záznamy s deleted_at vyplněným se ve výpisu neukazují.
  static Future<List<ZoneRow>> fetchList(String tenantId) async {
    final res = await SupabaseService.safeFrom('zones', tenantId)
        .select()
        .isFilter('deleted_at', null)
        .order('name', ascending: true);
    final list = res as List;
    return list
        .map((e) => ZoneRow.fromJson(e as Map<String, dynamic>))
        .where((z) => z.id.isNotEmpty)
        .toList();
  }

  /// Vloží novou oblast. tenant_id musí odpovídat aktuálnímu tenantu.
  /// Id generuje databáze (gen_random_uuid).
  static Future<void> insert(ZoneRow zone) async {
    if (zone.name.trim().isEmpty) throw ArgumentError('Název oblasti je povinný');
    final tid = zone.tenantId;
    if (tid.isEmpty) throw ArgumentError('tenantId je povinný');
    await SupabaseService.safeFrom('zones', tid).insert({
      'tenant_id': tid,
      'name': zone.name.trim(),
    });
  }

  /// Aktualizuje existující oblast (podle zone.id).
  static Future<void> update(ZoneRow zone) async {
    if (zone.id.isEmpty) throw ArgumentError('id je povinný pro update');
    final tid = zone.tenantId;
    if (tid.isEmpty) throw ArgumentError('tenantId je povinný pro update');
    await SupabaseService.safeFrom('zones', tid)
        .update({'name': zone.name.trim()})
        .eq('id', zone.id);
  }

  /// Měkké smazání oblasti: nastaví deleted_at = now(). Záznam zůstane v DB pro Audit Log.
  /// Apartmány s touto zone_id zůstanou (FK ON DELETE SET NULL) – zone_id se vynuluje.
  static Future<void> softDelete(String zoneId, String tenantId) async {
    if (zoneId.trim().isEmpty) throw ArgumentError('zoneId je povinný');
    if (tenantId.isEmpty) throw ArgumentError('tenantId je povinný');
    await SupabaseService.safeFrom('zones', tenantId)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', zoneId.trim());
  }
}
