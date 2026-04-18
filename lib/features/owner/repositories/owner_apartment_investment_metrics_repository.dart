import 'package:falconest/core/models/apartment_investment_metrics.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Čtení a zápis řádku `apartment_investment_metrics` z Klientského portálu majitele.
///
/// PROČ: RLS na Supabase filtruje podle role a `apartment_owners`; logika patří do
/// repozitáře, ne do widgetu. Upsert řeší první uložení (INSERT) i další změny (UPDATE).
class OwnerApartmentInvestmentMetricsRepository {
  OwnerApartmentInvestmentMetricsRepository._();

  /// Načte metriky pro [apartmentId], nebo `null` pokud řádek ještě neexistuje.
  static Future<ApartmentInvestmentMetrics?> fetchByApartmentId(String apartmentId) async {
    if (apartmentId.isEmpty) return null;
    try {
      final res = await SupabaseService.client
          .from('apartment_investment_metrics')
          .select()
          .eq('apartment_id', apartmentId)
          .maybeSingle();
      if (res == null) return null;
      return ApartmentInvestmentMetrics.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      AppLogger.error('OwnerApartmentInvestmentMetricsRepository.fetchByApartmentId', e, st);
      rethrow;
    }
  }

  /// Uloží částky; při prvním zápisu INSERT, jinak UPDATE (PostgREST upsert na PK).
  ///
  /// [marketPriceUpdatedAt] – čas „odhad aktualizován“ (typicky nyní při změně odhadu trhu).
  static Future<void> upsertMetrics({
    required String apartmentId,
    required double purchasePrice,
    required double initialRenovationCost,
    required double estimatedMarketPrice,
    required DateTime marketPriceUpdatedAtUtc,
  }) async {
    if (apartmentId.isEmpty) return;
    await SupabaseService.client.from('apartment_investment_metrics').upsert(
      <String, dynamic>{
        'apartment_id': apartmentId,
        'purchase_price': purchasePrice,
        'initial_renovation_cost': initialRenovationCost,
        'estimated_market_price': estimatedMarketPrice,
        'market_price_updated_at': marketPriceUpdatedAtUtc.toIso8601String(),
      },
      onConflict: 'apartment_id',
    );
  }
}
