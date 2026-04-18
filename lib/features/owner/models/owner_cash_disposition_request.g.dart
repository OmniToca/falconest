// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'owner_cash_disposition_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OwnerCashDispositionRequest _$OwnerCashDispositionRequestFromJson(
  Map<String, dynamic> json,
) => _OwnerCashDispositionRequest(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  settlementId: json['settlement_id'] as String,
  ownerProfileId: json['owner_profile_id'] as String,
  dispositionType: json['disposition_type'] as String,
  amount: amountFromJson(json['amount']),
  usedAmount: json['used_amount'] == null
      ? 0.0
      : amountFromJson(json['used_amount']),
  status: json['status'] as String,
  iban: json['iban'] as String?,
  pickupDate: const NullableIsoDateTimeConverter().fromJson(
    json['pickup_date'],
  ),
  adminNotes: json['admin_notes'] as String?,
  createdAt: const IsoDateTimeConverter().fromJson(json['created_at']),
  updatedAt: const IsoDateTimeConverter().fromJson(json['updated_at']),
);

Map<String, dynamic> _$OwnerCashDispositionRequestToJson(
  _OwnerCashDispositionRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'settlement_id': instance.settlementId,
  'owner_profile_id': instance.ownerProfileId,
  'disposition_type': instance.dispositionType,
  'amount': amountToJson(instance.amount),
  'used_amount': amountToJson(instance.usedAmount),
  'status': instance.status,
  'iban': instance.iban,
  'pickup_date': const NullableIsoDateTimeConverter().toJson(
    instance.pickupDate,
  ),
  'admin_notes': instance.adminNotes,
  'created_at': const IsoDateTimeConverter().toJson(instance.createdAt),
  'updated_at': const IsoDateTimeConverter().toJson(instance.updatedAt),
};
