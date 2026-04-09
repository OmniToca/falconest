import 'package:freezed_annotation/freezed_annotation.dart';

import 'checklist_json_converters.dart';

part 'task_checklist_item_model.freezed.dart';
part 'task_checklist_item_model.g.dart';

/// Zkopírovaná položka checklistu u úkolu – tabulka `task_checklist_items` (Supabase).
///
/// PROČ: Worker mění `is_completed`, `photo_url`, `completed_at`; mapování snake_case
/// odpovídá migraci `20260328120000_dynamic_checklists_base.sql`.
@freezed
abstract class TaskChecklistItemModel with _$TaskChecklistItemModel {
  const TaskChecklistItemModel._();

  const factory TaskChecklistItemModel({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'task_checklist_id') required String taskChecklistId,
    required String title,
    @JsonKey(name: 'is_photo_required') @Default(false) bool isPhotoRequired,
    @JsonKey(name: 'sort_order') required int sortOrder,
    @JsonKey(name: 'is_completed') @Default(false) bool isCompleted,
    @JsonKey(name: 'completed_at') @NullableIsoDateTimeConverter() DateTime? completedAt,
    @JsonKey(name: 'completed_by') String? completedBy,
    @JsonKey(name: 'photo_url') String? photoUrl,
    @JsonKey(name: 'created_at') @NullableIsoDateTimeConverter() DateTime? createdAt,
    @JsonKey(name: 'updated_at') @NullableIsoDateTimeConverter() DateTime? updatedAt,
  }) = _TaskChecklistItemModel;

  factory TaskChecklistItemModel.fromJson(Map<String, dynamic> json) =>
      _$TaskChecklistItemModelFromJson(json);
}
