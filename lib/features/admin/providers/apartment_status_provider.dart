import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';

/// Hodnoty dynamicky vypočítaného stavu apartmánu – odpovídají klíčům v _statusKeys.
const String apartmentStatusOccupied = 'Obsazeno hosty';
const String apartmentStatusNeedsCleaning = 'K úklidu';
const String apartmentStatusClean = 'Uklizeno';

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

/// KROK B: Existuje úkol typu úklid se statusem jiným než Hotovo?
bool _hasOpenCleaningTask(List<TaskRow> tasks, String apartmentId) {
  for (final t in tasks) {
    if (t.apartmentId != apartmentId) continue;
    final type = (t.taskType).toLowerCase();
    final isCleaning = type == 'cleaning' || type.contains('úklid');
    if (!isCleaning) continue;
    final status = t.status;
    if (status == 'Hotovo') continue; // hotový úklid = nepotřebujeme
    return true; // Návrh, Nový, Zadáno, Probíhá
  }
  return false;
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
/// a status není 'cancelled'? → Obsazeno hosty.
///
/// KROK B (Úklid): Pokud není obsazeno, existuje úkol typu cleaning se statusem
/// jiným než Hotovo? → K úklidu.
///
/// KROK C: Jinak → Uklizeno (Volno).
final apartmentStatusProvider =
    Provider.family<String, String>((ref, apartmentId) {
  final reservations = ref.watch(adminReservationsProvider);
  final tasks = ref.watch(adminTasksProvider);

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
