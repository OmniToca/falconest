import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Stav bytu odvozený od posledního (nejnovějšího) úkolu.
///
/// Určuje vizuální reprezentaci v UI – barva Chipu, ikona, lokalizovaný text.
enum OwnerApartmentStatus {
  /// Poslední úkol completed → zelená
  clean,

  /// Poslední úkol in_progress → modrá/oranžová
  cleaningInProgress,

  /// Poslední úkol pending → červená
  pendingCleaning,

  /// Byt nemá žádné úkoly → šedá
  unknown,
}

/// Model bytu majitele včetně vypočteného stavu.
///
/// [status] se určuje z nejnovějšího úkolu (seřazeného podle scheduled_start
/// sestupně) – první úkol v pořadí = nejbližší/m nejnovější.
class OwnerApartmentWithStatus {
  const OwnerApartmentWithStatus({
    required this.id,
    required this.name,
    this.address,
    required this.status,
  });

  final String id;
  final String name;
  final String? address;
  final OwnerApartmentStatus status;
}

/// Provider načítající byty majitele z Supabase včetně vnořených úkolů.
///
/// BUGFIX: Striktní filtrace apartmánů – majitel vidí pouze ty byty, se kterými
/// má vazbu v tabulce apartment_owners. Dvoukrokový dotaz zajišťuje obranu v hloubce
/// i při případné chybě RLS.
///
/// Logika výpočtu stavu bytu:
/// 1. Pro každý byt vezmeme pole tasks (vnořené z joinu).
/// 2. Seřadíme úkoly podle scheduled_start sestupně (od nejnovějšího).
/// 3. Vezmeme první úkol (nejnovější) a podle jeho status určíme stav:
///    - completed → Čistý (zelená)
///    - in_progress → Probíhá úklid (modrá/oranžová)
///    - pending → Čeká na úklid (červená)
/// 4. Pokud byt nemá žádné úkoly → Neznámý stav (šedá).
final ownerApartmentsProvider = FutureProvider<List<OwnerApartmentWithStatus>>((
  ref,
) async {
  final profileId = ref.watch(authNotifierProvider).state.profileId;
  if (profileId == null || profileId.isEmpty) return [];

  // Krok 1: Získat pouze ID apartmánů přiřazených majiteli v apartment_owners.
  final ownersRes = await SupabaseService.client
      .from('apartment_owners')
      .select('apartment_id')
      .eq('owner_id', profileId)
      .isFilter('deleted_at', null);

  final ownerList = ownersRes as List;
  if (ownerList.isEmpty) return [];

  final apartmentIds = ownerList
      .map((e) => (e as Map)['apartment_id']?.toString())
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>()
      .toList();

  if (apartmentIds.isEmpty) return [];

  // Krok 2: Načíst apartmány s úkoly – pouze ty z výše získaného seznamu.
  final response = await SupabaseService.client
      .from('apartments')
      .select('id, name, address, tasks(scheduled_start, status)')
      .inFilter('id', apartmentIds)
      .isFilter('deleted_at', null);

  return _parseAndComputeStatus(response as List);
});

/// Parsuje odpověď z Supabase a vypočte stav pro každý byt.
///
/// [raw] je seznam map – každý prvek odpovídá jednomu bytu.
/// Pole "tasks" může být List<Map> nebo null (RLS/prázdný vztah).
///
/// Výpočet stavu (detailně):
/// - Úkoly seřadíme podle scheduled_start sestupně (b.compareTo(a) = nejnovější první).
/// - První úkol v seznamu = ten s nejpozdějším datem = aktuálně nejrelevantnější.
/// - completed → byt je čistý; in_progress → probíhá úklid; pending → čeká.
/// - cancelled se přeskakuje – bereme další úkol (pokud existuje).
List<OwnerApartmentWithStatus> _parseAndComputeStatus(List<dynamic> raw) {
  final result = <OwnerApartmentWithStatus>[];

  for (final item in raw) {
    final map = item as Map<String, dynamic>;
    final id = map['id'] as String? ?? '';
    final name = map['name'] as String? ?? '';
    final address = map['address'] as String?;

    // tasks může být List (join vrací pole) nebo null
    final tasksRaw = map['tasks'];
    List<Map<String, dynamic>> tasks = [];
    if (tasksRaw is List) {
      tasks = tasksRaw
          .whereType<Map<String, dynamic>>()
          .where((t) => t['scheduled_start'] != null)
          .toList();
    }

    // Seřazení podle scheduled_start sestupně (nejnovější první)
    tasks.sort((a, b) {
      final aStr = a['scheduled_start'] as String? ?? '';
      final bStr = b['scheduled_start'] as String? ?? '';
      return bStr.compareTo(aStr);
    });

    // Stav podle posledního (nejnovějšího) úkolu
    final status = _computeStatus(tasks);

    result.add(
      OwnerApartmentWithStatus(
        id: id,
        name: name,
        address: address,
        status: status,
      ),
    );
  }

  return result;
}

/// Vypočte stav bytu podle seznamu úkolů (už seřazených od nejnovějšího).
///
/// První úkol v seznamu = nejnovější (nejpozdější scheduled_start).
/// Ten určuje aktuální stav bytu – např. pokud byl včera úklid completed,
/// dnes je byt stále „čistý“. Prázdný seznam = unknown.
OwnerApartmentStatus _computeStatus(List<Map<String, dynamic>> tasksSorted) {
  if (tasksSorted.isEmpty) return OwnerApartmentStatus.unknown;

  final lastTask = tasksSorted.first;
  final status = lastTask['status'] as String? ?? '';

  switch (status) {
    case 'completed':
      return OwnerApartmentStatus.clean;
    case 'in_progress':
      return OwnerApartmentStatus.cleaningInProgress;
    case 'pending':
      return OwnerApartmentStatus.pendingCleaning;
    case 'cancelled':
      // Zrušený úkol – vezmeme další v pořadí (pokud existuje)
      if (tasksSorted.length > 1) {
        return _computeStatus(tasksSorted.sublist(1));
      }
      return OwnerApartmentStatus.unknown;
    default:
      return OwnerApartmentStatus.unknown;
  }
}
