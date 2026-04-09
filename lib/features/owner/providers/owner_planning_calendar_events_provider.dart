import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/owner/providers/owner_planning_calendar_provider.dart';
import 'package:falconest/features/owner/providers/owner_reservations_provider.dart';

/// Jedna událost v plánovacím kalendáři majitele – buď úkol, nebo rezervace.
///
/// Slouží k sjednocení zdrojů: úkoly (úklidy/údržba) a rezervace (obsazenost bytu)
/// v jednom seznamu pro týdenní pohled. Rezervace se vykreslují v All-Day hlavičce,
/// úkoly v časové mřížce (bez změny stávající matematiky pozic).
class OwnerCalendarEvent {
  const OwnerCalendarEvent({
    required this.isReservation,
    required this.start,
    required this.end,
    this.task,
    this.reservation,
  }) : assert(
         !isReservation || reservation != null,
         'Rezervace musí mít reservation',
       ),
       assert(isReservation || task != null, 'Úkol musí mít task');

  final bool isReservation;
  final DateTime start;
  final DateTime end;
  final PlanningTask? task;
  final OwnerReservation? reservation;
}

/// Konvence časů: příjezd 15:00, odjezd 10:00 (použito při rozsekání rezervace po dnech).
const int _arrivalHour = 15;
const int _departureHour = 10;

/// Provider sloučených událostí kalendáře pro majitele (úkoly + rezervace).
///
/// a) Načte úkoly pro týden přes [ownerPlanningCalendarTasksProvider].
/// b) Načte rezervace přes [ownerReservationsForPlanningCalendarProvider] (jen měsíc
///    obsahující [weekStart]), pak je vyfiltruje na překryv s daným týdnem.
/// c) Úkoly převede na [OwnerCalendarEvent] (start = scheduledStart, délka = [planningTaskBlockDurationMinutes]).
/// d) Rezervace rozseká po dnech: pro každý den v týdnu, který spadá do pobytu,
///    vytvoří jeden event (první den od 15:00, poslední do 10:00, střední celý den).
final ownerPlanningCalendarEventsProvider = FutureProvider.autoDispose
    .family<List<OwnerCalendarEvent>, DateTime>((ref, weekStart) async {
      ref.watch(ownerPlanningCalendarTasksProvider(weekStart));
      ref.watch(ownerReservationsForPlanningCalendarProvider(weekStart));

      final tasks = await ref.read(
        ownerPlanningCalendarTasksProvider(weekStart).future,
      );
      final reservationsRaw = await ref.read(
        ownerReservationsForPlanningCalendarProvider(weekStart).future,
      );
      final reservations = reservationsRaw
          .where((r) => r.status != 'cancelled')
          .toList();

      final weekStartNorm = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );

      final events = <OwnerCalendarEvent>[];

      for (final t in tasks) {
        final durationMinutes = planningTaskBlockDurationMinutes(t);
        final start = t.scheduledStart;
        final end = start.add(Duration(minutes: durationMinutes));
        events.add(
          OwnerCalendarEvent(
            isReservation: false,
            start: start,
            end: end,
            task: t,
            reservation: null,
          ),
        );
      }

      for (final r in reservations) {
        final startDay = DateTime(
          r.startDate.year,
          r.startDate.month,
          r.startDate.day,
        );
        final endDay = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);

        for (var d = 0; d < 7; d++) {
          final day = weekStartNorm.add(Duration(days: d));
          if (day.isBefore(startDay) || day.isAfter(endDay)) continue;

          final isFirstDay =
              day.year == startDay.year &&
              day.month == startDay.month &&
              day.day == startDay.day;
          final isLastDay =
              day.year == endDay.year &&
              day.month == endDay.month &&
              day.day == endDay.day;

          final start = DateTime(
            day.year,
            day.month,
            day.day,
            isFirstDay ? _arrivalHour : 0,
            0,
          );
          final end = DateTime(
            day.year,
            day.month,
            day.day,
            isLastDay ? _departureHour : 23,
            isLastDay ? 0 : 59,
          );

          events.add(
            OwnerCalendarEvent(
              isReservation: true,
              start: start,
              end: end,
              task: null,
              reservation: r,
            ),
          );
        }
      }

      return events;
    });
