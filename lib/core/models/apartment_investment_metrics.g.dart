// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apartment_investment_metrics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApartmentInvestmentMetrics _$ApartmentInvestmentMetricsFromJson(
  Map<String, dynamic> json,
) => _ApartmentInvestmentMetrics(
  apartmentId: json['apartment_id'] as String,
  purchasePrice: json['purchase_price'] == null
      ? 0.0
      : modelAmountFromJson(json['purchase_price']),
  initialRenovationCost: json['initial_renovation_cost'] == null
      ? 0.0
      : modelAmountFromJson(json['initial_renovation_cost']),
  estimatedMarketPrice: json['estimated_market_price'] == null
      ? 0.0
      : modelAmountFromJson(json['estimated_market_price']),
  marketPriceUpdatedAt: const NullableIsoDateTimeConverter().fromJson(
    json['market_price_updated_at'],
  ),
  updatedAt: const IsoDateTimeConverter().fromJson(json['updated_at']),
);

Map<String, dynamic> _$ApartmentInvestmentMetricsToJson(
  _ApartmentInvestmentMetrics instance,
) => <String, dynamic>{
  'apartment_id': instance.apartmentId,
  'purchase_price': modelAmountToJson(instance.purchasePrice),
  'initial_renovation_cost': modelAmountToJson(instance.initialRenovationCost),
  'estimated_market_price': modelAmountToJson(instance.estimatedMarketPrice),
  'market_price_updated_at': const NullableIsoDateTimeConverter().toJson(
    instance.marketPriceUpdatedAt,
  ),
  'updated_at': const IsoDateTimeConverter().toJson(instance.updatedAt),
};
