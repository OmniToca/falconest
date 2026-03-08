import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

/// Parsovaný záznam apartmánu z listu 03_Portfolio Master Excelu.
///
/// Sloupce: kód apartmánu, název, e-mail majitele, jméno majitele, telefon majitele,
/// aktivní služby (čárkou oddělené kódy). Kód apartmánu a e-mail majitele jsou povinné.
class ParsedApartment {
  const ParsedApartment({
    required this.apartmentCode,
    required this.name,
    required this.ownerEmail,
    required this.ownerName,
    this.ownerPhone,
    this.activeServices = const [],
  });

  final String apartmentCode;
  final String name;
  final String ownerEmail;
  final String ownerName;
  final String? ownerPhone;
  final List<String> activeServices;
}

/// Parsovaný záznam služby z listu 02_Katalog_Sluzeb Master Excelu.
///
/// Sloupce: kód služby, název, cena (EUR), plátce (guest/owner/tenant),
/// délka (minuty), vyžadovaná profese (kód), spouštěč. Kód služby je povinný.
class ParsedService {
  const ParsedService({
    required this.serviceCode,
    required this.name,
    required this.priceEur,
    required this.payer,
    this.durationMinutes,
    required this.requiredRole,
    required this.triggerType,
  });

  final String serviceCode;
  final String name;
  final double priceEur;
  final String payer;
  final int? durationMinutes;
  /// Vyžadovaná profese (any, cleaner, driver, maintenance, checkin_agent) – z Excelu bez normalizace.
  final String requiredRole;
  /// Spouštěč (on_demand, before_checkin, after_checkout, both_ways, scheduled) – z Excelu bez normalizace.
  final String triggerType;
}

/// Parsovaný záznam personálu z listu 01_Personal Master Excelu.
///
/// Sloupce: Jméno, E-mail, Role, Jazyk, Telefon, Systémová Profese. E-mail je povinný.
/// Normalizaci profese (cleaner, driver, …) provádí až DB servis.
class ParsedStaff {
  const ParsedStaff({
    required this.name,
    required this.email,
    required this.role,
    required this.language,
    this.phone,
    required this.systemRole,
  });

  final String name;
  final String email;
  final String role;
  final String language;
  final String? phone;
  /// Systémová profese (cleaner, driver, maintenance, checkin_agent) – z Excelu, fallback prázdný string.
  final String systemRole;
}

/// Parser pro Master Excel soubor White-Glove Onboarding.
///
/// Čte jednotlivé záložky podle předem dohodnutého formátu. List 01_Personal
/// obsahuje personál (administrátoři, pracovníci) v pevně daném pořadí sloupců.
class MasterExcelParser {
  MasterExcelParser._();

  /// Název listu s personálem – přesná shoda (včetně prefixu 01_).
  static const String staffSheetName = '01_Personal';

  /// Parsuje list 01_Personal a vrací seznam validních záznamů personálu.
  ///
  /// FORMÁT LISTU:
  /// - Řádek 0: technické hlavičky (např. interní názvy sloupců) – PŘESKOČENO.
  /// - Řádek 1: vizuální hlavičky pro uživatele (Jméno, E-mail, …) – PŘESKOČENO.
  /// - Řádky 2+: data. Sloupce: 0=Jméno, 1=E-mail, 2=Role, 3=Jazyk, 4=Telefon.
  ///
  /// PROČ PŘESKAKOVAT ŘÁDKY 0 A 1: Master Excel má často dvojitou hlavičku –
  /// první řádek pro systémovou identifikaci, druhý pro čitelnost v Excelu.
  /// Data začínají až na třetím řádku (index 2).
  ///
  /// PRÁZDNÉ ŘÁDKY: Řádek bez e-mailu (prázdná buňka ve sloupci 1) se přeskočí.
  /// E-mail je klíčový identifikátor – bez něj nelze vytvořit profil/pozvánku.
  static List<ParsedStaff> parseStaffSheet(List<int> bytes) {
    if (bytes.isEmpty) {
      throw Exception('Soubor je prázdný.');
    }

    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception('Nepodařilo se načíst Excel soubor. Je soubor poškozený? $e');
    }

    final sheetNames = excel.tables.keys.toList();
    if (sheetNames.isEmpty) {
      throw Exception('Excel soubor neobsahuje žádné listy.');
    }

    // Hledání listu 01_Personal – přesná shoda názvu.
    // Fallback na první list, pokud cílový list chybí (s varováním).
    String? sheetName;
    if (sheetNames.contains(staffSheetName)) {
      sheetName = staffSheetName;
    } else {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MasterExcelParser: List "$staffSheetName" nenalezen. Používám první list: ${sheetNames.first}');
      }
      sheetName = sheetNames.first;
    }

    final sheet = excel[sheetName];
    final maxRow = sheet.maxRows;
    final maxCol = sheet.maxColumns;

    if (maxRow < 3 || maxCol < 2) {
      throw Exception('List "$sheetName" nemá dostatek řádků nebo sloupců. Očekáván formát: řádky 0-1 hlavičky, od řádku 2 data.');
    }

    final result = <ParsedStaff>[];

    // Iterace od řádku 2 (index 2) – přeskočeny řádky 0 (technické hlavičky) a 1 (vizuální hlavičky).
    // Sloupec 5 = system_profese (Systémová Profese).
    for (var r = 2; r < maxRow; r++) {
      final name = _getCellString(sheet, r, 0);
      final email = _getCellString(sheet, r, 1);
      final role = _getCellString(sheet, r, 2);
      final language = _getCellString(sheet, r, 3);
      final phone = _getCellString(sheet, r, 4);
      final systemRole = maxCol > 5 ? _getCellString(sheet, r, 5) : '';

      // Přeskočení prázdných řádků – e-mail je povinný. Řádek bez e-mailu = konec dat nebo oddělovač.
      if (email.trim().isEmpty) continue;

      // Jméno je doporučené; pokud chybí, použijeme e-mail jako fallback pro zobrazení.
      final effectiveName = name.trim().isEmpty ? email : name.trim();

      result.add(ParsedStaff(
        name: effectiveName,
        email: email.trim(),
        role: role.trim().isEmpty ? 'worker' : role.trim(),
        language: language.trim().isEmpty ? 'cs' : language.trim(),
        phone: phone.trim().isEmpty ? null : phone.trim(),
        systemRole: systemRole.trim(),
      ));
    }

    return result;
  }

  /// Název listu s katalogem služeb – přesná shoda.
  static const String servicesSheetName = '02_Katalog_Sluzeb';

  /// Parsuje list 02_Katalog_Sluzeb a vrací seznam validních záznamů služeb.
  ///
  /// FORMÁT LISTU:
  /// - Řádek 0: technické hlavičky – PŘESKOČENO.
  /// - Řádek 1: vizuální hlavičky – PŘESKOČENO.
  /// - Řádky 2+: data. Sloupce: 0=kód služby, 1=název, 2=cena (EUR), 3=plátce, 4=délka (min).
  ///
  /// BEZPEČNÉ PARSOVÁNÍ ČÍSEL: Cena a délka mohou být v Excelu jako text, číslo nebo prázdno.
  /// Používají se num.tryParse() a int.tryParse() – při neplatné hodnotě se použije výchozí
  /// (0.0 pro cenu, null pro délku). Nahrazení čárky tečkou zajišťuje správné parsování
  /// českých desetinných čísel (např. "12,50" → 12.50).
  ///
  /// PLÁTCE: Povolené hodnoty guest, owner, tenant. Jiné hodnoty se normalizují na 'guest'.
  static List<ParsedService> parseServicesSheet(List<int> bytes) {
    if (bytes.isEmpty) {
      throw Exception('Soubor je prázdný.');
    }

    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception('Nepodařilo se načíst Excel soubor. Je soubor poškozený? $e');
    }

    final sheetNames = excel.tables.keys.toList();
    if (sheetNames.isEmpty) {
      throw Exception('Excel soubor neobsahuje žádné listy.');
    }

    // Hledání listu 02_Katalog_Sluzeb. Fallback na list s indexem 1 (druhý list),
    // protože Master Excel má typicky 01_Personal jako první a 02_... jako druhý.
    String sheetName;
    if (sheetNames.contains(servicesSheetName)) {
      sheetName = servicesSheetName;
    } else if (sheetNames.length > 1) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MasterExcelParser: List "$servicesSheetName" nenalezen. Používám druhý list: ${sheetNames[1]}');
      }
      sheetName = sheetNames[1];
    } else {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MasterExcelParser: List "$servicesSheetName" nenalezen. Používám první list.');
      }
      sheetName = sheetNames.first;
    }

    final sheet = excel[sheetName];
    final maxRow = sheet.maxRows;
    final maxCol = sheet.maxColumns;

    if (maxRow < 3 || maxCol < 3) {
      throw Exception('List "$sheetName" nemá dostatek řádků nebo sloupců. Očekáván formát: řádky 0-1 hlavičky, od řádku 2 data.');
    }

    final result = <ParsedService>[];

    for (var r = 2; r < maxRow; r++) {
      final code = _getCellString(sheet, r, 0).trim();
      final name = _getCellString(sheet, r, 1).trim();
      final priceStr = _getCellString(sheet, r, 2).trim();
      final payerStr = _getCellString(sheet, r, 3).trim().toLowerCase();
      final durationStr = _getCellString(sheet, r, 4).trim();
      final requiredRole = maxCol > 5 ? _getCellString(sheet, r, 5).trim() : '';
      final triggerType = maxCol > 6 ? _getCellString(sheet, r, 6).trim() : '';

      // Přeskočení řádků bez kódu služby – kód je klíčový identifikátor.
      if (code.isEmpty) continue;

      // Bezpečné parsování ceny: replace čárka→tečka, pak num.tryParse. Výchozí 0.0.
      final priceEur = num.tryParse(priceStr.replaceAll(',', '.'))?.toDouble() ?? 0.0;

      // Bezpečné parsování délky: int.tryParse. Výchozí null (nepovinné).
      // Extrakce prvního čísla pro případy jako "30 min" nebo "45".
      int? durationMinutes;
      if (durationStr.isNotEmpty) {
        final match = RegExp(r'\d+').firstMatch(durationStr);
        durationMinutes = match != null ? int.tryParse(match.group(0)!) : null;
      }

      // Normalizace plátce: pouze guest, owner, tenant.
      String payer = 'guest';
      if (payerStr == 'owner' || payerStr == 'majitel') {
        payer = 'owner';
      } else if (payerStr == 'tenant' || payerStr == 'nájemce') {
        payer = 'tenant';
      } else if (payerStr == 'guest' || payerStr == 'host') {
        payer = 'guest';
      }

      result.add(ParsedService(
        serviceCode: code,
        name: name.isEmpty ? code : name,
        priceEur: priceEur,
        payer: payer,
        durationMinutes: durationMinutes,
        requiredRole: requiredRole,
        triggerType: triggerType,
      ));
    }

    return result;
  }

  /// Název listu s portfoliem – přesná shoda.
  static const String portfolioSheetName = '03_Portfolio';

  /// Parsuje list 03_Portfolio a vrací seznam validních záznamů apartmánů s majiteli.
  ///
  /// FORMÁT LISTU:
  /// - Řádek 0: technické hlavičky – PŘESKOČENO.
  /// - Řádek 1: vizuální hlavičky – PŘESKOČENO.
  /// - Řádky 2+: data. Sloupce: 0=kód apartmánu, 1=název, 2=e-mail majitele,
  ///   3=jméno majitele, 4=telefon majitele, 5=aktivní služby (čárkou oddělené kódy).
  ///
  /// ROZDĚLOVÁNÍ SLUŽEB PŘES ČÁRKU (sloupec 5):
  /// Buňka může obsahovat např. "transfer_in, transfer_out, cleaning". Pro získání
  /// seznamu kódů služeb použijeme split(','). Každý prvek se otrimuje (trim),
  /// aby se odstranily mezery kolem čárek. Prázdné prvky po trimu se vyfiltrují.
  /// Pokud je buňka prázdná, vracíme prázdný seznam – apartmán nemá navázané služby.
  static List<ParsedApartment> parsePortfolioSheet(List<int> bytes) {
    if (bytes.isEmpty) {
      throw Exception('Soubor je prázdný.');
    }

    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception('Nepodařilo se načíst Excel soubor. Je soubor poškozený? $e');
    }

    final sheetNames = excel.tables.keys.toList();
    if (sheetNames.isEmpty) {
      throw Exception('Excel soubor neobsahuje žádné listy.');
    }

    String sheetName;
    if (sheetNames.contains(portfolioSheetName)) {
      sheetName = portfolioSheetName;
    } else if (sheetNames.length > 2) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MasterExcelParser: List "$portfolioSheetName" nenalezen. Používám třetí list: ${sheetNames[2]}');
      }
      sheetName = sheetNames[2];
    } else if (sheetNames.length > 1) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MasterExcelParser: List "$portfolioSheetName" nenalezen. Používám druhý list.');
      }
      sheetName = sheetNames[1];
    } else {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MasterExcelParser: List "$portfolioSheetName" nenalezen. Používám první list.');
      }
      sheetName = sheetNames.first;
    }

    final sheet = excel[sheetName];
    final maxRow = sheet.maxRows;
    final maxCol = sheet.maxColumns;

    if (maxRow < 3 || maxCol < 4) {
      throw Exception('List "$sheetName" nemá dostatek řádků nebo sloupců. Očekáván formát: řádky 0-1 hlavičky, od řádku 2 data.');
    }

    final result = <ParsedApartment>[];

    for (var r = 2; r < maxRow; r++) {
      final code = _getCellString(sheet, r, 0).trim();
      final name = _getCellString(sheet, r, 1).trim();
      final ownerEmail = _getCellString(sheet, r, 2).trim();
      final ownerName = _getCellString(sheet, r, 3).trim();
      final ownerPhone = _getCellString(sheet, r, 4).trim();
      final servicesStr = _getCellString(sheet, r, 5).trim();

      // Vyřazení řádků bez kódu apartmánu nebo e-mailu majitele – obě hodnoty jsou povinné.
      if (code.isEmpty || ownerEmail.isEmpty) continue;

      // Rozdělení aktivních služeb podle čárky: "a, b, c" → ["a", "b", "c"].
      // Každý prvek se otrimuje a prázdné stringy se vyfiltrují.
      final activeServices = servicesStr.isEmpty
          ? <String>[]
          : servicesStr
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

      result.add(ParsedApartment(
        apartmentCode: code,
        name: name.isEmpty ? code : name,
        ownerEmail: ownerEmail,
        ownerName: ownerName.isEmpty ? ownerEmail : ownerName,
        ownerPhone: ownerPhone.isEmpty ? null : ownerPhone,
        activeServices: activeServices,
      ));
    }

    return result;
  }

  /// Převede buňku na řetězec – podpora všech typů z balíčku excel 4.x.
  static String _getCellString(Sheet sheet, int row, int col) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    final v = cell.value;
    return _cellValueToString(v);
  }

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
}
