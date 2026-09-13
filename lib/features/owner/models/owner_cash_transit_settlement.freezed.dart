// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'owner_cash_transit_settlement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OwnerCashTransitSettlement {

 String get id;@JsonKey(name: 'tenant_id') String get tenantId;@JsonKey(name: 'reservation_id') String? get reservationId;@JsonKey(name: 'apartment_id') String? get apartmentId;@JsonKey(name: 'task_id') String? get taskId;@JsonKey(fromJson: amountFromJson, toJson: amountToJson) double get amount; String get currency;@JsonKey(name: 'settled_at')@NullableIsoDateTimeConverter() DateTime? get settledAt;@JsonKey(name: 'settled_by') String? get settledBy;/// V rozšířené DB může být CHECK; jinak výchozí `available` (majitel nefiltruje podle DB sloupce).
 String get status;@JsonKey(name: 'employee_cash_transaction_id') String? get employeeCashTransactionId;@JsonKey(name: 'note') String? get notes;@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? get createdAt;@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? get updatedAt;/// Začátek pobytu z `reservations.start_date` – doplní repozitář při výpisu pro majitele; není v JSON odpovědi settlements.
@JsonKey(includeFromJson: false, includeToJson: false) DateTime? get reservationStayStart;/// Konec pobytu z `reservations.end_date` (viz [reservationStayStart]).
@JsonKey(includeFromJson: false, includeToJson: false) DateTime? get reservationStayEnd;/// Jméno hosta z `reservations.guest_name` – doplní repozitář pro dropdown dispozice.
@JsonKey(includeFromJson: false, includeToJson: false) String? get guestName;/// Reálně dostupná částka pro novou žádost (po odečtení rezervací z `owner_cash_disposition_requests`).
@JsonKey(includeFromJson: false, includeToJson: false) double? get availableAmount;
/// Create a copy of OwnerCashTransitSettlement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OwnerCashTransitSettlementCopyWith<OwnerCashTransitSettlement> get copyWith => _$OwnerCashTransitSettlementCopyWithImpl<OwnerCashTransitSettlement>(this as OwnerCashTransitSettlement, _$identity);

  /// Serializes this OwnerCashTransitSettlement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OwnerCashTransitSettlement&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.reservationId, reservationId) || other.reservationId == reservationId)&&(identical(other.apartmentId, apartmentId) || other.apartmentId == apartmentId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.settledAt, settledAt) || other.settledAt == settledAt)&&(identical(other.settledBy, settledBy) || other.settledBy == settledBy)&&(identical(other.status, status) || other.status == status)&&(identical(other.employeeCashTransactionId, employeeCashTransactionId) || other.employeeCashTransactionId == employeeCashTransactionId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.reservationStayStart, reservationStayStart) || other.reservationStayStart == reservationStayStart)&&(identical(other.reservationStayEnd, reservationStayEnd) || other.reservationStayEnd == reservationStayEnd)&&(identical(other.guestName, guestName) || other.guestName == guestName)&&(identical(other.availableAmount, availableAmount) || other.availableAmount == availableAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,reservationId,apartmentId,taskId,amount,currency,settledAt,settledBy,status,employeeCashTransactionId,notes,createdAt,updatedAt,reservationStayStart,reservationStayEnd,guestName,availableAmount);

@override
String toString() {
  return 'OwnerCashTransitSettlement(id: $id, tenantId: $tenantId, reservationId: $reservationId, apartmentId: $apartmentId, taskId: $taskId, amount: $amount, currency: $currency, settledAt: $settledAt, settledBy: $settledBy, status: $status, employeeCashTransactionId: $employeeCashTransactionId, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt, reservationStayStart: $reservationStayStart, reservationStayEnd: $reservationStayEnd, guestName: $guestName, availableAmount: $availableAmount)';
}


}

/// @nodoc
abstract mixin class $OwnerCashTransitSettlementCopyWith<$Res>  {
  factory $OwnerCashTransitSettlementCopyWith(OwnerCashTransitSettlement value, $Res Function(OwnerCashTransitSettlement) _then) = _$OwnerCashTransitSettlementCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'reservation_id') String? reservationId,@JsonKey(name: 'apartment_id') String? apartmentId,@JsonKey(name: 'task_id') String? taskId,@JsonKey(fromJson: amountFromJson, toJson: amountToJson) double amount, String currency,@JsonKey(name: 'settled_at')@NullableIsoDateTimeConverter() DateTime? settledAt,@JsonKey(name: 'settled_by') String? settledBy, String status,@JsonKey(name: 'employee_cash_transaction_id') String? employeeCashTransactionId,@JsonKey(name: 'note') String? notes,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt,@JsonKey(includeFromJson: false, includeToJson: false) DateTime? reservationStayStart,@JsonKey(includeFromJson: false, includeToJson: false) DateTime? reservationStayEnd,@JsonKey(includeFromJson: false, includeToJson: false) String? guestName,@JsonKey(includeFromJson: false, includeToJson: false) double? availableAmount
});




}
/// @nodoc
class _$OwnerCashTransitSettlementCopyWithImpl<$Res>
    implements $OwnerCashTransitSettlementCopyWith<$Res> {
  _$OwnerCashTransitSettlementCopyWithImpl(this._self, this._then);

  final OwnerCashTransitSettlement _self;
  final $Res Function(OwnerCashTransitSettlement) _then;

/// Create a copy of OwnerCashTransitSettlement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? reservationId = freezed,Object? apartmentId = freezed,Object? taskId = freezed,Object? amount = null,Object? currency = null,Object? settledAt = freezed,Object? settledBy = freezed,Object? status = null,Object? employeeCashTransactionId = freezed,Object? notes = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? reservationStayStart = freezed,Object? reservationStayEnd = freezed,Object? guestName = freezed,Object? availableAmount = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,reservationId: freezed == reservationId ? _self.reservationId : reservationId // ignore: cast_nullable_to_non_nullable
as String?,apartmentId: freezed == apartmentId ? _self.apartmentId : apartmentId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,settledAt: freezed == settledAt ? _self.settledAt : settledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,settledBy: freezed == settledBy ? _self.settledBy : settledBy // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,employeeCashTransactionId: freezed == employeeCashTransactionId ? _self.employeeCashTransactionId : employeeCashTransactionId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reservationStayStart: freezed == reservationStayStart ? _self.reservationStayStart : reservationStayStart // ignore: cast_nullable_to_non_nullable
as DateTime?,reservationStayEnd: freezed == reservationStayEnd ? _self.reservationStayEnd : reservationStayEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,guestName: freezed == guestName ? _self.guestName : guestName // ignore: cast_nullable_to_non_nullable
as String?,availableAmount: freezed == availableAmount ? _self.availableAmount : availableAmount // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [OwnerCashTransitSettlement].
extension OwnerCashTransitSettlementPatterns on OwnerCashTransitSettlement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OwnerCashTransitSettlement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OwnerCashTransitSettlement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OwnerCashTransitSettlement value)  $default,){
final _that = this;
switch (_that) {
case _OwnerCashTransitSettlement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OwnerCashTransitSettlement value)?  $default,){
final _that = this;
switch (_that) {
case _OwnerCashTransitSettlement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'reservation_id')  String? reservationId, @JsonKey(name: 'apartment_id')  String? apartmentId, @JsonKey(name: 'task_id')  String? taskId, @JsonKey(fromJson: amountFromJson, toJson: amountToJson)  double amount,  String currency, @JsonKey(name: 'settled_at')@NullableIsoDateTimeConverter()  DateTime? settledAt, @JsonKey(name: 'settled_by')  String? settledBy,  String status, @JsonKey(name: 'employee_cash_transaction_id')  String? employeeCashTransactionId, @JsonKey(name: 'note')  String? notes, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt, @JsonKey(includeFromJson: false, includeToJson: false)  DateTime? reservationStayStart, @JsonKey(includeFromJson: false, includeToJson: false)  DateTime? reservationStayEnd, @JsonKey(includeFromJson: false, includeToJson: false)  String? guestName, @JsonKey(includeFromJson: false, includeToJson: false)  double? availableAmount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OwnerCashTransitSettlement() when $default != null:
return $default(_that.id,_that.tenantId,_that.reservationId,_that.apartmentId,_that.taskId,_that.amount,_that.currency,_that.settledAt,_that.settledBy,_that.status,_that.employeeCashTransactionId,_that.notes,_that.createdAt,_that.updatedAt,_that.reservationStayStart,_that.reservationStayEnd,_that.guestName,_that.availableAmount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'reservation_id')  String? reservationId, @JsonKey(name: 'apartment_id')  String? apartmentId, @JsonKey(name: 'task_id')  String? taskId, @JsonKey(fromJson: amountFromJson, toJson: amountToJson)  double amount,  String currency, @JsonKey(name: 'settled_at')@NullableIsoDateTimeConverter()  DateTime? settledAt, @JsonKey(name: 'settled_by')  String? settledBy,  String status, @JsonKey(name: 'employee_cash_transaction_id')  String? employeeCashTransactionId, @JsonKey(name: 'note')  String? notes, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt, @JsonKey(includeFromJson: false, includeToJson: false)  DateTime? reservationStayStart, @JsonKey(includeFromJson: false, includeToJson: false)  DateTime? reservationStayEnd, @JsonKey(includeFromJson: false, includeToJson: false)  String? guestName, @JsonKey(includeFromJson: false, includeToJson: false)  double? availableAmount)  $default,) {final _that = this;
switch (_that) {
case _OwnerCashTransitSettlement():
return $default(_that.id,_that.tenantId,_that.reservationId,_that.apartmentId,_that.taskId,_that.amount,_that.currency,_that.settledAt,_that.settledBy,_that.status,_that.employeeCashTransactionId,_that.notes,_that.createdAt,_that.updatedAt,_that.reservationStayStart,_that.reservationStayEnd,_that.guestName,_that.availableAmount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'reservation_id')  String? reservationId, @JsonKey(name: 'apartment_id')  String? apartmentId, @JsonKey(name: 'task_id')  String? taskId, @JsonKey(fromJson: amountFromJson, toJson: amountToJson)  double amount,  String currency, @JsonKey(name: 'settled_at')@NullableIsoDateTimeConverter()  DateTime? settledAt, @JsonKey(name: 'settled_by')  String? settledBy,  String status, @JsonKey(name: 'employee_cash_transaction_id')  String? employeeCashTransactionId, @JsonKey(name: 'note')  String? notes, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt, @JsonKey(includeFromJson: false, includeToJson: false)  DateTime? reservationStayStart, @JsonKey(includeFromJson: false, includeToJson: false)  DateTime? reservationStayEnd, @JsonKey(includeFromJson: false, includeToJson: false)  String? guestName, @JsonKey(includeFromJson: false, includeToJson: false)  double? availableAmount)?  $default,) {final _that = this;
switch (_that) {
case _OwnerCashTransitSettlement() when $default != null:
return $default(_that.id,_that.tenantId,_that.reservationId,_that.apartmentId,_that.taskId,_that.amount,_that.currency,_that.settledAt,_that.settledBy,_that.status,_that.employeeCashTransactionId,_that.notes,_that.createdAt,_that.updatedAt,_that.reservationStayStart,_that.reservationStayEnd,_that.guestName,_that.availableAmount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OwnerCashTransitSettlement extends OwnerCashTransitSettlement {
  const _OwnerCashTransitSettlement({required this.id, @JsonKey(name: 'tenant_id') required this.tenantId, @JsonKey(name: 'reservation_id') this.reservationId, @JsonKey(name: 'apartment_id') this.apartmentId, @JsonKey(name: 'task_id') this.taskId, @JsonKey(fromJson: amountFromJson, toJson: amountToJson) required this.amount, this.currency = 'EUR', @JsonKey(name: 'settled_at')@NullableIsoDateTimeConverter() this.settledAt, @JsonKey(name: 'settled_by') this.settledBy, this.status = 'available', @JsonKey(name: 'employee_cash_transaction_id') this.employeeCashTransactionId, @JsonKey(name: 'note') this.notes, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() this.createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() this.updatedAt, @JsonKey(includeFromJson: false, includeToJson: false) this.reservationStayStart, @JsonKey(includeFromJson: false, includeToJson: false) this.reservationStayEnd, @JsonKey(includeFromJson: false, includeToJson: false) this.guestName, @JsonKey(includeFromJson: false, includeToJson: false) this.availableAmount}): super._();
  factory _OwnerCashTransitSettlement.fromJson(Map<String, dynamic> json) => _$OwnerCashTransitSettlementFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override@JsonKey(name: 'reservation_id') final  String? reservationId;
@override@JsonKey(name: 'apartment_id') final  String? apartmentId;
@override@JsonKey(name: 'task_id') final  String? taskId;
@override@JsonKey(fromJson: amountFromJson, toJson: amountToJson) final  double amount;
@override@JsonKey() final  String currency;
@override@JsonKey(name: 'settled_at')@NullableIsoDateTimeConverter() final  DateTime? settledAt;
@override@JsonKey(name: 'settled_by') final  String? settledBy;
/// V rozšířené DB může být CHECK; jinak výchozí `available` (majitel nefiltruje podle DB sloupce).
@override@JsonKey() final  String status;
@override@JsonKey(name: 'employee_cash_transaction_id') final  String? employeeCashTransactionId;
@override@JsonKey(name: 'note') final  String? notes;
@override@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() final  DateTime? updatedAt;
/// Začátek pobytu z `reservations.start_date` – doplní repozitář při výpisu pro majitele; není v JSON odpovědi settlements.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  DateTime? reservationStayStart;
/// Konec pobytu z `reservations.end_date` (viz [reservationStayStart]).
@override@JsonKey(includeFromJson: false, includeToJson: false) final  DateTime? reservationStayEnd;
/// Jméno hosta z `reservations.guest_name` – doplní repozitář pro dropdown dispozice.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? guestName;
/// Reálně dostupná částka pro novou žádost (po odečtení rezervací z `owner_cash_disposition_requests`).
@override@JsonKey(includeFromJson: false, includeToJson: false) final  double? availableAmount;

/// Create a copy of OwnerCashTransitSettlement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OwnerCashTransitSettlementCopyWith<_OwnerCashTransitSettlement> get copyWith => __$OwnerCashTransitSettlementCopyWithImpl<_OwnerCashTransitSettlement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OwnerCashTransitSettlementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OwnerCashTransitSettlement&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.reservationId, reservationId) || other.reservationId == reservationId)&&(identical(other.apartmentId, apartmentId) || other.apartmentId == apartmentId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.settledAt, settledAt) || other.settledAt == settledAt)&&(identical(other.settledBy, settledBy) || other.settledBy == settledBy)&&(identical(other.status, status) || other.status == status)&&(identical(other.employeeCashTransactionId, employeeCashTransactionId) || other.employeeCashTransactionId == employeeCashTransactionId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.reservationStayStart, reservationStayStart) || other.reservationStayStart == reservationStayStart)&&(identical(other.reservationStayEnd, reservationStayEnd) || other.reservationStayEnd == reservationStayEnd)&&(identical(other.guestName, guestName) || other.guestName == guestName)&&(identical(other.availableAmount, availableAmount) || other.availableAmount == availableAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,reservationId,apartmentId,taskId,amount,currency,settledAt,settledBy,status,employeeCashTransactionId,notes,createdAt,updatedAt,reservationStayStart,reservationStayEnd,guestName,availableAmount);

@override
String toString() {
  return 'OwnerCashTransitSettlement(id: $id, tenantId: $tenantId, reservationId: $reservationId, apartmentId: $apartmentId, taskId: $taskId, amount: $amount, currency: $currency, settledAt: $settledAt, settledBy: $settledBy, status: $status, employeeCashTransactionId: $employeeCashTransactionId, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt, reservationStayStart: $reservationStayStart, reservationStayEnd: $reservationStayEnd, guestName: $guestName, availableAmount: $availableAmount)';
}


}

/// @nodoc
abstract mixin class _$OwnerCashTransitSettlementCopyWith<$Res> implements $OwnerCashTransitSettlementCopyWith<$Res> {
  factory _$OwnerCashTransitSettlementCopyWith(_OwnerCashTransitSettlement value, $Res Function(_OwnerCashTransitSettlement) _then) = __$OwnerCashTransitSettlementCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'reservation_id') String? reservationId,@JsonKey(name: 'apartment_id') String? apartmentId,@JsonKey(name: 'task_id') String? taskId,@JsonKey(fromJson: amountFromJson, toJson: amountToJson) double amount, String currency,@JsonKey(name: 'settled_at')@NullableIsoDateTimeConverter() DateTime? settledAt,@JsonKey(name: 'settled_by') String? settledBy, String status,@JsonKey(name: 'employee_cash_transaction_id') String? employeeCashTransactionId,@JsonKey(name: 'note') String? notes,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt,@JsonKey(includeFromJson: false, includeToJson: false) DateTime? reservationStayStart,@JsonKey(includeFromJson: false, includeToJson: false) DateTime? reservationStayEnd,@JsonKey(includeFromJson: false, includeToJson: false) String? guestName,@JsonKey(includeFromJson: false, includeToJson: false) double? availableAmount
});




}
/// @nodoc
class __$OwnerCashTransitSettlementCopyWithImpl<$Res>
    implements _$OwnerCashTransitSettlementCopyWith<$Res> {
  __$OwnerCashTransitSettlementCopyWithImpl(this._self, this._then);

  final _OwnerCashTransitSettlement _self;
  final $Res Function(_OwnerCashTransitSettlement) _then;

/// Create a copy of OwnerCashTransitSettlement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? reservationId = freezed,Object? apartmentId = freezed,Object? taskId = freezed,Object? amount = null,Object? currency = null,Object? settledAt = freezed,Object? settledBy = freezed,Object? status = null,Object? employeeCashTransactionId = freezed,Object? notes = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? reservationStayStart = freezed,Object? reservationStayEnd = freezed,Object? guestName = freezed,Object? availableAmount = freezed,}) {
  return _then(_OwnerCashTransitSettlement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,reservationId: freezed == reservationId ? _self.reservationId : reservationId // ignore: cast_nullable_to_non_nullable
as String?,apartmentId: freezed == apartmentId ? _self.apartmentId : apartmentId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,settledAt: freezed == settledAt ? _self.settledAt : settledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,settledBy: freezed == settledBy ? _self.settledBy : settledBy // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,employeeCashTransactionId: freezed == employeeCashTransactionId ? _self.employeeCashTransactionId : employeeCashTransactionId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reservationStayStart: freezed == reservationStayStart ? _self.reservationStayStart : reservationStayStart // ignore: cast_nullable_to_non_nullable
as DateTime?,reservationStayEnd: freezed == reservationStayEnd ? _self.reservationStayEnd : reservationStayEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,guestName: freezed == guestName ? _self.guestName : guestName // ignore: cast_nullable_to_non_nullable
as String?,availableAmount: freezed == availableAmount ? _self.availableAmount : availableAmount // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
