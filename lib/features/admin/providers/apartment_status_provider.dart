import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartment_live_context_provider.dart';

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
  } catch (e, st) {
    AppLogger.error('apartment_status_provider._parseReservationDate selhalo', e, st);
    return null;
  }
}

/// KROK 1 (Obsazeno): Dnešní kalendářní den spadá do intervalu [checkIn, checkOut] rezervace?
///
/// PROČ celý den odjezdu jako „obsazeno“: dashboard je denní – dispečer vidí konzistentně
/// „host ještě může být ubytován“ až do konce dne odjezdu (stejně jako původní logika).
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

/// Typ úkolu = úklid (DB + legacy české řetězce).
bool _isCleaningTaskType(String taskType) {
  final type = taskType.toLowerCase().trim();
  return type == 'cleaning' || type.contains('cleaning') || type.contains('úklid');
}

/// Pojistka: otevřený (nedokončený) úklid s plánem do konce dneška nebo v minulosti.
///
/// PROČ stále ignorujeme čistě budoucí termíny: ruční úklid naplánovaný za týden není
/// „urgentní špína dnes“, ale turnover (KROK 2) ji stejně vyřeší po odjezdu hostů.
bool _hasOpenCleaningTaskDueByEndOfToday(List<TaskRow> tasks, String apartmentId) {
  final now = DateTime.now();
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  for (final t in tasks) {
    if (t.apartmentId != apartmentId) continue;
    if (t.deletedAt != null) continue;
    if (!_isCleaningTaskType(t.taskType)) continue;
    final s = (t.status).toLowerCase().trim();
    if (_isCompletedStatus(s)) continue;
    if (_isDraftOrProposalStatus(s)) continue;
    final taskDate = t.scheduledStart ?? t.dueDate;
    if (taskDate.isAfter(endOfToday)) continue;
    return true;
  }
  return false;
}

/// Stav úkolu znamená „návrh k odsouhlasení" – byt tedy není reálně v režimu „K úklidu".
bool _isDraftOrProposalStatus(String status) {
  final lower = status.trim().toLowerCase();
  return lower == 'draft' || lower == 'návrh' || lower == 'navrh';
}

/// Vrací true, pokud status znamená dokončený úkol (anglické DB hodnoty + legacy).
bool _isCompletedStatus(String status) {
  return status == 'completed' ||
      status == 'done' ||
      status == 'hotovo' ||
      status == 'dokončeno';
}

/// Nejnovější **den konce pobytu** u rezervací, které už skončily před dneškem (check-out včera a dřív).
///
/// PROČ `endDay < today`: v den odjezdu je byt stále „Obsazeno“ (KROK 1), turnover řešíme až následující dny.
DateTime? _latestStayEndDayBeforeToday(
  List<ReservationRow> reservations,
  String apartmentId,
  DateTime todayStart,
) {
  DateTime? best;
  for (final r in reservations) {
    if (r.apartmentId != apartmentId) continue;
    if (r.status == 'cancelled') continue;
    final end = _parseReservationDate(r.checkOut);
    if (end == null) continue;
    final endDay = DateTime(end.year, end.month, end.day);
    if (!endDay.isBefore(todayStart)) continue;
    if (best == null || endDay.isAfter(best)) best = endDay;
  }
  return best;
}

/// Nejnovější **kalendářní den** dokončení úklidu u bytu (podle `completed_at`, lokální čas).
DateTime? _latestCompletedCleaningDay(List<TaskRow> tasks, String apartmentId) {
  DateTime? best;
  for (final t in tasks) {
    if (t.apartmentId != apartmentId) continue;
    if (t.deletedAt != null) continue;
    if (!_isCleaningTaskType(t.taskType)) continue;
    if (!_isCompletedStatus(t.status)) continue;
    final raw = t.completedAt ?? t.scheduledStart;
    if (raw == null) continue;
    final local = raw.isUtc ? raw.toLocal() : raw;
    final day = DateTime(local.year, local.month, local.day);
    if (best == null || day.isAfter(best)) best = day;
  }
  return best;
}

/// Po odjezdu hostů chybí dokončený úklid: poslední checkout je **novější** než poslední hotový úklid.
///
/// PROČ `isBefore`: pokud není žádný dokončený úklid (`lastClean == null`), vracíme true.
bool _needsCleaningAfterCheckout(
  DateTime? lastStayEndDay,
  DateTime? lastCleanDay,
) {
  if (lastStayEndDay == null) return false;
  if (lastCleanDay == null) return true;
  return lastCleanDay.isBefore(lastStayEndDay);
}

/// Vrátí dynamický stav apartmánu pro dnešek z předaných seznamů rezervací a úkolů.
/// Použij pro hromadné počítání stavů (např. na nástěnce) bez nutnosti watchovat
/// apartmentStatusProvider pro každý byt zvlášť.
String getApartmentStatusForToday(
  List<ReservationRow> reservations,
  List<TaskRow> tasks,
  String apartmentId,
) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  // KROK 1 – Obsazeno hosty (dnešní den uvnitř [checkIn, checkOut]).
  for (final r in reservations) {
    if (r.apartmentId != apartmentId) continue;
    if (r.status == 'cancelled') continue;
    if (_isTodayWithinReservation(r.checkIn, r.checkOut)) {
      return apartmentStatusOccupied;
    }
  }

  // KROK 2a – Turnover: po skončeném pobytu musí existovat dokončený úklid alespoň v den checkoutu nebo později.
  final lastStayEnd = _latestStayEndDayBeforeToday(reservations, apartmentId, todayStart);
  final lastCleanDay = _latestCompletedCleaningDay(tasks, apartmentId);
  if (_needsCleaningAfterCheckout(lastStayEnd, lastCleanDay)) {
    return apartmentStatusNeedsCleaning;
  }

  // KROK 2b – Pojistka: ruční otevřený úklid s termínem do konce dneška (nebo po splatnosti).
  if (_hasOpenCleaningTaskDueByEndOfToday(tasks, apartmentId)) {
    return apartmentStatusNeedsCleaning;
  }

  // KROK 3 – Volno / připraveno.
  return apartmentStatusClean;
}

/// Obsazeno jen z rezervací – při čekání na stream úkolů nesmíme ztratit KROK 1.
String _occupiedFromReservationsOnly(
  List<ReservationRow> resList,
  String apartmentId,
) {
  for (final r in resList) {
    if (r.apartmentId != apartmentId) continue;
    if (r.status == 'cancelled') continue;
    if (_isTodayWithinReservation(r.checkIn, r.checkOut)) {
      return apartmentStatusOccupied;
    }
  }
  return apartmentStatusClean;
}

/// Provider dynamického stavu apartmánu – rezervace a úkoly z [apartmentStatusContextReservationsProvider]
/// a [todayApartmentTasksProvider] (žádná vazba na měsíc v modulu Úkoly).
///
/// KROK 1: dnes v intervalu rezervace → occupied.
/// KROK 2: po checkoutu chybí dokončený úklid **nebo** otevřený úklid do konce dneška → to_clean.
/// KROK 3: jinak clean.
final apartmentStatusProvider =
    Provider.autoDispose.family<String, String>((ref, apartmentId) {
  final reservations = ref.watch(apartmentStatusContextReservationsProvider);
  final tasks = ref.watch(todayApartmentTasksProvider);

  return reservations.when(
    data: (resList) => tasks.when(
      data: (taskList) => getApartmentStatusForToday(resList, taskList, apartmentId),
      loading: () => _occupiedFromReservationsOnly(resList, apartmentId),
      error: (_, _) => apartmentStatusClean,
    ),
    loading: () => apartmentStatusClean,
    error: (_, _) => apartmentStatusClean,
  );
});
