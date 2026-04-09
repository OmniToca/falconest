import 'package:freezed_annotation/freezed_annotation.dart';

import 'checklist_json_converters.dart';

part 'checklist_template_item_model.freezed.dart';
part 'checklist_template_item_model.g.dart';

/// Položka šablony – tabulka `checklist_template_items` (Supabase).
@freezed
abstract class ChecklistTemplateItemModel with _$ChecklistTemplateItemModel {
  const ChecklistTemplateItemModel._();

  const factory ChecklistTemplateItemModel({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'template_id') required String templateId,
    required String title,
    @JsonKey(name: 'is_photo_required') @Default(false) bool isPhotoRequired,
    @JsonKey(name: 'sort_order') required int sortOrder,
    @JsonKey(name: 'created_at') @NullableIsoDateTimeConverter() DateTime? createdAt,
    @JsonKey(name: 'updated_at') @NullableIsoDateTimeConverter() DateTime? updatedAt,
  }) = _ChecklistTemplateItemModel;

  factory ChecklistTemplateItemModel.fromJson(Map<String, dynamic> json) =>
      _$ChecklistTemplateItemModelFromJson(json);
}
