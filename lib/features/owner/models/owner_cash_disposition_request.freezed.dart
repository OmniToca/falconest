// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'owner_cash_disposition_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OwnerCashDispositionRequest {

 String get id;@JsonKey(name: 'tenant_id') String get tenantId;@JsonKey(name: 'settlement_id') String get settlementId;@JsonKey(name: 'owner_profile_id') String get ownerProfileId;/// `bank_transfer` | `invoice_credit` | `vault_pickup`
@JsonKey(name: 'disposition_type') String get dispositionType;@JsonKey(fromJson: amountFromJson, toJson: amountToJson) double get amount;/// Již uplatněná část žádosti (umoření atd., migrace `20260410010000`).
@JsonKey(name: 'used_amount', fromJson: amountFromJson, toJson: amountToJson) double get usedAmount;/// `pending` | `approved` | `rejected` | `completed` | `partially_completed` | `ready_for_pickup`
 String get status;/// IBAN / číslo účtu u `bank_transfer` (volitelné, migrace `20260410000000`).
 String? get iban;/// Plánované vyzvednutí u `vault_pickup` (migrace `20260410020000`).
@JsonKey(name: 'pickup_date')@NullableIsoDateTimeConverter() DateTime? get pickupDate;@JsonKey(name: 'admin_notes') String? get adminNotes;@JsonKey(name: 'created_at')@IsoDateTimeConverter() DateTime get createdAt;@JsonKey(name: 'updated_at')@IsoDateTimeConverter() DateTime get updatedAt;
/// Create a copy of OwnerCashDispositionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OwnerCashDispositionRequestCopyWith<OwnerCashDispositionRequest> get copyWith => _$OwnerCashDispositionRequestCopyWithImpl<OwnerCashDispositionRequest>(this as OwnerCashDispositionRequest, _$identity);

  /// Serializes this OwnerCashDispositionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OwnerCashDispositionRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.settlementId, settlementId) || other.settlementId == settlementId)&&(identical(other.ownerProfileId, ownerProfileId) || other.ownerProfileId == ownerProfileId)&&(identical(other.dispositionType, dispositionType) || other.dispositionType == dispositionType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.usedAmount, usedAmount) || other.usedAmount == usedAmount)&&(identical(other.status, status) || other.status == status)&&(identical(other.iban, iban) || other.iban == iban)&&(identical(other.pickupDate, pickupDate) || other.pickupDate == pickupDate)&&(identical(other.adminNotes, adminNotes) || other.adminNotes == adminNotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,settlementId,ownerProfileId,dispositionType,amount,usedAmount,status,iban,pickupDate,adminNotes,createdAt,updatedAt);

@override
String toString() {
  return 'OwnerCashDispositionRequest(id: $id, tenantId: $tenantId, settlementId: $settlementId, ownerProfileId: $ownerProfileId, dispositionType: $dispositionType, amount: $amount, usedAmount: $usedAmount, status: $status, iban: $iban, pickupDate: $pickupDate, adminNotes: $adminNotes, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $OwnerCashDispositionRequestCopyWith<$Res>  {
  factory $OwnerCashDispositionRequestCopyWith(OwnerCashDispositionRequest value, $Res Function(OwnerCashDispositionRequest) _then) = _$OwnerCashDispositionRequestCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'settlement_id') String settlementId,@JsonKey(name: 'owner_profile_id') String ownerProfileId,@JsonKey(name: 'disposition_type') String dispositionType,@JsonKey(fromJson: amountFromJson, toJson: amountToJson) double amount,@JsonKey(name: 'used_amount', fromJson: amountFromJson, toJson: amountToJson) double usedAmount, String status, String? iban,@JsonKey(name: 'pickup_date')@NullableIsoDateTimeConverter() DateTime? pickupDate,@JsonKey(name: 'admin_notes') String? adminNotes,@JsonKey(name: 'created_at')@IsoDateTimeConverter() DateTime createdAt,@JsonKey(name: 'updated_at')@IsoDateTimeConverter() DateTime updatedAt
});




}
/// @nodoc
class _$OwnerCashDispositionRequestCopyWithImpl<$Res>
    implements $OwnerCashDispositionRequestCopyWith<$Res> {
  _$OwnerCashDispositionRequestCopyWithImpl(this._self, this._then);

  final OwnerCashDispositionRequest _self;
  final $Res Function(OwnerCashDispositionRequest) _then;

/// Create a copy of OwnerCashDispositionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? settlementId = null,Object? ownerProfileId = null,Object? dispositionType = null,Object? amount = null,Object? usedAmount = null,Object? status = null,Object? iban = freezed,Object? pickupDate = freezed,Object? adminNotes = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,settlementId: null == settlementId ? _self.settlementId : settlementId // ignore: cast_nullable_to_non_nullable
as String,ownerProfileId: null == ownerProfileId ? _self.ownerProfileId : ownerProfileId // ignore: cast_nullable_to_non_nullable
as String,dispositionType: null == dispositionType ? _self.dispositionType : dispositionType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,usedAmount: null == usedAmount ? _self.usedAmount : usedAmount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,iban: freezed == iban ? _self.iban : iban // ignore: cast_nullable_to_non_nullable
as String?,pickupDate: freezed == pickupDate ? _self.pickupDate : pickupDate // ignore: cast_nullable_to_non_nullable
as DateTime?,adminNotes: freezed == adminNotes ? _self.adminNotes : adminNotes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [OwnerCashDispositionRequest].
extension OwnerCashDispositionRequestPatterns on OwnerCashDispositionRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OwnerCashDispositionRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OwnerCashDispositionRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OwnerCashDispositionRequest value)  $default,){
final _that = this;
switch (_that) {
case _OwnerCashDispositionRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OwnerCashDispositionRequest value)?  $default,){
final _that = this;
switch (_that) {
case _OwnerCashDispositionRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'settlement_id')  String settlementId, @JsonKey(name: 'owner_profile_id')  String ownerProfileId, @JsonKey(name: 'disposition_type')  String dispositionType, @JsonKey(fromJson: amountFromJson, toJson: amountToJson)  double amount, @JsonKey(name: 'used_amount', fromJson: amountFromJson, toJson: amountToJson)  double usedAmount,  String status,  String? iban, @JsonKey(name: 'pickup_date')@NullableIsoDateTimeConverter()  DateTime? pickupDate, @JsonKey(name: 'admin_notes')  String? adminNotes, @JsonKey(name: 'created_at')@IsoDateTimeConverter()  DateTime createdAt, @JsonKey(name: 'updated_at')@IsoDateTimeConverter()  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OwnerCashDispositionRequest() when $default != null:
return $default(_that.id,_that.tenantId,_that.settlementId,_that.ownerProfileId,_that.dispositionType,_that.amount,_that.usedAmount,_that.status,_that.iban,_that.pickupDate,_that.adminNotes,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'settlement_id')  String settlementId, @JsonKey(name: 'owner_profile_id')  String ownerProfileId, @JsonKey(name: 'disposition_type')  String dispositionType, @JsonKey(fromJson: amountFromJson, toJson: amountToJson)  double amount, @JsonKey(name: 'used_amount', fromJson: amountFromJson, toJson: amountToJson)  double usedAmount,  String status,  String? iban, @JsonKey(name: 'pickup_date')@NullableIsoDateTimeConverter()  DateTime? pickupDate, @JsonKey(name: 'admin_notes')  String? adminNotes, @JsonKey(name: 'created_at')@IsoDateTimeConverter()  DateTime createdAt, @JsonKey(name: 'updated_at')@IsoDateTimeConverter()  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _OwnerCashDispositionRequest():
return $default(_that.id,_that.tenantId,_that.settlementId,_that.ownerProfileId,_that.dispositionType,_that.amount,_that.usedAmount,_that.status,_that.iban,_that.pickupDate,_that.adminNotes,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'settlement_id')  String settlementId, @JsonKey(name: 'owner_profile_id')  String ownerProfileId, @JsonKey(name: 'disposition_type')  String dispositionType, @JsonKey(fromJson: amountFromJson, toJson: amountToJson)  double amount, @JsonKey(name: 'used_amount', fromJson: amountFromJson, toJson: amountToJson)  double usedAmount,  String status,  String? iban, @JsonKey(name: 'pickup_date')@NullableIsoDateTimeConverter()  DateTime? pickupDate, @JsonKey(name: 'admin_notes')  String? adminNotes, @JsonKey(name: 'created_at')@IsoDateTimeConverter()  DateTime createdAt, @JsonKey(name: 'updated_at')@IsoDateTimeConverter()  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _OwnerCashDispositionRequest() when $default != null:
return $default(_that.id,_that.tenantId,_that.settlementId,_that.ownerProfileId,_that.dispositionType,_that.amount,_that.usedAmount,_that.status,_that.iban,_that.pickupDate,_that.adminNotes,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OwnerCashDispositionRequest extends OwnerCashDispositionRequest {
  const _OwnerCashDispositionRequest({required this.id, @JsonKey(name: 'tenant_id') required this.tenantId, @JsonKey(name: 'settlement_id') required this.settlementId, @JsonKey(name: 'owner_profile_id') required this.ownerProfileId, @JsonKey(name: 'disposition_type') required this.dispositionType, @JsonKey(fromJson: amountFromJson, toJson: amountToJson) required this.amount, @JsonKey(name: 'used_amount', fromJson: amountFromJson, toJson: amountToJson) this.usedAmount = 0.0, required this.status, this.iban, @JsonKey(name: 'pickup_date')@NullableIsoDateTimeConverter() this.pickupDate, @JsonKey(name: 'admin_notes') this.adminNotes, @JsonKey(name: 'created_at')@IsoDateTimeConverter() required this.createdAt, @JsonKey(name: 'updated_at')@IsoDateTimeConverter() required this.updatedAt}): super._();
  factory _OwnerCashDispositionRequest.fromJson(Map<String, dynamic> json) => _$OwnerCashDispositionRequestFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override@JsonKey(name: 'settlement_id') final  String settlementId;
@override@JsonKey(name: 'owner_profile_id') final  String ownerProfileId;
/// `bank_transfer` | `invoice_credit` | `vault_pickup`
@override@JsonKey(name: 'disposition_type') final  String dispositionType;
@override@JsonKey(fromJson: amountFromJson, toJson: amountToJson) final  double amount;
/// Již uplatněná část žádosti (umoření atd., migrace `20260410010000`).
@override@JsonKey(name: 'used_amount', fromJson: amountFromJson, toJson: amountToJson) final  double usedAmount;
/// `pending` | `approved` | `rejected` | `completed` | `partially_completed` | `ready_for_pickup`
@override final  String status;
/// IBAN / číslo účtu u `bank_transfer` (volitelné, migrace `20260410000000`).
@override final  String? iban;
/// Plánované vyzvednutí u `vault_pickup` (migrace `20260410020000`).
@override@JsonKey(name: 'pickup_date')@NullableIsoDateTimeConverter() final  DateTime? pickupDate;
@override@JsonKey(name: 'admin_notes') final  String? adminNotes;
@override@JsonKey(name: 'created_at')@IsoDateTimeConverter() final  DateTime createdAt;
@override@JsonKey(name: 'updated_at')@IsoDateTimeConverter() final  DateTime updatedAt;

/// Create a copy of OwnerCashDispositionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OwnerCashDispositionRequestCopyWith<_OwnerCashDispositionRequest> get copyWith => __$OwnerCashDispositionRequestCopyWithImpl<_OwnerCashDispositionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OwnerCashDispositionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OwnerCashDispositionRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.settlementId, settlementId) || other.settlementId == settlementId)&&(identical(other.ownerProfileId, ownerProfileId) || other.ownerProfileId == ownerProfileId)&&(identical(other.dispositionType, dispositionType) || other.dispositionType == dispositionType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.usedAmount, usedAmount) || other.usedAmount == usedAmount)&&(identical(other.status, status) || other.status == status)&&(identical(other.iban, iban) || other.iban == iban)&&(identical(other.pickupDate, pickupDate) || other.pickupDate == pickupDate)&&(identical(other.adminNotes, adminNotes) || other.adminNotes == adminNotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,settlementId,ownerProfileId,dispositionType,amount,usedAmount,status,iban,pickupDate,adminNotes,createdAt,updatedAt);

@override
String toString() {
  return 'OwnerCashDispositionRequest(id: $id, tenantId: $tenantId, settlementId: $settlementId, ownerProfileId: $ownerProfileId, dispositionType: $dispositionType, amount: $amount, usedAmount: $usedAmount, status: $status, iban: $iban, pickupDate: $pickupDate, adminNotes: $adminNotes, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$OwnerCashDispositionRequestCopyWith<$Res> implements $OwnerCashDispositionRequestCopyWith<$Res> {
  factory _$OwnerCashDispositionRequestCopyWith(_OwnerCashDispositionRequest value, $Res Function(_OwnerCashDispositionRequest) _then) = __$OwnerCashDispositionRequestCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'settlement_id') String settlementId,@JsonKey(name: 'owner_profile_id') String ownerProfileId,@JsonKey(name: 'disposition_type') String dispositionType,@JsonKey(fromJson: amountFromJson, toJson: amountToJson) double amount,@JsonKey(name: 'used_amount', fromJson: amountFromJson, toJson: amountToJson) double usedAmount, String status, String? iban,@JsonKey(name: 'pickup_date')@NullableIsoDateTimeConverter() DateTime? pickupDate,@JsonKey(name: 'admin_notes') String? adminNotes,@JsonKey(name: 'created_at')@IsoDateTimeConverter() DateTime createdAt,@JsonKey(name: 'updated_at')@IsoDateTimeConverter() DateTime updatedAt
});




}
/// @nodoc
class __$OwnerCashDispositionRequestCopyWithImpl<$Res>
    implements _$OwnerCashDispositionRequestCopyWith<$Res> {
  __$OwnerCashDispositionRequestCopyWithImpl(this._self, this._then);

  final _OwnerCashDispositionRequest _self;
  final $Res Function(_OwnerCashDispositionRequest) _then;

/// Create a copy of OwnerCashDispositionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? settlementId = null,Object? ownerProfileId = null,Object? dispositionType = null,Object? amount = null,Object? usedAmount = null,Object? status = null,Object? iban = freezed,Object? pickupDate = freezed,Object? adminNotes = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_OwnerCashDispositionRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,settlementId: null == settlementId ? _self.settlementId : settlementId // ignore: cast_nullable_to_non_nullable
as String,ownerProfileId: null == ownerProfileId ? _self.ownerProfileId : ownerProfileId // ignore: cast_nullable_to_non_nullable
as String,dispositionType: null == dispositionType ? _self.dispositionType : dispositionType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,usedAmount: null == usedAmount ? _self.usedAmount : usedAmount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,iban: freezed == iban ? _self.iban : iban // ignore: cast_nullable_to_non_nullable
as String?,pickupDate: freezed == pickupDate ? _self.pickupDate : pickupDate // ignore: cast_nullable_to_non_nullable
as DateTime?,adminNotes: freezed == adminNotes ? _self.adminNotes : adminNotes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
