// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_checklist_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskChecklistModel {

 String get id;@JsonKey(name: 'tenant_id') String get tenantId;@JsonKey(name: 'task_id') String get taskId;@JsonKey(name: 'template_id') String? get templateId;@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? get createdAt;@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? get updatedAt;
/// Create a copy of TaskChecklistModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskChecklistModelCopyWith<TaskChecklistModel> get copyWith => _$TaskChecklistModelCopyWithImpl<TaskChecklistModel>(this as TaskChecklistModel, _$identity);

  /// Serializes this TaskChecklistModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskChecklistModel&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,taskId,templateId,createdAt,updatedAt);

@override
String toString() {
  return 'TaskChecklistModel(id: $id, tenantId: $tenantId, taskId: $taskId, templateId: $templateId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $TaskChecklistModelCopyWith<$Res>  {
  factory $TaskChecklistModelCopyWith(TaskChecklistModel value, $Res Function(TaskChecklistModel) _then) = _$TaskChecklistModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'task_id') String taskId,@JsonKey(name: 'template_id') String? templateId,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt
});




}
/// @nodoc
class _$TaskChecklistModelCopyWithImpl<$Res>
    implements $TaskChecklistModelCopyWith<$Res> {
  _$TaskChecklistModelCopyWithImpl(this._self, this._then);

  final TaskChecklistModel _self;
  final $Res Function(TaskChecklistModel) _then;

/// Create a copy of TaskChecklistModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? taskId = null,Object? templateId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,templateId: freezed == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskChecklistModel].
extension TaskChecklistModelPatterns on TaskChecklistModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskChecklistModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskChecklistModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskChecklistModel value)  $default,){
final _that = this;
switch (_that) {
case _TaskChecklistModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskChecklistModel value)?  $default,){
final _that = this;
switch (_that) {
case _TaskChecklistModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'task_id')  String taskId, @JsonKey(name: 'template_id')  String? templateId, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskChecklistModel() when $default != null:
return $default(_that.id,_that.tenantId,_that.taskId,_that.templateId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'task_id')  String taskId, @JsonKey(name: 'template_id')  String? templateId, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _TaskChecklistModel():
return $default(_that.id,_that.tenantId,_that.taskId,_that.templateId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'task_id')  String taskId, @JsonKey(name: 'template_id')  String? templateId, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _TaskChecklistModel() when $default != null:
return $default(_that.id,_that.tenantId,_that.taskId,_that.templateId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskChecklistModel extends TaskChecklistModel {
  const _TaskChecklistModel({required this.id, @JsonKey(name: 'tenant_id') required this.tenantId, @JsonKey(name: 'task_id') required this.taskId, @JsonKey(name: 'template_id') this.templateId, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() this.createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() this.updatedAt}): super._();
  factory _TaskChecklistModel.fromJson(Map<String, dynamic> json) => _$TaskChecklistModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override@JsonKey(name: 'task_id') final  String taskId;
@override@JsonKey(name: 'template_id') final  String? templateId;
@override@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() final  DateTime? updatedAt;

/// Create a copy of TaskChecklistModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskChecklistModelCopyWith<_TaskChecklistModel> get copyWith => __$TaskChecklistModelCopyWithImpl<_TaskChecklistModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskChecklistModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskChecklistModel&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,taskId,templateId,createdAt,updatedAt);

@override
String toString() {
  return 'TaskChecklistModel(id: $id, tenantId: $tenantId, taskId: $taskId, templateId: $templateId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$TaskChecklistModelCopyWith<$Res> implements $TaskChecklistModelCopyWith<$Res> {
  factory _$TaskChecklistModelCopyWith(_TaskChecklistModel value, $Res Function(_TaskChecklistModel) _then) = __$TaskChecklistModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'task_id') String taskId,@JsonKey(name: 'template_id') String? templateId,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt
});




}
/// @nodoc
class __$TaskChecklistModelCopyWithImpl<$Res>
    implements _$TaskChecklistModelCopyWith<$Res> {
  __$TaskChecklistModelCopyWithImpl(this._self, this._then);

  final _TaskChecklistModel _self;
  final $Res Function(_TaskChecklistModel) _then;

/// Create a copy of TaskChecklistModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? taskId = null,Object? templateId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_TaskChecklistModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,templateId: freezed == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
