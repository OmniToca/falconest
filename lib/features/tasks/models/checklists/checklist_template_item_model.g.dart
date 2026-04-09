// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_template_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChecklistTemplateItemModel _$ChecklistTemplateItemModelFromJson(
  Map<String, dynamic> json,
) => _ChecklistTemplateItemModel(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  templateId: json['template_id'] as String,
  title: json['title'] as String,
  isPhotoRequired: json['is_photo_required'] as bool? ?? false,
  sortOrder: (json['sort_order'] as num).toInt(),
  createdAt: const NullableIsoDateTimeConverter().fromJson(json['created_at']),
  updatedAt: const NullableIsoDateTimeConverter().fromJson(json['updated_at']),
);

Map<String, dynamic> _$ChecklistTemplateItemModelToJson(
  _ChecklistTemplateItemModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'template_id': instance.templateId,
  'title': instance.title,
  'is_photo_required': instance.isPhotoRequired,
  'sort_order': instance.sortOrder,
  'created_at': const NullableIsoDateTimeConverter().toJson(instance.createdAt),
  'updated_at': const NullableIsoDateTimeConverter().toJson(instance.updatedAt),
};
