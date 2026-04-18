// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apartment_investment_pnl_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApartmentInvestmentPnlEntry _$ApartmentInvestmentPnlEntryFromJson(
  Map<String, dynamic> json,
) => _ApartmentInvestmentPnlEntry(
  id: json['id'] as String,
  apartmentId: json['apartment_id'] as String,
  entryMonth: const IsoDateOnlyConverter().fromJson(json['entry_month']),
  entryType: json['entry_type'] as String,
  amount: json['amount'] == null ? 0.0 : modelAmountFromJson(json['amount']),
  description: json['description'] as String?,
  createdAt: const NullableIsoDateTimeConverter().fromJson(json['created_at']),
  updatedAt: const NullableIsoDateTimeConverter().fromJson(json['updated_at']),
);

Map<String, dynamic> _$ApartmentInvestmentPnlEntryToJson(
  _ApartmentInvestmentPnlEntry instance,
) => <String, dynamic>{
  'id': instance.id,
  'apartment_id': instance.apartmentId,
  'entry_month': const IsoDateOnlyConverter().toJson(instance.entryMonth),
  'entry_type': instance.entryType,
  'amount': modelAmountToJson(instance.amount),
  'description': instance.description,
  'created_at': const NullableIsoDateTimeConverter().toJson(instance.createdAt),
  'updated_at': const NullableIsoDateTimeConverter().toJson(instance.updatedAt),
};
