import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Načte všechny měny z DB (cache přes [currenciesProvider]).
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

/// Cache kurzů z DB. Invaliduj při změně v Nastavení (Kurzovní lístek).
final currenciesProvider = FutureProvider<List<CurrencyRow>>((ref) async {
  return CurrencyService.fetchCurrencies();
});
