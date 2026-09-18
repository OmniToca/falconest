import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_reservations_repository.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_repository.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';

/// Rezervace překrývající **aktuální měsíc** – přesný SQL řez pro teploměr obsazenosti na kartě bytu.
///
/// PROČ samostatný stream: [adminReservationsProvider] má tvrdý limit 500 řádků; dlouhé pobyty
/// by jinak vypadly z cache a měsíční obsazenost by klamala. Tento zdroj ignoruje filtry z jiných obrazovek.
final currentMonthReservationsProvider =
    StreamProvider<List<ReservationRow>>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final nameMap = await ref.watch(apartmentsNameByIdLiteProvider.future);
  final apartmentIds = nameMap.keys.where((id) => id.isNotEmpty).toList();
  if (apartmentIds.isEmpty) {
    yield [];
    return;
  }

  await for (final rawList in AdminReservationsRepository.instance
      .watchReservationsOverlappingCurrentMonth(apartmentIds, tenantId)) {
    yield _parseReservationRows(
      rawList,
      nameMap,
      debugLabel: 'currentMonthReservationsProvider',
    );
  }
});

/// Rezervace pro výpočet denního stavu bytu (obsazeno / k úklidu / uklizeno).
///
/// PROČ: Odděleně od globálního admin streamu s limitem 500; okno cca 400 dní + zítřek pokrývá checkouty
/// a aktivní pobyty bez vazby na jiné UI filtry.
final apartmentStatusContextReservationsProvider =
    StreamProvider<List<ReservationRow>>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final nameMap = await ref.watch(apartmentsNameByIdLiteProvider.future);
  final apartmentIds = nameMap.keys.where((id) => id.isNotEmpty).toList();
  if (apartmentIds.isEmpty) {
    yield [];
    return;
  }

  await for (final rawList in AdminReservationsRepository.instance
      .watchReservationsForApartmentStatusContext(apartmentIds, tenantId)) {
    yield _parseReservationRows(
      rawList,
      nameMap,
      debugLabel: 'apartmentStatusContextReservationsProvider',
    );
  }
});

/// Úkoly (úklidy) vstupující do výpočtu stavu apartmánu – nezávislé na záložce Úkoly a [selectedTaskMonthProvider].
///
/// PROČ název „today“ v uživatelské specifikaci: jde o **provozní kontext pro dnešek** (splatnost do konce dne
/// + nedávné dokončené úklidy pro porovnání s checkoutem). Nejsou to jen úkoly s datem == dnes – turnover
/// vyžaduje historii dokončení.
final todayApartmentTasksProvider = StreamProvider<List<TaskRow>>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final apartmentById = await ref.watch(apartmentsNameByIdLiteProvider.future);
  final nameByProfileId = await ref.watch(teamNameByProfileIdLiteProvider.future);

  await for (final rawList
      in AdminTasksRepository.instance.watchTasksRawForApartmentStatus(tenantId)) {
    final rows = <TaskRow>[];
    for (final raw in rawList) {
      try {
        rows.add(
          TaskRow.fromSupabaseRow(
            Map<String, dynamic>.from(raw),
            apartmentById: apartmentById,
            nameByProfileId: nameByProfileId,
          ),
        );
      } catch (e, st) {
        AppLogger.error('todayApartmentTasksProvider: řádek úkolu přeskočen', e, st);
      }
    }
    yield rows;
  }
});

/// Parsování rezervací po jednom řádku – jeden poškozený JSON nesmí shodit celou Nástěnku.
List<ReservationRow> _parseReservationRows(
  List<Map<String, dynamic>> rawList,
  Map<String, String> nameMap, {
  required String debugLabel,
}) {
  final rows = <ReservationRow>[];
  for (final raw in rawList) {
    try {
      final enriched = Map<String, dynamic>.from(raw);
      if (enriched['apartments'] == null &&
          nameMap[raw['apartment_id']?.toString()] != null) {
        enriched['apartments'] = {
          'name': nameMap[raw['apartment_id']?.toString()],
        };
      }
      rows.add(ReservationRow.fromJson(enriched));
    } catch (e, st) {
      AppLogger.error('$debugLabel: řádek rezervace přeskočen', e, st);
    }
  }
  return rows;
}
