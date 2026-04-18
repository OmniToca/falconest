import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Stav úkolu považovaný za dokončený – tyto úkoly patří do záložky Historie, ne do aktivního Kanbanu.
bool isOwnerTaskCompletedStatus(String? status) {
  final s = (status ?? '').trim().toLowerCase();
  return s == 'completed' ||
      s == 'done' ||
      s == 'hotovo' ||
      s == 'dokončeno' ||
      s == 'dokonceno';
}

/// Provider **aktivních** úkolů pro Klientský portál (majitel bytu).
///
/// Načítá úkoly u bytů majitele. RLS (tasks_property_owner_select_own_apartments)
/// automaticky omezí výsledky na apartmány z apartment_owners.
///
/// Vyloučí dokončené stavy (ty jsou v [ownerTaskHistoryProvider]) a vyfakturované řádky.
///
/// SECURITY: Odstranění interních návrhů z pohledu majitele.
/// Statusy draft, Návrh apod. jsou striktně interní – majitel je neuvidí.
final ownerTasksProvider = FutureProvider<List<TaskRow>>((ref) async {
  final apartments = await ref.read(ownerApartmentsProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};

  final ownedApartmentIds = apartments
      .map((a) => a.id)
      .where((id) => id.isNotEmpty)
      .toList();

  // Early exit: uživatel nevlastní žádný apartmán – ušetříme dotaz do DB.
  if (ownedApartmentIds.isEmpty) return [];

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  try {
    // BUGFIX: Dvojitá ochrana – explicitní stažení úkolů POUZE pro byty vlastněné tímto uživatelem.
    // SECURITY: Klientský portál nikdy nestahuje tasks bez parametru apartment_id omezeného na vlastněné byty.
    // Vynecháme JOIN na profiles (assigned_to) – ochrana soukromí, jména personálu nenačítáme.
    // PROČ: Archivace. Vyfakturované úkoly (invoiced_at != null) schováváme z aktivních pohledů.
    final tasksResponse = await SupabaseService.safeFrom('tasks', tenantId)
        .select(
          '''
          *,
          apartments(name),
          reservations(guest_name, start_date, end_date, guest_adults, guest_children)
          ''',
        )
        .inFilter('apartment_id', ownedApartmentIds)
        .isFilter('deleted_at', null)
        .isFilter('invoiced_at', null)
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

    // SECURITY: Odstranění interních návrhů; aktivní záložka bez dokončených úkolů.
    return allTasks
        .where((t) => !_isDraftStatus(t.status))
        .where((t) => !isOwnerTaskCompletedStatus(t.status))
        .toList();
  } on PostgrestException {
    rethrow;
  }
});

/// Historie dokončené práce u bytů majitele (včetně již vyfakturovaných).
///
/// PROČ: Archiv transparentnosti – majitel vidí, co už proběhlo, seřazeno od nejnovějšího.
final ownerTaskHistoryProvider = FutureProvider<List<TaskRow>>((ref) async {
  final apartments = await ref.read(ownerApartmentsProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};

  final ownedApartmentIds = apartments
      .map((a) => a.id)
      .where((id) => id.isNotEmpty)
      .toList();

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
        .inFilter('apartment_id', ownedApartmentIds)
        .isFilter('deleted_at', null)
        .order('completed_at', ascending: false);

    final list = tasksResponse as List;
    final nameByProfileId = <String, String>{};

    final allTasks = list
        .map((e) => TaskRow.fromSupabaseRow(
              e as Map<String, dynamic>,
              apartmentById: apartmentById,
              nameByProfileId: nameByProfileId,
            ))
        .where((t) => !_isDraftStatus(t.status))
        .where((t) => isOwnerTaskCompletedStatus(t.status))
        .toList();

    allTasks.sort((a, b) {
      final ca = a.completedAt;
      final cb = b.completedAt;
      if (ca != null && cb != null) return cb.compareTo(ca);
      if (ca != null) return -1;
      if (cb != null) return 1;
      return b.dueDate.compareTo(a.dueDate);
    });

    return allTasks;
  } on PostgrestException {
    rethrow;
  }
});

/// Určí, zda je status úkolu interní návrh – majitel tyto úkoly neuvidí.
///
/// Zahrnuje pouze draft a Návrh. Status "pending" NEFILTRUJEME – majitel musí
/// vidět své nahlášené závady (údržbu), které se zakládají se statusem pending (Nové).
bool _isDraftStatus(String? status) {
  if (status == null || status.trim().isEmpty) return false;
  final lower = status.trim().toLowerCase();
  return lower == 'draft' || lower == 'návrh' || lower == 'navrh';
}
