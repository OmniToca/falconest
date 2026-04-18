// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monthly_pnl_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MonthlyPnlSummary {

/// První den kalendářního měsíce (UTC), konzistentně s P&L záznamy v DB.
 DateTime get month; double get ownerIncome; double get ownerExpense;/// Částka vyúčtovaná agenturou za tento byt a měsíc (0 = žádný uzamčený snapshot).
 double get agencyCosts;
/// Create a copy of MonthlyPnlSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MonthlyPnlSummaryCopyWith<MonthlyPnlSummary> get copyWith => _$MonthlyPnlSummaryCopyWithImpl<MonthlyPnlSummary>(this as MonthlyPnlSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MonthlyPnlSummary&&(identical(other.month, month) || other.month == month)&&(identical(other.ownerIncome, ownerIncome) || other.ownerIncome == ownerIncome)&&(identical(other.ownerExpense, ownerExpense) || other.ownerExpense == ownerExpense)&&(identical(other.agencyCosts, agencyCosts) || other.agencyCosts == agencyCosts));
}


@override
int get hashCode => Object.hash(runtimeType,month,ownerIncome,ownerExpense,agencyCosts);

@override
String toString() {
  return 'MonthlyPnlSummary(month: $month, ownerIncome: $ownerIncome, ownerExpense: $ownerExpense, agencyCosts: $agencyCosts)';
}


}

/// @nodoc
abstract mixin class $MonthlyPnlSummaryCopyWith<$Res>  {
  factory $MonthlyPnlSummaryCopyWith(MonthlyPnlSummary value, $Res Function(MonthlyPnlSummary) _then) = _$MonthlyPnlSummaryCopyWithImpl;
@useResult
$Res call({
 DateTime month, double ownerIncome, double ownerExpense, double agencyCosts
});




}
/// @nodoc
class _$MonthlyPnlSummaryCopyWithImpl<$Res>
    implements $MonthlyPnlSummaryCopyWith<$Res> {
  _$MonthlyPnlSummaryCopyWithImpl(this._self, this._then);

  final MonthlyPnlSummary _self;
  final $Res Function(MonthlyPnlSummary) _then;

/// Create a copy of MonthlyPnlSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? month = null,Object? ownerIncome = null,Object? ownerExpense = null,Object? agencyCosts = null,}) {
  return _then(_self.copyWith(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as DateTime,ownerIncome: null == ownerIncome ? _self.ownerIncome : ownerIncome // ignore: cast_nullable_to_non_nullable
as double,ownerExpense: null == ownerExpense ? _self.ownerExpense : ownerExpense // ignore: cast_nullable_to_non_nullable
as double,agencyCosts: null == agencyCosts ? _self.agencyCosts : agencyCosts // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [MonthlyPnlSummary].
extension MonthlyPnlSummaryPatterns on MonthlyPnlSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MonthlyPnlSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MonthlyPnlSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MonthlyPnlSummary value)  $default,){
final _that = this;
switch (_that) {
case _MonthlyPnlSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MonthlyPnlSummary value)?  $default,){
final _that = this;
switch (_that) {
case _MonthlyPnlSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime month,  double ownerIncome,  double ownerExpense,  double agencyCosts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MonthlyPnlSummary() when $default != null:
return $default(_that.month,_that.ownerIncome,_that.ownerExpense,_that.agencyCosts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime month,  double ownerIncome,  double ownerExpense,  double agencyCosts)  $default,) {final _that = this;
switch (_that) {
case _MonthlyPnlSummary():
return $default(_that.month,_that.ownerIncome,_that.ownerExpense,_that.agencyCosts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime month,  double ownerIncome,  double ownerExpense,  double agencyCosts)?  $default,) {final _that = this;
switch (_that) {
case _MonthlyPnlSummary() when $default != null:
return $default(_that.month,_that.ownerIncome,_that.ownerExpense,_that.agencyCosts);case _:
  return null;

}
}

}

/// @nodoc


class _MonthlyPnlSummary extends MonthlyPnlSummary {
  const _MonthlyPnlSummary({required this.month, this.ownerIncome = 0.0, this.ownerExpense = 0.0, this.agencyCosts = 0.0}): super._();
  

/// První den kalendářního měsíce (UTC), konzistentně s P&L záznamy v DB.
@override final  DateTime month;
@override@JsonKey() final  double ownerIncome;
@override@JsonKey() final  double ownerExpense;
/// Částka vyúčtovaná agenturou za tento byt a měsíc (0 = žádný uzamčený snapshot).
@override@JsonKey() final  double agencyCosts;

/// Create a copy of MonthlyPnlSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MonthlyPnlSummaryCopyWith<_MonthlyPnlSummary> get copyWith => __$MonthlyPnlSummaryCopyWithImpl<_MonthlyPnlSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MonthlyPnlSummary&&(identical(other.month, month) || other.month == month)&&(identical(other.ownerIncome, ownerIncome) || other.ownerIncome == ownerIncome)&&(identical(other.ownerExpense, ownerExpense) || other.ownerExpense == ownerExpense)&&(identical(other.agencyCosts, agencyCosts) || other.agencyCosts == agencyCosts));
}


@override
int get hashCode => Object.hash(runtimeType,month,ownerIncome,ownerExpense,agencyCosts);

@override
String toString() {
  return 'MonthlyPnlSummary(month: $month, ownerIncome: $ownerIncome, ownerExpense: $ownerExpense, agencyCosts: $agencyCosts)';
}


}

/// @nodoc
abstract mixin class _$MonthlyPnlSummaryCopyWith<$Res> implements $MonthlyPnlSummaryCopyWith<$Res> {
  factory _$MonthlyPnlSummaryCopyWith(_MonthlyPnlSummary value, $Res Function(_MonthlyPnlSummary) _then) = __$MonthlyPnlSummaryCopyWithImpl;
@override @useResult
$Res call({
 DateTime month, double ownerIncome, double ownerExpense, double agencyCosts
});




}
/// @nodoc
class __$MonthlyPnlSummaryCopyWithImpl<$Res>
    implements _$MonthlyPnlSummaryCopyWith<$Res> {
  __$MonthlyPnlSummaryCopyWithImpl(this._self, this._then);

  final _MonthlyPnlSummary _self;
  final $Res Function(_MonthlyPnlSummary) _then;

/// Create a copy of MonthlyPnlSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? month = null,Object? ownerIncome = null,Object? ownerExpense = null,Object? agencyCosts = null,}) {
  return _then(_MonthlyPnlSummary(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as DateTime,ownerIncome: null == ownerIncome ? _self.ownerIncome : ownerIncome // ignore: cast_nullable_to_non_nullable
as double,ownerExpense: null == ownerExpense ? _self.ownerExpense : ownerExpense // ignore: cast_nullable_to_non_nullable
as double,agencyCosts: null == agencyCosts ? _self.agencyCosts : agencyCosts // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
