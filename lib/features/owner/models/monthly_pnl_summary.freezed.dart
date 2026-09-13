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
 double get agencyCosts;/// Datum skutečného výběru / potvrzení nájmu (dlouhodobý pronájem) – hotovost / P&L.
 DateTime? get rentPaidAt;/// Plánovaný termín výběru ([tasks.due_date], rent_collection).
 DateTime? get rentPlannedCollectionDate;/// Skutečné dokončení ([tasks.completed_at] nebo potvrzení převodu).
 DateTime? get rentActualCollectionDate;/// Bilance nájmu po FIFO amortizaci napříč měsíci (alokované platby − očekáváno).
/// null = bez kontextu nájmu nebo měsíc kauce.
 double? get rentBalanceDifference;/// Částka kauce z P&L (`description` obsahuje „Kauce“) – nezapočítává se do [rentBalanceDifference].
 double? get rentDepositAmount;/// Částka z FIFO poolu alokovaná na tento měsíc (pro vysvětlení úhrady z minula).
 double get rentFifoAllocatedFromPool;/// True = část úhrady šla z historických plateb, ne jen z výběru v tomto měsíci.
 bool get rentCoveredFromPreviousPool;
/// Create a copy of MonthlyPnlSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MonthlyPnlSummaryCopyWith<MonthlyPnlSummary> get copyWith => _$MonthlyPnlSummaryCopyWithImpl<MonthlyPnlSummary>(this as MonthlyPnlSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MonthlyPnlSummary&&(identical(other.month, month) || other.month == month)&&(identical(other.ownerIncome, ownerIncome) || other.ownerIncome == ownerIncome)&&(identical(other.ownerExpense, ownerExpense) || other.ownerExpense == ownerExpense)&&(identical(other.agencyCosts, agencyCosts) || other.agencyCosts == agencyCosts)&&(identical(other.rentPaidAt, rentPaidAt) || other.rentPaidAt == rentPaidAt)&&(identical(other.rentPlannedCollectionDate, rentPlannedCollectionDate) || other.rentPlannedCollectionDate == rentPlannedCollectionDate)&&(identical(other.rentActualCollectionDate, rentActualCollectionDate) || other.rentActualCollectionDate == rentActualCollectionDate)&&(identical(other.rentBalanceDifference, rentBalanceDifference) || other.rentBalanceDifference == rentBalanceDifference)&&(identical(other.rentDepositAmount, rentDepositAmount) || other.rentDepositAmount == rentDepositAmount)&&(identical(other.rentFifoAllocatedFromPool, rentFifoAllocatedFromPool) || other.rentFifoAllocatedFromPool == rentFifoAllocatedFromPool)&&(identical(other.rentCoveredFromPreviousPool, rentCoveredFromPreviousPool) || other.rentCoveredFromPreviousPool == rentCoveredFromPreviousPool));
}


@override
int get hashCode => Object.hash(runtimeType,month,ownerIncome,ownerExpense,agencyCosts,rentPaidAt,rentPlannedCollectionDate,rentActualCollectionDate,rentBalanceDifference,rentDepositAmount,rentFifoAllocatedFromPool,rentCoveredFromPreviousPool);

@override
String toString() {
  return 'MonthlyPnlSummary(month: $month, ownerIncome: $ownerIncome, ownerExpense: $ownerExpense, agencyCosts: $agencyCosts, rentPaidAt: $rentPaidAt, rentPlannedCollectionDate: $rentPlannedCollectionDate, rentActualCollectionDate: $rentActualCollectionDate, rentBalanceDifference: $rentBalanceDifference, rentDepositAmount: $rentDepositAmount, rentFifoAllocatedFromPool: $rentFifoAllocatedFromPool, rentCoveredFromPreviousPool: $rentCoveredFromPreviousPool)';
}


}

/// @nodoc
abstract mixin class $MonthlyPnlSummaryCopyWith<$Res>  {
  factory $MonthlyPnlSummaryCopyWith(MonthlyPnlSummary value, $Res Function(MonthlyPnlSummary) _then) = _$MonthlyPnlSummaryCopyWithImpl;
@useResult
$Res call({
 DateTime month, double ownerIncome, double ownerExpense, double agencyCosts, DateTime? rentPaidAt, DateTime? rentPlannedCollectionDate, DateTime? rentActualCollectionDate, double? rentBalanceDifference, double? rentDepositAmount, double rentFifoAllocatedFromPool, bool rentCoveredFromPreviousPool
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
@pragma('vm:prefer-inline') @override $Res call({Object? month = null,Object? ownerIncome = null,Object? ownerExpense = null,Object? agencyCosts = null,Object? rentPaidAt = freezed,Object? rentPlannedCollectionDate = freezed,Object? rentActualCollectionDate = freezed,Object? rentBalanceDifference = freezed,Object? rentDepositAmount = freezed,Object? rentFifoAllocatedFromPool = null,Object? rentCoveredFromPreviousPool = null,}) {
  return _then(_self.copyWith(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as DateTime,ownerIncome: null == ownerIncome ? _self.ownerIncome : ownerIncome // ignore: cast_nullable_to_non_nullable
as double,ownerExpense: null == ownerExpense ? _self.ownerExpense : ownerExpense // ignore: cast_nullable_to_non_nullable
as double,agencyCosts: null == agencyCosts ? _self.agencyCosts : agencyCosts // ignore: cast_nullable_to_non_nullable
as double,rentPaidAt: freezed == rentPaidAt ? _self.rentPaidAt : rentPaidAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rentPlannedCollectionDate: freezed == rentPlannedCollectionDate ? _self.rentPlannedCollectionDate : rentPlannedCollectionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rentActualCollectionDate: freezed == rentActualCollectionDate ? _self.rentActualCollectionDate : rentActualCollectionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rentBalanceDifference: freezed == rentBalanceDifference ? _self.rentBalanceDifference : rentBalanceDifference // ignore: cast_nullable_to_non_nullable
as double?,rentDepositAmount: freezed == rentDepositAmount ? _self.rentDepositAmount : rentDepositAmount // ignore: cast_nullable_to_non_nullable
as double?,rentFifoAllocatedFromPool: null == rentFifoAllocatedFromPool ? _self.rentFifoAllocatedFromPool : rentFifoAllocatedFromPool // ignore: cast_nullable_to_non_nullable
as double,rentCoveredFromPreviousPool: null == rentCoveredFromPreviousPool ? _self.rentCoveredFromPreviousPool : rentCoveredFromPreviousPool // ignore: cast_nullable_to_non_nullable
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime month,  double ownerIncome,  double ownerExpense,  double agencyCosts,  DateTime? rentPaidAt,  DateTime? rentPlannedCollectionDate,  DateTime? rentActualCollectionDate,  double? rentBalanceDifference,  double? rentDepositAmount,  double rentFifoAllocatedFromPool,  bool rentCoveredFromPreviousPool)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MonthlyPnlSummary() when $default != null:
return $default(_that.month,_that.ownerIncome,_that.ownerExpense,_that.agencyCosts,_that.rentPaidAt,_that.rentPlannedCollectionDate,_that.rentActualCollectionDate,_that.rentBalanceDifference,_that.rentDepositAmount,_that.rentFifoAllocatedFromPool,_that.rentCoveredFromPreviousPool);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime month,  double ownerIncome,  double ownerExpense,  double agencyCosts,  DateTime? rentPaidAt,  DateTime? rentPlannedCollectionDate,  DateTime? rentActualCollectionDate,  double? rentBalanceDifference,  double? rentDepositAmount,  double rentFifoAllocatedFromPool,  bool rentCoveredFromPreviousPool)  $default,) {final _that = this;
switch (_that) {
case _MonthlyPnlSummary():
return $default(_that.month,_that.ownerIncome,_that.ownerExpense,_that.agencyCosts,_that.rentPaidAt,_that.rentPlannedCollectionDate,_that.rentActualCollectionDate,_that.rentBalanceDifference,_that.rentDepositAmount,_that.rentFifoAllocatedFromPool,_that.rentCoveredFromPreviousPool);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime month,  double ownerIncome,  double ownerExpense,  double agencyCosts,  DateTime? rentPaidAt,  DateTime? rentPlannedCollectionDate,  DateTime? rentActualCollectionDate,  double? rentBalanceDifference,  double? rentDepositAmount,  double rentFifoAllocatedFromPool,  bool rentCoveredFromPreviousPool)?  $default,) {final _that = this;
switch (_that) {
case _MonthlyPnlSummary() when $default != null:
return $default(_that.month,_that.ownerIncome,_that.ownerExpense,_that.agencyCosts,_that.rentPaidAt,_that.rentPlannedCollectionDate,_that.rentActualCollectionDate,_that.rentBalanceDifference,_that.rentDepositAmount,_that.rentFifoAllocatedFromPool,_that.rentCoveredFromPreviousPool);case _:
  return null;

}
}

}

/// @nodoc


class _MonthlyPnlSummary extends MonthlyPnlSummary {
  const _MonthlyPnlSummary({required this.month, this.ownerIncome = 0.0, this.ownerExpense = 0.0, this.agencyCosts = 0.0, this.rentPaidAt, this.rentPlannedCollectionDate, this.rentActualCollectionDate, this.rentBalanceDifference, this.rentDepositAmount, this.rentFifoAllocatedFromPool = 0.0, this.rentCoveredFromPreviousPool = false}): super._();
  

/// První den kalendářního měsíce (UTC), konzistentně s P&L záznamy v DB.
@override final  DateTime month;
@override@JsonKey() final  double ownerIncome;
@override@JsonKey() final  double ownerExpense;
/// Částka vyúčtovaná agenturou za tento byt a měsíc (0 = žádný uzamčený snapshot).
@override@JsonKey() final  double agencyCosts;
/// Datum skutečného výběru / potvrzení nájmu (dlouhodobý pronájem) – hotovost / P&L.
@override final  DateTime? rentPaidAt;
/// Plánovaný termín výběru ([tasks.due_date], rent_collection).
@override final  DateTime? rentPlannedCollectionDate;
/// Skutečné dokončení ([tasks.completed_at] nebo potvrzení převodu).
@override final  DateTime? rentActualCollectionDate;
/// Bilance nájmu po FIFO amortizaci napříč měsíci (alokované platby − očekáváno).
/// null = bez kontextu nájmu nebo měsíc kauce.
@override final  double? rentBalanceDifference;
/// Částka kauce z P&L (`description` obsahuje „Kauce“) – nezapočítává se do [rentBalanceDifference].
@override final  double? rentDepositAmount;
/// Částka z FIFO poolu alokovaná na tento měsíc (pro vysvětlení úhrady z minula).
@override@JsonKey() final  double rentFifoAllocatedFromPool;
/// True = část úhrady šla z historických plateb, ne jen z výběru v tomto měsíci.
@override@JsonKey() final  bool rentCoveredFromPreviousPool;

/// Create a copy of MonthlyPnlSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MonthlyPnlSummaryCopyWith<_MonthlyPnlSummary> get copyWith => __$MonthlyPnlSummaryCopyWithImpl<_MonthlyPnlSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MonthlyPnlSummary&&(identical(other.month, month) || other.month == month)&&(identical(other.ownerIncome, ownerIncome) || other.ownerIncome == ownerIncome)&&(identical(other.ownerExpense, ownerExpense) || other.ownerExpense == ownerExpense)&&(identical(other.agencyCosts, agencyCosts) || other.agencyCosts == agencyCosts)&&(identical(other.rentPaidAt, rentPaidAt) || other.rentPaidAt == rentPaidAt)&&(identical(other.rentPlannedCollectionDate, rentPlannedCollectionDate) || other.rentPlannedCollectionDate == rentPlannedCollectionDate)&&(identical(other.rentActualCollectionDate, rentActualCollectionDate) || other.rentActualCollectionDate == rentActualCollectionDate)&&(identical(other.rentBalanceDifference, rentBalanceDifference) || other.rentBalanceDifference == rentBalanceDifference)&&(identical(other.rentDepositAmount, rentDepositAmount) || other.rentDepositAmount == rentDepositAmount)&&(identical(other.rentFifoAllocatedFromPool, rentFifoAllocatedFromPool) || other.rentFifoAllocatedFromPool == rentFifoAllocatedFromPool)&&(identical(other.rentCoveredFromPreviousPool, rentCoveredFromPreviousPool) || other.rentCoveredFromPreviousPool == rentCoveredFromPreviousPool));
}


@override
int get hashCode => Object.hash(runtimeType,month,ownerIncome,ownerExpense,agencyCosts,rentPaidAt,rentPlannedCollectionDate,rentActualCollectionDate,rentBalanceDifference,rentDepositAmount,rentFifoAllocatedFromPool,rentCoveredFromPreviousPool);

@override
String toString() {
  return 'MonthlyPnlSummary(month: $month, ownerIncome: $ownerIncome, ownerExpense: $ownerExpense, agencyCosts: $agencyCosts, rentPaidAt: $rentPaidAt, rentPlannedCollectionDate: $rentPlannedCollectionDate, rentActualCollectionDate: $rentActualCollectionDate, rentBalanceDifference: $rentBalanceDifference, rentDepositAmount: $rentDepositAmount, rentFifoAllocatedFromPool: $rentFifoAllocatedFromPool, rentCoveredFromPreviousPool: $rentCoveredFromPreviousPool)';
}


}

/// @nodoc
abstract mixin class _$MonthlyPnlSummaryCopyWith<$Res> implements $MonthlyPnlSummaryCopyWith<$Res> {
  factory _$MonthlyPnlSummaryCopyWith(_MonthlyPnlSummary value, $Res Function(_MonthlyPnlSummary) _then) = __$MonthlyPnlSummaryCopyWithImpl;
@override @useResult
$Res call({
 DateTime month, double ownerIncome, double ownerExpense, double agencyCosts, DateTime? rentPaidAt, DateTime? rentPlannedCollectionDate, DateTime? rentActualCollectionDate, double? rentBalanceDifference, double? rentDepositAmount, double rentFifoAllocatedFromPool, bool rentCoveredFromPreviousPool
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
@override @pragma('vm:prefer-inline') $Res call({Object? month = null,Object? ownerIncome = null,Object? ownerExpense = null,Object? agencyCosts = null,Object? rentPaidAt = freezed,Object? rentPlannedCollectionDate = freezed,Object? rentActualCollectionDate = freezed,Object? rentBalanceDifference = freezed,Object? rentDepositAmount = freezed,Object? rentFifoAllocatedFromPool = null,Object? rentCoveredFromPreviousPool = null,}) {
  return _then(_MonthlyPnlSummary(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as DateTime,ownerIncome: null == ownerIncome ? _self.ownerIncome : ownerIncome // ignore: cast_nullable_to_non_nullable
as double,ownerExpense: null == ownerExpense ? _self.ownerExpense : ownerExpense // ignore: cast_nullable_to_non_nullable
as double,agencyCosts: null == agencyCosts ? _self.agencyCosts : agencyCosts // ignore: cast_nullable_to_non_nullable
as double,rentPaidAt: freezed == rentPaidAt ? _self.rentPaidAt : rentPaidAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rentPlannedCollectionDate: freezed == rentPlannedCollectionDate ? _self.rentPlannedCollectionDate : rentPlannedCollectionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rentActualCollectionDate: freezed == rentActualCollectionDate ? _self.rentActualCollectionDate : rentActualCollectionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rentBalanceDifference: freezed == rentBalanceDifference ? _self.rentBalanceDifference : rentBalanceDifference // ignore: cast_nullable_to_non_nullable
as double?,rentDepositAmount: freezed == rentDepositAmount ? _self.rentDepositAmount : rentDepositAmount // ignore: cast_nullable_to_non_nullable
as double?,rentFifoAllocatedFromPool: null == rentFifoAllocatedFromPool ? _self.rentFifoAllocatedFromPool : rentFifoAllocatedFromPool // ignore: cast_nullable_to_non_nullable
as double,rentCoveredFromPreviousPool: null == rentCoveredFromPreviousPool ? _self.rentCoveredFromPreviousPool : rentCoveredFromPreviousPool // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
