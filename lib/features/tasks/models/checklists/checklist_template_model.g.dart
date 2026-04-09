// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_template_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChecklistTemplateModel _$ChecklistTemplateModelFromJson(
  Map<String, dynamic> json,
) => _ChecklistTemplateModel(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  createdAt: const NullableIsoDateTimeConverter().fromJson(json['created_at']),
  updatedAt: const NullableIsoDateTimeConverter().fromJson(json['updated_at']),
);

Map<String, dynamic> _$ChecklistTemplateModelToJson(
  _ChecklistTemplateModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'name': instance.name,
  'description': instance.description,
  'is_active': instance.isActive,
  'created_at': const NullableIsoDateTimeConverter().toJson(instance.createdAt),
  'updated_at': const NullableIsoDateTimeConverter().toJson(instance.updatedAt),
};
