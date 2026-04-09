// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_template_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChecklistTemplateModel {

 String get id;@JsonKey(name: 'tenant_id') String get tenantId; String get name; String? get description;@JsonKey(name: 'is_active') bool get isActive;@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? get createdAt;@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? get updatedAt;
/// Create a copy of ChecklistTemplateModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChecklistTemplateModelCopyWith<ChecklistTemplateModel> get copyWith => _$ChecklistTemplateModelCopyWithImpl<ChecklistTemplateModel>(this as ChecklistTemplateModel, _$identity);

  /// Serializes this ChecklistTemplateModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChecklistTemplateModel&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,name,description,isActive,createdAt,updatedAt);

@override
String toString() {
  return 'ChecklistTemplateModel(id: $id, tenantId: $tenantId, name: $name, description: $description, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ChecklistTemplateModelCopyWith<$Res>  {
  factory $ChecklistTemplateModelCopyWith(ChecklistTemplateModel value, $Res Function(ChecklistTemplateModel) _then) = _$ChecklistTemplateModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId, String name, String? description,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt
});




}
/// @nodoc
class _$ChecklistTemplateModelCopyWithImpl<$Res>
    implements $ChecklistTemplateModelCopyWith<$Res> {
  _$ChecklistTemplateModelCopyWithImpl(this._self, this._then);

  final ChecklistTemplateModel _self;
  final $Res Function(ChecklistTemplateModel) _then;

/// Create a copy of ChecklistTemplateModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? name = null,Object? description = freezed,Object? isActive = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChecklistTemplateModel].
extension ChecklistTemplateModelPatterns on ChecklistTemplateModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChecklistTemplateModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChecklistTemplateModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChecklistTemplateModel value)  $default,){
final _that = this;
switch (_that) {
case _ChecklistTemplateModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChecklistTemplateModel value)?  $default,){
final _that = this;
switch (_that) {
case _ChecklistTemplateModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId,  String name,  String? description, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChecklistTemplateModel() when $default != null:
return $default(_that.id,_that.tenantId,_that.name,_that.description,_that.isActive,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId,  String name,  String? description, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ChecklistTemplateModel():
return $default(_that.id,_that.tenantId,_that.name,_that.description,_that.isActive,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tenant_id')  String tenantId,  String name,  String? description, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ChecklistTemplateModel() when $default != null:
return $default(_that.id,_that.tenantId,_that.name,_that.description,_that.isActive,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChecklistTemplateModel extends ChecklistTemplateModel {
  const _ChecklistTemplateModel({required this.id, @JsonKey(name: 'tenant_id') required this.tenantId, required this.name, this.description, @JsonKey(name: 'is_active') this.isActive = true, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() this.createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() this.updatedAt}): super._();
  factory _ChecklistTemplateModel.fromJson(Map<String, dynamic> json) => _$ChecklistTemplateModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override final  String name;
@override final  String? description;
@override@JsonKey(name: 'is_active') final  bool isActive;
@override@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() final  DateTime? updatedAt;

/// Create a copy of ChecklistTemplateModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChecklistTemplateModelCopyWith<_ChecklistTemplateModel> get copyWith => __$ChecklistTemplateModelCopyWithImpl<_ChecklistTemplateModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChecklistTemplateModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChecklistTemplateModel&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,name,description,isActive,createdAt,updatedAt);

@override
String toString() {
  return 'ChecklistTemplateModel(id: $id, tenantId: $tenantId, name: $name, description: $description, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ChecklistTemplateModelCopyWith<$Res> implements $ChecklistTemplateModelCopyWith<$Res> {
  factory _$ChecklistTemplateModelCopyWith(_ChecklistTemplateModel value, $Res Function(_ChecklistTemplateModel) _then) = __$ChecklistTemplateModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId, String name, String? description,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt
});




}
/// @nodoc
class __$ChecklistTemplateModelCopyWithImpl<$Res>
    implements _$ChecklistTemplateModelCopyWith<$Res> {
  __$ChecklistTemplateModelCopyWithImpl(this._self, this._then);

  final _ChecklistTemplateModel _self;
  final $Res Function(_ChecklistTemplateModel) _then;

/// Create a copy of ChecklistTemplateModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? name = null,Object? description = freezed,Object? isActive = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_ChecklistTemplateModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
