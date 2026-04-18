import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Jedna fotka z checklistu s názvem položky (pro popisek v galerii majitele).
class OwnerTaskChecklistPhoto {
  const OwnerTaskChecklistPhoto({required this.title, required this.photoUrl});

  final String title;
  final String photoUrl;
}

/// Načte všechny neprázdné [photo_url] z [task_checklist_items] pro daný [taskId].
///
/// PROČ: Důkazní fotky z terénu často žijí u položek checklistu, ne v [tasks.media_urls].
/// SECURITY: RLS [task_checklist_items_select_property_owner] + vlastnictví bytu.
final ownerTaskChecklistPhotosProvider =
    FutureProvider.autoDispose.family<List<OwnerTaskChecklistPhoto>, String>((ref, taskId) async {
  final tid = taskId.trim();
  if (tid.isEmpty) return [];

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  try {
    final clRaw = await SupabaseService.safeFrom('task_checklists', tenantId)
        .select('id')
        .eq('task_id', tid);
    final clList = clRaw is List ? clRaw : <dynamic>[];
    final checklistIds = <String>[];
    for (final e in clList) {
      if (e is! Map) continue;
      final id = (e['id']?.toString() ?? '').trim();
      if (id.isNotEmpty) checklistIds.add(id);
    }
    if (checklistIds.isEmpty) return [];

    final itemsRaw = await SupabaseService.safeFrom('task_checklist_items', tenantId)
        .select('title, photo_url')
        .inFilter('task_checklist_id', checklistIds)
        .order('sort_order');

    final items = itemsRaw is List ? itemsRaw : <dynamic>[];
    final out = <OwnerTaskChecklistPhoto>[];
    for (final e in items) {
      if (e is! Map) continue;
      final url = (e['photo_url']?.toString() ?? '').trim();
      if (url.isEmpty) continue;
      final title = (e['title']?.toString() ?? '').trim();
      out.add(OwnerTaskChecklistPhoto(title: title.isEmpty ? '—' : title, photoUrl: url));
    }
    return out;
  } catch (_) {
    return [];
  }
});
