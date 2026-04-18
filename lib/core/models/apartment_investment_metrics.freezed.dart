// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'apartment_investment_metrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApartmentInvestmentMetrics {

@JsonKey(name: 'apartment_id') String get apartmentId;@JsonKey(name: 'purchase_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double get purchasePrice;@JsonKey(name: 'initial_renovation_cost', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double get initialRenovationCost;@JsonKey(name: 'estimated_market_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double get estimatedMarketPrice;@JsonKey(name: 'market_price_updated_at')@NullableIsoDateTimeConverter() DateTime? get marketPriceUpdatedAt;@JsonKey(name: 'updated_at')@IsoDateTimeConverter() DateTime get updatedAt;
/// Create a copy of ApartmentInvestmentMetrics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApartmentInvestmentMetricsCopyWith<ApartmentInvestmentMetrics> get copyWith => _$ApartmentInvestmentMetricsCopyWithImpl<ApartmentInvestmentMetrics>(this as ApartmentInvestmentMetrics, _$identity);

  /// Serializes this ApartmentInvestmentMetrics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApartmentInvestmentMetrics&&(identical(other.apartmentId, apartmentId) || other.apartmentId == apartmentId)&&(identical(other.purchasePrice, purchasePrice) || other.purchasePrice == purchasePrice)&&(identical(other.initialRenovationCost, initialRenovationCost) || other.initialRenovationCost == initialRenovationCost)&&(identical(other.estimatedMarketPrice, estimatedMarketPrice) || other.estimatedMarketPrice == estimatedMarketPrice)&&(identical(other.marketPriceUpdatedAt, marketPriceUpdatedAt) || other.marketPriceUpdatedAt == marketPriceUpdatedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apartmentId,purchasePrice,initialRenovationCost,estimatedMarketPrice,marketPriceUpdatedAt,updatedAt);

@override
String toString() {
  return 'ApartmentInvestmentMetrics(apartmentId: $apartmentId, purchasePrice: $purchasePrice, initialRenovationCost: $initialRenovationCost, estimatedMarketPrice: $estimatedMarketPrice, marketPriceUpdatedAt: $marketPriceUpdatedAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ApartmentInvestmentMetricsCopyWith<$Res>  {
  factory $ApartmentInvestmentMetricsCopyWith(ApartmentInvestmentMetrics value, $Res Function(ApartmentInvestmentMetrics) _then) = _$ApartmentInvestmentMetricsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'apartment_id') String apartmentId,@JsonKey(name: 'purchase_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double purchasePrice,@JsonKey(name: 'initial_renovation_cost', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double initialRenovationCost,@JsonKey(name: 'estimated_market_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double estimatedMarketPrice,@JsonKey(name: 'market_price_updated_at')@NullableIsoDateTimeConverter() DateTime? marketPriceUpdatedAt,@JsonKey(name: 'updated_at')@IsoDateTimeConverter() DateTime updatedAt
});




}
/// @nodoc
class _$ApartmentInvestmentMetricsCopyWithImpl<$Res>
    implements $ApartmentInvestmentMetricsCopyWith<$Res> {
  _$ApartmentInvestmentMetricsCopyWithImpl(this._self, this._then);

  final ApartmentInvestmentMetrics _self;
  final $Res Function(ApartmentInvestmentMetrics) _then;

/// Create a copy of ApartmentInvestmentMetrics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apartmentId = null,Object? purchasePrice = null,Object? initialRenovationCost = null,Object? estimatedMarketPrice = null,Object? marketPriceUpdatedAt = freezed,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
apartmentId: null == apartmentId ? _self.apartmentId : apartmentId // ignore: cast_nullable_to_non_nullable
as String,purchasePrice: null == purchasePrice ? _self.purchasePrice : purchasePrice // ignore: cast_nullable_to_non_nullable
as double,initialRenovationCost: null == initialRenovationCost ? _self.initialRenovationCost : initialRenovationCost // ignore: cast_nullable_to_non_nullable
as double,estimatedMarketPrice: null == estimatedMarketPrice ? _self.estimatedMarketPrice : estimatedMarketPrice // ignore: cast_nullable_to_non_nullable
as double,marketPriceUpdatedAt: freezed == marketPriceUpdatedAt ? _self.marketPriceUpdatedAt : marketPriceUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ApartmentInvestmentMetrics].
extension ApartmentInvestmentMetricsPatterns on ApartmentInvestmentMetrics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApartmentInvestmentMetrics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApartmentInvestmentMetrics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApartmentInvestmentMetrics value)  $default,){
final _that = this;
switch (_that) {
case _ApartmentInvestmentMetrics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApartmentInvestmentMetrics value)?  $default,){
final _that = this;
switch (_that) {
case _ApartmentInvestmentMetrics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'apartment_id')  String apartmentId, @JsonKey(name: 'purchase_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double purchasePrice, @JsonKey(name: 'initial_renovation_cost', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double initialRenovationCost, @JsonKey(name: 'estimated_market_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double estimatedMarketPrice, @JsonKey(name: 'market_price_updated_at')@NullableIsoDateTimeConverter()  DateTime? marketPriceUpdatedAt, @JsonKey(name: 'updated_at')@IsoDateTimeConverter()  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApartmentInvestmentMetrics() when $default != null:
return $default(_that.apartmentId,_that.purchasePrice,_that.initialRenovationCost,_that.estimatedMarketPrice,_that.marketPriceUpdatedAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'apartment_id')  String apartmentId, @JsonKey(name: 'purchase_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double purchasePrice, @JsonKey(name: 'initial_renovation_cost', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double initialRenovationCost, @JsonKey(name: 'estimated_market_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double estimatedMarketPrice, @JsonKey(name: 'market_price_updated_at')@NullableIsoDateTimeConverter()  DateTime? marketPriceUpdatedAt, @JsonKey(name: 'updated_at')@IsoDateTimeConverter()  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ApartmentInvestmentMetrics():
return $default(_that.apartmentId,_that.purchasePrice,_that.initialRenovationCost,_that.estimatedMarketPrice,_that.marketPriceUpdatedAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'apartment_id')  String apartmentId, @JsonKey(name: 'purchase_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double purchasePrice, @JsonKey(name: 'initial_renovation_cost', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double initialRenovationCost, @JsonKey(name: 'estimated_market_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson)  double estimatedMarketPrice, @JsonKey(name: 'market_price_updated_at')@NullableIsoDateTimeConverter()  DateTime? marketPriceUpdatedAt, @JsonKey(name: 'updated_at')@IsoDateTimeConverter()  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ApartmentInvestmentMetrics() when $default != null:
return $default(_that.apartmentId,_that.purchasePrice,_that.initialRenovationCost,_that.estimatedMarketPrice,_that.marketPriceUpdatedAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApartmentInvestmentMetrics extends ApartmentInvestmentMetrics {
  const _ApartmentInvestmentMetrics({@JsonKey(name: 'apartment_id') required this.apartmentId, @JsonKey(name: 'purchase_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) this.purchasePrice = 0.0, @JsonKey(name: 'initial_renovation_cost', fromJson: modelAmountFromJson, toJson: modelAmountToJson) this.initialRenovationCost = 0.0, @JsonKey(name: 'estimated_market_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) this.estimatedMarketPrice = 0.0, @JsonKey(name: 'market_price_updated_at')@NullableIsoDateTimeConverter() this.marketPriceUpdatedAt, @JsonKey(name: 'updated_at')@IsoDateTimeConverter() required this.updatedAt}): super._();
  factory _ApartmentInvestmentMetrics.fromJson(Map<String, dynamic> json) => _$ApartmentInvestmentMetricsFromJson(json);

@override@JsonKey(name: 'apartment_id') final  String apartmentId;
@override@JsonKey(name: 'purchase_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) final  double purchasePrice;
@override@JsonKey(name: 'initial_renovation_cost', fromJson: modelAmountFromJson, toJson: modelAmountToJson) final  double initialRenovationCost;
@override@JsonKey(name: 'estimated_market_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) final  double estimatedMarketPrice;
@override@JsonKey(name: 'market_price_updated_at')@NullableIsoDateTimeConverter() final  DateTime? marketPriceUpdatedAt;
@override@JsonKey(name: 'updated_at')@IsoDateTimeConverter() final  DateTime updatedAt;

/// Create a copy of ApartmentInvestmentMetrics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApartmentInvestmentMetricsCopyWith<_ApartmentInvestmentMetrics> get copyWith => __$ApartmentInvestmentMetricsCopyWithImpl<_ApartmentInvestmentMetrics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApartmentInvestmentMetricsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApartmentInvestmentMetrics&&(identical(other.apartmentId, apartmentId) || other.apartmentId == apartmentId)&&(identical(other.purchasePrice, purchasePrice) || other.purchasePrice == purchasePrice)&&(identical(other.initialRenovationCost, initialRenovationCost) || other.initialRenovationCost == initialRenovationCost)&&(identical(other.estimatedMarketPrice, estimatedMarketPrice) || other.estimatedMarketPrice == estimatedMarketPrice)&&(identical(other.marketPriceUpdatedAt, marketPriceUpdatedAt) || other.marketPriceUpdatedAt == marketPriceUpdatedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apartmentId,purchasePrice,initialRenovationCost,estimatedMarketPrice,marketPriceUpdatedAt,updatedAt);

@override
String toString() {
  return 'ApartmentInvestmentMetrics(apartmentId: $apartmentId, purchasePrice: $purchasePrice, initialRenovationCost: $initialRenovationCost, estimatedMarketPrice: $estimatedMarketPrice, marketPriceUpdatedAt: $marketPriceUpdatedAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ApartmentInvestmentMetricsCopyWith<$Res> implements $ApartmentInvestmentMetricsCopyWith<$Res> {
  factory _$ApartmentInvestmentMetricsCopyWith(_ApartmentInvestmentMetrics value, $Res Function(_ApartmentInvestmentMetrics) _then) = __$ApartmentInvestmentMetricsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'apartment_id') String apartmentId,@JsonKey(name: 'purchase_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double purchasePrice,@JsonKey(name: 'initial_renovation_cost', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double initialRenovationCost,@JsonKey(name: 'estimated_market_price', fromJson: modelAmountFromJson, toJson: modelAmountToJson) double estimatedMarketPrice,@JsonKey(name: 'market_price_updated_at')@NullableIsoDateTimeConverter() DateTime? marketPriceUpdatedAt,@JsonKey(name: 'updated_at')@IsoDateTimeConverter() DateTime updatedAt
});




}
/// @nodoc
class __$ApartmentInvestmentMetricsCopyWithImpl<$Res>
    implements _$ApartmentInvestmentMetricsCopyWith<$Res> {
  __$ApartmentInvestmentMetricsCopyWithImpl(this._self, this._then);

  final _ApartmentInvestmentMetrics _self;
  final $Res Function(_ApartmentInvestmentMetrics) _then;

/// Create a copy of ApartmentInvestmentMetrics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apartmentId = null,Object? purchasePrice = null,Object? initialRenovationCost = null,Object? estimatedMarketPrice = null,Object? marketPriceUpdatedAt = freezed,Object? updatedAt = null,}) {
  return _then(_ApartmentInvestmentMetrics(
apartmentId: null == apartmentId ? _self.apartmentId : apartmentId // ignore: cast_nullable_to_non_nullable
as String,purchasePrice: null == purchasePrice ? _self.purchasePrice : purchasePrice // ignore: cast_nullable_to_non_nullable
as double,initialRenovationCost: null == initialRenovationCost ? _self.initialRenovationCost : initialRenovationCost // ignore: cast_nullable_to_non_nullable
as double,estimatedMarketPrice: null == estimatedMarketPrice ? _self.estimatedMarketPrice : estimatedMarketPrice // ignore: cast_nullable_to_non_nullable
as double,marketPriceUpdatedAt: freezed == marketPriceUpdatedAt ? _self.marketPriceUpdatedAt : marketPriceUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
