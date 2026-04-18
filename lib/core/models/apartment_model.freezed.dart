// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'apartment_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApartmentModel {

 String get id;@JsonKey(name: 'tenant_id') String get tenantId; String get name; String? get address; String? get keybox;@JsonKey(name: 'parking_instructions', fromJson: _trimmedNullable) String? get parkingInstructions;@JsonKey(name: 'review_link', fromJson: _trimmedNullable) String? get reviewLink;@JsonKey(fromJson: _trimmedNullable) String? get code;@JsonKey(name: 'zone_id', fromJson: _trimmedNullable) String? get zoneId;@JsonKey(fromJson: _apartmentStatusFromJson) String get status;@JsonKey(name: 'check_in_time', fromJson: _checkInTimeFromJson) String get checkInTime;@JsonKey(name: 'check_out_time', fromJson: _checkOutTimeFromJson) String get checkOutTime;@JsonKey(name: 'standard_cleaning_duration', fromJson: _standardCleaningDurationFromJson) int get standardCleaningDuration;@JsonKey(name: 'owner_notes', fromJson: _trimmedNullable) String? get ownerNotes;@JsonKey(name: 'monthly_management_fee', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double get monthlyManagementFee;@JsonKey(name: 'managed_from')@NullableIsoDateTimeConverter() DateTime? get managedFrom;@JsonKey(name: 'deleted_at')@NullableIsoDateTimeConverter() DateTime? get deletedAt;@JsonKey(name: 'investment_tracking_enabled') bool get investmentTrackingEnabled;/// `short_term` | `long_term` – výchozí STR pro zpětnou kompatibilitu.
@JsonKey(name: 'rental_mode', fromJson: _rentalModeFromJson) String get rentalMode;/// Platnost smlouvy od (jen smysl u [kApartmentRentalModeLongTerm], jinak obvykle null).
@JsonKey(name: 'lease_start_date')@NullableIsoDateOnlyConverter() DateTime? get leaseStartDate;/// Platnost smlouvy do.
@JsonKey(name: 'lease_end_date')@NullableIsoDateOnlyConverter() DateTime? get leaseEndDate;/// Měsíční nájem (dlouhodobý režim); u STR typicky 0.
@JsonKey(name: 'rent_amount', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double get rentAmount;/// Den splatnosti v měsíci (1–31) – musí odpovídat CHECK v Supabase.
@JsonKey(name: 'rent_due_day', fromJson: _rentDueDayFromJson) int get rentDueDay;/// Připomínka v aplikaci vs. úkol pro pracovníka (`rent_collection`).
@JsonKey(name: 'rent_collection_mode', fromJson: _rentCollectionModeFromJson) String get rentCollectionMode;/// Kdo má úkol výběru nájmu (profiles.id), jen pro [kApartmentRentCollectionModeTask].
@JsonKey(name: 'rent_task_assignee_id', fromJson: _trimmedNullable) String? get rentTaskAssigneeId;/// Raw GeoJSON z `geo_location` – pro serializaci zpět použijte [GeoJsonPoint.toPostgrestJson].
@JsonKey(name: 'geo_location') Object? get geoLocation;
/// Create a copy of ApartmentModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApartmentModelCopyWith<ApartmentModel> get copyWith => _$ApartmentModelCopyWithImpl<ApartmentModel>(this as ApartmentModel, _$identity);

  /// Serializes this ApartmentModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApartmentModel&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.keybox, keybox) || other.keybox == keybox)&&(identical(other.parkingInstructions, parkingInstructions) || other.parkingInstructions == parkingInstructions)&&(identical(other.reviewLink, reviewLink) || other.reviewLink == reviewLink)&&(identical(other.code, code) || other.code == code)&&(identical(other.zoneId, zoneId) || other.zoneId == zoneId)&&(identical(other.status, status) || other.status == status)&&(identical(other.checkInTime, checkInTime) || other.checkInTime == checkInTime)&&(identical(other.checkOutTime, checkOutTime) || other.checkOutTime == checkOutTime)&&(identical(other.standardCleaningDuration, standardCleaningDuration) || other.standardCleaningDuration == standardCleaningDuration)&&(identical(other.ownerNotes, ownerNotes) || other.ownerNotes == ownerNotes)&&(identical(other.monthlyManagementFee, monthlyManagementFee) || other.monthlyManagementFee == monthlyManagementFee)&&(identical(other.managedFrom, managedFrom) || other.managedFrom == managedFrom)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.investmentTrackingEnabled, investmentTrackingEnabled) || other.investmentTrackingEnabled == investmentTrackingEnabled)&&(identical(other.rentalMode, rentalMode) || other.rentalMode == rentalMode)&&(identical(other.leaseStartDate, leaseStartDate) || other.leaseStartDate == leaseStartDate)&&(identical(other.leaseEndDate, leaseEndDate) || other.leaseEndDate == leaseEndDate)&&(identical(other.rentAmount, rentAmount) || other.rentAmount == rentAmount)&&(identical(other.rentDueDay, rentDueDay) || other.rentDueDay == rentDueDay)&&(identical(other.rentCollectionMode, rentCollectionMode) || other.rentCollectionMode == rentCollectionMode)&&(identical(other.rentTaskAssigneeId, rentTaskAssigneeId) || other.rentTaskAssigneeId == rentTaskAssigneeId)&&const DeepCollectionEquality().equals(other.geoLocation, geoLocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,name,address,keybox,parkingInstructions,reviewLink,code,zoneId,status,checkInTime,checkOutTime,standardCleaningDuration,ownerNotes,monthlyManagementFee,managedFrom,deletedAt,investmentTrackingEnabled,rentalMode,leaseStartDate,leaseEndDate,rentAmount,rentDueDay,rentCollectionMode,rentTaskAssigneeId,const DeepCollectionEquality().hash(geoLocation)]);

@override
String toString() {
  return 'ApartmentModel(id: $id, tenantId: $tenantId, name: $name, address: $address, keybox: $keybox, parkingInstructions: $parkingInstructions, reviewLink: $reviewLink, code: $code, zoneId: $zoneId, status: $status, checkInTime: $checkInTime, checkOutTime: $checkOutTime, standardCleaningDuration: $standardCleaningDuration, ownerNotes: $ownerNotes, monthlyManagementFee: $monthlyManagementFee, managedFrom: $managedFrom, deletedAt: $deletedAt, investmentTrackingEnabled: $investmentTrackingEnabled, rentalMode: $rentalMode, leaseStartDate: $leaseStartDate, leaseEndDate: $leaseEndDate, rentAmount: $rentAmount, rentDueDay: $rentDueDay, rentCollectionMode: $rentCollectionMode, rentTaskAssigneeId: $rentTaskAssigneeId, geoLocation: $geoLocation)';
}


}

/// @nodoc
abstract mixin class $ApartmentModelCopyWith<$Res>  {
  factory $ApartmentModelCopyWith(ApartmentModel value, $Res Function(ApartmentModel) _then) = _$ApartmentModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId, String name, String? address, String? keybox,@JsonKey(name: 'parking_instructions', fromJson: _trimmedNullable) String? parkingInstructions,@JsonKey(name: 'review_link', fromJson: _trimmedNullable) String? reviewLink,@JsonKey(fromJson: _trimmedNullable) String? code,@JsonKey(name: 'zone_id', fromJson: _trimmedNullable) String? zoneId,@JsonKey(fromJson: _apartmentStatusFromJson) String status,@JsonKey(name: 'check_in_time', fromJson: _checkInTimeFromJson) String checkInTime,@JsonKey(name: 'check_out_time', fromJson: _checkOutTimeFromJson) String checkOutTime,@JsonKey(name: 'standard_cleaning_duration', fromJson: _standardCleaningDurationFromJson) int standardCleaningDuration,@JsonKey(name: 'owner_notes', fromJson: _trimmedNullable) String? ownerNotes,@JsonKey(name: 'monthly_management_fee', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double monthlyManagementFee,@JsonKey(name: 'managed_from')@NullableIsoDateTimeConverter() DateTime? managedFrom,@JsonKey(name: 'deleted_at')@NullableIsoDateTimeConverter() DateTime? deletedAt,@JsonKey(name: 'investment_tracking_enabled') bool investmentTrackingEnabled,@JsonKey(name: 'rental_mode', fromJson: _rentalModeFromJson) String rentalMode,@JsonKey(name: 'lease_start_date')@NullableIsoDateOnlyConverter() DateTime? leaseStartDate,@JsonKey(name: 'lease_end_date')@NullableIsoDateOnlyConverter() DateTime? leaseEndDate,@JsonKey(name: 'rent_amount', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double rentAmount,@JsonKey(name: 'rent_due_day', fromJson: _rentDueDayFromJson) int rentDueDay,@JsonKey(name: 'rent_collection_mode', fromJson: _rentCollectionModeFromJson) String rentCollectionMode,@JsonKey(name: 'rent_task_assignee_id', fromJson: _trimmedNullable) String? rentTaskAssigneeId,@JsonKey(name: 'geo_location') Object? geoLocation
});




}
/// @nodoc
class _$ApartmentModelCopyWithImpl<$Res>
    implements $ApartmentModelCopyWith<$Res> {
  _$ApartmentModelCopyWithImpl(this._self, this._then);

  final ApartmentModel _self;
  final $Res Function(ApartmentModel) _then;

/// Create a copy of ApartmentModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? name = null,Object? address = freezed,Object? keybox = freezed,Object? parkingInstructions = freezed,Object? reviewLink = freezed,Object? code = freezed,Object? zoneId = freezed,Object? status = null,Object? checkInTime = null,Object? checkOutTime = null,Object? standardCleaningDuration = null,Object? ownerNotes = freezed,Object? monthlyManagementFee = null,Object? managedFrom = freezed,Object? deletedAt = freezed,Object? investmentTrackingEnabled = null,Object? rentalMode = null,Object? leaseStartDate = freezed,Object? leaseEndDate = freezed,Object? rentAmount = null,Object? rentDueDay = null,Object? rentCollectionMode = null,Object? rentTaskAssigneeId = freezed,Object? geoLocation = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,keybox: freezed == keybox ? _self.keybox : keybox // ignore: cast_nullable_to_non_nullable
as String?,parkingInstructions: freezed == parkingInstructions ? _self.parkingInstructions : parkingInstructions // ignore: cast_nullable_to_non_nullable
as String?,reviewLink: freezed == reviewLink ? _self.reviewLink : reviewLink // ignore: cast_nullable_to_non_nullable
as String?,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,zoneId: freezed == zoneId ? _self.zoneId : zoneId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,checkInTime: null == checkInTime ? _self.checkInTime : checkInTime // ignore: cast_nullable_to_non_nullable
as String,checkOutTime: null == checkOutTime ? _self.checkOutTime : checkOutTime // ignore: cast_nullable_to_non_nullable
as String,standardCleaningDuration: null == standardCleaningDuration ? _self.standardCleaningDuration : standardCleaningDuration // ignore: cast_nullable_to_non_nullable
as int,ownerNotes: freezed == ownerNotes ? _self.ownerNotes : ownerNotes // ignore: cast_nullable_to_non_nullable
as String?,monthlyManagementFee: null == monthlyManagementFee ? _self.monthlyManagementFee : monthlyManagementFee // ignore: cast_nullable_to_non_nullable
as double,managedFrom: freezed == managedFrom ? _self.managedFrom : managedFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,investmentTrackingEnabled: null == investmentTrackingEnabled ? _self.investmentTrackingEnabled : investmentTrackingEnabled // ignore: cast_nullable_to_non_nullable
as bool,rentalMode: null == rentalMode ? _self.rentalMode : rentalMode // ignore: cast_nullable_to_non_nullable
as String,leaseStartDate: freezed == leaseStartDate ? _self.leaseStartDate : leaseStartDate // ignore: cast_nullable_to_non_nullable
as DateTime?,leaseEndDate: freezed == leaseEndDate ? _self.leaseEndDate : leaseEndDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rentAmount: null == rentAmount ? _self.rentAmount : rentAmount // ignore: cast_nullable_to_non_nullable
as double,rentDueDay: null == rentDueDay ? _self.rentDueDay : rentDueDay // ignore: cast_nullable_to_non_nullable
as int,rentCollectionMode: null == rentCollectionMode ? _self.rentCollectionMode : rentCollectionMode // ignore: cast_nullable_to_non_nullable
as String,rentTaskAssigneeId: freezed == rentTaskAssigneeId ? _self.rentTaskAssigneeId : rentTaskAssigneeId // ignore: cast_nullable_to_non_nullable
as String?,geoLocation: freezed == geoLocation ? _self.geoLocation : geoLocation ,
  ));
}

}


/// Adds pattern-matching-related methods to [ApartmentModel].
extension ApartmentModelPatterns on ApartmentModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApartmentModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApartmentModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApartmentModel value)  $default,){
final _that = this;
switch (_that) {
case _ApartmentModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApartmentModel value)?  $default,){
final _that = this;
switch (_that) {
case _ApartmentModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId,  String name,  String? address,  String? keybox, @JsonKey(name: 'parking_instructions', fromJson: _trimmedNullable)  String? parkingInstructions, @JsonKey(name: 'review_link', fromJson: _trimmedNullable)  String? reviewLink, @JsonKey(fromJson: _trimmedNullable)  String? code, @JsonKey(name: 'zone_id', fromJson: _trimmedNullable)  String? zoneId, @JsonKey(fromJson: _apartmentStatusFromJson)  String status, @JsonKey(name: 'check_in_time', fromJson: _checkInTimeFromJson)  String checkInTime, @JsonKey(name: 'check_out_time', fromJson: _checkOutTimeFromJson)  String checkOutTime, @JsonKey(name: 'standard_cleaning_duration', fromJson: _standardCleaningDurationFromJson)  int standardCleaningDuration, @JsonKey(name: 'owner_notes', fromJson: _trimmedNullable)  String? ownerNotes, @JsonKey(name: 'monthly_management_fee', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double monthlyManagementFee, @JsonKey(name: 'managed_from')@NullableIsoDateTimeConverter()  DateTime? managedFrom, @JsonKey(name: 'deleted_at')@NullableIsoDateTimeConverter()  DateTime? deletedAt, @JsonKey(name: 'investment_tracking_enabled')  bool investmentTrackingEnabled, @JsonKey(name: 'rental_mode', fromJson: _rentalModeFromJson)  String rentalMode, @JsonKey(name: 'lease_start_date')@NullableIsoDateOnlyConverter()  DateTime? leaseStartDate, @JsonKey(name: 'lease_end_date')@NullableIsoDateOnlyConverter()  DateTime? leaseEndDate, @JsonKey(name: 'rent_amount', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double rentAmount, @JsonKey(name: 'rent_due_day', fromJson: _rentDueDayFromJson)  int rentDueDay, @JsonKey(name: 'rent_collection_mode', fromJson: _rentCollectionModeFromJson)  String rentCollectionMode, @JsonKey(name: 'rent_task_assignee_id', fromJson: _trimmedNullable)  String? rentTaskAssigneeId, @JsonKey(name: 'geo_location')  Object? geoLocation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApartmentModel() when $default != null:
return $default(_that.id,_that.tenantId,_that.name,_that.address,_that.keybox,_that.parkingInstructions,_that.reviewLink,_that.code,_that.zoneId,_that.status,_that.checkInTime,_that.checkOutTime,_that.standardCleaningDuration,_that.ownerNotes,_that.monthlyManagementFee,_that.managedFrom,_that.deletedAt,_that.investmentTrackingEnabled,_that.rentalMode,_that.leaseStartDate,_that.leaseEndDate,_that.rentAmount,_that.rentDueDay,_that.rentCollectionMode,_that.rentTaskAssigneeId,_that.geoLocation);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId,  String name,  String? address,  String? keybox, @JsonKey(name: 'parking_instructions', fromJson: _trimmedNullable)  String? parkingInstructions, @JsonKey(name: 'review_link', fromJson: _trimmedNullable)  String? reviewLink, @JsonKey(fromJson: _trimmedNullable)  String? code, @JsonKey(name: 'zone_id', fromJson: _trimmedNullable)  String? zoneId, @JsonKey(fromJson: _apartmentStatusFromJson)  String status, @JsonKey(name: 'check_in_time', fromJson: _checkInTimeFromJson)  String checkInTime, @JsonKey(name: 'check_out_time', fromJson: _checkOutTimeFromJson)  String checkOutTime, @JsonKey(name: 'standard_cleaning_duration', fromJson: _standardCleaningDurationFromJson)  int standardCleaningDuration, @JsonKey(name: 'owner_notes', fromJson: _trimmedNullable)  String? ownerNotes, @JsonKey(name: 'monthly_management_fee', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double monthlyManagementFee, @JsonKey(name: 'managed_from')@NullableIsoDateTimeConverter()  DateTime? managedFrom, @JsonKey(name: 'deleted_at')@NullableIsoDateTimeConverter()  DateTime? deletedAt, @JsonKey(name: 'investment_tracking_enabled')  bool investmentTrackingEnabled, @JsonKey(name: 'rental_mode', fromJson: _rentalModeFromJson)  String rentalMode, @JsonKey(name: 'lease_start_date')@NullableIsoDateOnlyConverter()  DateTime? leaseStartDate, @JsonKey(name: 'lease_end_date')@NullableIsoDateOnlyConverter()  DateTime? leaseEndDate, @JsonKey(name: 'rent_amount', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double rentAmount, @JsonKey(name: 'rent_due_day', fromJson: _rentDueDayFromJson)  int rentDueDay, @JsonKey(name: 'rent_collection_mode', fromJson: _rentCollectionModeFromJson)  String rentCollectionMode, @JsonKey(name: 'rent_task_assignee_id', fromJson: _trimmedNullable)  String? rentTaskAssigneeId, @JsonKey(name: 'geo_location')  Object? geoLocation)  $default,) {final _that = this;
switch (_that) {
case _ApartmentModel():
return $default(_that.id,_that.tenantId,_that.name,_that.address,_that.keybox,_that.parkingInstructions,_that.reviewLink,_that.code,_that.zoneId,_that.status,_that.checkInTime,_that.checkOutTime,_that.standardCleaningDuration,_that.ownerNotes,_that.monthlyManagementFee,_that.managedFrom,_that.deletedAt,_that.investmentTrackingEnabled,_that.rentalMode,_that.leaseStartDate,_that.leaseEndDate,_that.rentAmount,_that.rentDueDay,_that.rentCollectionMode,_that.rentTaskAssigneeId,_that.geoLocation);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tenant_id')  String tenantId,  String name,  String? address,  String? keybox, @JsonKey(name: 'parking_instructions', fromJson: _trimmedNullable)  String? parkingInstructions, @JsonKey(name: 'review_link', fromJson: _trimmedNullable)  String? reviewLink, @JsonKey(fromJson: _trimmedNullable)  String? code, @JsonKey(name: 'zone_id', fromJson: _trimmedNullable)  String? zoneId, @JsonKey(fromJson: _apartmentStatusFromJson)  String status, @JsonKey(name: 'check_in_time', fromJson: _checkInTimeFromJson)  String checkInTime, @JsonKey(name: 'check_out_time', fromJson: _checkOutTimeFromJson)  String checkOutTime, @JsonKey(name: 'standard_cleaning_duration', fromJson: _standardCleaningDurationFromJson)  int standardCleaningDuration, @JsonKey(name: 'owner_notes', fromJson: _trimmedNullable)  String? ownerNotes, @JsonKey(name: 'monthly_management_fee', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double monthlyManagementFee, @JsonKey(name: 'managed_from')@NullableIsoDateTimeConverter()  DateTime? managedFrom, @JsonKey(name: 'deleted_at')@NullableIsoDateTimeConverter()  DateTime? deletedAt, @JsonKey(name: 'investment_tracking_enabled')  bool investmentTrackingEnabled, @JsonKey(name: 'rental_mode', fromJson: _rentalModeFromJson)  String rentalMode, @JsonKey(name: 'lease_start_date')@NullableIsoDateOnlyConverter()  DateTime? leaseStartDate, @JsonKey(name: 'lease_end_date')@NullableIsoDateOnlyConverter()  DateTime? leaseEndDate, @JsonKey(name: 'rent_amount', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double rentAmount, @JsonKey(name: 'rent_due_day', fromJson: _rentDueDayFromJson)  int rentDueDay, @JsonKey(name: 'rent_collection_mode', fromJson: _rentCollectionModeFromJson)  String rentCollectionMode, @JsonKey(name: 'rent_task_assignee_id', fromJson: _trimmedNullable)  String? rentTaskAssigneeId, @JsonKey(name: 'geo_location')  Object? geoLocation)?  $default,) {final _that = this;
switch (_that) {
case _ApartmentModel() when $default != null:
return $default(_that.id,_that.tenantId,_that.name,_that.address,_that.keybox,_that.parkingInstructions,_that.reviewLink,_that.code,_that.zoneId,_that.status,_that.checkInTime,_that.checkOutTime,_that.standardCleaningDuration,_that.ownerNotes,_that.monthlyManagementFee,_that.managedFrom,_that.deletedAt,_that.investmentTrackingEnabled,_that.rentalMode,_that.leaseStartDate,_that.leaseEndDate,_that.rentAmount,_that.rentDueDay,_that.rentCollectionMode,_that.rentTaskAssigneeId,_that.geoLocation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApartmentModel extends ApartmentModel {
  const _ApartmentModel({required this.id, @JsonKey(name: 'tenant_id') required this.tenantId, required this.name, this.address, this.keybox, @JsonKey(name: 'parking_instructions', fromJson: _trimmedNullable) this.parkingInstructions, @JsonKey(name: 'review_link', fromJson: _trimmedNullable) this.reviewLink, @JsonKey(fromJson: _trimmedNullable) this.code, @JsonKey(name: 'zone_id', fromJson: _trimmedNullable) this.zoneId, @JsonKey(fromJson: _apartmentStatusFromJson) this.status = 'Uklizeno', @JsonKey(name: 'check_in_time', fromJson: _checkInTimeFromJson) this.checkInTime = '15:00', @JsonKey(name: 'check_out_time', fromJson: _checkOutTimeFromJson) this.checkOutTime = '10:00', @JsonKey(name: 'standard_cleaning_duration', fromJson: _standardCleaningDurationFromJson) this.standardCleaningDuration = 120, @JsonKey(name: 'owner_notes', fromJson: _trimmedNullable) this.ownerNotes, @JsonKey(name: 'monthly_management_fee', fromJson: modelAmountFromJson, toJson: modelAmountToJson) this.monthlyManagementFee = 0.0, @JsonKey(name: 'managed_from')@NullableIsoDateTimeConverter() this.managedFrom, @JsonKey(name: 'deleted_at')@NullableIsoDateTimeConverter() this.deletedAt, @JsonKey(name: 'investment_tracking_enabled') this.investmentTrackingEnabled = false, @JsonKey(name: 'rental_mode', fromJson: _rentalModeFromJson) this.rentalMode = kApartmentRentalModeShortTerm, @JsonKey(name: 'lease_start_date')@NullableIsoDateOnlyConverter() this.leaseStartDate, @JsonKey(name: 'lease_end_date')@NullableIsoDateOnlyConverter() this.leaseEndDate, @JsonKey(name: 'rent_amount', fromJson: modelAmountFromJson, toJson: modelAmountToJson) this.rentAmount = 0.0, @JsonKey(name: 'rent_due_day', fromJson: _rentDueDayFromJson) this.rentDueDay = 1, @JsonKey(name: 'rent_collection_mode', fromJson: _rentCollectionModeFromJson) this.rentCollectionMode = kApartmentRentCollectionModeNotification, @JsonKey(name: 'rent_task_assignee_id', fromJson: _trimmedNullable) this.rentTaskAssigneeId, @JsonKey(name: 'geo_location') this.geoLocation}): super._();
  factory _ApartmentModel.fromJson(Map<String, dynamic> json) => _$ApartmentModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override final  String name;
@override final  String? address;
@override final  String? keybox;
@override@JsonKey(name: 'parking_instructions', fromJson: _trimmedNullable) final  String? parkingInstructions;
@override@JsonKey(name: 'review_link', fromJson: _trimmedNullable) final  String? reviewLink;
@override@JsonKey(fromJson: _trimmedNullable) final  String? code;
@override@JsonKey(name: 'zone_id', fromJson: _trimmedNullable) final  String? zoneId;
@override@JsonKey(fromJson: _apartmentStatusFromJson) final  String status;
@override@JsonKey(name: 'check_in_time', fromJson: _checkInTimeFromJson) final  String checkInTime;
@override@JsonKey(name: 'check_out_time', fromJson: _checkOutTimeFromJson) final  String checkOutTime;
@override@JsonKey(name: 'standard_cleaning_duration', fromJson: _standardCleaningDurationFromJson) final  int standardCleaningDuration;
@override@JsonKey(name: 'owner_notes', fromJson: _trimmedNullable) final  String? ownerNotes;
@override@JsonKey(name: 'monthly_management_fee', fromJson: modelAmountFromJson, toJson: modelAmountToJson) final  double monthlyManagementFee;
@override@JsonKey(name: 'managed_from')@NullableIsoDateTimeConverter() final  DateTime? managedFrom;
@override@JsonKey(name: 'deleted_at')@NullableIsoDateTimeConverter() final  DateTime? deletedAt;
@override@JsonKey(name: 'investment_tracking_enabled') final  bool investmentTrackingEnabled;
/// `short_term` | `long_term` – výchozí STR pro zpětnou kompatibilitu.
@override@JsonKey(name: 'rental_mode', fromJson: _rentalModeFromJson) final  String rentalMode;
/// Platnost smlouvy od (jen smysl u [kApartmentRentalModeLongTerm], jinak obvykle null).
@override@JsonKey(name: 'lease_start_date')@NullableIsoDateOnlyConverter() final  DateTime? leaseStartDate;
/// Platnost smlouvy do.
@override@JsonKey(name: 'lease_end_date')@NullableIsoDateOnlyConverter() final  DateTime? leaseEndDate;
/// Měsíční nájem (dlouhodobý režim); u STR typicky 0.
@override@JsonKey(name: 'rent_amount', fromJson: modelAmountFromJson, toJson: modelAmountToJson) final  double rentAmount;
/// Den splatnosti v měsíci (1–31) – musí odpovídat CHECK v Supabase.
@override@JsonKey(name: 'rent_due_day', fromJson: _rentDueDayFromJson) final  int rentDueDay;
/// Připomínka v aplikaci vs. úkol pro pracovníka (`rent_collection`).
@override@JsonKey(name: 'rent_collection_mode', fromJson: _rentCollectionModeFromJson) final  String rentCollectionMode;
/// Kdo má úkol výběru nájmu (profiles.id), jen pro [kApartmentRentCollectionModeTask].
@override@JsonKey(name: 'rent_task_assignee_id', fromJson: _trimmedNullable) final  String? rentTaskAssigneeId;
/// Raw GeoJSON z `geo_location` – pro serializaci zpět použijte [GeoJsonPoint.toPostgrestJson].
@override@JsonKey(name: 'geo_location') final  Object? geoLocation;

/// Create a copy of ApartmentModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApartmentModelCopyWith<_ApartmentModel> get copyWith => __$ApartmentModelCopyWithImpl<_ApartmentModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApartmentModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApartmentModel&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.keybox, keybox) || other.keybox == keybox)&&(identical(other.parkingInstructions, parkingInstructions) || other.parkingInstructions == parkingInstructions)&&(identical(other.reviewLink, reviewLink) || other.reviewLink == reviewLink)&&(identical(other.code, code) || other.code == code)&&(identical(other.zoneId, zoneId) || other.zoneId == zoneId)&&(identical(other.status, status) || other.status == status)&&(identical(other.checkInTime, checkInTime) || other.checkInTime == checkInTime)&&(identical(other.checkOutTime, checkOutTime) || other.checkOutTime == checkOutTime)&&(identical(other.standardCleaningDuration, standardCleaningDuration) || other.standardCleaningDuration == standardCleaningDuration)&&(identical(other.ownerNotes, ownerNotes) || other.ownerNotes == ownerNotes)&&(identical(other.monthlyManagementFee, monthlyManagementFee) || other.monthlyManagementFee == monthlyManagementFee)&&(identical(other.managedFrom, managedFrom) || other.managedFrom == managedFrom)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.investmentTrackingEnabled, investmentTrackingEnabled) || other.investmentTrackingEnabled == investmentTrackingEnabled)&&(identical(other.rentalMode, rentalMode) || other.rentalMode == rentalMode)&&(identical(other.leaseStartDate, leaseStartDate) || other.leaseStartDate == leaseStartDate)&&(identical(other.leaseEndDate, leaseEndDate) || other.leaseEndDate == leaseEndDate)&&(identical(other.rentAmount, rentAmount) || other.rentAmount == rentAmount)&&(identical(other.rentDueDay, rentDueDay) || other.rentDueDay == rentDueDay)&&(identical(other.rentCollectionMode, rentCollectionMode) || other.rentCollectionMode == rentCollectionMode)&&(identical(other.rentTaskAssigneeId, rentTaskAssigneeId) || other.rentTaskAssigneeId == rentTaskAssigneeId)&&const DeepCollectionEquality().equals(other.geoLocation, geoLocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,name,address,keybox,parkingInstructions,reviewLink,code,zoneId,status,checkInTime,checkOutTime,standardCleaningDuration,ownerNotes,monthlyManagementFee,managedFrom,deletedAt,investmentTrackingEnabled,rentalMode,leaseStartDate,leaseEndDate,rentAmount,rentDueDay,rentCollectionMode,rentTaskAssigneeId,const DeepCollectionEquality().hash(geoLocation)]);

@override
String toString() {
  return 'ApartmentModel(id: $id, tenantId: $tenantId, name: $name, address: $address, keybox: $keybox, parkingInstructions: $parkingInstructions, reviewLink: $reviewLink, code: $code, zoneId: $zoneId, status: $status, checkInTime: $checkInTime, checkOutTime: $checkOutTime, standardCleaningDuration: $standardCleaningDuration, ownerNotes: $ownerNotes, monthlyManagementFee: $monthlyManagementFee, managedFrom: $managedFrom, deletedAt: $deletedAt, investmentTrackingEnabled: $investmentTrackingEnabled, rentalMode: $rentalMode, leaseStartDate: $leaseStartDate, leaseEndDate: $leaseEndDate, rentAmount: $rentAmount, rentDueDay: $rentDueDay, rentCollectionMode: $rentCollectionMode, rentTaskAssigneeId: $rentTaskAssigneeId, geoLocation: $geoLocation)';
}


}

/// @nodoc
abstract mixin class _$ApartmentModelCopyWith<$Res> implements $ApartmentModelCopyWith<$Res> {
  factory _$ApartmentModelCopyWith(_ApartmentModel value, $Res Function(_ApartmentModel) _then) = __$ApartmentModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId, String name, String? address, String? keybox,@JsonKey(name: 'parking_instructions', fromJson: _trimmedNullable) String? parkingInstructions,@JsonKey(name: 'review_link', fromJson: _trimmedNullable) String? reviewLink,@JsonKey(fromJson: _trimmedNullable) String? code,@JsonKey(name: 'zone_id', fromJson: _trimmedNullable) String? zoneId,@JsonKey(fromJson: _apartmentStatusFromJson) String status,@JsonKey(name: 'check_in_time', fromJson: _checkInTimeFromJson) String checkInTime,@JsonKey(name: 'check_out_time', fromJson: _checkOutTimeFromJson) String checkOutTime,@JsonKey(name: 'standard_cleaning_duration', fromJson: _standardCleaningDurationFromJson) int standardCleaningDuration,@JsonKey(name: 'owner_notes', fromJson: _trimmedNullable) String? ownerNotes,@JsonKey(name: 'monthly_management_fee', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double monthlyManagementFee,@JsonKey(name: 'managed_from')@NullableIsoDateTimeConverter() DateTime? managedFrom,@JsonKey(name: 'deleted_at')@NullableIsoDateTimeConverter() DateTime? deletedAt,@JsonKey(name: 'investment_tracking_enabled') bool investmentTrackingEnabled,@JsonKey(name: 'rental_mode', fromJson: _rentalModeFromJson) String rentalMode,@JsonKey(name: 'lease_start_date')@NullableIsoDateOnlyConverter() DateTime? leaseStartDate,@JsonKey(name: 'lease_end_date')@NullableIsoDateOnlyConverter() DateTime? leaseEndDate,@JsonKey(name: 'rent_amount', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double rentAmount,@JsonKey(name: 'rent_due_day', fromJson: _rentDueDayFromJson) int rentDueDay,@JsonKey(name: 'rent_collection_mode', fromJson: _rentCollectionModeFromJson) String rentCollectionMode,@JsonKey(name: 'rent_task_assignee_id', fromJson: _trimmedNullable) String? rentTaskAssigneeId,@JsonKey(name: 'geo_location') Object? geoLocation
});




}
/// @nodoc
class __$ApartmentModelCopyWithImpl<$Res>
    implements _$ApartmentModelCopyWith<$Res> {
  __$ApartmentModelCopyWithImpl(this._self, this._then);

  final _ApartmentModel _self;
  final $Res Function(_ApartmentModel) _then;

/// Create a copy of ApartmentModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? name = null,Object? address = freezed,Object? keybox = freezed,Object? parkingInstructions = freezed,Object? reviewLink = freezed,Object? code = freezed,Object? zoneId = freezed,Object? status = null,Object? checkInTime = null,Object? checkOutTime = null,Object? standardCleaningDuration = null,Object? ownerNotes = freezed,Object? monthlyManagementFee = null,Object? managedFrom = freezed,Object? deletedAt = freezed,Object? investmentTrackingEnabled = null,Object? rentalMode = null,Object? leaseStartDate = freezed,Object? leaseEndDate = freezed,Object? rentAmount = null,Object? rentDueDay = null,Object? rentCollectionMode = null,Object? rentTaskAssigneeId = freezed,Object? geoLocation = freezed,}) {
  return _then(_ApartmentModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,keybox: freezed == keybox ? _self.keybox : keybox // ignore: cast_nullable_to_non_nullable
as String?,parkingInstructions: freezed == parkingInstructions ? _self.parkingInstructions : parkingInstructions // ignore: cast_nullable_to_non_nullable
as String?,reviewLink: freezed == reviewLink ? _self.reviewLink : reviewLink // ignore: cast_nullable_to_non_nullable
as String?,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,zoneId: freezed == zoneId ? _self.zoneId : zoneId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,checkInTime: null == checkInTime ? _self.checkInTime : checkInTime // ignore: cast_nullable_to_non_nullable
as String,checkOutTime: null == checkOutTime ? _self.checkOutTime : checkOutTime // ignore: cast_nullable_to_non_nullable
as String,standardCleaningDuration: null == standardCleaningDuration ? _self.standardCleaningDuration : standardCleaningDuration // ignore: cast_nullable_to_non_nullable
as int,ownerNotes: freezed == ownerNotes ? _self.ownerNotes : ownerNotes // ignore: cast_nullable_to_non_nullable
as String?,monthlyManagementFee: null == monthlyManagementFee ? _self.monthlyManagementFee : monthlyManagementFee // ignore: cast_nullable_to_non_nullable
as double,managedFrom: freezed == managedFrom ? _self.managedFrom : managedFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,investmentTrackingEnabled: null == investmentTrackingEnabled ? _self.investmentTrackingEnabled : investmentTrackingEnabled // ignore: cast_nullable_to_non_nullable
as bool,rentalMode: null == rentalMode ? _self.rentalMode : rentalMode // ignore: cast_nullable_to_non_nullable
as String,leaseStartDate: freezed == leaseStartDate ? _self.leaseStartDate : leaseStartDate // ignore: cast_nullable_to_non_nullable
as DateTime?,leaseEndDate: freezed == leaseEndDate ? _self.leaseEndDate : leaseEndDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rentAmount: null == rentAmount ? _self.rentAmount : rentAmount // ignore: cast_nullable_to_non_nullable
as double,rentDueDay: null == rentDueDay ? _self.rentDueDay : rentDueDay // ignore: cast_nullable_to_non_nullable
as int,rentCollectionMode: null == rentCollectionMode ? _self.rentCollectionMode : rentCollectionMode // ignore: cast_nullable_to_non_nullable
as String,rentTaskAssigneeId: freezed == rentTaskAssigneeId ? _self.rentTaskAssigneeId : rentTaskAssigneeId // ignore: cast_nullable_to_non_nullable
as String?,geoLocation: freezed == geoLocation ? _self.geoLocation : geoLocation ,
  ));
}


}

// dart format on
