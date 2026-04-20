// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'owner_cash_transit_settlement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OwnerCashTransitSettlement _$OwnerCashTransitSettlementFromJson(
  Map<String, dynamic> json,
) => _OwnerCashTransitSettlement(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  reservationId: json['reservation_id'] as String?,
  apartmentId: json['apartment_id'] as String?,
  taskId: json['task_id'] as String?,
  amount: amountFromJson(json['amount']),
  currency: json['currency'] as String? ?? 'EUR',
  settledAt: const NullableIsoDateTimeConverter().fromJson(json['settled_at']),
  settledBy: json['settled_by'] as String?,
  status: json['status'] as String? ?? 'available',
  employeeCashTransactionId: json['employee_cash_transaction_id'] as String?,
  notes: json['note'] as String?,
  createdAt: const NullableIsoDateTimeConverter().fromJson(json['created_at']),
  updatedAt: const NullableIsoDateTimeConverter().fromJson(json['updated_at']),
);

Map<String, dynamic> _$OwnerCashTransitSettlementToJson(
  _OwnerCashTransitSettlement instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'reservation_id': instance.reservationId,
  'apartment_id': instance.apartmentId,
  'task_id': instance.taskId,
  'amount': amountToJson(instance.amount),
  'currency': instance.currency,
  'settled_at': const NullableIsoDateTimeConverter().toJson(instance.settledAt),
  'settled_by': instance.settledBy,
  'status': instance.status,
  'employee_cash_transaction_id': instance.employeeCashTransactionId,
  'note': instance.notes,
  'created_at': const NullableIsoDateTimeConverter().toJson(instance.createdAt),
  'updated_at': const NullableIsoDateTimeConverter().toJson(instance.updatedAt),
};
