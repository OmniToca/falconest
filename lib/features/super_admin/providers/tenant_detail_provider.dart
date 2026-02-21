import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';

/// Model uživatele z profiles pro zobrazení v týmu agentury.
class ProfileRow {
  const ProfileRow({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;
}

/// Fakturační / obchodní údaje tenanta – ukládají se do sloupce [tenants.billing_info] (jsonb).
class BillingInfo {
  const BillingInfo({
    this.companyName,
    this.ico,
    this.dic,
    this.street,
    this.city,
    this.zip,
    this.country,
    this.contactEmail,
    this.phone,
  });

  final String? companyName;
  final String? ico;
  final String? dic;
  final String? street;
  final String? city;
  final String? zip;
  final String? country;
  final String? contactEmail;
  final String? phone;

  /// Parsuje JSONB billing_info z DB. Podporuje klíče contact_email i email (DB může mít oba).
  factory BillingInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const BillingInfo();
    return BillingInfo(
      companyName: _str(json['company_name']),
      ico: _str(json['ico']),
      dic: _str(json['dic']),
      street: _str(json['street']),
      city: _str(json['city']),
      zip: _str(json['zip']),
      country: _str(json['country']),
      contactEmail: _str(json['contact_email'] ?? json['email']),
      phone: _str(json['phone']),
    );
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Map<String, dynamic> toJson() {
    return {
      if (companyName != null && companyName!.isNotEmpty) 'company_name': companyName,
      if (ico != null && ico!.isNotEmpty) 'ico': ico,
      if (dic != null && dic!.isNotEmpty) 'dic': dic,
      if (street != null && street!.isNotEmpty) 'street': street,
      if (city != null && city!.isNotEmpty) 'city': city,
      if (zip != null && zip!.isNotEmpty) 'zip': zip,
      if (country != null && country!.isNotEmpty) 'country': country,
      if (contactEmail != null && contactEmail!.isNotEmpty) 'contact_email': contactEmail,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
    };
  }
}

/// Model detailu tenantu – název, poznámky, fakturační údaje, cena za byt, měna, sleva, Stripe.
class TenantDetailRow {
  const TenantDetailRow({
    required this.id,
    required this.name,
    this.notes,
    this.billingInfo,
    this.pricePerApartment,
    this.currency,
    this.discountPercentage = 0,
    this.stripeCustomerId,
  });

  final String id;
  final String name;
  final String? notes;
  final BillingInfo? billingInfo;
  /// ID zákazníka ve Stripe – null = platební brána zatím nepřipojena.
  final String? stripeCustomerId;
  /// Měsíční cena za jeden byt (základ předplatného). Null = nevyplněno.
  final num? pricePerApartment;
  /// Měna tenanta pro zobrazení cen (CZK, EUR, USD).
  final String? currency;
  /// Sleva v procentech (0–100) aplikovaná na MRR z placených modulů (mimo trial).
  final int discountPercentage;

  factory TenantDetailRow.fromJson(Map<String, dynamic> map) {
    final rawBilling = map['billing_info'];
    BillingInfo? billing;
    if (rawBilling != null) {
      if (rawBilling is Map<String, dynamic>) {
        billing = BillingInfo.fromJson(rawBilling);
      } else if (rawBilling is Map) {
        billing = BillingInfo.fromJson(Map<String, dynamic>.from(rawBilling));
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
    final stripeCustomerId = (map['stripe_customer_id'] as String?)?.trim();
    return TenantDetailRow(
      id: map['id'] as String? ?? '',
      name: (map['name'] as String?) ?? '',
      notes: map['notes'] as String?,
      billingInfo: billing ?? const BillingInfo(),
      pricePerApartment: pricePerApartment,
      currency: currency?.isNotEmpty == true ? currency : null,
      discountPercentage: discountPercentage,
      stripeCustomerId: stripeCustomerId?.isEmpty == true ? null : stripeCustomerId,
    );
  }
}

/// Provider načítající detail jednoho tenanta (včetně notes, billing_info, price_per_apartment).
final tenantDetailProvider =
    FutureProvider.family<TenantDetailRow?, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return null;
  try {
    final res = await SupabaseService.client
        .from('tenants')
        .select('id, name, notes, billing_info, price_per_apartment, currency, discount_percentage, stripe_customer_id')
        .eq('id', tenantId)
        .maybeSingle();

    if (res == null) return null;
    return TenantDetailRow.fromJson(Map<String, dynamic>.from(res as Map));
  } catch (_) {
    return null;
  }
});

/// Provider načítající uživatele (profiles) pro daného tenanta.
final tenantProfilesProvider =
    FutureProvider.family<List<ProfileRow>, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return [];
  try {
    final res = await SupabaseService.client
        .from('profiles')
        .select('id, name, role')
        .eq('tenant_id', tenantId)
        .filter('deleted_at', 'is', null);

    final list = res as List<dynamic>;
    final result = <ProfileRow>[];
    for (final e in list) {
      try {
        final map = Map<String, dynamic>.from(e as Map);
        result.add(ProfileRow(
          id: map['id']?.toString() ?? '',
          name: map['name'] as String? ?? '',
          role: map['role'] as String? ?? '',
        ));
      } catch (_) {}
    }
    return result;
  } catch (_) {
    return [];
  }
});

/// Statistiky tenanta – počet bytů a rezervací v aktuálním měsíci (pro MRR a přehled).
class TenantStats {
  const TenantStats({
    this.apartmentCount = 0,
    this.reservationsThisMonth = 0,
  });

  final int apartmentCount;
  final int reservationsThisMonth;
}

/// Rozšířené statistiky tenanta pro „Smart Modal“ – aktivní uživatelé, čekající pozvánky, byty, poslední přihlášení.
class TenantStatsFull {
  const TenantStatsFull({
    this.activeUsers = 0,
    this.pendingInvitations = 0,
    this.apartmentCount = 0,
    this.lastLogin,
  });

  final int activeUsers;
  final int pendingInvitations;
  final int apartmentCount;
  final DateTime? lastLogin;
}

/// Načte rozšířené statistiky tenanta: počet aktivních uživatelů (profiles), čekajících pozvánek (invitations), bytů.
final tenantStatsFullProvider =
    FutureProvider.family<TenantStatsFull, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return const TenantStatsFull();
  final client = SupabaseService.client;
  int activeUsers = 0;
  int pendingInvitations = 0;
  int apartmentCount = 0;
  try {
    final profilesRes = await client
        .from('profiles')
        .select('id')
        .eq('tenant_id', tenantId)
        .filter('deleted_at', 'is', null);
    activeUsers = (profilesRes as List).length;
  } catch (_) {}
  try {
    dynamic invRes;
    try {
      invRes = await client
          .from('invitations')
          .select('id')
          .eq('tenant_id', tenantId)
          .filter('deleted_at', 'is', null);
    } catch (_) {
      invRes = await client
          .from('invitations')
          .select('id')
          .eq('tenant_id', tenantId);
    }
    pendingInvitations = (invRes as List).length;
  } catch (_) {}
  try {
    final aptRes = await client
        .from('apartments')
        .select('id')
        .eq('tenant_id', tenantId)
        .filter('deleted_at', 'is', null);
    apartmentCount = (aptRes as List).length;
  } catch (_) {}
  return TenantStatsFull(
    activeUsers: activeUsers,
    pendingInvitations: pendingInvitations,
    apartmentCount: apartmentCount,
  );
});

final tenantStatsProvider =
    FutureProvider.family<TenantStats, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return const TenantStats();
  final client = SupabaseService.client;
  int apartments = 0;
  int reservations = 0;
  try {
    final aptRes = await client
        .from('apartments')
        .select('id')
        .eq('tenant_id', tenantId)
        .filter('deleted_at', 'is', null);
    apartments = (aptRes as List).length;
  } catch (_) {}
  try {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toUtc().toIso8601String();
    final aptRes = await client
        .from('apartments')
        .select('id')
        .eq('tenant_id', tenantId)
        .filter('deleted_at', 'is', null);
    final apartmentIds = (aptRes as List)
        .map((e) => (e is Map ? e['id'] : null)?.toString())
        .whereType<String>()
        .toList();
    if (apartmentIds.isNotEmpty) {
      final resRes = await client
          .from('reservations')
          .select('id')
          .inFilter('apartment_id', apartmentIds)
          .filter('deleted_at', 'is', null)
          .gte('start_date', start)
          .lte('start_date', end);
      reservations = (resRes as List).length;
    }
  } catch (_) {}
  return TenantStats(
    apartmentCount: apartments,
    reservationsThisMonth: reservations,
  );
});

/// Data řádku tenant_modules pro trial/platnost – is_trial, trial_ends_at, valid_until.
/// Používá se pro zobrazení badge „Trial do: …“ a v dialogu Marketing & Předplatné.
class TenantModuleSubscriptionData {
  const TenantModuleSubscriptionData({
    required this.isTrial,
    this.trialEndsAt,
    this.validUntil,
  });

  final bool isTrial;
  final DateTime? trialEndsAt;
  final DateTime? validUntil;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory TenantModuleSubscriptionData.fromJson(Map<String, dynamic>? map) {
    if (map == null) return const TenantModuleSubscriptionData(isTrial: false);
    final isTrial = map['is_trial'] == true || map['is_trial'] == 1;
    return TenantModuleSubscriptionData(
      isTrial: isTrial,
      trialEndsAt: _parseDate(map['trial_ends_at']),
      validUntil: _parseDate(map['valid_until']),
    );
  }
}

/// Mapa module_id -> TenantModuleSubscriptionData pro daného tenanta (aktivní moduly).
/// Načítá z tenant_modules sloupce is_trial, trial_ends_at, valid_until.
/// Filtruje: deleted_at IS NULL, valid_until/trial_ends_at v budoucnosti nebo null.
final tenantModuleSubscriptionMapProvider =
    FutureProvider.family<Map<String, TenantModuleSubscriptionData>, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return {};
  try {
    final res = await SupabaseService.client
        .from('tenant_modules')
        .select('module_id, is_trial, trial_ends_at, valid_until')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null);
    final list = res as List<dynamic>;
    final now = DateTime.now().toUtc();
    final map = <String, TenantModuleSubscriptionData>{};
    for (final e in list) {
      final row = e is Map ? Map<String, dynamic>.from(e) : null;
      if (row == null) continue;
      if (!_isSubscriptionValidNow(row['valid_until'], row['trial_ends_at'], now)) continue;
      final moduleId = (row['module_id']?.toString() ?? '').trim();
      if (moduleId.isEmpty) continue;
      map[moduleId] = TenantModuleSubscriptionData.fromJson(row);
    }
    return map;
  } catch (_) {
    return {};
  }
});

bool _isSubscriptionValidNow(dynamic validUntilRaw, dynamic trialEndsAtRaw, DateTime now) {
  final validUntil = validUntilRaw != null ? DateTime.tryParse(validUntilRaw.toString()) : null;
  final trialEndsAt = trialEndsAtRaw != null ? DateTime.tryParse(trialEndsAtRaw.toString()) : null;
  if (validUntil != null && validUntil.isBefore(now)) return false;
  if (trialEndsAt != null && trialEndsAt.isBefore(now)) return false;
  return true;
}
