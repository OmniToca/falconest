import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';

/// Hodnoty dynamicky vypočítaného stavu apartmánu – vracíme i18n klíče (ne české texty).
/// Volající má použít status.tr() pro lokalizovaný výstup.
const String apartmentStatusOccupied = 'apartments.status.occupied';
const String apartmentStatusNeedsCleaning = 'apartments.status.to_clean';
const String apartmentStatusClean = 'apartments.status.clean';

/// Parsuje datum z formátu DD.MM.YYYY nebo DD.MM.YYYY HH:mm na DateTime (pouze datum).
DateTime? _parseReservationDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.trim().split(' ');
  final dStr = parts[0];
  final dParts = dStr.split('.');
  if (dParts.length < 3) return null;
  try {
    return DateTime(
      int.parse(dParts[2]),
      int.parse(dParts[1]),
      int.parse(dParts[0]),
    );
  } catch (_) {
    return null;
  }
}

/// KROK A: Dnešní datum spadá do intervalu [checkIn, checkOut] rezervace?
bool _isTodayWithinReservation(String? checkIn, String? checkOut) {
  final start = _parseReservationDate(checkIn);
  final end = _parseReservationDate(checkOut);
  if (start == null || end == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  return !today.isBefore(startDay) && !today.isAfter(endDay);
}

/// KROK B: Existuje úkol typu úklid se statusem jiným než dokončený?
///
/// DŮLEŽITÉ: DB ukládá anglické stavy (completed, done, in_progress, assigned, pending).
/// Záměrně porovnáváme proti anglickým DB hodnotám – nikoli proti českému 'Hotovo',
/// které by nikdy nesedělo a způsobilo by chybný stav „K úklidu“ i pro dokončené úkoly.
bool _hasOpenCleaningTask(List<TaskRow> tasks, String apartmentId) {
  for (final t in tasks) {
    if (t.apartmentId != apartmentId) continue;
    final type = (t.taskType).toLowerCase().trim();
    final isCleaning = type == 'cleaning' || type.contains('cleaning') || type.contains('úklid');
    if (!isCleaning) continue;
    final s = (t.status).toLowerCase().trim();
    if (_isCompletedStatus(s)) continue;
    return true;
  }
  return false;
}

/// Vrací true, pokud status znamená dokončený úkol (anglické DB hodnoty + legacy).
bool _isCompletedStatus(String status) {
  return status == 'completed' ||
      status == 'done' ||
      status == 'hotovo' ||
      status == 'dokončeno';
}

/// Vrátí dynamický stav apartmánu pro dnešek z předaných seznamů rezervací a úkolů.
/// Použij pro hromadné počítání stavů (např. na nástěnce) bez nutnosti watchovat
/// apartmentStatusProvider pro každý byt zvlášť.
String getApartmentStatusForToday(
  List<ReservationRow> reservations,
  List<TaskRow> tasks,
  String apartmentId,
) {
  for (final r in reservations) {
    if (r.apartmentId != apartmentId) continue;
    if (r.status == 'cancelled') continue;
    if (_isTodayWithinReservation(r.checkIn, r.checkOut)) {
      return apartmentStatusOccupied;
    }
  }
  if (_hasOpenCleaningTask(tasks, apartmentId)) {
    return apartmentStatusNeedsCleaning;
  }
  return apartmentStatusClean;
}

/// Provider dynamického stavu apartmánu – počítá se z Rezervací a Úkolů v reálném čase.
///
/// KROK A (Hosté): Existuje rezervace, kde dnešní datum spadá do [checkIn, checkOut]
/// a status není 'cancelled'? → apartments.status.occupied.
///
/// KROK B (Úklid): Pokud není obsazeno, existuje úkol typu cleaning se statusem
/// jiným než completed/done? → apartments.status.to_clean.
///
/// KROK C: Jinak → apartments.status.clean (Volno).
final apartmentStatusProvider =
    Provider.family<String, String>((ref, apartmentId) {
  final reservations = ref.watch(adminReservationsProvider);
  final tasks = ref.watch(adminTasksStreamProvider);

  return reservations.when(
    data: (resList) {
      // KROK A – Hosté
      for (final r in resList) {
        if (r.apartmentId != apartmentId) continue;
        if (r.status == 'cancelled') continue;
        if (_isTodayWithinReservation(r.checkIn, r.checkOut)) {
          return apartmentStatusOccupied;
        }
      }

      // KROK B – Úklid (pouze pokud není obsazeno)
      return tasks.when(
        data: (taskList) {
          if (_hasOpenCleaningTask(taskList, apartmentId)) {
            return apartmentStatusNeedsCleaning;
          }
          return apartmentStatusClean;
        },
        loading: () => apartmentStatusClean,
        error: (_, _) => apartmentStatusClean,
      );
    },
    loading: () => apartmentStatusClean,
    error: (_, _) => apartmentStatusClean,
  );
});
