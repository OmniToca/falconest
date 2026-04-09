import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Jeden záznam interního HQ personálu (Super-Admin nebo Account Manager).
///
/// PROČ: Slouží pro výběr Lovce a Farmáře u agentur – pouze interní zaměstnanci
/// zodpovědní za získání a správu klientů, ne běžní uživatelé z tenantů.
class HqStaffRow {
  const HqStaffRow({
    required this.id,
    required this.name,
    this.role,
  });

  final String id;
  final String name;
  final String? role;

  String get displayName => name.trim().isEmpty ? id : name;
}

/// Provider načítající seznam HQ personálu – pouze profily s rolí super_admin nebo account_manager.
///
/// PROČ: Dropdowny „Lovec“ a „Farmář“ v detailu tenanta musí čerpat pouze z interních
/// zaměstnanců (HQ), kteří mohou být přiřazeni k agenturám jako zodpovědní. Omezujeme
/// výběr na tyto role, aby se do acquired_by/managed_by nedostali náhodní uživatelé.
final hqStaffProvider = FutureProvider<List<HqStaffRow>>((ref) async {
  try {
    final res = await SupabaseService.client
        .from('profiles')
        .select('id, name, first_name, last_name, email, role')
        .inFilter('role', ['super_admin', 'account_manager'])
        .order('name', ascending: true);

    final list = res as List<dynamic>;
    final result = <HqStaffRow>[];
    for (final e in list) {
      try {
        final map = Map<String, dynamic>.from(e as Map);
        final id = (map['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) continue;
        final name = (map['name'] as String?)?.trim() ?? '';
        final first = (map['first_name'] as String?)?.trim() ?? '';
        final last = (map['last_name'] as String?)?.trim() ?? '';
        final displayName = name.isNotEmpty
            ? name
            : '$first $last'.trim().isEmpty
                ? (map['email'] as String?)?.trim() ?? id
                : '$first $last'.trim();
        final role = (map['role'] as String?)?.trim();
        result.add(HqStaffRow(id: id, name: displayName, role: role?.isEmpty == true ? null : role));
      } catch (e, st) {
        AppLogger.error('hqStaffProvider: parsování řádku profilu HQ selhalo', e, st);
      }
    }
    return result;
  } catch (e, st) {
    AppLogger.error('hqStaffProvider: načtení seznamu HQ staff selhalo', e, st);
    return [];
  }
});

/// Seznam členů HQ týmu pro modul „HQ Tým“ – pouze profily s tenant_id IS NULL a role super_admin/account_manager.
///
/// PROČ: Na obrazovce HQ Tým zobrazujeme jen skutečný interní tým (bez tenant_id), aby se
/// do seznamu nedostali uživatelé, kteří mají HQ roli ale jsou přiřazeni k testovací agentuře.
final hqStaffListProvider = FutureProvider<List<HqStaffRow>>((ref) async {
  try {
    final res = await SupabaseService.client
        .from('profiles')
        .select('id, name, first_name, last_name, email, role')
        .filter('tenant_id', 'is', null)
        .inFilter('role', ['super_admin', 'account_manager'])
        .order('name', ascending: true);

    final list = res as List<dynamic>;
    final result = <HqStaffRow>[];
    for (final e in list) {
      try {
        final map = Map<String, dynamic>.from(e as Map);
        final id = (map['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) continue;
        final name = (map['name'] as String?)?.trim() ?? '';
        final first = (map['first_name'] as String?)?.trim() ?? '';
        final last = (map['last_name'] as String?)?.trim() ?? '';
        final displayName = name.isNotEmpty
            ? name
            : '$first $last'.trim().isEmpty
                ? (map['email'] as String?)?.trim() ?? id
                : '$first $last'.trim();
        final role = (map['role'] as String?)?.trim();
        result.add(HqStaffRow(id: id, name: displayName, role: role?.isEmpty == true ? null : role));
      } catch (e, st) {
        AppLogger.error('hqStaffListProvider: parsování řádku profilu HQ selhalo', e, st);
      }
    }
    return result;
  } catch (e, st) {
    AppLogger.error('hqStaffListProvider: načtení seznamu HQ týmu selhalo', e, st);
    return [];
  }
});
