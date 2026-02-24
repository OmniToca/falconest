import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Provider úkolů pro Klientský portál (majitel bytu).
///
/// Načítá úkoly u bytů majitele. RLS (tasks_property_owner_select_own_apartments)
/// automaticky omezí výsledky na apartmány z apartment_owners.
///
/// SECURITY: Odstranění interních návrhů z pohledu majitele.
/// Statusy draft, pending, Návrh apod. jsou striktně interní – majitel je neuvidí.
final ownerTasksProvider = FutureProvider<List<TaskRow>>((ref) async {
  final apartments = await ref.read(ownerApartmentsProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};

  final ownedApartmentIds = apartments
      .map((a) => a.id)
      .where((id) => id.isNotEmpty)
      .toList();

  // Early exit: uživatel nevlastní žádný apartmán – ušetříme dotaz do DB.
  if (ownedApartmentIds.isEmpty) return [];

  try {
    // BUGFIX: Dvojitá ochrana – explicitní stažení úkolů POUZE pro byty vlastněné tímto uživatelem.
    // SECURITY: Klientský portál nikdy nestahuje tasks bez parametru apartment_id omezeného na vlastněné byty.
    // Vynecháme JOIN na profiles (assigned_to) – ochrana soukromí, jména personálu nenačítáme.
    final tasksResponse = await SupabaseService.client
        .from('tasks')
        .select(
          '''
          *,
          apartments(name),
          reservations(guest_name, start_date, end_date, guest_adults, guest_children)
          ''',
        )
        .inFilter('apartment_id', ownedApartmentIds)
        .isFilter('deleted_at', null)
        .order('due_date', ascending: true);

    final list = tasksResponse as List;
    final nameByProfileId = <String, String>{}; // Prázdná mapa – jména personálu neukazujeme.

    final allTasks = list
        .map((e) => TaskRow.fromSupabaseRow(
              e as Map<String, dynamic>,
              apartmentById: apartmentById,
              nameByProfileId: nameByProfileId,
            ))
        .toList();

    // SECURITY: Odstranění interních návrhů z pohledu majitele.
    return allTasks.where((t) => !_isDraftStatus(t.status)).toList();
  } on PostgrestException {
    rethrow;
  }
});

/// Určí, zda je status úkolu interní návrh – majitel tyto úkoly neuvidí.
///
/// Zahrnuje: draft, pending, Návrh a jazykové varianty (case-insensitive).
bool _isDraftStatus(String? status) {
  if (status == null || status.trim().isEmpty) return false;
  final lower = status.trim().toLowerCase();
  return lower == 'draft' ||
      lower == 'pending' ||
      lower == 'návrh' ||
      lower == 'navrh';
}
