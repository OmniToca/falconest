import 'package:freezed_annotation/freezed_annotation.dart';

import 'checklist_json_converters.dart';

part 'checklist_template_model.freezed.dart';
part 'checklist_template_model.g.dart';

/// Šablona checklistu – tabulka `checklist_templates` (Supabase).
///
/// PROČ: Admin definuje šablony; mobil je typicky neukládá do Driftu, ale model
/// slouží pro API/admin a budoucí načítání přes síť.
@freezed
abstract class ChecklistTemplateModel with _$ChecklistTemplateModel {
  const ChecklistTemplateModel._();

  const factory ChecklistTemplateModel({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    required String name,
    String? description,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') @NullableIsoDateTimeConverter() DateTime? createdAt,
    @JsonKey(name: 'updated_at') @NullableIsoDateTimeConverter() DateTime? updatedAt,
  }) = _ChecklistTemplateModel;

  factory ChecklistTemplateModel.fromJson(Map<String, dynamic> json) =>
      _$ChecklistTemplateModelFromJson(json);
}
