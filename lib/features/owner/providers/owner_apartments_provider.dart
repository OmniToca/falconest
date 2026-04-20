import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Stav bytu v Klientském portálu — kombinace pobytu hosta a workflow úklidu.
///
/// Určuje vizuální reprezentaci v UI – barva Chipu, ikona, lokalizovaný text.
enum OwnerApartmentStatus {
  /// Probíhá aktivní rezervace (host v intervalu pobytu) — má přednost před úklidem.
  occupied,

  /// Poslední úkol completed → zelená
  clean,

  /// Poslední úkol in_progress → modrá/oranžová
  cleaningInProgress,

  /// Poslední úkol pending → červená
  pendingCleaning,

  /// Byt nemá žádné úkoly (pro úklid) → šedá
  unknown,
}

/// Model bytu majitele včetně vypočteného stavu.
///
/// [status] se určuje nejdříve z rezervací (obsazeno), jinak z nejnovějšího úkolu úklidu.
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

/// Provider načítající byty majitele z Supabase včetně vnořených úkolů a rezervací.
///
/// BUGFIX: Striktní filtrace apartmánů – majitel vidí pouze ty byty, se kterými
/// má vazbu v tabulce apartment_owners. Dvoukrokový dotaz zajišťuje obranu v hloubce
/// i při případné chybě RLS.
///
/// Logika výpočtu stavu bytu (stavová mašina):
/// 1) Existuje platná rezervace, jejíž interval pokrývá „teď“? → [OwnerApartmentStatus.occupied].
/// 2) Jinak: z úkolů úklidu (scheduled_start ≤ dnes, ne draft) vezmi nejnovější a mapuj status.
final ownerApartmentsProvider = FutureProvider<List<OwnerApartmentWithStatus>>((
  ref,
) async {
  final profileId = ref.watch(authNotifierProvider).state.profileId;
  if (profileId == null || profileId.isEmpty) return [];
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  // Krok 1: Získat pouze ID apartmánů přiřazených majiteli v apartment_owners.
  // PROČ safeFrom: stejná tenant vrstva jako v adminu (sloupec tenant_id na apartment_owners).
  final ownersRes = await SupabaseService.safeFrom('apartment_owners', tenantId)
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
  final response = await SupabaseService.safeFrom('apartments', tenantId)
      .select('id, name, address, tasks(scheduled_start, status)')
      .inFilter('id', apartmentIds)
      .isFilter('deleted_at', null);

  // Krok 3: Rezervace pro detekci obsazenosti (ne smazané; zrušené vyloučíme v parseru).
  final reservationsByApartment = await _fetchReservationsForOccupancy(
    tenantId: tenantId,
    apartmentIds: apartmentIds,
  );

  return _parseAndComputeStatus(response as List, reservationsByApartment);
});

/// Načte rezervace potřebné pro rozhodnutí „obsazeno teď“ (datum + časy odjezdu/příjezdu).
Future<Map<String, List<Map<String, dynamic>>>> _fetchReservationsForOccupancy({
  required String tenantId,
  required List<String> apartmentIds,
}) async {
  final map = <String, List<Map<String, dynamic>>>{};
  try {
    final res = await SupabaseService.safeFrom('reservations', tenantId)
        .select(
          'apartment_id, start_date, end_date, status, arrival_time, departure_time',
        )
        .inFilter('apartment_id', apartmentIds)
        .isFilter('deleted_at', null);
    for (final row in (res as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final aid = (m['apartment_id'] as String?)?.trim() ?? '';
      if (aid.isEmpty) continue;
      map.putIfAbsent(aid, () => []).add(m);
    }
  } catch (_) {
    // Bez rezervací pokračujeme jen úklidem (kompatibilita se staršími schématy).
  }
  return map;
}

/// Parsuje odpověď z Supabase a vypočte stav pro každý byt.
///
/// [raw] je seznam map – každý prvek odpovídá jednomu bytu.
/// Pole "tasks" může být List<Map> nebo null (RLS/prázdný vztah).
///
/// Výpočet stavu (detailně):
/// - Nejdřív obsazenost z rezervací ([_isApartmentOccupiedNow]).
/// - Úkoly seřadíme podle scheduled_start sestupně (nejnovější první).
/// - První úkol v seznamu = ten s nejpozdějším datem = aktuálně nejrelevantnější pro úklid.
/// - completed → byt je čistý; in_progress → probíhá úklid; pending → čeká.
/// - cancelled se přeskakuje – bereme další úkol (pokud existuje).
///
/// BUGFIX – před výpočtem stavu z úkolů filtrujeme:
/// A) Návrhy (draft/návrh): Úkol ve stavu návrh je jen k odsouhlasení – majitel vidí
///    aktuální stav bytu podle potvrzených úkolů, ne podle návrhů.
/// B) Dalekou budoucnost: Úkol se scheduled_start > konec dneška ignorujeme – úklid
///    na příští týden nesmí způsobit, že dnes byt svítí „čeká na úklid".
List<OwnerApartmentWithStatus> _parseAndComputeStatus(
  List<dynamic> raw,
  Map<String, List<Map<String, dynamic>>> reservationsByApartment,
) {
  final result = <OwnerApartmentWithStatus>[];
  final now = DateTime.now();
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  for (final item in raw) {
    final map = item as Map<String, dynamic>;
    final id = map['id'] as String? ?? '';
    final name = map['name'] as String? ?? '';
    final address = map['address'] as String?;

    final resRows = reservationsByApartment[id] ?? [];
    if (_isApartmentOccupiedNow(resRows, now)) {
      result.add(
        OwnerApartmentWithStatus(
          id: id,
          name: name,
          address: address,
          status: OwnerApartmentStatus.occupied,
        ),
      );
      continue;
    }

    // tasks může být List (join vrací pole) nebo null
    final tasksRaw = map['tasks'];
    List<Map<String, dynamic>> tasks = [];
    if (tasksRaw is List) {
      tasks = tasksRaw
          .whereType<Map<String, dynamic>>()
          .where((t) => t['scheduled_start'] != null)
          .where((t) {
            // A) Ignorujeme návrhy – majitel vidí stav podle potvrzených úkolů.
            final s = (t['status'] as String? ?? '').trim().toLowerCase();
            if (_isDraftOrProposalStatus(s)) return false;
            // B) Ignorujeme úkoly v budoucnu – scheduled_start musí být ≤ konec dneška.
            final rawStart = t['scheduled_start'];
            DateTime? scheduled;
            if (rawStart is String) {
              scheduled = DateTime.tryParse(rawStart);
            } else if (rawStart is DateTime) {
              scheduled = rawStart;
            }
            if (scheduled == null || scheduled.isAfter(endOfToday)) return false;
            return true;
          })
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

/// Stav úkolu znamená „návrh k odsouhlasení" – pro výpočet stavu bytu ignorujeme.
bool _isDraftOrProposalStatus(String status) {
  return status == 'draft' || status == 'návrh' || status == 'navrh';
}

/// True, pokud [now] leží u některé rezervace v aktivním pobytu (ne zrušený, ne odhlášený).
///
/// PROČ: Štítek „Čistý“ z posledního úklidu nesmí přebít realitu, že v bytě právě host přespává.
bool _isApartmentOccupiedNow(
  List<Map<String, dynamic>> reservationRows,
  DateTime now,
) {
  for (final row in reservationRows) {
    if (_reservationRowCoversNow(row, now)) return true;
  }
  return false;
}

DateTime? _parseDynamicDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Interval pobytu: od začátku dne start_date (případně od arrival_time) do konce dne end_date
/// nebo dříve podle departure_time v den odjezdu (checkout).
bool _reservationRowCoversNow(Map<String, dynamic> row, DateTime now) {
  final status = (row['status'] as String?)?.trim().toLowerCase() ?? '';
  if (status == 'cancelled' || status == 'checked_out') return false;

  final startDate = _parseDynamicDateTime(row['start_date']);
  final endDate = _parseDynamicDateTime(row['end_date']);
  if (startDate == null || endDate == null) return false;

  final startDay = DateTime(startDate.year, startDate.month, startDate.day);
  final endCalDay = DateTime(endDate.year, endDate.month, endDate.day);
  var intervalStart = startDay;

  final arrival = _parseDynamicDateTime(row['arrival_time']);
  if (arrival != null) {
    final arrDay = DateTime(arrival.year, arrival.month, arrival.day);
    if (!arrDay.isBefore(startDay) && !arrDay.isAfter(endCalDay)) {
      if (arrDay == startDay && arrival.isAfter(intervalStart)) {
        intervalStart = arrival;
      }
    }
  }

  var intervalEnd = DateTime(
    endCalDay.year,
    endCalDay.month,
    endCalDay.day,
    23,
    59,
    59,
    999,
  );

  final departure = _parseDynamicDateTime(row['departure_time']);
  if (departure != null) {
    final depDay = DateTime(departure.year, departure.month, departure.day);
    if (depDay == endCalDay && departure.isBefore(intervalEnd)) {
      intervalEnd = departure;
    }
  }

  return !now.isBefore(intervalStart) && !now.isAfter(intervalEnd);
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

  switch (status.toLowerCase().trim()) {
    case 'completed':
    case 'done':
    case 'hotovo':
      return OwnerApartmentStatus.clean;
    case 'in_progress':
      return OwnerApartmentStatus.cleaningInProgress;
    case 'pending':
    case 'assigned':
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
