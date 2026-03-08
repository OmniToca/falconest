import 'package:excel/excel.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/download_helper/download_helper.dart';
import 'package:falconest/features/super_admin/services/master_excel_parser.dart';

/// Služba pro export dat agentury do Master Excel šablony (1:1 kompatibilita s importem).
///
/// Generuje XLSX se 4 listy: 00_Navod (číselníky a návod), 01_Personal, 02_Katalog_Sluzeb, 03_Portfolio.
/// List 00_Navod je první a slouží klientovi jako nápověda a zdroj pro Data Validation v Excelu.
class OnboardingExportService {
  OnboardingExportService._();

  /// Název listu s číselníky a návodem – první list v souboru.
  static const String navodSheetName = '00_Navod';

  /// Číselníky pro list 00_Navod: hlavičky (R0) a řádky R1–R5 (Povolené Profese | Povolené Spouštěče | Povolený Plátce).
  static const List<List<String>> _navodRows = [
    ['Povolené Profese', 'Povolené Spouštěče', 'Povolený Plátce'],
    ['cleaner', 'before_checkin', 'guest'],
    ['driver', 'after_checkout', 'owner'],
    ['maintenance', 'on_demand', ''],
    ['checkin_agent', 'both_ways', ''],
    ['admin', 'scheduled', ''],
  ];

  /// R0 a R1 pro list 01_Personal – nutná 1:1 shoda s MasterExcelParser.
  static const List<String> _staffR0 = ['jmeno', 'email', 'role', 'jazyk', 'telefon', 'system_profese'];
  static const List<String> _staffR1 = [
    'Jméno a Příjmení',
    'E-mail (Login)',
    'Role v systému',
    'Jazyk',
    'Telefon',
    'Systémová Profese (cleaner, driver, maintenance, checkin_agent)',
  ];

  /// R0 a R1 pro list 02_Katalog_Sluzeb.
  static const List<String> _servicesR0 = [
    'kod_sluzby',
    'nazev_sluzby',
    'cena_eur',
    'platce',
    'delka_minut',
    'vyzadovana_profese',
    'spoustec',
  ];
  static const List<String> _servicesR1 = [
    'Systémový Kód',
    'Název pro klienta',
    'Cena (€)',
    'Kdo platí',
    'Délka (min.)',
    'Vyžadovaná Profese (kód)',
    'Spouštěč (before_checkin, after_checkout, on_demand)',
  ];

  /// R0 a R1 pro list 03_Portfolio.
  static const List<String> _portfolioR0 = [
    'kod_apartmanu',
    'nazev_apartmanu',
    'email_majitele',
    'jmeno_majitele',
    'telefon_majitele',
    'aktivni_sluzby',
  ];
  static const List<String> _portfolioR1 = [
    'Kód Apartmánu',
    'Název',
    'E-mail MAJITELE',
    'Jméno MAJITELE',
    'Telefon MAJITELE',
    'Aktivní Služby (kódy)',
  ];

  /// Stáhne prázdnou Excel šablonu pro White-Glove Onboarding (bez čtení z databáze).
  ///
  /// Vytvoří soubor se 4 listy: 00_Navod (číselníky), 01_Personal, 02_Katalog_Sluzeb, 03_Portfolio
  /// pouze s hlavičkami – klient může šablonu vyplnit a nahrát při importu. Název souboru:
  /// [FalcoNest_Onboarding_Sablona.xlsx].
  ///
  /// Vrhá [Exception] při chybě generování nebo zápisu souboru.
  static Future<void> downloadEmptyTemplate() async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet == null) {
      throw Exception('Excel.createExcel() nevratil výchozí list.');
    }

    // List 00_Navod – číselníky (první list v souboru).
    excel.rename(defaultSheet, navodSheetName);
    for (var r = 0; r < _navodRows.length; r++) {
      _writeRow(excel, navodSheetName, r, _navodRows[r]);
    }

    // List 01_Personal – pouze hlavičky R0 a R1.
    excel.insertRowIterables(
      MasterExcelParser.staffSheetName,
      _staffR0.map((s) => TextCellValue(s)).toList(),
      0,
    );
    excel.insertRowIterables(
      MasterExcelParser.staffSheetName,
      _staffR1.map((s) => TextCellValue(s)).toList(),
      1,
    );

    // List 02_Katalog_Sluzeb – pouze hlavičky.
    excel.insertRowIterables(
      MasterExcelParser.servicesSheetName,
      _servicesR0.map((s) => TextCellValue(s)).toList(),
      0,
    );
    excel.insertRowIterables(
      MasterExcelParser.servicesSheetName,
      _servicesR1.map((s) => TextCellValue(s)).toList(),
      1,
    );

    // List 03_Portfolio – pouze hlavičky.
    excel.insertRowIterables(
      MasterExcelParser.portfolioSheetName,
      _portfolioR0.map((s) => TextCellValue(s)).toList(),
      0,
    );
    excel.insertRowIterables(
      MasterExcelParser.portfolioSheetName,
      _portfolioR1.map((s) => TextCellValue(s)).toList(),
      1,
    );

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Excel.encode() vrátil prázdný soubor.');
    }
    const fileName = 'FalcoNest_Onboarding_Sablona.xlsx';
    await downloadBytesAsFile(bytes, fileName);
  }

  /// Exportuje všechna data agentury do XLSX a spustí stažení souboru.
  ///
  /// [tenantId] – agentura k exportu.
  /// [tenantName] – používá se v názvu souboru (např. `NazevAgentury_export_v1.xlsx`).
  ///
  /// Vrhá [Exception] při chybě načítání z DB nebo generování Excelu.
  static Future<void> exportTenantData(String tenantId, String tenantName) async {
    final client = SupabaseService.client;

    // ═══════════════════════════════════════════════════════════════════════════
    // NAČTENÍ DAT Z SUPABASE
    // ═══════════════════════════════════════════════════════════════════════════

    // Personál: profiles s tenant_id a role != 'property_owner'.
    // Majitelé (property_owner) se exportují v 03_Portfolio u apartmánů.
    // Ochrana proti exportu smazaných záznamů (Soft-Delete).
    final staffRes = await client
        .from('profiles')
        .select('id, email, first_name, last_name, name, role, roles, language_code')
        .eq('tenant_id', tenantId)
        .neq('role', 'property_owner')
        .isFilter('deleted_at', null);

    final staffList = (staffRes as List).cast<Map<String, dynamic>>();

    // Katalog služeb: tenant_services. service_type = systémový kód (cleaning, transfer, …).
    // Pro platce (payer) nemá tenant_services sloupec – bereme první nalezený payer_type
    // z apartment_services pro danou službu, případně fallback 'guest'.
    // Ochrana proti exportu smazaných záznamů (Soft-Delete).
    final servicesRes = await client
        .from('tenant_services')
        .select('id, service_type, name, default_price, duration_minutes, required_role')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null);

    final servicesList = (servicesRes as List).cast<Map<String, dynamic>>();

    // Mapování service_id → payer_type z apartment_services (první záznam pro danou službu).
    // apartment_services nemá deleted_at – soft-delete se zde neuplatňuje.
    final payerByServiceId = <String, String>{};
    final triggerByServiceId = <String, String>{};
    final asRes = await client
        .from('apartment_services')
        .select('service_id, payer_type, trigger_type')
        .eq('tenant_id', tenantId);
    for (final row in asRes as List) {
      final m = row as Map<String, dynamic>;
      final sid = (m['service_id']?.toString() ?? '').trim();
      if (sid.isNotEmpty && !payerByServiceId.containsKey(sid)) {
        final pt = (m['payer_type']?.toString() ?? 'guest').trim().toLowerCase();
        payerByServiceId[sid] = pt == 'owner' ? 'owner' : 'guest';
      }
      if (sid.isNotEmpty && !triggerByServiceId.containsKey(sid)) {
        final tt = (m['trigger_type']?.toString() ?? '').trim();
        if (tt.isNotEmpty) triggerByServiceId[sid] = tt;
      }
    }

    // Apartmány: apartments s filtrem Soft-Delete.
    // Ochrana proti exportu smazaných záznamů (Soft-Delete).
    final apartmentsRes = await client
        .from('apartments')
        .select('id, code, name')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null);

    final apartmentsList = (apartmentsRes as List).cast<Map<String, dynamic>>();
    final apartmentIds = apartmentsList.map((a) => _str(a['id'])).where((id) => id.isNotEmpty).toList();

    // Majitelé: apartment_owners s profiles – samostatný dotaz kvůli filtru deleted_at na apartment_owners.
    // Ochrana proti exportu smazaných záznamů (Soft-Delete) – filtrujeme apartment_owners i profiles.
    final Map<String, Map<String, dynamic>> apartmentIdToOwner = {};
    if (apartmentIds.isNotEmpty) {
      final ownersRes = await client
          .from('apartment_owners')
          .select('apartment_id, profiles(email, first_name, last_name, name, deleted_at)')
          .inFilter('apartment_id', apartmentIds)
          .isFilter('deleted_at', null);
      for (final row in (ownersRes as List)) {
        final m = row as Map<String, dynamic>;
        final aptId = (m['apartment_id']?.toString() ?? '').trim();
        if (aptId.isEmpty || apartmentIdToOwner.containsKey(aptId)) continue;
        final prof = m['profiles'];
        if (prof is Map && prof['deleted_at'] != null) continue; // Vynechat smazané profily majitelů.
        apartmentIdToOwner[aptId] = m;
      }
    }

    // Služby k apartmánům: apartment_services → tenant_services pro service_type.
    // Načteme apartment_services a spojíme s tenant_services (už máme servicesList).
    final serviceIdToCode = <String, String>{};
    for (final s in servicesList) {
      final id = (s['id']?.toString() ?? '').trim();
      final code = (s['service_type']?.toString() ?? '').trim();
      if (id.isNotEmpty && code.isNotEmpty) {
        serviceIdToCode[id] = code;
      }
    }

    // apartment_services nemá sloupec deleted_at – vazby byt↔služba se berou všechny.
    final aptServicesRes = await client
        .from('apartment_services')
        .select('apartment_id, service_id')
        .eq('tenant_id', tenantId);

    // Sestavení mapy apartment_id → seznam kódů služeb (service_type).
    final apartmentIdToServiceCodes = <String, List<String>>{};
    for (final row in aptServicesRes as List) {
      final m = row as Map<String, dynamic>;
      final aptId = (m['apartment_id']?.toString() ?? '').trim();
      final svcId = (m['service_id']?.toString() ?? '').trim();
      if (aptId.isEmpty || svcId.isEmpty) continue;
      final code = serviceIdToCode[svcId];
      if (code == null) continue;
      apartmentIdToServiceCodes.putIfAbsent(aptId, () => []).add(code);
    }

    // Majitelé – potřebujeme phone. profiles nemusí mít phone přímo.
    // database_schema: profiles má first_name, last_name, name, email, ale ne phone.
    // clients může mít phone, ale majitelé jsou v profiles. Zkontrolujeme – možná je phone v jiné tabulce.
    // Pro jistotu načteme profiles z embedu – telefon majitele: pokud nemáme v profiles, dáme prázdno.
    // Schema profiles: phone není. Takže telefon majitele = prázdný, pokud ho nemáme jinde.
    // (Později lze rozšířit o clients nebo jiný zdroj.)

    // ═══════════════════════════════════════════════════════════════════════════
    // GENEROVÁNÍ EXCELU
    // ═══════════════════════════════════════════════════════════════════════════

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet == null) {
      throw Exception('Excel.createExcel() nevratil výchozí list.');
    }

    // LIST 00_Navod jako první – přejmenujeme výchozí list a zapíšeme číselníky (nápověda pro klienta).
    excel.rename(defaultSheet, navodSheetName);
    for (var r = 0; r < _navodRows.length; r++) {
      _writeRow(excel, navodSheetName, r, _navodRows[r]);
    }

    // LIST 01_Personal: vytvoříme zápisem (insertRowIterables vytvoří list), R0 hlavičky, R1 vizuální, R2+ data.
    excel.insertRowIterables(
      MasterExcelParser.staffSheetName,
      _staffR0.map((s) => TextCellValue(s)).toList(),
      0,
    );
    excel.insertRowIterables(
      MasterExcelParser.staffSheetName,
      _staffR1.map((s) => TextCellValue(s)).toList(),
      1,
    );
    for (var i = 0; i < staffList.length; i++) {
      final p = staffList[i];
      final n = _str(p['name']);
      final name = n.isNotEmpty ? n : '${_str(p['first_name'])} ${_str(p['last_name'])}'.trim();
      final email = _str(p['email']);
      final role = _str(p['role']).isNotEmpty ? _str(p['role']) : 'worker';
      final lang = _str(p['language_code']).isNotEmpty ? _str(p['language_code']) : 'cs';
      final phone = ''; // profiles nemá phone – rozšíření možné přes clients/jiný zdroj
      final rolesRaw = p['roles'];
      final systemProfese = (rolesRaw is List && rolesRaw.isNotEmpty)
          ? _str(rolesRaw.first)
          : '';
      _writeRow(excel, MasterExcelParser.staffSheetName, 2 + i, [name, email, role, lang, phone, systemProfese]);
    }

    // LIST 02_Katalog_Sluzeb: insertRowIterables vytvoří list, pokud neexistuje.
    excel.insertRowIterables(
      MasterExcelParser.servicesSheetName,
      _servicesR0.map((s) => TextCellValue(s)).toList(),
      0,
    );
    excel.insertRowIterables(
      MasterExcelParser.servicesSheetName,
      _servicesR1.map((s) => TextCellValue(s)).toList(),
      1,
    );
    for (var i = 0; i < servicesList.length; i++) {
      final s = servicesList[i];
      final code = _str(s['service_type']).isNotEmpty ? _str(s['service_type']) : 'extra';
      final nameRaw = _str(s['name']);
      final name = nameRaw.isNotEmpty ? nameRaw : code;
      final price = s['default_price'];
      final priceStr = price != null ? (price is num ? price.toString() : price.toString()) : '0';
      final payer = payerByServiceId[_str(s['id'])] ?? 'guest';
      final duration = s['duration_minutes'];
      final durationStr = duration != null ? duration.toString() : '60';
      final requiredRole = _str(s['required_role']);
      final trigger = triggerByServiceId[_str(s['id'])] ?? '';
      _writeRow(excel, MasterExcelParser.servicesSheetName, 2 + i, [
        code,
        name,
        priceStr,
        payer,
        durationStr,
        requiredRole,
        trigger,
      ]);
    }

    // LIST 03_Portfolio: insertRowIterables vytvoří list, pokud neexistuje.
    excel.insertRowIterables(
      MasterExcelParser.portfolioSheetName,
      _portfolioR0.map((s) => TextCellValue(s)).toList(),
      0,
    );
    excel.insertRowIterables(
      MasterExcelParser.portfolioSheetName,
      _portfolioR1.map((s) => TextCellValue(s)).toList(),
      1,
    );
    for (var i = 0; i < apartmentsList.length; i++) {
      final a = apartmentsList[i];
      final aptId = _str(a['id']);
      final code = _str(a['code']);
      final nameRaw = _str(a['name']);
      final name = nameRaw.isNotEmpty ? nameRaw : code;
      var ownerEmail = '';
      var ownerName = '';
      var ownerPhone = '';

      final ao = apartmentIdToOwner[aptId];
      if (ao != null) {
        final prof = ao['profiles'];
        if (prof is Map<String, dynamic>) {
          ownerEmail = _str(prof['email']);
          final fn = _str(prof['first_name']);
          final ln = _str(prof['last_name']);
          ownerName = _str(prof['name']);
          if (ownerName.isEmpty) ownerName = '$fn $ln'.trim();
          if (ownerName.isEmpty) ownerName = ownerEmail;
        }
      }

      final serviceCodes = apartmentIdToServiceCodes[aptId] ?? [];
      final activeServicesStr = serviceCodes.join(', ');

      _writeRow(excel, MasterExcelParser.portfolioSheetName, 2 + i, [
        code,
        name,
        ownerEmail,
        ownerName,
        ownerPhone,
        activeServicesStr,
      ]);
    }

    // Encode a stažení.
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Excel.encode() vrátil prázdný soubor.');
    }

    final safeName = tenantName.replaceAll(RegExp(r'[^\w\s\-]'), '_').replaceAll(RegExp(r'\s+'), '_');
    final fileName = '${safeName}_export_v1.xlsx';
    await downloadBytesAsFile(bytes, fileName);
  }

  /// Vrátí trimovaný string nebo prázdný řetězec (pro bezpečné zápisy do buněk).
  static String _str(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    return s;
  }

  static void _writeRow(Excel excel, String sheetName, int rowIndex, List<String> values) {
    for (var c = 0; c < values.length; c++) {
      excel.updateCell(
        sheetName,
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
        TextCellValue(values[c]),
      );
    }
  }
}
