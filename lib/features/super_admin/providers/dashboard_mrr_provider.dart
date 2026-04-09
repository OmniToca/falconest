import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/super_admin/providers/all_tenants_provider.dart';

/// Výsledek výpočtu MRR pro dashboard: celkové MRR v EUR a per-tenant MRR v EUR.
/// Zobrazení v měně admina pomocí CurrencyService.formatPrice(eur, displayCurrency, currencies).
class DashboardMrrResult {
  const DashboardMrrResult({
    required this.totalEur,
    required this.perTenantEur,
  });

  final double totalEur;
  final Map<String, double> perTenantEur;
}

/// Načte tenant_modules: tenant_id -> mapa module_id -> is_trial (pouze ne-trial se započítá do MRR).
/// Filtruje: deleted_at IS NULL, valid_until/trial_ends_at v budoucnosti nebo null.
Future<Map<String, Map<String, bool>>> _loadTenantModuleTrial() async {
  final result = <String, Map<String, bool>>{};
  try {
    final res = await SupabaseService.client
        .from('tenant_modules')
        .select('tenant_id, module_id, is_trial, valid_until, trial_ends_at')
        .isFilter('deleted_at', null);
    final list = res as List<dynamic>;
    final now = DateTime.now().toUtc();
    for (final e in list) {
      final map = e is Map ? e as Map<String, dynamic> : null;
      if (map == null) continue;
      if (!_isModuleValidForMrr(map['valid_until'], map['trial_ends_at'], now)) continue;
      final tenantId = (map['tenant_id'] as String?)?.trim();
      final moduleId = (map['module_id'] as String?)?.trim();
      if (tenantId == null || tenantId.isEmpty || moduleId == null || moduleId.isEmpty) continue;
      result.putIfAbsent(tenantId, () => {})[moduleId] = map['is_trial'] == true;
    }
  } catch (e, st) {
    AppLogger.error('dashboard MRR: načtení tenant_modules pro trial stav selhalo', e, st);
  }
  return result;
}

bool _isModuleValidForMrr(Object? validUntilRaw, Object? trialEndsAtRaw, DateTime now) {
  final validUntil = validUntilRaw is String ? DateTime.tryParse(validUntilRaw) : null;
  final trialEndsAt = trialEndsAtRaw is String ? DateTime.tryParse(trialEndsAtRaw) : null;
  if (validUntil != null && validUntil.isBefore(now)) return false;
  if (trialEndsAt != null && trialEndsAt.isBefore(now)) return false;
  return true;
}

/// Provider: vypočte skutečné MRR pro všechny aktivní tenanty.
/// Pro každého tenanta: základ (price_per_apartment × počet bytů v měně tenanta → EUR)
/// + součet aktivních modulů (fixed / per_apartment × byty / per_user × uživatelé) v EUR.
/// Celkové MRR = součet všech tenantů v EUR (zobrazení v preferované měně admina).
final dashboardMrrProvider = FutureProvider<DashboardMrrResult>((ref) async {
  final tenantsAsync = ref.watch(tenantsWithStatusProvider);
  final modulesAsync = ref.watch(allModulesProvider);
  final currenciesAsync = ref.watch(currenciesProvider);

  final items = tenantsAsync.valueOrNull ?? [];
  final modules = modulesAsync.valueOrNull ?? [];
  final currencies = currenciesAsync.valueOrNull ?? [];

  if (items.isEmpty) return const DashboardMrrResult(totalEur: 0, perTenantEur: {});

  final tenantModuleTrial = await _loadTenantModuleTrial();
  final moduleById = {for (final m in modules) m.id: m};

  double totalEur = 0;
  final perTenantEur = <String, double>{};

  final now = DateTime.now().toUtc();
  for (final item in items) {
    final tenant = item.tenant;
    if (!tenant.isActive) continue;

    // A) Celý tenant ve zkušební době → MRR = 0 (Ochranný štít).
    if (tenant.trialEndsAt != null && tenant.trialEndsAt!.isAfter(now)) {
      perTenantEur[tenant.id] = 0.0;
      continue;
    }

    final apartmentCount = item.apartmentCount ?? 0;
    final userCount = item.teamCount ?? 0;
    final tenantCurrency = tenant.currency ?? 'EUR';
    final pricePerApt = (tenant.pricePerApartment ?? 0).toDouble();
    final discountPct = tenant.discountPercentage.clamp(0, 100);

    double baseInTenantCurrency = pricePerApt * apartmentCount;
    double baseEur = currencies.isEmpty
        ? baseInTenantCurrency
        : CurrencyService.toEur(baseInTenantCurrency, tenantCurrency, currencies);

    // B) Moduly v Trialu (is_trial a trial_ends_at platí) → přičítáme 0.
    double moduleEur = 0;
    final moduleTrial = tenantModuleTrial[tenant.id] ?? {};
    for (final entry in moduleTrial.entries) {
      if (entry.value) continue; // vynechat trial moduly (priceEur = 0)
      final module = moduleById[entry.key];
      if (module == null) continue;
      final priceEur = module.price?.toDouble() ?? 0;
      switch (module.pricingType) {
        case 'per_apartment':
          moduleEur += priceEur * apartmentCount;
          break;
        case 'per_user':
          moduleEur += priceEur * userCount;
          break;
        default:
          moduleEur += priceEur;
      }
    }

    final subtotalEur = baseEur + moduleEur;
    final tenantTotalEur = subtotalEur * (1 - (discountPct / 100));
    perTenantEur[tenant.id] = tenantTotalEur;
    totalEur += tenantTotalEur;
  }

  return DashboardMrrResult(totalEur: totalEur, perTenantEur: perTenantEur);
});
