import 'package:excel/excel.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/id_generator.dart';

/// Výsledek parsování buňky služby v Excelu.
///
/// Formát buňky: CENA|PLÁTCE|ČÍSLO_LETU|POZNÁMKA (prázdná místa = výchozí z DB).
/// Speciální hodnoty: "ano", "yes", "1", "x", "true" = použít výchozí nastavení z DB.
class ParsedService {
  const ParsedService({
    this.chargedPrice,
    this.customNote,
    this.payerType,
    this.flightNumber,
  });

  final num? chargedPrice;
  final String? customNote;
  final String? payerType;
  final String? flightNumber;
}

/// Výsledek XLSX importu – počet úspěšných, varování (záchranná brzda) a chyb.
///
/// Pro zobrazení ve SnackBar použij [formatReportMessage] nebo i18n klíč
/// admin.import_report s namedArgs.
class ReservationImportResult {
  const ReservationImportResult({
    required this.successCount,
    required this.warningCount,
    required this.errorCount,
  });

  final int successCount;
  final int warningCount;
  final int errorCount;

  /// Vrátí true, pokud byl alespoň jeden řádek úspěšně importován.
  bool get hasSuccess => successCount > 0;
}

/// Služba pro hromadný import rezervací z XLSX (Excel).
///
/// White-Glove onboarding: klienti dostanou vzorovou XLSX šablonu s dynamickými
/// sloupci služeb a listem „Kódy“ jako tahákem pro validaci apartment_code.
/// Rezervace se párují přes [apartment_code] (apartments.code).
///
/// Pevné sloupce: apartment_code, guest_name, guest_phone, guest_email, check_in,
/// check_out, check_in_time, check_out_time, guest_count, internal_note.
/// Časy check_in_time a check_out_time jsou volitelné (formát např. 15:00, 23:55) – při prázdné buňce se použijí defaulty (15:00 příjezd, 10:00 odjezd). Dynamické sloupce = služby z katalogu.
/// Parametry v buňce služby oddělené svislítkem (|), např. "50|FR1495|owner|dětská sedačka".
///
/// ZÁCHRANNÁ BRZDA: Jakákoliv volitelná služba, která selže (neexistuje v katalogu,
/// apartmán ji nepodporuje atd.), NESMÍ způsobit pád importu. Místo toho se její
/// obsah zapíše do interní poznámky rezervace ve formátu [CHYBA IMPORTU - {služba}]: {obsah}.
class ReservationImportService {
  ReservationImportService._();

  /// Pevné sloupce šablony (v tomto pořadí). check_in_time a check_out_time jsou volitelné (např. 15:00, 10:00).
  /// Sloupce za internal_note jsou dynamické – služby.
  static const _fixedHeaders = [
    'apartment_code',
    'guest_name',
    'guest_phone',
    'guest_email',
    'check_in',
    'check_out',
    'check_in_time',
    'check_out_time',
    'guest_count',
    'internal_note',
  ];

  /// Vygeneruje vzorový XLSX soubor s listem „Kódy“ (tahák) a listem „Rezervace“ (hlavní šablona).
  ///
  /// Načte z DB apartmány (kódy) a tenant_services (katalog). Hlavička Rezervace obsahuje
  /// pevné sloupce + dynamické sloupce pro VŠECHNY služby agentury.
  /// Data Validation pro apartment_code – balíček excel ji přímo neumí, list „Kódy“ slouží jako tahák.
  static Future<List<int>> generateExcelTemplate(String tenantId) async {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError('admin.import_no_tenant');
    }

    // KROK A: Načtení apartmánů a tenant_services z DB
    final apartments = <Map<String, dynamic>>[];
    final tenantServices = <Map<String, dynamic>>[];

    try {
      final aptRes = await SupabaseService.safeFrom('apartments', tenantId)
          .select('id, code')
          .isFilter('deleted_at', null);
      for (final e in aptRes as List) {
        apartments.add(e as Map<String, dynamic>);
      }

      final tsRes = await SupabaseService.safeFrom('tenant_services', tenantId)
          .select('id, service_type')
          .eq('is_active', true)
          .isFilter('deleted_at', null);
      for (final e in tsRes as List) {
        tenantServices.add(e as Map<String, dynamic>);
      }
    } catch (_) {
      // Při chybě DB pokračujeme s prázdnými seznamy – šablona bude mít minimální strukturu
    }

    final codes = apartments
        .map((a) => (a['code']?.toString() ?? '').trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final serviceTypes = tenantServices
        .map((t) => (t['service_type']?.toString() ?? '').trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    // KROK B: Vytvoření Excel instance
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

    // KROK C: List „Kódy“ – sloupec A = kódy apartmánů (tahák pro uživatele)
    excel.rename(defaultSheet, 'Kódy');
    for (var i = 0; i < codes.length; i++) {
      excel.updateCell(
        'Kódy',
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i),
        TextCellValue(codes[i]),
      );
    }
    if (codes.isEmpty) {
      excel.updateCell(
        'Kódy',
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        TextCellValue('(žádné apartmány v katalogu)'),
      );
    }

    // KROK D: List „Rezervace“ – hlavičky + dynamické sloupce s prefixem srv_
    // PROČ srv_: Kolize jmen – pevné sloupce check_in/check_out (datum) vs. služby check_in/check_out.
    // Nápověda k vyplňování služeb – sloupce D1–D7
    const helpRows = [
      '--- NÁPOVĚDA K VYPLŇOVÁNÍ SLUŽEB ---',
      'Formát buňky: CENA | KDO PLATÍ | ČÍSLO LETU | POZNÁMKA',
      'Pokud chcete použít VÝCHOZÍ nastavení z databáze (z ceníku apartmánu), nechte místo prázdné nebo napište jen \'ano\'.',
      'Příklady:',
      'ano (nebo yes) = Zapne službu s výchozí cenou a plátcem z databáze.',
      '||FR1495 = Vezme výchozí cenu a plátce z DB, doplní jen číslo letu FR1495.',
      '50|owner|FR1495|dětská sedačka = Vše ručně (přepíše výchozí hodnoty).',
    ];
    for (var i = 0; i < helpRows.length; i++) {
      excel.updateCell(
        'Kódy',
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i),
        TextCellValue(helpRows[i]),
      );
    }

    final serviceHeaderNames = serviceTypes.map((s) => 'srv_$s').toList();
    final headers = [..._fixedHeaders, ...serviceHeaderNames];
    final headerRow = headers.map((h) => TextCellValue(h)).toList();

    excel.insertRowIterables('Rezervace', headerRow, 0);

    // Ukázkový řádek dat – check_in_time / check_out_time jako příklad (15:00 příjezd, 10:00 odjezd).
    final sampleValues = <CellValue?>[
      TextCellValue(codes.isNotEmpty ? codes.first : 'KATA-01'),
      TextCellValue('Jakub Novák'),
      TextCellValue('+420123456789'),
      TextCellValue('jakub@example.com'),
      TextCellValue('2026-05-01'),
      TextCellValue('2026-05-10'),
      TextCellValue('15:00'),
      TextCellValue('10:00'),
      IntCellValue(2),
      TextCellValue('Tajná poznámka'),
      ...serviceTypes.map((_) => TextCellValue('')), // prázdné buňky pro služby
    ];
    if (serviceTypes.isNotEmpty) {
      sampleValues[_fixedHeaders.length] =
          TextCellValue('50|FR1495|owner|dětská sedačka'); // první služba – ukázka parametrů
    }
    excel.insertRowIterables('Rezervace', sampleValues, 1);

    // KROK E: Nastavení výchozího listu na Rezervace (uživatel vidí hlavní šablonu při otevření)
    excel.setDefaultSheet('Rezervace');

    final encoded = excel.encode();
    if (encoded == null || encoded.isEmpty) {
      throw StateError('excel.encode() vrátil prázdný soubor');
    }
    return encoded;
  }

  /// Zpracuje XLSX obsah a vytvoří rezervace v Supabase včetně reservation_services.
  ///
  /// [codeToApartmentId] – mapa kód→UUID bytu. Volající sestaví z apartments.
  ///
  /// BULK FETCH: Na začátku se jednorázově načtou tenant_services a apartment_services.
  /// ZÁCHRANNÁ BRZDA: Neexistuje-li služba v katalogu nebo byt ji nepodporuje,
  /// obsah buňky jde do internal_note. BULK INSERT reservation_services na konci smyčky.
  static Future<ReservationImportResult> processImport(
    List<int> fileBytes,
    String tenantId,
    Map<String, String> codeToApartmentId,
  ) async {
    if (fileBytes.isEmpty) {
      throw ArgumentError('admin.import_empty_csv');
    }

    Excel excel;
    try {
      excel = Excel.decodeBytes(fileBytes);
    } catch (_) {
      throw ArgumentError('admin.import_invalid_xlsx');
    }

    // Čtení listu „Rezervace“ (fallback na první list)
    final sheetNames = excel.tables.keys.toList();
    final reservationSheet =
        sheetNames.contains('Rezervace') ? 'Rezervace' : (sheetNames.isNotEmpty ? sheetNames.first : null);

    if (reservationSheet == null) {
      throw ArgumentError('admin.import_empty_csv');
    }

    final sheet = excel[reservationSheet];
    final rows = <List<String>>[];
    final maxCol = sheet.maxColumns;
    final maxRow = sheet.maxRows;

    for (var r = 0; r < maxRow; r++) {
      final row = <String>[];
      for (var c = 0; c < maxCol; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        final v = cell.value;
        final s = _cellValueToString(v);
        row.add(s.trim());
      }
      if (row.any((c) => c.isNotEmpty)) {
        rows.add(row);
      }
    }

    if (rows.isEmpty) {
      throw ArgumentError('admin.import_empty_csv');
    }

    final header = rows.first;
    final headerStrings = header.map((c) => c.toLowerCase()).toList();

    // Indexy pevných sloupců (check_in_time a check_out_time volitelné – při chybějícím sloupci -1, pak fallback na default časy).
    final idxApartmentCode = _indexOf(headerStrings, 'apartment_code');
    final idxGuestName = _indexOf(headerStrings, 'guest_name');
    final idxGuestPhone = _indexOf(headerStrings, 'guest_phone');
    final idxGuestEmail = _indexOf(headerStrings, 'guest_email');
    final idxCheckIn = _indexOf(headerStrings, 'check_in');
    final idxCheckOut = _indexOf(headerStrings, 'check_out');
    final idxCheckInTime = _indexOf(headerStrings, 'check_in_time');
    final idxCheckOutTime = _indexOf(headerStrings, 'check_out_time');
    final idxGuestCount = _indexOf(headerStrings, 'guest_count');
    final idxInternalNote = _indexOf(headerStrings, 'internal_note');

    if (idxApartmentCode < 0 || idxCheckIn < 0 || idxCheckOut < 0) {
      throw ArgumentError('admin.import_missing_columns');
    }

    // Dynamické sloupce (služby) – jen ty s prefixem srv_ (např. srv_transfer_in → transfer_in)
    // Odříznutí prefixu zachová párování do tenant_services.service_type.
    final dynamicServiceHeaders = <int, String>{};
    const srvPrefix = 'srv_';
    for (var i = 0; i < headerStrings.length; i++) {
      final name = headerStrings[i];
      if (name.isEmpty) continue;
      if (_fixedHeaders.any((h) => h.toLowerCase() == name)) continue;
      if (name.startsWith(srvPrefix)) {
        final serviceType = name.substring(srvPrefix.length).trim();
        if (serviceType.isNotEmpty) {
          dynamicServiceHeaders[i] = serviceType;
        }
      }
    }

    // KROK 0: BULK FETCH – tenant_services, apartment_services včetně výchozích hodnot pro parseServiceCell
    final serviceTypeToId = <String, String>{};
    final aptServiceByKey = <String, String>{};
    final aptServiceRowById = <String, Map<String, dynamic>>{};
    final tenantServiceRowById = <String, Map<String, dynamic>>{};
    try {
      final tsRes = await SupabaseService.safeFrom('tenant_services', tenantId)
          .select('id, service_type, default_price')
          .isFilter('deleted_at', null);
      for (final e in tsRes as List) {
        final m = e as Map<String, dynamic>;
        final rawSt = m['service_type'];
        final rawId = m['id'];
        final st = (rawSt != null ? rawSt.toString() : '').trim().toLowerCase();
        final id = rawId?.toString().trim();
        if (st.isNotEmpty && id != null && id.isNotEmpty) {
          serviceTypeToId[st] = id;
          tenantServiceRowById[id] = m;
        }
      }
      final asRes = await SupabaseService.safeFrom('apartment_services', tenantId)
          .select('id, apartment_id, service_id, custom_price, payer_type');
      for (final e in asRes as List) {
        final m = e as Map<String, dynamic>;
        final rawApt = m['apartment_id'];
        final rawSvc = m['service_id'];
        final rawAsId = m['id'];
        final aptId = (rawApt != null ? rawApt.toString() : '').trim();
        final svcId = (rawSvc != null ? rawSvc.toString() : '').trim();
        final asId = (rawAsId != null ? rawAsId.toString() : '').trim();
        if (aptId.isNotEmpty && svcId.isNotEmpty && asId.isNotEmpty) {
          aptServiceByKey['$aptId|$svcId'] = asId;
          aptServiceRowById[asId] = m;
        }
      }
    } catch (_) {
      // Při chybě fetchu pokračujeme – dynamické sloupce půjdou do záchranné brzdy
    }

    int successCount = 0;
    int warningCount = 0;
    int errorCount = 0;
    final pendingReservationServices = <Map<String, dynamic>>[];

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      final codeRaw = _cell(row, idxApartmentCode);
      final code = codeRaw.trim();
      if (code.isEmpty) continue;

      final apartmentId = codeToApartmentId[code];
      if (apartmentId == null || apartmentId.isEmpty) {
        errorCount++;
        continue;
      }

      final referenceNumber = generateReservationRef();
      var internalNote = _cell(row, idxInternalNote).trim();

      // Dynamické sloupce – služby
      final rowServices = <Map<String, dynamic>>[];
      for (final entry in dynamicServiceHeaders.entries) {
        final cellContent = _cell(row, entry.key).trim();
        if (cellContent.isEmpty) continue;

        final columnName = entry.value.trim().toLowerCase();
        final tenantServiceId = serviceTypeToId[columnName];
        if (tenantServiceId == null || tenantServiceId.isEmpty) {
          warningCount++;
          final line = '[CHYBA IMPORTU - ${entry.value}]: $cellContent';
          internalNote = internalNote.isEmpty ? line : '$internalNote\n$line';
          continue;
        }

        final aptServiceId = aptServiceByKey['$apartmentId|$tenantServiceId'];
        if (aptServiceId == null || aptServiceId.isEmpty) {
          warningCount++;
          final line = '[CHYBA IMPORTU - ${entry.value}]: $cellContent';
          internalNote = internalNote.isEmpty ? line : '$internalNote\n$line';
          continue;
        }

        final aptRow = aptServiceRowById[aptServiceId];
        final tenantRow = tenantServiceRowById[tenantServiceId];
        num? defaultPrice;
        String? defaultPayer = 'host';
        try {
          if (tenantRow != null && tenantRow['default_price'] != null) {
            final v = tenantRow['default_price'];
            defaultPrice = v is num ? v : num.tryParse(v.toString());
          }
          if (aptRow != null) {
            final cp = aptRow['custom_price'];
            if (cp != null) defaultPrice = cp is num ? cp : num.tryParse(cp.toString());
            final pt = (aptRow['payer_type']?.toString() ?? '').trim();
            if (pt == 'owner' || pt == 'guest') defaultPayer = pt;
          }
        } catch (_) {}

        final parsed = parseServiceCell(
          cellContent,
          defaultPrice: defaultPrice,
          defaultPayer: defaultPayer,
        );
        // Normalizace payer_type: DB přijímá pouze 'owner'|'guest'. 'host' (synonymum) -> 'guest'.
        final payerType = (parsed.payerType == 'host') ? 'guest' : parsed.payerType;

        rowServices.add({
          'apartment_service_id': aptServiceId,
          'charged_price': parsed.chargedPrice,
          'custom_note': parsed.customNote?.trim().isEmpty == true ? null : parsed.customNote,
          'payer_type': payerType,
          'flight_number': parsed.flightNumber?.trim().isEmpty == true ? null : parsed.flightNumber,
        });
      }

      final checkInStr = _cell(row, idxCheckIn).trim();
      final checkOutStr = _cell(row, idxCheckOut).trim();
      if (checkInStr.isEmpty || checkOutStr.isEmpty) {
        errorCount++;
        continue;
      }

      final guestName = _cell(row, idxGuestName).trim();
      final guestPhone = _cell(row, idxGuestPhone).trim();
      final guestCount = int.tryParse(_cell(row, idxGuestCount).trim()) ?? 0;
      final guestAdults = guestCount > 0 ? guestCount : 0;
      final guestChildren = 0;

      final startDate = _parseDate(checkInStr);
      final endDate = _parseDate(checkOutStr);
      if (startDate == null || endDate == null || !endDate.isAfter(startDate)) {
        errorCount++;
        continue;
      }

      // Časy příjezdu/odjezdu z Excelu – pokud vyplněné, použijeme je; jinak default 15:00 a 10:00 (fallback).
      final checkInTimeStr = idxCheckInTime >= 0 ? _cell(row, idxCheckInTime).trim() : '';
      final checkOutTimeStr = idxCheckOutTime >= 0 ? _cell(row, idxCheckOutTime).trim() : '';
      final parsedCheckInTime = _parseTime(checkInTimeStr);
      final parsedCheckOutTime = _parseTime(checkOutTimeStr);
      final arrivalTime = parsedCheckInTime != null
          ? DateTime(startDate.year, startDate.month, startDate.day, parsedCheckInTime.$1, parsedCheckInTime.$2, 0).toUtc().toIso8601String()
          : DateTime(startDate.year, startDate.month, startDate.day, 15, 0, 0).toUtc().toIso8601String();
      final departureTime = parsedCheckOutTime != null
          ? DateTime(endDate.year, endDate.month, endDate.day, parsedCheckOutTime.$1, parsedCheckOutTime.$2, 0).toUtc().toIso8601String()
          : DateTime(endDate.year, endDate.month, endDate.day, 10, 0, 0).toUtc().toIso8601String();

      try {
        final insertPayload = <String, dynamic>{
          'tenant_id': tenantId,
          'apartment_id': apartmentId,
          'reference_number': referenceNumber,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'status': 'new',
          'guest_name': guestName.isEmpty ? null : guestName,
          'guest_phone': guestPhone.isEmpty ? null : guestPhone,
          'guest_adults': guestAdults,
          'guest_children': guestChildren,
          'internal_note': internalNote.isEmpty ? null : internalNote,
          'arrival_time': arrivalTime,
          'departure_time': departureTime,
        };
        // guest_email – DB zatím nemá sloupec; připraveno pro budoucí migraci
        if (idxGuestEmail >= 0) {
          final email = _cell(row, idxGuestEmail).trim();
          if (email.isNotEmpty) {
            // Reservations tabulka nemá guest_email – zatím neukládáme, pouze čteme pro budoucí rozšíření
          }
        }

        final insertRes =
            await SupabaseService.safeFrom('reservations', tenantId).insert(insertPayload).select('id');

        String? reservationId;
        final insertList = insertRes as List;
        if (insertList.isNotEmpty) {
          final firstRow = insertList.first;
          if (firstRow is Map) {
            final idVal = firstRow['id'];
            final idStr = (idVal != null ? idVal.toString() : '').trim();
            reservationId = idStr.isEmpty ? null : idStr;
          }
        }
        if (reservationId != null && reservationId.isNotEmpty && rowServices.isNotEmpty) {
          for (final svc in rowServices) {
            pendingReservationServices.add({
              'tenant_id': tenantId,
              'reservation_id': reservationId,
              'apartment_service_id': svc['apartment_service_id'],
              'charged_price': svc['charged_price'],
              'custom_note': svc['custom_note'],
              'payer_type': svc['payer_type'],
              'flight_number': svc['flight_number'],
            });
          }
        }
        successCount++;
      } catch (_) {
        errorCount++;
      }
    }

    if (pendingReservationServices.isNotEmpty) {
      try {
        await SupabaseService.safeFrom('reservation_services', tenantId).insert(pendingReservationServices);
      } catch (_) {
        // Rezervace už jsou uložené – služby lze doplnit ručně
      }
    }

    return ReservationImportResult(
      successCount: successCount,
      warningCount: warningCount,
      errorCount: errorCount,
    );
  }

  /// Převod CellValue na řetězec pro import – podpora všech typů z excel balíčku 4.x.
  static String _cellValueToString(CellValue? v) {
    if (v == null) return '';
    return switch (v) {
      TextCellValue(:final value) => value.toString(),
      IntCellValue(:final value) => '$value',
      DoubleCellValue(:final value) => '$value',
      BoolCellValue(:final value) => value ? '1' : '0',
      DateCellValue() => '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}',
      TimeCellValue() => '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}',
      DateTimeCellValue() => '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}',
      FormulaCellValue(:final formula) => formula.toString(),
    };
  }

  static String _cell(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index];
  }

  static int _indexOf(List<String> headers, String name) {
    final lower = name.toLowerCase();
    for (var i = 0; i < headers.length; i++) {
      if (headers[i] == lower) return i;
    }
    return -1;
  }

  /// Parsuje buňku služby – CENA|PLÁTCE|ČÍSLO_LETU|POZNÁMKA.
  /// Prázdné místo = výchozí z DB. "ano"/"yes"/"1"/"x"/"true" = vše z DB.
  static ParsedService parseServiceCell(
    String cellValue, {
    num? defaultPrice,
    String? defaultPayer,
  }) {
    try {
      final trimmed = cellValue.trim();
      final lower = trimmed.toLowerCase();
      if (lower == 'ano' || lower == 'yes' || lower == '1' || lower == 'x' || lower == 'true') {
        return ParsedService(
          chargedPrice: defaultPrice,
          payerType: defaultPayer ?? 'host',
          customNote: null,
          flightNumber: null,
        );
      }

      final parts = cellValue.split('|').map((p) => p.trim()).toList();
      if (parts.isEmpty) return ParsedService(chargedPrice: defaultPrice, payerType: defaultPayer ?? 'host');

      num? chargedPrice;
      final first = parts[0];
      if (first.isNotEmpty) {
        chargedPrice = num.tryParse(first.replaceAll(',', '.'));
      }
      chargedPrice ??= defaultPrice;

      String? payerType = defaultPayer ?? 'host';
      if (parts.length > 1 && parts[1].isNotEmpty) {
        final p = parts[1].toLowerCase();
        if (p == 'owner' || p == 'majitel') {
          payerType = 'owner';
        } else if (p == 'guest' || p == 'host') payerType = 'guest';
      }

      String? flightNumber;
      if (parts.length > 2 && parts[2].isNotEmpty) {
        flightNumber = parts[2];
      }

      String? customNote;
      if (parts.length > 3) {
        final rest = parts.sublist(3).where((p) => p.isNotEmpty).toList();
        customNote = rest.isEmpty ? null : 'Parametry z importu: ${rest.join(', ')}';
      }

      return ParsedService(
        chargedPrice: chargedPrice,
        payerType: payerType,
        flightNumber: flightNumber,
        customNote: customNote,
      );
    } catch (_) {
      return ParsedService(chargedPrice: defaultPrice, payerType: defaultPayer ?? 'host');
    }
  }

  static DateTime? _parseDate(String s) {
    if (s.trim().isEmpty) return null;
    var parsed = DateTime.tryParse(s.trim());
    if (parsed != null) return parsed;
    final parts = s.trim().split(RegExp(r'[\./\-]'));
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        if (c > 999) return DateTime(c, b, a);
        if (a > 999) return DateTime(a, b, c);
      }
    }
    return null;
  }

  /// Parsuje čas z řetězce (např. "23:55", "9:00", "14.30") na (hodina, minuta).
  /// Vrací null při prázdném nebo neplatném vstupu – pak import použije defaultní časy.
  /// Hodina 0–23, minuta 0–59 (přetečení se ořízne).
  static (int, int)? _parseTime(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    // Podpora : i . jako oddělovač (Excel může zobrazit čas s tečkou).
    final parts = t.split(RegExp(r'[:\.]'));
    if (parts.isEmpty) return null;
    final hour = int.tryParse(parts[0].trim());
    if (hour == null || hour < 0 || hour > 23) return null;
    int minute = 0;
    if (parts.length >= 2) {
      final m = int.tryParse(parts[1].trim());
      if (m != null && m >= 0 && m <= 59) minute = m;
    }
    return (hour, minute);
  }
}
