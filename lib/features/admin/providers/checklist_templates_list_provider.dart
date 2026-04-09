import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/repositories/checklist_template_repository.dart';
import 'package:falconest/features/tasks/models/checklists/checklist_template_model.dart';

/// Seznam šablon checklistů pro aktuální tenant (Admin).
///
/// PROČ: Samostatný [FutureProvider] pro obrazovku seznamu; po uložení editoru
/// zavolej [invalidateSelf] přes ref.invalidate(checklistTemplatesListProvider).
final checklistTemplatesListProvider =
    FutureProvider.autoDispose<List<ChecklistTemplateModel>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];
  return ChecklistTemplateRepository.instance.listTemplates(tenantId);
});
