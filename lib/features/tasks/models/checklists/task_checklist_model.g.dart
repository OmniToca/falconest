// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_checklist_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskChecklistModel _$TaskChecklistModelFromJson(
  Map<String, dynamic> json,
) => _TaskChecklistModel(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  taskId: json['task_id'] as String,
  templateId: json['template_id'] as String?,
  createdAt: const NullableIsoDateTimeConverter().fromJson(json['created_at']),
  updatedAt: const NullableIsoDateTimeConverter().fromJson(json['updated_at']),
);

Map<String, dynamic> _$TaskChecklistModelToJson(
  _TaskChecklistModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'task_id': instance.taskId,
  'template_id': instance.templateId,
  'created_at': const NullableIsoDateTimeConverter().toJson(instance.createdAt),
  'updated_at': const NullableIsoDateTimeConverter().toJson(instance.updatedAt),
};
