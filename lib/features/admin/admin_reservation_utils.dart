import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';

/// Typ kolize: koliduje začátek (check-in) nebo konec (check-out) rezervace.
enum CollisionSide { checkIn, checkOut }

/// Výjimka při detekci kolize rezervací – obsahuje návrh náhradního času a stranu kolize.
class ReservationCollisionException implements Exception {
  ReservationCollisionException(
    this.message, {
    this.suggestedTime,
    this.suggestedDateTime,
    this.collisionSide = CollisionSide.checkIn,
  });

  final String message;
  /// Čas ve formátu HH:mm pro zobrazení v chybové hlášce.
  final String? suggestedTime;
  /// Celý navržený čas (check-in nebo check-out) pro úpravu ve formuláři.
  final DateTime? suggestedDateTime;
  /// Zda koliduje příjezd (nejbližší check-in) nebo odjezd (nejzazší check-out).
  final CollisionSide collisionSide;

  @override
  String toString() => message;
}

/// Pro check-in bez času používá 15:00 (standardní příjezd).
DateTime? parseReservationCheckIn(String? s) => parseReservationDateTime(s);

/// Pro check-out bez času používá 10:00 (standardní odjezd).
DateTime? parseReservationCheckOut(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.trim().split(' ');
  if (parts.length == 1) {
    final d = parseReservationDateOnly(parts[0]);
    if (d != null) return DateTime(d.year, d.month, d.day, 10, 0);
  }
  return parseReservationDateTime(s);
}

/// Počet nocí mezi check-in a check-out (pro zobrazení v kartě rezervace).
int? reservationNights(String? checkIn, String? checkOut) {
  final start = parseReservationCheckIn(checkIn);
  final end = parseReservationCheckOut(checkOut);
  if (start == null || end == null) return null;
  final startDate = DateTime(start.year, start.month, start.day);
  final endDate = DateTime(end.year, end.month, end.day);
  return endDate.difference(startDate).inDays;
}

DateTime? parseReservationDateOnly(String s) {
  final dParts = s.split('.');
  if (dParts.length >= 3) {
    return DateTime(
      int.parse(dParts[2]),
      int.parse(dParts[1]),
      int.parse(dParts[0]),
    );
  }
  return null;
}

/// Zkontroluje kolizi rezervací. Při kolizi vyhodí [ReservationCollisionException].
void checkReservationCollision({
  required List<ReservationRow> existingReservations,
  required String apartmentId,
  required int standardCleaningDuration,
  required DateTime newCheckIn,
  required DateTime newCheckOut,
  String? excludeReservationId,
}) {
  final bufferMinutes = standardCleaningDuration + 60;

  for (final existing in existingReservations) {
    if (existing.apartmentId != apartmentId) continue;
    if (excludeReservationId != null && existing.id == excludeReservationId) {
      continue;
    }

    final existingCheckIn = parseReservationCheckIn(existing.checkIn);
    final existingCheckOut = parseReservationCheckOut(existing.checkOut);
    if (existingCheckIn == null || existingCheckOut == null) continue;

    final existingCheckOutWithBuffer =
        existingCheckOut.add(Duration(minutes: bufferMinutes));
    final newCheckOutWithBuffer =
        newCheckOut.add(Duration(minutes: bufferMinutes));

    final collides = newCheckIn.isBefore(existingCheckOutWithBuffer) &&
        newCheckOutWithBuffer.isAfter(existingCheckIn);

    if (collides) {
      final suggestedCheckIn =
          existingCheckOut.add(Duration(minutes: bufferMinutes));
      final suggestedCheckOut =
          existingCheckIn.subtract(Duration(minutes: bufferMinutes));
      // Kolize na začátku: jiná rezervace končí před námi → navrhnout posun check-in.
      // Kolize na konci: jiná rezervace začíná po nás → navrhnout posun check-out.
      final isCheckInCollision = existingCheckOut.isBefore(newCheckOut) ||
          existingCheckOut.isAtSameMomentAs(newCheckOut);
      final suggested = isCheckInCollision ? suggestedCheckIn : suggestedCheckOut;
      final suggestedTimeStr =
          '${suggested.hour.toString().padLeft(2, '0')}:${suggested.minute.toString().padLeft(2, '0')}';
      final side = isCheckInCollision ? CollisionSide.checkIn : CollisionSide.checkOut;
      final msg = isCheckInCollision
          ? 'Tento apartmán je v daném termínu již obsazen. '
            'S ohledem na úklid je nejbližší možný check-in v $suggestedTimeStr.'
          : 'Tento apartmán je v daném termínu již obsazen. '
            'S ohledem na další rezervaci je nejzazší možný check-out v $suggestedTimeStr (kvůli dalšímu úklidu).';
      throw ReservationCollisionException(
        msg,
        suggestedTime: suggestedTimeStr,
        suggestedDateTime: suggested,
        collisionSide: side,
      );
    }
  }
}

/// Formátuje rozsah dat pro pole termínu pobytu (DD.MM.YYYY - DD.MM.YYYY).
String formatReservationDateRangeDisplay(DateTimeRange range) {
  String d(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
  return '${d(range.start)} - ${d(range.end)}';
}

/// Formát DD.MM.YYYY HH:mm pro zobrazení uživateli.
String formatReservationDateTime(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// Zobrazí interaktivní dialog při kolizi – pouze upraví čas ve formuláři, ukládání provede uživatel sám.
void showReservationCollisionDialog({
  required BuildContext context,
  required CollisionSide collisionSide,
  required DateTime suggestedDateTime,
  required VoidCallback onApplyTime,
}) {
  final navrhovanyCas = formatReservationDateTime(suggestedDateTime);
  final contentText = collisionSide == CollisionSide.checkIn
      ? 'admin.reservations_collision_check_in_message'.tr(namedArgs: {'time': navrhovanyCas})
      : 'admin.reservations_collision_check_out_message'.tr(namedArgs: {'time': navrhovanyCas});
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        'admin.reservations_collision_title'.tr(),
        style: TextStyle(color: Colors.red),
      ),
      content: Text(contentText),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('admin.reservations_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            onApplyTime();
          },
          child: Text('admin.reservations_collision_apply_time'.tr()),
        ),
      ],
    ),
  );
}

/// Parsuje string DD.MM.YYYY nebo DD.MM.YYYY HH:mm na DateTime.
DateTime? parseReservationDateTime(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final trimmed = s.trim();
  try {
    if (trimmed.contains(' ')) {
      final parts = trimmed.split(' ');
      final dParts = parts[0].split('.');
      final tParts = parts[1].split(':');
      if (dParts.length >= 3 && tParts.length >= 2) {
        return DateTime(
          int.parse(dParts[2]),
          int.parse(dParts[1]),
          int.parse(dParts[0]),
          int.parse(tParts[0]),
          int.parse(tParts[1]),
        );
      }
    } else {
      final dParts = trimmed.split('.');
      if (dParts.length >= 3) {
        return DateTime(
          int.parse(dParts[2]),
          int.parse(dParts[1]),
          int.parse(dParts[0]),
          15,
          0,
        );
      }
    }
  } catch (_) {}
  return null;
}

/// Normalizuje task_type / service_type z DB na kanonický identifikátor.
/// Podporuje hodnoty z tenant_services.service_type: transfer_in, transfer_out, check_in, check_out, cleaning, maintenance, extra.
String _reservationNormalizeTaskType(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'other';
  final s = raw.trim().toLowerCase();
  if (s == 'cleaning' || s == 'úklid' || s == 'uklid') return 'cleaning';
  if (s == 'transfer_in' || s.contains('příjezd') || s.contains('prijezd') || (s.contains('transfer') && s.contains('in'))) return 'transfer_in';
  if (s == 'transfer_out' || s.contains('odjezd') || (s.contains('transfer') && s.contains('out'))) return 'transfer_out';
  if (s == 'transfer') return 'transfer_in'; // fallback pro samotné "transfer"
  if (s == 'check_in' || s == 'check-in') return 'check_in';
  if (s == 'check_out' || s == 'check-out') return 'check_out';
  if (s == 'maintenance' || s.contains('údržba') || s.contains('udrzba')) return 'maintenance';
  if (s == 'extra') return 'extra';
  if (s == 'issue' || s.contains('závada') || s.contains('zavada')) return 'issue';
  if (s == 'material' || s.contains('materiál') || s.contains('material')) return 'material';
  if (s == 'other') return 'other';
  return 'other';
}

/// i18n klíč pro typ úkolu (pro sekci Související úkoly).
String reservationTaskTypeLabelKey(String taskType) {
  final canonical = _reservationNormalizeTaskType(taskType);
  switch (canonical) {
    case 'cleaning':
      return 'admin.task_type_cleaning';
    case 'transfer_in':
      return 'admin.task_type_transfer_in';
    case 'transfer_out':
      return 'admin.task_type_transfer_out';
    case 'check_in':
      return 'admin.task_type_check_in';
    case 'check_out':
      return 'admin.task_type_check_out';
    case 'maintenance':
      return 'admin.task_type_maintenance';
    case 'extra':
      return 'admin.task_type_extra';
    case 'issue':
      return 'admin.task_type_issue';
    case 'material':
      return 'admin.task_type_material';
    default:
      return 'admin.task_type_other';
  }
}

/// Emoji pro typ úkolu (pro sekci Související úkoly).
String reservationTaskTypeEmoji(String taskType) {
  switch (_reservationNormalizeTaskType(taskType)) {
    case 'cleaning':
      return '🧹';
    case 'transfer_in':
    case 'transfer_out':
      return '🚗';
    case 'check_in':
    case 'check_out':
      return '🔑';
    case 'maintenance':
    case 'issue':
      return '🔧';
    case 'material':
      return '📦';
    case 'extra':
      return '✨';
    default:
      return '📋';
  }
}

/// Ikona podle typu úkolu (pro sekci Související úkoly).
IconData reservationTaskTypeIcon(String taskType) {
  switch (_reservationNormalizeTaskType(taskType)) {
    case 'cleaning':
      return Icons.cleaning_services;
    case 'transfer_in':
    case 'transfer_out':
      return Icons.directions_car;
    case 'check_in':
      return Icons.key;
    case 'check_out':
      return Icons.key_off;
    case 'maintenance':
    case 'issue':
      return Icons.build;
    case 'material':
      return Icons.inventory_2;
    case 'extra':
      return Icons.star_outline;
    default:
      return Icons.task_alt;
  }
}

/// Normalizuje status z DB na systémovou hodnotu (pending, assigned, in_progress, completed, problem).
String _reservationNormalizeStatus(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'pending';
  final s = raw.trim().toLowerCase();
  if (s == 'pending' || s == 'draft' || s == 'návrh') return 'pending';
  if (s == 'assigned' || s == 'new' || s == 'nový' || s == 'zadáno') return 'assigned';
  if (s == 'in_progress' || s == 'probíhá') return 'in_progress';
  if (s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno') return 'completed';
  if (s == 'problém' || s == 'problem' || s == 'issue') return 'problem';
  return 'pending';
}

/// i18n klíč pro stav úkolu (task_status.*).
String reservationTaskStatusLabelKey(String status) => 'task_status.${_reservationNormalizeStatus(status)}';

/// Barva Chipu pro stav úkolu (Návrh, Zadáno, Probíhá, Hotovo).
Color reservationTaskStatusChipColor(String status) {
  final norm = _reservationNormalizeStatus(status);
  switch (norm) {
    case 'completed':
      return Colors.green;
    case 'in_progress':
    case 'problem':
      return Colors.blue;
    case 'assigned':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}
