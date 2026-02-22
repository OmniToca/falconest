import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/super_admin/providers/tenant_detail_provider.dart';

/// Model záznamu z tabulky tenants.
/// [notes] je nullable – sloupec může chybět nebo být prázdný.
/// [is_active] – false = agentura pozastavena (kill-switch).
/// [billingInfo], [pricePerApartment], [currency] – pro vyhledávání (IČO, firma) a výpočet MRR.
/// [trial_ends_at] – konec zkušební doby; když v budoucnosti, zobrazíme štítek „V Trialu“.
/// [paid_until] – zaplaceno do; když v minulosti → badge „Nezaplaceno“.
/// [systemAnnouncement] – text Globálního Megafonu; neprázdný = aktuálně se vysílá všem.
class TenantRow {
  const TenantRow({
    required this.id,
    required this.name,
    this.createdAt,
    this.notes,
    this.isActive = true,
    this.trialEndsAt,
    this.paidUntil,
    this.systemAnnouncement,
    this.billingInfo,
    this.pricePerApartment,
    this.currency,
    this.discountPercentage = 0,
    this.deletedAt,
  });

  final String id;
  final String name;
  final DateTime? createdAt;
  final String? notes;
  final bool isActive;
  final DateTime? trialEndsAt;
  /// Zaplaceno do – Kill Switch; v minulosti → badge „Nezaplaceno“.
  final DateTime? paidUntil;
  final String? systemAnnouncement;
  final BillingInfo? billingInfo;
  final num? pricePerApartment;
  final String? currency;
  /// Sleva v procentech (0–100) pro výpočet MRR.
  final int discountPercentage;
  /// Soft delete: když není null, agentura je skrytá ze seznamu.
  final DateTime? deletedAt;
}

/// Model záznamu z tabulky invitations (čekající pozvánka pro daného tenant_id).
class InvitationRow {
  const InvitationRow({
    required this.tenantId,
    required this.email,
    this.firstName,
    this.lastName,
  });

  final String tenantId;
  final String email;
  final String? firstName;
  final String? lastName;

  /// Jméno pro pozvánku (first_name + last_name nebo pouze email).
  String get displayName {
    if (firstName != null && firstName!.trim().isNotEmpty) {
      return '${firstName!.trim()} ${(lastName ?? '').trim()}'.trim();
    }
    return email;
  }
}

/// Agentura s přiřazeným stavem a volitelnými statistikami.
///
/// Stav se určuje z tabulky [profiles]: existuje-li pro tenant_id uživatel
/// s administrátorskými právy (admin/manager) → Aktivní. Jinak pouze
/// pozvánka v invitations → Čeká na manažera.
///
/// [latestActivityAt] = MAX(profiles.last_sign_in_at) pro tento tenant (Health / Traffic Light).
/// [moduleActiveCount] / [moduleTotalCount] = Adoption Score (např. 5/9 Aktivní).
/// [activeUsersCount] = pouze profily (deleted_at IS NULL). [pendingInvitationsCount] = čekající pozvánky.
class TenantWithStatus {
  const TenantWithStatus({
    required this.tenant,
    this.invitation,
    required this.hasAdminProfile,
    this.activeUsersCount,
    this.pendingInvitationsCount = 0,
    this.apartmentCount,
    this.latestActivityAt,
    this.moduleActiveCount = 0,
    this.moduleTotalCount = 0,
  });

  final TenantRow tenant;
  final InvitationRow? invitation;

  /// True = v profiles existuje alespoň jeden uživatel s role admin/manager pro tento tenant.
  final bool hasAdminProfile;

  /// Počet aktivních uživatelů (profiles s deleted_at IS NULL). Null = nezjištěno.
  final int? activeUsersCount;

  /// Počet čekajících pozvánek (invitations). Zobrazuje se jako (+N).
  final int pendingInvitationsCount;

  /// Zpětná kompatibilita: aktivní uživatelé (null → 0).
  int? get teamCount => activeUsersCount;

  /// Počet apartmánů u této agentury. Null = nezjištěno.
  final int? apartmentCount;

  /// Poslední aktivita (přihlášení) libovolného uživatele v této agentuře. Null = neaktivní.
  final DateTime? latestActivityAt;

  /// Počet modulů zapnutých u tenanta (tenant_modules.status = 'active').
  final int moduleActiveCount;

  /// Celkový počet modulů v systému (katalog). Pro zobrazení „X/Y Aktivní“.
  final int moduleTotalCount;

  /// Čeká na manažera = žádný admin v profiles (pouze pozvánka nebo prázdno).
  bool get isAwaitingManager => !hasAdminProfile;

  /// Aktivní = má alespoň jednoho admina v profiles.
  bool get isActive => hasAdminProfile;
}

/// Provider načítající všechny tenanty (agentury) z Supabase.
///
/// Čistý dotaz BEZ filtrace – Super Admin vidí VŠECHNY záznamy.
/// Sloupce: id, name (created_at a notes volitelné – tabulka je může nemít).
final allTenantsProvider = FutureProvider<List<TenantRow>>((ref) async {
  try {
    // Čistý select – Super Admin vidí vše; filtr deleted_at IS NULL (soft delete)
    final response = await SupabaseService.client
        .from('tenants')
        .select('id, name')
        .isFilter('deleted_at', null);

    if (kDebugMode) {
      // ignore: avoid_print
      print('--- DEBUG TENANTS RAW: $response');
    }

    final list = _toList(response);
    if (kDebugMode) {
      // ignore: avoid_print
      print('--- DEBUG TENANTS LIST LENGTH: ${list.length}');
    }

    final result = <TenantRow>[];
    for (var i = 0; i < list.length; i++) {
      try {
        final e = list[i];
        result.add(_parseTenant(Map<String, dynamic>.from(e as Map)));
      } catch (err, st) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('--- CHYBA PARSOVÁNÍ TENANTA[$i]: $err');
          // ignore: avoid_print
          print('--- Stack: $st');
        }
      }
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('--- DEBUG TENANTS VÝSLEDEK: ${result.length} agentur');
    }
    return result;
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('--- CHYBA STAŽENÍ TENANTŮ: $e');
      // ignore: avoid_print
      print('--- Stack: $st');
    }
    return [];
  }
});

TenantRow _parseTenant(Map<String, dynamic> map) {
  final id = map['id']?.toString() ?? '';
  final name = map['name'] as String? ?? '';
  final createdAtRaw = map['created_at'];
  DateTime? createdAt;
  if (createdAtRaw != null) {
    createdAt = DateTime.tryParse(createdAtRaw.toString());
  }
  final notes = map['notes'] as String?;
  final isActive = _parseBool(map['is_active'], true);
  final trialEndsAtRaw = map['trial_ends_at'];
  DateTime? trialEndsAt;
  if (trialEndsAtRaw != null) {
    trialEndsAt = DateTime.tryParse(trialEndsAtRaw.toString());
  }
  final paidUntilRaw = map['paid_until'];
  DateTime? paidUntil;
  if (paidUntilRaw != null) {
    paidUntil = DateTime.tryParse(paidUntilRaw.toString());
  }
  final systemAnnouncementRaw = map['system_announcement'];
  final systemAnnouncement = systemAnnouncementRaw is String
      ? (systemAnnouncementRaw.trim().isEmpty ? null : systemAnnouncementRaw.trim())
      : null;
  BillingInfo? billingInfo;
  final rawBilling = map['billing_info'];
  if (rawBilling != null) {
    if (rawBilling is Map<String, dynamic>) {
      billingInfo = BillingInfo.fromJson(rawBilling);
    } else if (rawBilling is Map) {
      billingInfo = BillingInfo.fromJson(Map<String, dynamic>.from(rawBilling));
    }
  }
  num? pricePerApartment;
  final rawPrice = map['price_per_apartment'];
  if (rawPrice != null) {
    if (rawPrice is num) pricePerApartment = rawPrice;
    if (rawPrice is String) pricePerApartment = num.tryParse(rawPrice);
  }
  final currency = (map['currency'] as String?)?.trim();
  int discountPercentage = 0;
  final rawDiscount = map['discount_percentage'];
  if (rawDiscount != null) {
    if (rawDiscount is int) discountPercentage = rawDiscount.clamp(0, 100);
    if (rawDiscount is num) discountPercentage = rawDiscount.toInt().clamp(0, 100);
    if (rawDiscount is String) discountPercentage = (int.tryParse(rawDiscount) ?? 0).clamp(0, 100);
  }
  DateTime? deletedAt;
  final deletedAtRaw = map['deleted_at'];
  if (deletedAtRaw != null) {
    deletedAt = DateTime.tryParse(deletedAtRaw.toString());
  }
  return TenantRow(
    id: id,
    name: name,
    createdAt: createdAt,
    notes: notes,
    isActive: isActive,
    trialEndsAt: trialEndsAt,
    paidUntil: paidUntil,
    systemAnnouncement: systemAnnouncement,
    billingInfo: billingInfo,
    pricePerApartment: pricePerApartment,
    currency: currency?.isNotEmpty == true ? currency : null,
    discountPercentage: discountPercentage,
    deletedAt: deletedAt,
  );
}

bool _parseBool(dynamic v, bool defaultValue) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is String) {
    final lower = v.trim().toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return defaultValue;
}

InvitationRow _parseInvitation(Map<String, dynamic> map) {
  final tenantId = map['tenant_id']?.toString() ?? '';
  final email = map['email'] as String? ?? '';
  final firstName = map['first_name'] as String?;
  final lastName = map['last_name'] as String?;
  return InvitationRow(
    tenantId: tenantId,
    email: email,
    firstName: firstName,
    lastName: lastName,
  );
}

/// Bezpečně převede odpověď Supabase na List.
/// Supabase SDK vrací přímo `List<Map<String, dynamic>>`.
List<dynamic> _toList(dynamic response) {
  if (response == null) return [];
  if (response is List) return response;
  return [];
}

/// Vrátí true, pokud modul má platnost (valid_until a trial_ends_at nevypršely).
bool _isTenantModuleValidNow(dynamic validUntilRaw, dynamic trialEndsAtRaw) {
  final now = DateTime.now().toUtc();
  final validUntil = _parseOptionalDateTime(validUntilRaw);
  final trialEndsAt = _parseOptionalDateTime(trialEndsAtRaw);
  if (validUntil != null && validUntil.isBefore(now)) return false;
  if (trialEndsAt != null && trialEndsAt.isBefore(now)) return false;
  return true;
}

DateTime? _parseOptionalDateTime(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Množina tenant_id, u kterých existuje alespoň jeden profil s role admin nebo manager.
/// Načteno z tabulky profiles – určuje stav „Aktivní“ vs „Čeká na manažera“.
Future<Set<String>> _loadTenantIdsWithAdmin(dynamic client) async {
  final set = <String>{};
  try {
    final res = await client
        .from('profiles')
        .select('tenant_id, role')
        .filter('deleted_at', 'is', null)
        .not('tenant_id', 'is', null);
    final list = _toList(res);
    for (final e in list) {
      try {
        final map = Map<String, dynamic>.from(e as Map);
        final tenantId = map['tenant_id']?.toString().trim();
        final role = (map['role'] as String?)?.trim().toLowerCase();
        if (tenantId != null &&
            tenantId.isNotEmpty &&
            (role == 'admin' || role == 'manager')) {
          set.add(tenantId);
        }
      } catch (_) {}
    }
  } catch (_) {}
  return set;
}

/// Počty záznamů v tabulce podle sloupce. Filtrování na DB: u tabulek se soft-delete (profiles, apartments, tasks, reservations)
/// se použije WHERE deleted_at IS NULL – oficiální syntax supabase_flutter: .filter('deleted_at', 'is', null).
Future<Map<String, int>> _loadCountsByTenant(
  dynamic client,
  String table,
  String column,
) async {
  final counts = <String, int>{};
  try {
    dynamic query = client.from(table).select(column);
    if (table == 'profiles' || table == 'apartments' || table == 'tasks' || table == 'reservations') {
      query = query.filter('deleted_at', 'is', null);
    }
    final res = await query;
    final list = _toList(res);
    if (kDebugMode && (table == 'profiles' || table == 'apartments')) {
      // ignore: avoid_print
      print('DEBUG FETCH: table=$table total rows from DB=${list.length}');
    }
    for (final e in list) {
      try {
        final map = Map<String, dynamic>.from(e as Map);
        final id = map[column]?.toString().trim();
        if (id != null && id.isNotEmpty) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      } catch (_) {}
    }
  } catch (_) {}
  return counts;
}

/// Počet bytů (apartments) pro daného tenanta. Filtrování na DB: WHERE deleted_at IS NULL.
Future<int> _loadApartmentCountForTenant(dynamic client, String tenantId) async {
  try {
    final res = await client
        .from('apartments')
        .select('id')
        .eq('tenant_id', tenantId)
        .filter('deleted_at', 'is', null);
    final list = _toList(res);
    final count = list.length;
    if (kDebugMode) {
      // ignore: avoid_print
      print('DEBUG FETCH: Tenant $tenantId -> Apartments: $count');
    }
    return count;
  } catch (_) {
    return 0;
  }
}

/// Pro každého tenanta asynchronně načte počet bytů a vrátí mapu tenant_id -> počet.
Future<Map<String, int>> _loadApartmentCountsByTenant(
  dynamic client,
  List<TenantRow> tenants,
) async {
  final counts = <String, int>{};
  await Future.wait(tenants.map((t) async {
    final c = await _loadApartmentCountForTenant(client, t.id);
    counts[t.id] = c;
  }));
  return counts;
}

/// Načte pro každého tenanta nejnovější last_sign_in_at z profiles (MAX přes uživatele).
/// Používá se pro Health indikátor: Online dnes / X dny zpět / Neaktivní.
Future<Map<String, DateTime?>> _loadLatestActivityByTenant(dynamic client) async {
  final result = <String, DateTime?>{};
  try {
    final res = await client
        .from('profiles')
        .select('tenant_id, last_sign_in_at')
        .filter('deleted_at', 'is', null);
    final list = _toList(res);
    for (final e in list) {
      try {
        final map = Map<String, dynamic>.from(e as Map);
        final tenantId = map['tenant_id']?.toString().trim();
        if (tenantId == null || tenantId.isEmpty) continue;
        final raw = map['last_sign_in_at'];
        DateTime? at;
        if (raw != null) {
          if (raw is String) {
            at = DateTime.tryParse(raw);
          } else if (raw is DateTime) {
            at = raw;
          }
        }
        if (at != null) {
          final existing = result[tenantId];
          if (existing == null || at.isAfter(existing)) {
            result[tenantId] = at;
          }
        }
      } catch (_) {}
    }
  } catch (_) {
    // Sloupec last_sign_in_at může chybět dokud neběží migrace nebo sync z auth
  }
  return result;
}

/// Celkový počet modulů v katalogu a počet aktivních modulů (status = 'active') per tenant.
/// Vrací (totalModules, map tenant_id -> activeCount).
Future<(int total, Map<String, int> activeByTenant)> _loadModuleAdoption(
  dynamic client,
) async {
  int total = 0;
  final activeByTenant = <String, int>{};
  try {
    final modRes = await client.from('modules').select('id');
    total = _toList(modRes).length;
  } catch (_) {}
  try {
    // Soft delete + platnost: pouze moduly s deleted_at IS NULL a platným valid_until/trial_ends_at.
    final res = await client
        .from('tenant_modules')
        .select('tenant_id, valid_until, trial_ends_at')
        .isFilter('deleted_at', null);
    final list = _toList(res);
    for (final e in list) {
      try {
        final map = Map<String, dynamic>.from(e as Map);
        if (!_isTenantModuleValidNow(map['valid_until'], map['trial_ends_at'])) continue;
        final tenantId = map['tenant_id']?.toString().trim();
        if (tenantId != null && tenantId.isNotEmpty) {
          activeByTenant[tenantId] = (activeByTenant[tenantId] ?? 0) + 1;
        }
      } catch (_) {}
    }
  } catch (_) {}
  return (total, activeByTenant);
}

/// Provider načítající agentury: nejdřív pouze tenants (bez joinů), poté volitelně
/// dopočítá stavy a statistiky. Selhá-li dopočítání, seznam agentur zůstane zobrazen.
///
/// 1. Krok: Načtení VŠECH záznamů z tabulky tenants (minimální select, žádné joiny).
/// 2. Krok: Po úspěchu se asynchronně doplní invitations, stavy z profiles a počty.
///    Při selhání dopočítání se použijí výchozí hodnoty (hasAdminProfile=false, null počty).
final tenantsWithStatusProvider =
    FutureProvider<List<TenantWithStatus>>((ref) async {
  final client = SupabaseService.client;

  // KROK 1: Pouze tenants – minimální dotaz, bez joinů. Hlavní seznam nesmí padnout.
  List<TenantRow> tenants;
  try {
    final tenantsRes = await client
        .from('tenants')
        .select('id, name, is_active, trial_ends_at, paid_until, system_announcement, billing_info, price_per_apartment, currency, discount_percentage')
        .isFilter('deleted_at', null);
    final tenantList = _toList(tenantsRes);
    tenants = [];
    for (var i = 0; i < tenantList.length; i++) {
      try {
        final e = tenantList[i];
        tenants.add(_parseTenant(Map<String, dynamic>.from(e as Map)));
      } catch (err, st) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('--- CHYBA PARSOVÁNÍ TENANTA[$i]: $err');
          // ignore: avoid_print
          print('--- Stack: $st');
        }
      }
    }
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('--- CHYBA STAŽENÍ TENANTŮ: $e');
      // ignore: avoid_print
      print('--- Stack: $st');
    }
    return [];
  }

  if (tenants.isEmpty) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('--- DEBUG TENANTS VÝSLEDEK: 0 agentur');
    }
    return [];
  }

  // KROK 2: Dopočítání stavů a statistik – každý dotaz zvlášť, selhání nebere seznam.
  // Pozvánky: filtrujeme deleted_at IS NULL, aby se do teamCount nezapočítaly zrušené pozvánky.
  List<InvitationRow> invitations = [];
  try {
    dynamic invRes;
    try {
      invRes = await client
          .from('invitations')
          .select('tenant_id, email, first_name, last_name')
          .filter('deleted_at', 'is', null);
    } catch (_) {
      // Fallback: tabulka invitations nemá sloupec deleted_at – načti bez filtru.
      invRes = await client
          .from('invitations')
          .select('tenant_id, email, first_name, last_name');
    }
    final invList = _toList(invRes);
    if (kDebugMode) {
      // ignore: avoid_print
      print('DEBUG FETCH: Invitations total rows from DB=${invList.length}');
    }
    for (final e in invList) {
      try {
        invitations.add(_parseInvitation(Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('--- DEBUG INVITATIONS CHYBA (ignorováno): $e');
    }
  }

  Set<String> tenantIdsWithAdmin = {};
  try {
    tenantIdsWithAdmin = await _loadTenantIdsWithAdmin(client);
  } catch (_) {}

  // Počet lidí v profiles (přiřazených k tenantovi)
  Map<String, int> profilesCountByTenant = {};
  try {
    profilesCountByTenant =
        await _loadCountsByTenant(client, 'profiles', 'tenant_id');
  } catch (_) {}

  // Počet bytů – per-tenant dotaz (select id, eq tenant_id) pro správné RLS
  Map<String, int> apartmentCounts = {};
  try {
    apartmentCounts = await _loadApartmentCountsByTenant(client, tenants);
  } catch (_) {}

  // Poslední aktivita (Health / Traffic Light): MAX(last_sign_in_at) per tenant
  Map<String, DateTime?> latestActivityByTenant = {};
  try {
    latestActivityByTenant = await _loadLatestActivityByTenant(client);
  } catch (_) {}

  // Adoption Score: celkový počet modulů + počet aktivních modulů per tenant
  int moduleTotalCount = 0;
  Map<String, int> moduleActiveByTenant = {};
  try {
    final adoption = await _loadModuleAdoption(client);
    moduleTotalCount = adoption.$1;
    moduleActiveByTenant = adoption.$2;
  } catch (_) {}

  // Počet pozvánek podle tenant_id (nevyřízené pozvánky = „lidé v týmu“)
  final invitationCountByTenant = <String, int>{};
  for (final inv in invitations) {
    final tid = inv.tenantId;
    if (tid.isNotEmpty) {
      invitationCountByTenant[tid] = (invitationCountByTenant[tid] ?? 0) + 1;
    }
  }

  final result = <TenantWithStatus>[];
  for (final tenant in tenants) {
    final matches =
        invitations.where((inv) => inv.tenantId == tenant.id).toList();
    final inv = matches.isEmpty ? null : matches.first;
    final activeUsersCount = profilesCountByTenant[tenant.id] ?? 0;
    final pendingInvitationsCount = invitationCountByTenant[tenant.id] ?? 0;
    final apartmentCount = apartmentCounts[tenant.id];
    if (kDebugMode) {
      // ignore: avoid_print
      print(
          'DEBUG FETCH: Tenant ${tenant.id} -> Apartments: $apartmentCount, activeUsers: $activeUsersCount, pendingInv: $pendingInvitationsCount');
    }
    result.add(TenantWithStatus(
      tenant: tenant,
      invitation: inv,
      hasAdminProfile: tenantIdsWithAdmin.contains(tenant.id),
      activeUsersCount: activeUsersCount,
      pendingInvitationsCount: pendingInvitationsCount,
      apartmentCount: apartmentCount,
      latestActivityAt: latestActivityByTenant[tenant.id],
      moduleActiveCount: moduleActiveByTenant[tenant.id] ?? 0,
      moduleTotalCount: moduleTotalCount,
    ));
  }

  if (kDebugMode) {
      // ignore: avoid_print
      print('--- DEBUG TENANTS VÝSLEDEK: ${result.length} agentur');
    }
  return result;
});

/// Počty úkolů vytvořených/aktualizovaných dnes podle tenant_id (Špionážní radar).
/// Načítá se na pozadí; pokud tabulka tasks nemá created_at/updated_at nebo RLS
/// neumožní Super Adminovi čtení, vrací prázdnou mapu.
final todayTaskCountByTenantProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final client = SupabaseService.client;
  final now = DateTime.now().toUtc();
  final startOfDay = DateTime.utc(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  final startIso = startOfDay.toIso8601String();
  final endIso = endOfDay.toIso8601String();

  final counts = <String, int>{};
  try {
    // Sloupec created_at bývá v Supabase automaticky; pokud chybí, použij updated_at
    final res = await client
        .from('tasks')
        .select('tenant_id')
        .filter('deleted_at', 'is', null)
        .gte('created_at', startIso)
        .lt('created_at', endIso);
    final list = _toList(res);
    for (final e in list) {
      try {
        final map = Map<String, dynamic>.from(e as Map);
        final tid = map['tenant_id']?.toString().trim();
        if (tid != null && tid.isNotEmpty) {
          counts[tid] = (counts[tid] ?? 0) + 1;
        }
      } catch (_) {}
    }
  } catch (_) {
    // Tabulka může nemít created_at nebo RLS blokuje – vracíme prázdnou mapu
  }
  return counts;
});

/// Globální Megafon: hromadný UPDATE sloupce [system_announcement] u všech
/// aktivních tenantů (is_active == true). [message] null = vymazat oznámení.
Future<void> broadcastAnnouncementToActiveTenants(String? message) async {
  await SupabaseService.client
      .from('tenants')
      .update({'system_announcement': message}).eq('is_active', true);
}

/// Zastavení vysílání: vymaže system_announcement u všech agentur, které ho mají.
/// Podmínka .not('system_announcement', 'is', null) vybere jen řádky s neprázdným
/// oznámením a splní požadavek PostgreSQL na WHERE u UPDATE.
Future<void> clearAnnouncementForAllTenants() async {
  await SupabaseService.client
      .from('tenants')
      .update({'system_announcement': null})
      .not('system_announcement', 'is', null);
}
