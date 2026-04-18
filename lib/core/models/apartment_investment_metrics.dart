import 'package:freezed_annotation/freezed_annotation.dart';

import 'model_date_time_json.dart';
import 'model_numeric_json.dart';

part 'apartment_investment_metrics.freezed.dart';
part 'apartment_investment_metrics.g.dart';

/// Jednorázový řádek tabulky `apartment_investment_metrics` (1:1 k `apartments.id`).
///
/// PROČ: Majitel může dle RLS aktualizovat odhady a náklady u svého bytu; admin spravuje
/// celý tenant. Částky jsou [double] kvůli PostgREST `numeric` → num/String v JSON.
@freezed
abstract class ApartmentInvestmentMetrics with _$ApartmentInvestmentMetrics {
  const ApartmentInvestmentMetrics._();

  const factory ApartmentInvestmentMetrics({
    @JsonKey(name: 'apartment_id') required String apartmentId,
    @JsonKey(name: 'purchase_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson)
    @Default(0.0)
    double purchasePrice,
    @JsonKey(name: 'initial_renovation_cost', fromJson: modelAmountFromJson, toJson: modelAmountToJson)
    @Default(0.0)
    double initialRenovationCost,
    @JsonKey(name: 'estimated_market_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson)
    @Default(0.0)
    double estimatedMarketPrice,
    @JsonKey(name: 'market_price_updated_at') @NullableIsoDateTimeConverter() DateTime? marketPriceUpdatedAt,
    @JsonKey(name: 'updated_at') @IsoDateTimeConverter() required DateTime updatedAt,
  }) = _ApartmentInvestmentMetrics;

  factory ApartmentInvestmentMetrics.fromJson(Map<String, dynamic> json) =>
      _$ApartmentInvestmentMetricsFromJson(json);
}
