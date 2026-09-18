import 'dart:ui' show PlatformDispatcher;

import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

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
    this.parkingInstructions,
    this.reviewLink,
    this.ownerNotes,
  });
  final String? name;
  final String? address;
  final String? keybox;
  final String? parkingInstructions;
  final String? reviewLink;
  final String? ownerNotes;
}

/// Služba pro nahrazení placeholderů v textu šablony zprávy.
///
/// Kontext se sestaví z WorkerTaskDetail (host, úkol) a volitelně z
/// ReservationPlaceholderContext a ApartmentPlaceholderContext. Chybějící hodnoty se nahradí prázdným řetězcem.
class TemplatePlaceholderService {
  TemplatePlaceholderService._();

  /// Výchozí IANA zóna, pokud v DB nic není nebo hodnota není platná.
  static const String defaultTenantTimezone = 'Europe/Madrid';

  /// Bezpečná IANA hodnota z nastavení tenanta (nikdy prázdný řetězec).
  static String normalizeTenantIana(String? raw) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) return defaultTenantTimezone;
    return t;
  }

  static tz.Location _locationOrFallback(String iana) {
    try {
      return tz.getLocation(iana);
    } catch (e, st) {
      AppLogger.error('TemplatePlaceholderService._locationOrFallback: neplatná IANA zóna "$iana"', e, st);
      try {
        return tz.getLocation(defaultTenantTimezone);
      } catch (e2, st2) {
        AppLogger.error('TemplatePlaceholderService._locationOrFallback: ani výchozí zóna $defaultTenantTimezone neplatná', e2, st2);
        return tz.UTC;
      }
    }
  }

  /// Okamžik UTC → „nástěnné“ složky v zóně tenanta pro [DateFormat] (hodnoty z TZDateTime).
  static DateTime _wallDateTimeInTenantZone(DateTime instant, String tenantIana) {
    final zoneName = normalizeTenantIana(tenantIana);
    final loc = _locationOrFallback(zoneName);
    final utc = instant.isUtc ? instant : instant.toUtc();
    final z = tz.TZDateTime.from(utc, loc);
    return DateTime(z.year, z.month, z.day, z.hour, z.minute, z.second);
  }

  /// Kalendářní datum (bez času v DB) interpretujeme jako půlnoc v zóně tenanta.
  static DateTime _wallDateOnlyInTenantZone(int year, int month, int day, String tenantIana) {
    final loc = _locationOrFallback(normalizeTenantIana(tenantIana));
    final z = tz.TZDateTime(loc, year, month, day);
    return DateTime(z.year, z.month, z.day);
  }

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
    'parking',
    'review_link',
    'reference_number',
    'apartment_name',
    'owner_notes',
    'task_date',
    'task_time',
    'arrival_date',
    'arrival_time',
    'departure_date',
    'departure_time',
    'checkin_link',
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
    String? tenantIanaTimezone,
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
    final parking = apartment?.parkingInstructions?.trim().isNotEmpty == true
        ? apartment!.parkingInstructions!.trim()
        : '';
    final reviewLink = apartment?.reviewLink?.trim().isNotEmpty == true
        ? apartment!.reviewLink!.trim()
        : '';
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

    final localeTag = _localeTagForFormatting(guestLanguage: detail.guestLanguage);
    final tenantTz = normalizeTenantIana(tenantIanaTimezone);
    final taskDt = _taskDateTimePlaceholders(
      detail.scheduledStart,
      localeTag,
      tenantTz,
    );
    const emptyArrivalDeparture = {
      'arrival_date': '',
      'arrival_time': '',
      'departure_date': '',
      'departure_time': '',
      'checkin_link': '',
    };

    return {
      'guest_name': guestName,
      'guest_phone': guestPhone,
      'flight_number': flightNumber,
      'address': address,
      'keybox': keybox,
      'parking': parking,
      'review_link': reviewLink,
      'reference_number': referenceNumber,
      'apartment_name': apartmentName,
      'owner_notes': ownerNotes,
      ...taskDt,
      ...emptyArrivalDeparture,
      'checkin_link': '',
    };
  }

  /// Telefon hosta z rezervace, volitelně fallback na klienta (pro Admin kontext bez rezervace).
  /// PROČ: Jedna metoda pro konzistentní vyzvednutí čísla při volání selectora z rezervace.
  static String? resolveGuestPhoneFromReservation(
    ReservationRow reservation, {
    ClientModel? client,
  }) {
    final fromRes = reservation.guestPhone?.trim();
    if (fromRes != null && fromRes.isNotEmpty) return fromRes;
    final fromClient = client?.phone?.trim();
    if (fromClient != null && fromClient.isNotEmpty) return fromClient;
    return null;
  }

  /// Sestaví mapu placeholderů z rezervace a volitelně bytu/klienta.
  /// Stejné klíče jako [buildContextFromTask] – pro použití v šablonách zpráv z Admin rezervačního kontextu.
  /// Chybějící hodnoty prázdný řetězec (nikdy null v mapě).
  static Map<String, String> buildContextFromReservation(
    ReservationRow reservation, {
    ApartmentPlaceholderContext? apartment,
    ClientModel? client,
    String? tenantIanaTimezone,
  }) {
    final guestName = reservation.guestName?.trim().isNotEmpty == true
        ? reservation.guestName!.trim()
        : '';
    final guestPhone =
        resolveGuestPhoneFromReservation(reservation, client: client)?.trim() ?? '';
    final address = apartment?.address?.trim().isNotEmpty == true
        ? apartment!.address!.trim()
        : '';
    final keybox = apartment?.keybox?.trim().isNotEmpty == true
        ? apartment!.keybox!.trim()
        : '';
    final parking = apartment?.parkingInstructions?.trim().isNotEmpty == true
        ? apartment!.parkingInstructions!.trim()
        : '';
    final reviewLink = apartment?.reviewLink?.trim().isNotEmpty == true
        ? apartment!.reviewLink!.trim()
        : '';
    final referenceNumber = reservation.referenceNumber?.trim().isNotEmpty == true
        ? reservation.referenceNumber!.trim()
        : '';
    final apartmentName = reservation.apartmentName?.trim().isNotEmpty == true
        ? reservation.apartmentName!.trim()
        : (apartment?.name?.trim().isNotEmpty == true ? apartment!.name!.trim() : '');
    final ownerNotes = apartment?.ownerNotes?.trim().isNotEmpty == true
        ? (apartment!.ownerNotes ?? '').trim()
        : '';

    final localeTag = _localeTagForFormatting(
      guestLanguage: reservation.guestLanguage,
      clientLanguage: client?.languageCode,
    );
    final tenantTz = normalizeTenantIana(tenantIanaTimezone);
    final arrivalDeparture =
        _reservationArrivalDeparturePlaceholders(reservation, localeTag, tenantTz);
    final emptyTask = _taskDateTimePlaceholders(null, localeTag, tenantTz);

    return {
      'guest_name': guestName,
      'guest_phone': guestPhone,
      'flight_number': '', // rezervace nemá přímo flight_number; případně rozšířit z reservation_services
      'address': address,
      'keybox': keybox,
      'parking': parking,
      'review_link': reviewLink,
      'reference_number': referenceNumber,
      'apartment_name': apartmentName,
      'owner_notes': ownerNotes,
      ...emptyTask,
      ...arrivalDeparture,
      'checkin_link': '',
    };
  }

  /// Sestaví mapu placeholderů z Admin úkolu (TaskRow), volitelně rezervace a bytu.
  /// Stejné klíče jako [buildContextFromTask] – pro Smart Template Selector v Admin detailu úkolu.
  /// Telefon hosta/klienta se bere z rezervace, nebo fallback na CRM klienta pro externí úkoly.
  static Map<String, String> buildContextFromAdminTask(
    TaskRow task, {
    ReservationRow? reservation,
    ApartmentPlaceholderContext? apartment,
    ClientModel? client,
    String? tenantIanaTimezone,
  }) {
    final guestName = task.reservationGuestName?.trim().isNotEmpty == true
        ? task.reservationGuestName!.trim()
        : (reservation?.guestName?.trim().isNotEmpty == true
            ? reservation!.guestName!.trim()
            : (task.customTitle?.trim().isNotEmpty == true ? task.customTitle!.trim() : ''));
    final guestPhone = reservation?.guestPhone?.trim().isNotEmpty == true
        ? reservation!.guestPhone!.trim()
        : (client?.phone?.trim().isNotEmpty == true ? client!.phone!.trim() : '');
    final fallbackClientName = client?.name.trim().isNotEmpty == true ? client!.name.trim() : '';
    final effectiveGuestName = guestName.isNotEmpty ? guestName : fallbackClientName;
    final flightRaw = task.metadata?['flight_number'];
    final flightNumber = (flightRaw != null && flightRaw.toString().trim().isNotEmpty)
        ? flightRaw.toString().trim()
        : '';
    final address = task.customLocation?.trim().isNotEmpty == true
        ? task.customLocation!.trim()
        : (apartment?.address?.trim().isNotEmpty == true ? apartment!.address!.trim() : '');
    final keybox = apartment?.keybox?.trim().isNotEmpty == true
        ? apartment!.keybox!.trim()
        : '';
    final parking = apartment?.parkingInstructions?.trim().isNotEmpty == true
        ? apartment!.parkingInstructions!.trim()
        : '';
    final reviewLink = apartment?.reviewLink?.trim().isNotEmpty == true
        ? apartment!.reviewLink!.trim()
        : '';
    final referenceNumber = task.referenceNumber?.trim().isNotEmpty == true
        ? task.referenceNumber!.trim()
        : '';
    final apartmentName = task.apartmentName?.trim().isNotEmpty == true
        ? task.apartmentName!.trim()
        : (apartment?.name?.trim().isNotEmpty == true ? apartment!.name!.trim() : '');
    final ownerNotes = apartment?.ownerNotes?.trim().isNotEmpty == true
        ? (apartment!.ownerNotes ?? '').trim()
        : '';

    final localeTag = _localeTagForFormatting(
      guestLanguage: reservation?.guestLanguage,
      clientLanguage: client?.languageCode,
    );
    final tenantTz = normalizeTenantIana(tenantIanaTimezone);
    final taskInstant = task.scheduledStart ?? task.dueDate;
    final taskDt = _taskDateTimePlaceholders(taskInstant, localeTag, tenantTz);
    final arrivalDeparture = reservation != null
        ? _reservationArrivalDeparturePlaceholders(reservation, localeTag, tenantTz)
        : const {
            'arrival_date': '',
            'arrival_time': '',
            'departure_date': '',
            'departure_time': '',
          };

    return {
      'guest_name': effectiveGuestName,
      'guest_phone': guestPhone,
      'flight_number': flightNumber,
      'address': address,
      'keybox': keybox,
      'parking': parking,
      'review_link': reviewLink,
      'reference_number': referenceNumber,
      'apartment_name': apartmentName,
      'owner_notes': ownerNotes,
      ...taskDt,
      ...arrivalDeparture,
      'checkin_link': '',
    };
  }

  /// Locale pro [DateFormat]: host / klient, jinak jazyk prostředí (aplikace / zařízení).
  static String _localeTagForFormatting({
    String? guestLanguage,
    String? clientLanguage,
  }) {
    for (final raw in [guestLanguage, clientLanguage]) {
      final s = raw?.trim().toLowerCase();
      if (s == null || s.isEmpty) continue;
      if (s.startsWith('cs')) return 'cs';
      if (s.startsWith('en')) return 'en';
      if (s.startsWith('es')) return 'es';
      if (s.length >= 2) return s.substring(0, 2);
    }
    return PlatformDispatcher.instance.locale.toLanguageTag();
  }

  static Map<String, String> _taskDateTimePlaceholders(
    DateTime? scheduledOrDue,
    String localeTag,
    String tenantIana,
  ) {
    if (scheduledOrDue == null) {
      return {'task_date': '', 'task_time': ''};
    }
    final wall = _wallDateTimeInTenantZone(scheduledOrDue, tenantIana);
    return {
      'task_date': DateFormat.yMd(localeTag).format(wall),
      'task_time': DateFormat.Hm(localeTag).format(wall),
    };
  }

  /// [checkIn] / [checkOut] z [ReservationRow] – ISO nebo DD.MM.RRRR z [_formatIsoToDisplay].
  static DateTime? _tryParseReservationDisplayDate(String? display) {
    final s = display?.trim();
    if (s == null || s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(s);
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    final year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  static Map<String, String> _reservationArrivalDeparturePlaceholders(
    ReservationRow reservation,
    String localeTag,
    String tenantIana,
  ) {
    final arrivalTs = reservation.arrivalTime;
    final arrivalParsed = _tryParseReservationDisplayDate(reservation.checkIn);
    final DateTime? arrivalForDateWall = arrivalTs != null
        ? _wallDateTimeInTenantZone(arrivalTs, tenantIana)
        : (arrivalParsed != null
            ? _wallDateOnlyInTenantZone(
                arrivalParsed.year,
                arrivalParsed.month,
                arrivalParsed.day,
                tenantIana,
              )
            : null);
    final arrivalDate =
        arrivalForDateWall != null ? DateFormat.yMd(localeTag).format(arrivalForDateWall) : '';
    final arrivalTime = arrivalTs != null
        ? DateFormat.Hm(localeTag).format(_wallDateTimeInTenantZone(arrivalTs, tenantIana))
        : '';

    final departureTs = reservation.departureTime;
    final departureParsed = _tryParseReservationDisplayDate(reservation.checkOut);
    final DateTime? departureForDateWall = departureTs != null
        ? _wallDateTimeInTenantZone(departureTs, tenantIana)
        : (departureParsed != null
            ? _wallDateOnlyInTenantZone(
                departureParsed.year,
                departureParsed.month,
                departureParsed.day,
                tenantIana,
              )
            : null);
    final departureDate =
        departureForDateWall != null ? DateFormat.yMd(localeTag).format(departureForDateWall) : '';
    final departureTime = departureTs != null
        ? DateFormat.Hm(localeTag).format(_wallDateTimeInTenantZone(departureTs, tenantIana))
        : '';

    return {
      'arrival_date': arrivalDate,
      'arrival_time': arrivalTime,
      'departure_date': departureDate,
      'departure_time': departureTime,
    };
  }
}
