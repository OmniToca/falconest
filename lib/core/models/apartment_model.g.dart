// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apartment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApartmentModel _$ApartmentModelFromJson(
  Map<String, dynamic> json,
) => _ApartmentModel(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  name: json['name'] as String,
  address: json['address'] as String?,
  keybox: json['keybox'] as String?,
  parkingInstructions: _trimmedNullable(json['parking_instructions']),
  reviewLink: _trimmedNullable(json['review_link']),
  code: _trimmedNullable(json['code']),
  zoneId: _trimmedNullable(json['zone_id']),
  status: json['status'] == null
      ? 'Uklizeno'
      : _apartmentStatusFromJson(json['status']),
  checkInTime: json['check_in_time'] == null
      ? '15:00'
      : _checkInTimeFromJson(json['check_in_time']),
  checkOutTime: json['check_out_time'] == null
      ? '10:00'
      : _checkOutTimeFromJson(json['check_out_time']),
  standardCleaningDuration: json['standard_cleaning_duration'] == null
      ? 120
      : _standardCleaningDurationFromJson(json['standard_cleaning_duration']),
  ownerNotes: _trimmedNullable(json['owner_notes']),
  monthlyManagementFee: json['monthly_management_fee'] == null
      ? 0.0
      : modelAmountFromJson(json['monthly_management_fee']),
  managedFrom: const NullableIsoDateTimeConverter().fromJson(
    json['managed_from'],
  ),
  deletedAt: const NullableIsoDateTimeConverter().fromJson(json['deleted_at']),
  investmentTrackingEnabled:
      json['investment_tracking_enabled'] as bool? ?? false,
  rentalMode: json['rental_mode'] == null
      ? kApartmentRentalModeShortTerm
      : _rentalModeFromJson(json['rental_mode']),
  leaseStartDate: const NullableIsoDateOnlyConverter().fromJson(
    json['lease_start_date'],
  ),
  leaseEndDate: const NullableIsoDateOnlyConverter().fromJson(
    json['lease_end_date'],
  ),
  rentAmount: json['rent_amount'] == null
      ? 0.0
      : modelAmountFromJson(json['rent_amount']),
  rentDueDay: json['rent_due_day'] == null
      ? 1
      : _rentDueDayFromJson(json['rent_due_day']),
  rentCollectionMode: json['rent_collection_mode'] == null
      ? kApartmentRentCollectionModeNotification
      : _rentCollectionModeFromJson(json['rent_collection_mode']),
  rentTaskAssigneeId: _trimmedNullable(json['rent_task_assignee_id']),
  geoLocation: json['geo_location'],
);

Map<String, dynamic> _$ApartmentModelToJson(
  _ApartmentModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'name': instance.name,
  'address': instance.address,
  'keybox': instance.keybox,
  'parking_instructions': instance.parkingInstructions,
  'review_link': instance.reviewLink,
  'code': instance.code,
  'zone_id': instance.zoneId,
  'status': instance.status,
  'check_in_time': instance.checkInTime,
  'check_out_time': instance.checkOutTime,
  'standard_cleaning_duration': instance.standardCleaningDuration,
  'owner_notes': instance.ownerNotes,
  'monthly_management_fee': modelAmountToJson(instance.monthlyManagementFee),
  'managed_from': const NullableIsoDateTimeConverter().toJson(
    instance.managedFrom,
  ),
  'deleted_at': const NullableIsoDateTimeConverter().toJson(instance.deletedAt),
  'investment_tracking_enabled': instance.investmentTrackingEnabled,
  'rental_mode': instance.rentalMode,
  'lease_start_date': const NullableIsoDateOnlyConverter().toJson(
    instance.leaseStartDate,
  ),
  'lease_end_date': const NullableIsoDateOnlyConverter().toJson(
    instance.leaseEndDate,
  ),
  'rent_amount': modelAmountToJson(instance.rentAmount),
  'rent_due_day': instance.rentDueDay,
  'rent_collection_mode': instance.rentCollectionMode,
  'rent_task_assignee_id': instance.rentTaskAssigneeId,
  'geo_location': instance.geoLocation,
};
