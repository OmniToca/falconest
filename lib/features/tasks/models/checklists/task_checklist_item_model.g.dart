// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_checklist_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskChecklistItemModel _$TaskChecklistItemModelFromJson(
  Map<String, dynamic> json,
) => _TaskChecklistItemModel(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  taskChecklistId: json['task_checklist_id'] as String,
  title: json['title'] as String,
  isPhotoRequired: json['is_photo_required'] as bool? ?? false,
  sortOrder: (json['sort_order'] as num).toInt(),
  isCompleted: json['is_completed'] as bool? ?? false,
  completedAt: const NullableIsoDateTimeConverter().fromJson(
    json['completed_at'],
  ),
  completedBy: json['completed_by'] as String?,
  photoUrl: json['photo_url'] as String?,
  createdAt: const NullableIsoDateTimeConverter().fromJson(json['created_at']),
  updatedAt: const NullableIsoDateTimeConverter().fromJson(json['updated_at']),
);

Map<String, dynamic> _$TaskChecklistItemModelToJson(
  _TaskChecklistItemModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'task_checklist_id': instance.taskChecklistId,
  'title': instance.title,
  'is_photo_required': instance.isPhotoRequired,
  'sort_order': instance.sortOrder,
  'is_completed': instance.isCompleted,
  'completed_at': const NullableIsoDateTimeConverter().toJson(
    instance.completedAt,
  ),
  'completed_by': instance.completedBy,
  'photo_url': instance.photoUrl,
  'created_at': const NullableIsoDateTimeConverter().toJson(instance.createdAt),
  'updated_at': const NullableIsoDateTimeConverter().toJson(instance.updatedAt),
};
