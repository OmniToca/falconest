import 'package:falconest/core/repositories/task/task_repository.dart';

/// Kontext rezervace pro placeholder službu – bez závislosti na Isar/Drift.
class ReservationPlaceholderContext {
  const ReservationPlaceholderContext({this.guestName, this.guestPhone});
  final String? guestName;
  final String? guestPhone;
}

/// Kontext bytu pro placeholder službu – bez závislosti na Isar/Drift.
class ApartmentPlaceholderContext {
  const ApartmentPlaceholderContext({
    this.name,
    this.address,
    this.keybox,
    this.ownerNotes,
  });
  final String? name;
  final String? address;
  final String? keybox;
  final String? ownerNotes;
}

/// Služba pro nahrazení placeholderů v textu šablony zprávy.
///
/// Kontext se sestaví z WorkerTaskDetail (host, úkol) a volitelně z
/// ReservationPlaceholderContext a ApartmentPlaceholderContext. Chybějící hodnoty se nahradí prázdným řetězcem.
class TemplatePlaceholderService {
  TemplatePlaceholderService._();

  /// Fallback Chain pro vyhledání telefonního čísla hosta/klienta.
  /// PROČ: taskDetail.guestPhone může být null i když číslo existuje v rezervaci/klientovi;
  /// validace před odesláním musí prohledat všechny propojené entity.
  /// Pořadí: guestPhone → clientPhone → reservation.guestPhone → parsování z poznámky (číslo od +).
  static String? resolveGuestPhone(
    WorkerTaskDetail detail, {
    ReservationPlaceholderContext? reservation,
  }) {
    final a = detail.guestPhone?.trim();
    if (a != null && a.isNotEmpty) return a;

    final b = detail.clientPhone?.trim();
    if (b != null && b.isNotEmpty) return b;

    final c = reservation?.guestPhone?.trim();
    if (c != null && c.isNotEmpty) return c;

    return _tryParsePhoneFromNotes(detail);
  }

  /// Pokusí vyextraktovat telefonní číslo z description nebo metadata custom_note.
  /// PROČ: Při importu se občas přenese číslo do interní poznámky v formátu +420….
  static String? _tryParsePhoneFromNotes(WorkerTaskDetail detail) {
    final candidates = <String>[];
    if (detail.description.trim().isNotEmpty) {
      candidates.add(detail.description);
    }
    final note = detail.metadata?['custom_note'];
    if (note is String && note.trim().isNotEmpty) {
      candidates.add(note.trim());
    }
    for (final text in candidates) {
      // Hledáme sekvenci začínající + a obsahující číslice (mezinárodní formát).
      final match = RegExp(r'\+\d[\d\s\-\(\)]{8,25}').firstMatch(text);
      if (match != null) {
        final raw = match.group(0)!;
        final cleaned = raw.replaceAll(RegExp(r'[^\d]'), '');
        if (cleaned.length >= 10) return '+$cleaned';
      }
    }
    return null;
  }

  /// Podporované placeholder klíče – mapují se na hodnoty z buildContextFromTask.
  static const supportedPlaceholders = [
    'guest_name',
    'guest_phone',
    'flight_number',
    'address',
    'keybox',
    'reference_number',
    'apartment_name',
    'owner_notes',
  ];

  /// Nahradí v textu všechny výskyty {klíč} hodnotami z mapy.
  /// Neznámé klíče zůstanou nezměněné (např. {unknown} → {unknown}).
  /// Hodnoty null nebo prázdné se nahradí za "".
  static String replacePlaceholders(String templateBody, Map<String, String> values) {
    if (templateBody.isEmpty) return '';
    var result = templateBody;
    for (final entry in values.entries) {
      final key = entry.key;
      final value = entry.value;
      final placeholder = '{$key}';
      result = result.replaceAll(placeholder, value);
    }
    return result;
  }

  /// Sestaví Map placeholderů z WorkerTaskDetail a volitelných lokálních entit.
  /// Chybějící data se nastaví na prázdný řetězec, aby v textu nezůstalo "null".
  static Map<String, String> buildContextFromTask(
    WorkerTaskDetail detail, {
    ReservationPlaceholderContext? reservation,
    ApartmentPlaceholderContext? apartment,
  }) {
    final guestName = detail.displayName.trim().isNotEmpty
        ? detail.displayName.trim()
        : (reservation?.guestName?.trim().isNotEmpty == true
            ? reservation!.guestName!.trim()
            : '');
    final guestPhone = resolveGuestPhone(detail, reservation: reservation)?.trim() ?? '';
    final flightNumber = detail.flightNumber?.trim().isNotEmpty == true
        ? detail.flightNumber!.trim()
        : '';
    final address = detail.displayAddress.trim().isNotEmpty
        ? detail.displayAddress.trim()
        : (apartment?.address?.trim().isNotEmpty == true
            ? apartment!.address!.trim()
            : '');
    final keybox =
        (detail.keybox?.trim().isNotEmpty == true)
            ? detail.keybox!.trim()
            : (apartment?.keybox?.trim().isNotEmpty == true
                ? apartment!.keybox!.trim()
                : '');
    final referenceNumber = detail.referenceNumber?.trim().isNotEmpty == true
        ? detail.referenceNumber!.trim()
        : '';
    final apartmentName = detail.apartmentName?.trim().isNotEmpty == true
        ? detail.apartmentName!.trim()
        : ((apartment?.name ?? '').trim().isNotEmpty ? (apartment!.name ?? '').trim() : '');
    final ownerNotes = detail.ownerNotes?.trim().isNotEmpty == true
        ? detail.ownerNotes!.trim()
        : (apartment?.ownerNotes?.trim().isNotEmpty == true
            ? (apartment!.ownerNotes ?? '').trim()
            : '');

    return {
      'guest_name': guestName,
      'guest_phone': guestPhone,
      'flight_number': flightNumber,
      'address': address,
      'keybox': keybox,
      'reference_number': referenceNumber,
      'apartment_name': apartmentName,
      'owner_notes': ownerNotes,
    };
  }
}
