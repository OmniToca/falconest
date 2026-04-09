import 'package:freezed_annotation/freezed_annotation.dart';

import 'checklist_json_converters.dart';

part 'task_checklist_model.freezed.dart';
part 'task_checklist_model.g.dart';

/// Instance checklistu u úkolu – tabulka `task_checklists` (Supabase).
///
/// PROČ: Jeden řádek na úkol; `templateId` je jen informace o původu šablony.
@freezed
abstract class TaskChecklistModel with _$TaskChecklistModel {
  const TaskChecklistModel._();

  const factory TaskChecklistModel({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'task_id') required String taskId,
    @JsonKey(name: 'template_id') String? templateId,
    @JsonKey(name: 'created_at') @NullableIsoDateTimeConverter() DateTime? createdAt,
    @JsonKey(name: 'updated_at') @NullableIsoDateTimeConverter() DateTime? updatedAt,
  }) = _TaskChecklistModel;

  factory TaskChecklistModel.fromJson(Map<String, dynamic> json) =>
      _$TaskChecklistModelFromJson(json);
}
