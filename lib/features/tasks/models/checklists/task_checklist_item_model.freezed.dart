// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_checklist_item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskChecklistItemModel {

 String get id;@JsonKey(name: 'tenant_id') String get tenantId;@JsonKey(name: 'task_checklist_id') String get taskChecklistId; String get title;@JsonKey(name: 'is_photo_required') bool get isPhotoRequired;@JsonKey(name: 'sort_order') int get sortOrder;@JsonKey(name: 'is_completed') bool get isCompleted;@JsonKey(name: 'completed_at')@NullableIsoDateTimeConverter() DateTime? get completedAt;@JsonKey(name: 'completed_by') String? get completedBy;@JsonKey(name: 'photo_url') String? get photoUrl;@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? get createdAt;@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? get updatedAt;
/// Create a copy of TaskChecklistItemModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskChecklistItemModelCopyWith<TaskChecklistItemModel> get copyWith => _$TaskChecklistItemModelCopyWithImpl<TaskChecklistItemModel>(this as TaskChecklistItemModel, _$identity);

  /// Serializes this TaskChecklistItemModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskChecklistItemModel&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.taskChecklistId, taskChecklistId) || other.taskChecklistId == taskChecklistId)&&(identical(other.title, title) || other.title == title)&&(identical(other.isPhotoRequired, isPhotoRequired) || other.isPhotoRequired == isPhotoRequired)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.completedBy, completedBy) || other.completedBy == completedBy)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,taskChecklistId,title,isPhotoRequired,sortOrder,isCompleted,completedAt,completedBy,photoUrl,createdAt,updatedAt);

@override
String toString() {
  return 'TaskChecklistItemModel(id: $id, tenantId: $tenantId, taskChecklistId: $taskChecklistId, title: $title, isPhotoRequired: $isPhotoRequired, sortOrder: $sortOrder, isCompleted: $isCompleted, completedAt: $completedAt, completedBy: $completedBy, photoUrl: $photoUrl, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $TaskChecklistItemModelCopyWith<$Res>  {
  factory $TaskChecklistItemModelCopyWith(TaskChecklistItemModel value, $Res Function(TaskChecklistItemModel) _then) = _$TaskChecklistItemModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'task_checklist_id') String taskChecklistId, String title,@JsonKey(name: 'is_photo_required') bool isPhotoRequired,@JsonKey(name: 'sort_order') int sortOrder,@JsonKey(name: 'is_completed') bool isCompleted,@JsonKey(name: 'completed_at')@NullableIsoDateTimeConverter() DateTime? completedAt,@JsonKey(name: 'completed_by') String? completedBy,@JsonKey(name: 'photo_url') String? photoUrl,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt
});




}
/// @nodoc
class _$TaskChecklistItemModelCopyWithImpl<$Res>
    implements $TaskChecklistItemModelCopyWith<$Res> {
  _$TaskChecklistItemModelCopyWithImpl(this._self, this._then);

  final TaskChecklistItemModel _self;
  final $Res Function(TaskChecklistItemModel) _then;

/// Create a copy of TaskChecklistItemModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? taskChecklistId = null,Object? title = null,Object? isPhotoRequired = null,Object? sortOrder = null,Object? isCompleted = null,Object? completedAt = freezed,Object? completedBy = freezed,Object? photoUrl = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,taskChecklistId: null == taskChecklistId ? _self.taskChecklistId : taskChecklistId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isPhotoRequired: null == isPhotoRequired ? _self.isPhotoRequired : isPhotoRequired // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedBy: freezed == completedBy ? _self.completedBy : completedBy // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskChecklistItemModel].
extension TaskChecklistItemModelPatterns on TaskChecklistItemModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskChecklistItemModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskChecklistItemModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskChecklistItemModel value)  $default,){
final _that = this;
switch (_that) {
case _TaskChecklistItemModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskChecklistItemModel value)?  $default,){
final _that = this;
switch (_that) {
case _TaskChecklistItemModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'task_checklist_id')  String taskChecklistId,  String title, @JsonKey(name: 'is_photo_required')  bool isPhotoRequired, @JsonKey(name: 'sort_order')  int sortOrder, @JsonKey(name: 'is_completed')  bool isCompleted, @JsonKey(name: 'completed_at')@NullableIsoDateTimeConverter()  DateTime? completedAt, @JsonKey(name: 'completed_by')  String? completedBy, @JsonKey(name: 'photo_url')  String? photoUrl, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskChecklistItemModel() when $default != null:
return $default(_that.id,_that.tenantId,_that.taskChecklistId,_that.title,_that.isPhotoRequired,_that.sortOrder,_that.isCompleted,_that.completedAt,_that.completedBy,_that.photoUrl,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'task_checklist_id')  String taskChecklistId,  String title, @JsonKey(name: 'is_photo_required')  bool isPhotoRequired, @JsonKey(name: 'sort_order')  int sortOrder, @JsonKey(name: 'is_completed')  bool isCompleted, @JsonKey(name: 'completed_at')@NullableIsoDateTimeConverter()  DateTime? completedAt, @JsonKey(name: 'completed_by')  String? completedBy, @JsonKey(name: 'photo_url')  String? photoUrl, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _TaskChecklistItemModel():
return $default(_that.id,_that.tenantId,_that.taskChecklistId,_that.title,_that.isPhotoRequired,_that.sortOrder,_that.isCompleted,_that.completedAt,_that.completedBy,_that.photoUrl,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'task_checklist_id')  String taskChecklistId,  String title, @JsonKey(name: 'is_photo_required')  bool isPhotoRequired, @JsonKey(name: 'sort_order')  int sortOrder, @JsonKey(name: 'is_completed')  bool isCompleted, @JsonKey(name: 'completed_at')@NullableIsoDateTimeConverter()  DateTime? completedAt, @JsonKey(name: 'completed_by')  String? completedBy, @JsonKey(name: 'photo_url')  String? photoUrl, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter()  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _TaskChecklistItemModel() when $default != null:
return $default(_that.id,_that.tenantId,_that.taskChecklistId,_that.title,_that.isPhotoRequired,_that.sortOrder,_that.isCompleted,_that.completedAt,_that.completedBy,_that.photoUrl,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskChecklistItemModel extends TaskChecklistItemModel {
  const _TaskChecklistItemModel({required this.id, @JsonKey(name: 'tenant_id') required this.tenantId, @JsonKey(name: 'task_checklist_id') required this.taskChecklistId, required this.title, @JsonKey(name: 'is_photo_required') this.isPhotoRequired = false, @JsonKey(name: 'sort_order') required this.sortOrder, @JsonKey(name: 'is_completed') this.isCompleted = false, @JsonKey(name: 'completed_at')@NullableIsoDateTimeConverter() this.completedAt, @JsonKey(name: 'completed_by') this.completedBy, @JsonKey(name: 'photo_url') this.photoUrl, @JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() this.createdAt, @JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() this.updatedAt}): super._();
  factory _TaskChecklistItemModel.fromJson(Map<String, dynamic> json) => _$TaskChecklistItemModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override@JsonKey(name: 'task_checklist_id') final  String taskChecklistId;
@override final  String title;
@override@JsonKey(name: 'is_photo_required') final  bool isPhotoRequired;
@override@JsonKey(name: 'sort_order') final  int sortOrder;
@override@JsonKey(name: 'is_completed') final  bool isCompleted;
@override@JsonKey(name: 'completed_at')@NullableIsoDateTimeConverter() final  DateTime? completedAt;
@override@JsonKey(name: 'completed_by') final  String? completedBy;
@override@JsonKey(name: 'photo_url') final  String? photoUrl;
@override@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() final  DateTime? updatedAt;

/// Create a copy of TaskChecklistItemModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskChecklistItemModelCopyWith<_TaskChecklistItemModel> get copyWith => __$TaskChecklistItemModelCopyWithImpl<_TaskChecklistItemModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskChecklistItemModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskChecklistItemModel&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.taskChecklistId, taskChecklistId) || other.taskChecklistId == taskChecklistId)&&(identical(other.title, title) || other.title == title)&&(identical(other.isPhotoRequired, isPhotoRequired) || other.isPhotoRequired == isPhotoRequired)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.completedBy, completedBy) || other.completedBy == completedBy)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,taskChecklistId,title,isPhotoRequired,sortOrder,isCompleted,completedAt,completedBy,photoUrl,createdAt,updatedAt);

@override
String toString() {
  return 'TaskChecklistItemModel(id: $id, tenantId: $tenantId, taskChecklistId: $taskChecklistId, title: $title, isPhotoRequired: $isPhotoRequired, sortOrder: $sortOrder, isCompleted: $isCompleted, completedAt: $completedAt, completedBy: $completedBy, photoUrl: $photoUrl, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$TaskChecklistItemModelCopyWith<$Res> implements $TaskChecklistItemModelCopyWith<$Res> {
  factory _$TaskChecklistItemModelCopyWith(_TaskChecklistItemModel value, $Res Function(_TaskChecklistItemModel) _then) = __$TaskChecklistItemModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'task_checklist_id') String taskChecklistId, String title,@JsonKey(name: 'is_photo_required') bool isPhotoRequired,@JsonKey(name: 'sort_order') int sortOrder,@JsonKey(name: 'is_completed') bool isCompleted,@JsonKey(name: 'completed_at')@NullableIsoDateTimeConverter() DateTime? completedAt,@JsonKey(name: 'completed_by') String? completedBy,@JsonKey(name: 'photo_url') String? photoUrl,@JsonKey(name: 'created_at')@NullableIsoDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'updated_at')@NullableIsoDateTimeConverter() DateTime? updatedAt
});




}
/// @nodoc
class __$TaskChecklistItemModelCopyWithImpl<$Res>
    implements _$TaskChecklistItemModelCopyWith<$Res> {
  __$TaskChecklistItemModelCopyWithImpl(this._self, this._then);

  final _TaskChecklistItemModel _self;
  final $Res Function(_TaskChecklistItemModel) _then;

/// Create a copy of TaskChecklistItemModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? taskChecklistId = null,Object? title = null,Object? isPhotoRequired = null,Object? sortOrder = null,Object? isCompleted = null,Object? completedAt = freezed,Object? completedBy = freezed,Object? photoUrl = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_TaskChecklistItemModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,taskChecklistId: null == taskChecklistId ? _self.taskChecklistId : taskChecklistId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isPhotoRequired: null == isPhotoRequired ? _self.isPhotoRequired : isPhotoRequired // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedBy: freezed == completedBy ? _self.completedBy : completedBy // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
