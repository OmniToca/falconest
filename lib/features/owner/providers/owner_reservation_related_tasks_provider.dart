import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Úkoly navázané na rezervaci ([tasks.reservation_id]) – jen u bytů majitele.
///
/// PROČ: V Kanbanu pobytů majitel vidí související servisní práci (úklid, transfer…).
/// SECURITY: [inFilter] na vlastněné apartmány + RLS; rezervace už pochází z owner výpisu.
final ownerReservationRelatedTasksProvider =
    FutureProvider.autoDispose.family<List<TaskRow>, String>((ref, reservationId) async {
  final rid = reservationId.trim();
  if (rid.isEmpty) return [];

  final apartments = await ref.read(ownerApartmentsProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final ownedApartmentIds = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toList();
  if (ownedApartmentIds.isEmpty) return [];

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  try {
    final tasksResponse = await SupabaseService.safeFrom('tasks', tenantId)
        .select(
          '''
          *,
          apartments(name),
          reservations(guest_name, start_date, end_date, guest_adults, guest_children)
          ''',
        )
        .eq('reservation_id', rid)
        .inFilter('apartment_id', ownedApartmentIds)
        .isFilter('deleted_at', null)
        .order('scheduled_start', ascending: true);

    final list = tasksResponse as List;
    final nameByProfileId = <String, String>{};

    return list
        .map((e) => TaskRow.fromSupabaseRow(
              e as Map<String, dynamic>,
              apartmentById: apartmentById,
              nameByProfileId: nameByProfileId,
            ))
        .where((t) => !_ownerRelatedTaskDraft(t.status))
        .toList();
  } on PostgrestException {
    return [];
  }
});

bool _ownerRelatedTaskDraft(String? status) {
  if (status == null || status.trim().isEmpty) return false;
  final lower = status.trim().toLowerCase();
  return lower == 'draft' || lower == 'návrh' || lower == 'navrh';
}
