import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Jeden záznam z tabulky [public.currencies] – kód, symbol, kurz vůči EUR, název.
class CurrencyRow {
  const CurrencyRow({
    required this.code,
    required this.symbol,
    required this.rate,
    this.name,
  });

  final String code;
  final String symbol;
  /// Kurz vůči EUR (EUR = 1.0). Např. CZK 25 znamená 1 EUR = 25 CZK.
  final double rate;
  final String? name;

  factory CurrencyRow.fromJson(Map<String, dynamic> json) {
    final rateRaw = json['rate'];
    double r = 1.0;
    if (rateRaw != null) {
      if (rateRaw is num) {
        r = rateRaw.toDouble();
      } else if (rateRaw is String) {
        r = double.tryParse(rateRaw) ?? 1.0;
      }
    }
    return CurrencyRow(
      code: (json['code'] as String?)?.trim().toUpperCase() ?? '',
      symbol: (json['symbol'] as String?)?.trim() ?? '',
      rate: r,
      name: (json['name'] as String?)?.trim(),
    );
  }
}

/// Služba pro multi-měnové zobrazení cen.
///
/// Všechny ceny modulů jsou v EUR (price_eur). Pro tenanta se přepočítají
/// dle [tenants.currency] a kurzu z [public.currencies].
/// - [convert]: priceInEur * rate(target) → částka v cílové měně.
/// - [formatPrice]: převede a zformátuje např. "250 Kč".
class CurrencyService {
  CurrencyService._();

  /// In-memory cache kurzů – snižuje opakované dotazy na Supabase (viz [fetchCurrenciesCached]).
  static List<CurrencyRow>? _currenciesCache;
  static DateTime? _currenciesCacheAt;
  static const Duration _currenciesCacheTtl = Duration(hours: 1);

  /// Vymaže cache kurzů. Volat před [ref.invalidate(currenciesProvider)] po změně kurzovního lístku.
  static void invalidateCurrenciesCache() {
    _currenciesCache = null;
    _currenciesCacheAt = null;
  }

  /// Vrátí kurzy z DB nebo z cache platné max. [_currenciesCacheTtl] od posledního stažení.
  static Future<List<CurrencyRow>> fetchCurrenciesCached() async {
    final now = DateTime.now();
    if (_currenciesCache != null &&
        _currenciesCacheAt != null &&
        now.difference(_currenciesCacheAt!) < _currenciesCacheTtl) {
      return _currenciesCache!;
    }
    final list = await fetchCurrencies();
    _currenciesCache = list;
    _currenciesCacheAt = now;
    return list;
  }

  /// Načte všechny měny z DB (přímý dotaz bez TTL – pro vynucené obnovení uvnitř [fetchCurrenciesCached]).
  static Future<List<CurrencyRow>> fetchCurrencies() async {
    final res = await SupabaseService.client
        .from('currencies')
        .select('code, symbol, rate, name')
        .order('code');
    final list = res as List;
    return list
        .map((e) => CurrencyRow.fromJson(e as Map<String, dynamic>))
        .where((c) => c.code.isNotEmpty)
        .toList();
  }

  /// Přepočet ceny z EUR do cílové měny.
  /// Vzorec: priceInEur * rate(cíl). Pro EUR je rate = 1.0.
  static double convert(
    double priceInEur,
    String targetCurrencyCode,
    List<CurrencyRow> currencies,
  ) {
    final code = targetCurrencyCode.toUpperCase().trim();
    if (code.isEmpty) return priceInEur;
    final row = _findByCode(currencies, code);
    if (row == null) return priceInEur;
    return priceInEur * row.rate;
  }

  static CurrencyRow? _findByCode(List<CurrencyRow> currencies, String code) {
    for (final c in currencies) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// Převod částky z dané měny do EUR (inverze k [convert]). Pro zobrazení základu předplatného tenanta v EUR.
  /// amountInCurrency / rate(currency) = amountInEur (rate = kolik jednotek za 1 EUR).
  static double toEur(
    double amountInCurrency,
    String currencyCode,
    List<CurrencyRow> currencies,
  ) {
    final code = currencyCode.toUpperCase().trim();
    if (code.isEmpty) return amountInCurrency;
    final row = _findByCode(currencies, code);
    if (row == null || row.rate <= 0) return amountInCurrency;
    return amountInCurrency / row.rate;
  }

  /// Vrátí zformátovaný řetězec ceny v cílové měně (např. "250 Kč", "10.00 €").
  /// Používá symbol a rozumné zaokrouhlení (CZK bez desetinných, EUR/USD 2 desetinná).
  static String formatPrice(
    double priceInEur,
    String targetCurrencyCode,
    List<CurrencyRow> currencies,
  ) {
    final code = targetCurrencyCode.toUpperCase().trim();
    final amount = convert(priceInEur, code, currencies);
    final row = _findByCode(currencies, code);
    final symbol = row?.symbol ?? code;
    switch (code) {
      case 'CZK':
        return '${amount.toStringAsFixed(0)} $symbol';
      case 'EUR':
      case 'USD':
      default:
        return '$symbol ${amount.toStringAsFixed(2)}';
    }
  }

  /// Formátuje částku, která je již v cílové měně (bez přepočtu). Pro zobrazení např. base subscription.
  static String formatAmountInTargetCurrency(
    double amount,
    String targetCurrencyCode,
    List<CurrencyRow> currencies,
  ) {
    final code = targetCurrencyCode.toUpperCase().trim();
    final row = _findByCode(currencies, code);
    final symbol = row?.symbol ?? code;
    switch (code) {
      case 'CZK':
        return '${amount.toStringAsFixed(0)} $symbol';
      case 'EUR':
      case 'USD':
      default:
        return '$symbol ${amount.toStringAsFixed(2)}';
    }
  }

  /// Aktualizuje kurz měny (volá jen Super Admin; RLS to vynucuje).
  static Future<void> updateRate(String code, double rate) async {
    await SupabaseService.client
        .from('currencies')
        .update({'rate': rate})
        .eq('code', code.toUpperCase().trim());
  }

  /// Přidá novou měnu do kurzovníku (volá jen Super Admin).
  static Future<void> insertCurrency(CurrencyRow row) async {
    await SupabaseService.client.from('currencies').insert({
      'code': row.code.toUpperCase().trim(),
      'symbol': row.symbol,
      'rate': row.rate,
      'name': row.name?.trim(),
    });
  }
}

/// Sjednocený helper pro formátování částek v kontextu úkolů (Transfer, Check-in, Cash Collection).
/// BYZNYS PRAVIDLO: Měna pro výběr hotovosti se primárně řídí nastavením celé Agentury (Tenanta).
/// Profil uživatele je pouze fallback. Všechna UI zobrazující částky k vybrání od hosta musí volat tuto funkci.
String formatTaskAmount(BuildContext context, WidgetRef ref, num amountEur) {
  // Měna tenanta (agentury) má přednost.
  final tenantCurrency = ref.watch(currentTenantCurrencyProvider).valueOrNull;
  final preferredCurrency = ref.watch(authNotifierProvider).state.preferredCurrency;
  // Fallback: Tenant -> Profil uživatele -> EUR.
  final effectiveCurrency = (tenantCurrency?.isNotEmpty == true
          ? tenantCurrency
          : (preferredCurrency?.trim().isNotEmpty == true ? preferredCurrency!.trim().toUpperCase() : null)) ??
      'EUR';

  final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
  if (currencies.isNotEmpty) {
    return CurrencyService.formatPrice(amountEur.toDouble(), effectiveCurrency, currencies);
  }
  // Fallback při prázdném kurzovním lístku – měna dle tenanta/profilu.
  return NumberFormat.currency(
    locale: Localizations.localeOf(context).toString(),
    symbol: effectiveCurrency,
    decimalDigits: 2,
  ).format(amountEur);
}

/// Formátuje částku v měně tenanta pro modul Pokladna.
/// Částka je již v cílové měně (balance, transakce) – bez přepočtu z EUR.
String formatWalletAmount(BuildContext context, WidgetRef ref, double amount) {
  final tenantCurrency = ref.watch(currentTenantCurrencyProvider).valueOrNull;
  final preferredCurrency = ref.watch(authNotifierProvider).state.preferredCurrency;
  final effectiveCurrency = (tenantCurrency?.isNotEmpty == true
          ? tenantCurrency!.trim().toUpperCase()
          : (preferredCurrency?.trim().isNotEmpty == true ? preferredCurrency!.trim().toUpperCase() : null)) ??
      'EUR';

  final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
  if (currencies.isNotEmpty) {
    return CurrencyService.formatAmountInTargetCurrency(amount, effectiveCurrency, currencies);
  }
  return '${amount.toStringAsFixed(2)} $effectiveCurrency';
}

/// Formátování data transakce – lokalizované dle locale uživatele.
String formatTransactionDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMd(locale).add_Hm().format(date.toLocal());
}

/// Formátování data s časem – krátký formát (M/d HH:mm) lokalizovaně.
String formatTransactionDateShort(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.Md(locale).add_Hm().format(date.toLocal());
}


/// Cache kurzů z DB (TTL 1 h v [CurrencyService.fetchCurrenciesCached]).
/// Po změně kurzů v Nastavení volat [CurrencyService.invalidateCurrenciesCache] + invalidate provideru.
final currenciesProvider = FutureProvider<List<CurrencyRow>>((ref) async {
  return CurrencyService.fetchCurrenciesCached();
});
