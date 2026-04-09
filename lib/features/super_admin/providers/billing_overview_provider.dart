import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/providers/platform_messaging_rates_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/super_admin/providers/all_tenants_provider.dart';

/// Jedna položka fakturačního rozpisu – název, cena v EUR a příznaky trial / končící modul.
/// Používá se pro základní paušál i moduly. Trial položky mají priceEur=0.
class InvoiceItem {
  const InvoiceItem({
    required this.name,
    required this.priceEur,
    required this.isTrial,
    this.isModuleTrial = false,
    this.isCanceling = false,
  });

  final String name;
  final double priceEur;
  final bool isTrial;
  /// Modul ve zkušební době (tenant_modules.is_trial a trial_ends_at v budoucnosti) – cena 0.
  final bool isModuleTrial;
  /// Modul má cancel_at_period_end = true – ukončí se na konci měsíce.
  final bool isCanceling;
}

/// Řádek pro fakturační tabulku – jeden tenant s plným rozkladem položek.
///
/// Obsahuje: jméno, měnu, seznam fakturačních položek (základ + moduly), gross total před slevou,
/// hodnotu slevy (%) a finální částku k úhradě v EUR (pro sumarizaci celkového MRR).
class TenantBillingRow {
  const TenantBillingRow({
    required this.tenantId,
    required this.tenantName,
    required this.currency,
    required this.invoiceItems,
    required this.grossTotalEur,
    required this.discountPercentage,
    required this.netTotalEur,
    this.isInTrial = false,
  });

  final String tenantId;
  final String tenantName;
  /// Měna tenanta pro zobrazení částek (CZK, EUR, USD).
  final String currency;
  /// Rozpis položek – základní paušál + jednotlivé moduly s cenami (trial = priceEur 0).
  final List<InvoiceItem> invoiceItems;
  /// Celkový mezisoučet před slevou: suma všech priceEur v invoiceItems.
  final double grossTotalEur;
  /// Sleva v procentech (0–100).
  final int discountPercentage;
  /// K úhradě v EUR: grossTotalEur × (1 - discountPercentage/100), nebo 0 pokud isInTrial.
  final double netTotalEur;
  /// Pokud je tenant ve zkušební době (tenants.trial_ends_at v budoucnosti), true → netTotalEur = 0.
  final bool isInTrial;
}

/// Načte tenant_modules: tenant_id -> mapa module_id -> (is_trial, cancel_at_period_end).
/// Aktivní modul = deleted_at IS NULL, valid_until/trial_ends_at v budoucnosti nebo null.
/// Odpovídá logice v dashboard_mrr_provider – jednotný zdroj dat.
/// [cancel_at_period_end] = modul končí na konci měsíce – v UI zobrazíme „(Končí)“.
Future<Map<String, Map<String, ({bool isTrial, bool cancelAtPeriodEnd})>>> _loadTenantModuleBillingInfo() async {
  final result = <String, Map<String, ({bool isTrial, bool cancelAtPeriodEnd})>>{};
  try {
    final res = await SupabaseService.client
        .from('tenant_modules')
        .select('tenant_id, module_id, is_trial, cancel_at_period_end, valid_until, trial_ends_at')
        .isFilter('deleted_at', null);
    final list = res as List<dynamic>;
    final now = DateTime.now().toUtc();
    for (final e in list) {
      final map = e is Map ? e as Map<String, dynamic> : null;
      if (map == null) continue;
      if (!_isModuleValid(map['valid_until'], map['trial_ends_at'], now)) continue;
      final tenantId = (map['tenant_id'] as String?)?.trim();
      final moduleId = (map['module_id'] as String?)?.trim();
      if (tenantId == null || tenantId.isEmpty || moduleId == null || moduleId.isEmpty) continue;
      result.putIfAbsent(tenantId, () => {})[moduleId] = (
        isTrial: map['is_trial'] == true,
        cancelAtPeriodEnd: map['cancel_at_period_end'] == true,
      );
    }
  } catch (e, st) {
    AppLogger.error('billing_overview: _loadTenantModuleBillingInfo selhalo', e, st);
  }
  return result;
}

bool _isModuleValid(Object? validUntilRaw, Object? trialEndsAtRaw, DateTime now) {
  final validUntil = validUntilRaw is String ? DateTime.tryParse(validUntilRaw) : null;
  final trialEndsAt = trialEndsAtRaw is String ? DateTime.tryParse(trialEndsAtRaw) : null;
  if (validUntil != null && validUntil.isBefore(now)) return false;
  if (trialEndsAt != null && trialEndsAt.isBefore(now)) return false;
  return true;
}

/// Načte spotřebu SMS/WA (proxy přes `sent_count`) pro aktuální fakturační měsíc.
///
/// Důležité:
/// - `tenant_usage_monthly` agreguje `sent_count` zvlášť pro `channel`.
/// - Pro fakturaci overage chceme sečíst `sms` + `whatsapp` dohromady.
/// - Tento dotaz děláme jednou pro všechny tenanti, aby hlavní smyčka
///   nevolala DB pro každý tenant zvlášť (lepší výkon).
Future<Map<String, int>> _loadTenantSmsUsage(DateTime nowUtc) async {
  // Formát `YYYY-MM` – přesně jak je definováno v DB/migraci.
  final billingMonth = '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}';

  final smsUsageByTenant = <String, int>{};

  try {
    final res = await SupabaseService.client
        .from('tenant_usage_monthly')
        .select('tenant_id, channel, sent_count')
        .eq('billing_month', billingMonth)
        // Overages zcela odpovídají požadavku PO: `sms` + `whatsapp`.
        .inFilter('channel', ['sms', 'whatsapp']);

    final list = res as List<dynamic>;
    for (final e in list) {
      final map = e is Map ? e as Map<String, dynamic> : null;
      if (map == null) continue;

      final tenantId = (map['tenant_id'] as String?)?.trim() ?? '';
      if (tenantId.isEmpty) continue;

      final sentRaw = map['sent_count'];
      final sentCount = sentRaw is int ? sentRaw : (sentRaw is num ? sentRaw.toInt() : 0);
      smsUsageByTenant[tenantId] = (smsUsageByTenant[tenantId] ?? 0) + sentCount;
    }
  } catch (e, st) {
    // Pokud se spotřeba nepodaří načíst, raději nevystavíme fakturaci s chybou.
    // Všechny tenanti pak budou bez overage položky.
    AppLogger.error('_loadSmsUsageByTenantForMonth: načtení tenant_message_log selhalo', e, st);
  }

  return smsUsageByTenant;
}

/// Provider: přehled fakturace pro Super Admina – sjednocená matematika s dashboard_mrr_provider.
///
/// VÝPOČET Net Total (k úhradě):
/// 1. Base Price = tenant.price_per_apartment × apartmentCount (v měně tenanta)
///    → převod do EUR pomocí CurrencyService.toEur()
/// 2. Modules Price = součet aktivních modulů, kde is_trial == false
///    (moduly s is_trial == true se DO CENY NEZAPOČÍTÁVAJÍ, ale v UI se zobrazí se štítkem TRIAL)
///    Ceny podle pricing_type: fixed → price_eur, per_apartment → price_eur × byty, per_user → price_eur × uživatelé
/// 3. Gross Total = Base Price (EUR) + Modules Price (EUR)
/// 4. Net Total = Gross Total × (1 - tenant.discount_percentage / 100)
///
/// Provider vrací seznam TenantBillingRow s plným rozkladem pro fakturační tabulku.
final billingOverviewProvider = FutureProvider<List<TenantBillingRow>>((ref) async {
  final tenantsAsync = ref.watch(tenantsWithStatusProvider);
  final modulesAsync = ref.watch(allModulesProvider);
  final currenciesAsync = ref.watch(currenciesProvider);

  final items = tenantsAsync.valueOrNull ?? [];
  final modules = modulesAsync.valueOrNull ?? [];
  final currencies = currenciesAsync.valueOrNull ?? [];

  if (items.isEmpty) return [];

  // PROČ: Jednotková cena za „SMS jednotku“ v overage musí odpovídat tarifu v DB (stejně jako dispatch).
  final messagingRates = await ref.watch(platformMessagingRatesProvider.future);

  final tenantModuleBillingInfo = await _loadTenantModuleBillingInfo();
  final nowUtc = DateTime.now().toUtc();
  final tenantSmsUsageByTenant = await _loadTenantSmsUsage(nowUtc);
  final moduleById = {for (final m in modules) m.id: m};
  final now = nowUtc;

  final rows = <TenantBillingRow>[];
  for (final item in items) {
    final tenant = item.tenant;
    if (!tenant.isActive) continue; // Stejně jako dashboard_mrr – neaktivní tenanty (kill-switch) se nezapočítávají
    final apartmentCount = item.apartmentCount ?? 0;
    final userCount = item.teamCount ?? 0;
    final tenantCurrency = tenant.currency ?? 'EUR';
    final pricePerApt = (tenant.pricePerApartment ?? 0).toDouble();
    final discountPct = tenant.discountPercentage.clamp(0, 100);

    // Pokud je tenant ve zkušební době (trial_ends_at v budoucnosti), fakturuje se 0 (Ochranný štít).
    final isInTrial = tenant.trialEndsAt != null && tenant.trialEndsAt!.isAfter(now);

    // 1. Base Price: price_per_apartment × apartmentCount v měně tenanta → převod do EUR
    final baseInTenantCurrency = pricePerApt * apartmentCount;
    final baseEur = currencies.isEmpty
        ? baseInTenantCurrency
        : CurrencyService.toEur(baseInTenantCurrency, tenantCurrency, currencies);

    // 2. Sestavení fakturačního rozpisu – položka po položce s přesnou cenou
    final invoiceItems = <InvoiceItem>[];
    if (baseInTenantCurrency > 0) {
      invoiceItems.add(InvoiceItem(
        name: 'super_admin.billing_item_base_subscription',
        priceEur: baseEur,
        isTrial: false,
        isModuleTrial: false,
      ));
    }
    final moduleInfo = tenantModuleBillingInfo[tenant.id] ?? {};
    for (final entry in moduleInfo.entries) {
      final module = moduleById[entry.key];
      if (module == null) continue;
      final info = entry.value;
      final moduleName = module.name.isNotEmpty ? module.name : module.key;
      double priceEur = 0;
      if (!info.isTrial) {
        final unitPrice = module.price?.toDouble() ?? 0;
        switch (module.pricingType) {
          case 'per_apartment':
            priceEur = unitPrice * apartmentCount;
            break;
          case 'per_user':
            priceEur = unitPrice * userCount;
            break;
          default:
            priceEur = unitPrice;
        }
      }
      invoiceItems.add(InvoiceItem(
        name: moduleName,
        priceEur: priceEur,
        isTrial: info.isTrial,
        isModuleTrial: info.isTrial,
        isCanceling: info.cancelAtPeriodEnd,
      ));
    }

    // 5) SMS/WA Overage (FÁZE 4 – Super Admin fakturace)
    //
    // BUSINESS LOGIKA:
    // - Manažer agentury má v ceně modulu/servisu zdarma limit (FREE_LIMIT).
    // - Pokud automatizace odešle víc zpráv (sent_count pro sms+whatsapp),
    //   nadlimit se zpoplatní pevnou cenou PRICE_PER_SMS.
    // - Není to nový kreditní systém; přidáme pouze další fakturační položku
    //   do rozpisu.
    //
    // PROČ do invoiceItems:
    // - Řešíme to tak, aby gross/net sleva/diskontování zůstalo konzistentní
    //   se stávající matematickou logikou.
    const int freeLimit = 250;
    final pricePerSmsEur = messagingRates.sms;

    final totalSmsWaSent = tenantSmsUsageByTenant[tenant.id] ?? 0;
    final overage = math.max(0, totalSmsWaSent - freeLimit);
    final overagePriceEur = overage * pricePerSmsEur;

    if (overagePriceEur > 0) {
      invoiceItems.add(InvoiceItem(
        name: 'super_admin.billing_item_overage_sms',
        priceEur: overagePriceEur,
        isTrial: false,
        isModuleTrial: false,
      ));
    }

    // 3. Gross Total = suma všech priceEur v rozpisu (vždy spočítáme pro přehled byznysu)
    final grossEur = invoiceItems.fold<double>(0, (sum, i) => sum + i.priceEur);

    // 4. Net Total: pokud je tenant ve zkušební době, k úhradě je 0; jinak standardní sleva
    final netEur = isInTrial ? 0.0 : grossEur * (1 - (discountPct / 100));

    rows.add(TenantBillingRow(
      tenantId: tenant.id,
      tenantName: tenant.name,
      currency: tenantCurrency,
      invoiceItems: invoiceItems,
      grossTotalEur: grossEur,
      discountPercentage: discountPct,
      netTotalEur: netEur,
      isInTrial: isInTrial,
    ));
  }

  return rows;
});
