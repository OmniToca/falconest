// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'apartment_investment_pnl_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApartmentInvestmentPnlEntry {

 String get id;@JsonKey(name: 'apartment_id') String get apartmentId;/// První den měsíce (Postgres `date`).
@JsonKey(name: 'entry_month')@IsoDateOnlyConverter() DateTime get entryMonth;/// `income` nebo `expense`.
@JsonKey(name: 'entry_type') String get entryType;@JsonKey(fromJson: modelAmountFromJson, toJson: modelAmountToJson) double get amount; String? get description;@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? get createdAt;@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? get updatedAt;
/// Create a copy of ApartmentInvestmentPnlEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApartmentInvestmentPnlEntryCopyWith<ApartmentInvestmentPnlEntry> get copyWith => _$ApartmentInvestmentPnlEntryCopyWithImpl<ApartmentInvestmentPnlEntry>(this as ApartmentInvestmentPnlEntry, _$identity);

  /// Serializes this ApartmentInvestmentPnlEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApartmentInvestmentPnlEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.apartmentId, apartmentId) || other.apartmentId == apartmentId)&&(identical(other.entryMonth, entryMonth) || other.entryMonth == entryMonth)&&(identical(other.entryType, entryType) || other.entryType == entryType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,apartmentId,entryMonth,entryType,amount,description,createdAt,updatedAt);

@override
String toString() {
  return 'ApartmentInvestmentPnlEntry(id: $id, apartmentId: $apartmentId, entryMonth: $entryMonth, entryType: $entryType, amount: $amount, description: $description, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ApartmentInvestmentPnlEntryCopyWith<$Res>  {
  factory $ApartmentInvestmentPnlEntryCopyWith(ApartmentInvestmentPnlEntry value, $Res Function(ApartmentInvestmentPnlEntry) _then) = _$ApartmentInvestmentPnlEntryCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'apartment_id') String apartmentId,@JsonKey(name: 'entry_month')@IsoDateOnlyConverter() DateTime entryMonth,@JsonKey(name: 'entry_type') String entryType,@JsonKey(fromJson: modelAmountFromJson, toJson: modelAmountToJson) double amount, String? description,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt
});




}
/// @nodoc
class _$ApartmentInvestmentPnlEntryCopyWithImpl<$Res>
    implements $ApartmentInvestmentPnlEntryCopyWith<$Res> {
  _$ApartmentInvestmentPnlEntryCopyWithImpl(this._self, this._then);

  final ApartmentInvestmentPnlEntry _self;
  final $Res Function(ApartmentInvestmentPnlEntry) _then;

/// Create a copy of ApartmentInvestmentPnlEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? apartmentId = null,Object? entryMonth = null,Object? entryType = null,Object? amount = null,Object? description = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,apartmentId: null == apartmentId ? _self.apartmentId : apartmentId // ignore: cast_nullable_to_non_nullable
as String,entryMonth: null == entryMonth ? _self.entryMonth : entryMonth // ignore: cast_nullable_to_non_nullable
as DateTime,entryType: null == entryType ? _self.entryType : entryType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ApartmentInvestmentPnlEntry].
extension ApartmentInvestmentPnlEntryPatterns on ApartmentInvestmentPnlEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApartmentInvestmentPnlEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApartmentInvestmentPnlEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApartmentInvestmentPnlEntry value)  $default,){
final _that = this;
switch (_that) {
case _ApartmentInvestmentPnlEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApartmentInvestmentPnlEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ApartmentInvestmentPnlEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'apartment_id')  String apartmentId, @JsonKey(name: 'entry_month')@IsoDateOnlyConverter()  DateTime entryMonth, @JsonKey(name: 'entry_type')  String entryType, @JsonKey(fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double amount,  String? description, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApartmentInvestmentPnlEntry() when $default != null:
return $default(_that.id,_that.apartmentId,_that.entryMonth,_that.entryType,_that.amount,_that.description,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'apartment_id')  String apartmentId, @JsonKey(name: 'entry_month')@IsoDateOnlyConverter()  DateTime entryMonth, @JsonKey(name: 'entry_type')  String entryType, @JsonKey(fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double amount,  String? description, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ApartmentInvestmentPnlEntry():
return $default(_that.id,_that.apartmentId,_that.entryMonth,_that.entryType,_that.amount,_that.description,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'apartment_id')  String apartmentId, @JsonKey(name: 'entry_month')@IsoDateOnlyConverter()  DateTime entryMonth, @JsonKey(name: 'entry_type')  String entryType, @JsonKey(fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double amount,  String? description, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ApartmentInvestmentPnlEntry() when $default != null:
return $default(_that.id,_that.apartmentId,_that.entryMonth,_that.entryType,_that.amount,_that.description,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApartmentInvestmentPnlEntry extends ApartmentInvestmentPnlEntry {
  const _ApartmentInvestmentPnlEntry({required this.id, @JsonKey(name: 'apartment_id') required this.apartmentId, @JsonKey(name: 'entry_month')@IsoDateOnlyConverter() required this.entryMonth, @JsonKey(name: 'entry_type') required this.entryType, @JsonKey(fromJson: modelAmountFromJson, toJson: modelAmountToJson) this.amount = 0.0, this.description, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() this.createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() this.updatedAt}): super._();
  factory _ApartmentInvestmentPnlEntry.fromJson(Map<String, dynamic> json) => _$ApartmentInvestmentPnlEntryFromJson(json);

@override final  String id;
@override@JsonKey(name: 'apartment_id') final  String apartmentId;
/// První den měsíce (Postgres `date`).
@override@JsonKey(name: 'entry_month')@IsoDateOnlyConverter() final  DateTime entryMonth;
/// `income` nebo `expense`.
@override@JsonKey(name: 'entry_type') final  String entryType;
@override@JsonKey(fromJson: modelAmountFromJson, toJson: modelAmountToJson) final  double amount;
@override final  String? description;
@override@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() final  DateTime? updatedAt;

/// Create a copy of ApartmentInvestmentPnlEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApartmentInvestmentPnlEntryCopyWith<_ApartmentInvestmentPnlEntry> get copyWith => __$ApartmentInvestmentPnlEntryCopyWithImpl<_ApartmentInvestmentPnlEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApartmentInvestmentPnlEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApartmentInvestmentPnlEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.apartmentId, apartmentId) || other.apartmentId == apartmentId)&&(identical(other.entryMonth, entryMonth) || other.entryMonth == entryMonth)&&(identical(other.entryType, entryType) || other.entryType == entryType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,apartmentId,entryMonth,entryType,amount,description,createdAt,updatedAt);

@override
String toString() {
  return 'ApartmentInvestmentPnlEntry(id: $id, apartmentId: $apartmentId, entryMonth: $entryMonth, entryType: $entryType, amount: $amount, description: $description, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ApartmentInvestmentPnlEntryCopyWith<$Res> implements $ApartmentInvestmentPnlEntryCopyWith<$Res> {
  factory _$ApartmentInvestmentPnlEntryCopyWith(_ApartmentInvestmentPnlEntry value, $Res Function(_ApartmentInvestmentPnlEntry) _then) = __$ApartmentInvestmentPnlEntryCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'apartment_id') String apartmentId,@JsonKey(name: 'entry_month')@IsoDateOnlyConverter() DateTime entryMonth,@JsonKey(name: 'entry_type') String entryType,@JsonKey(fromJson: modelAmountFromJson, toJson: modelAmountToJson) double amount, String? description,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt
});




}
/// @nodoc
class __$ApartmentInvestmentPnlEntryCopyWithImpl<$Res>
    implements _$ApartmentInvestmentPnlEntryCopyWith<$Res> {
  __$ApartmentInvestmentPnlEntryCopyWithImpl(this._self, this._then);

  final _ApartmentInvestmentPnlEntry _self;
  final $Res Function(_ApartmentInvestmentPnlEntry) _then;

/// Create a copy of ApartmentInvestmentPnlEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? apartmentId = null,Object? entryMonth = null,Object? entryType = null,Object? amount = null,Object? description = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_ApartmentInvestmentPnlEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,apartmentId: null == apartmentId ? _self.apartmentId : apartmentId // ignore: cast_nullable_to_non_nullable
as String,entryMonth: null == entryMonth ? _self.entryMonth : entryMonth // ignore: cast_nullable_to_non_nullable
as DateTime,entryType: null == entryType ? _self.entryType : entryType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
