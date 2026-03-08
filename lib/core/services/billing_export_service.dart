import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/utils/download_helper/download_helper.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';

/// Služba pro export fakturačních podkladů do nativního Excelu (.xlsx).
///
/// B2B strategie: generujeme rovnou XLSX soubory, se kterými se klientům
/// a účetním pracuje lépe než s CSV. Balíček [excel] vytváří platné .xlsx.
class BillingExportService {
  BillingExportService._();

  /// Hromadný export – všechny skupiny do jednoho Excelu (pro účetní).
  static Future<void> exportAllToExcel(
    List<BillingGroup> groups,
    DateTime month,
    String tenantCurrency, {
    required String externalDisplayName,
    Map<String, String>? labels,
  }) async {
    final bytes = _buildExcel(groups, tenantCurrency, externalDisplayName, labels);
    final prefix = labels?['file_prefix_bulk'] ?? 'billing_complete';
    final fileName = '${prefix}_${_pad(month.month)}_${month.year}.xlsx';
    await downloadBytesAsFile(bytes, fileName);
  }

  /// Individuální export – jeden klient do Excelu (pro osobní výkaz).
  static Future<void> exportClientToExcel(
    BillingGroup clientGroup,
    DateTime month,
    String tenantCurrency, {
    required String externalDisplayName,
    Map<String, String>? labels,
  }) async {
    final bytes = _buildExcel([clientGroup], tenantCurrency, externalDisplayName, labels);
    final fallback = labels?['fallback_client_name'] ?? 'client';
    final clientName = clientGroup.groupKey == 'external'
        ? _sanitizeFileName(externalDisplayName, fallback: fallback)
        : _sanitizeFileName(clientGroup.groupName, fallback: fallback);
    final prefix = labels?['file_prefix_client'] ?? 'billing';
    final fileName = '${prefix}_${clientName}_${_pad(month.month)}_${month.year}.xlsx';
    await downloadBytesAsFile(bytes, fileName);
  }

  /// Vytvoří Excel soubor s daty – hlavičky, úkoly, uhrado hosty, náklady, celkem.
  static List<int> _buildExcel(
    List<BillingGroup> groups,
    String currency,
    String externalDisplayName,
    Map<String, String>? labels,
  ) {
    final labelsMap = labels ?? {};
    final paidByGuestsCat = labelsMap['paid_by_guests'] ?? 'Paid by guests';
    final paidByGuestsDetail = labelsMap['paid_by_guests_detail'] ?? 'Cash collected from guests';
    final colClient = labelsMap['col_client'] ?? 'Client';
    final colReservation = labelsMap['col_reservation'] ?? 'Reservation';
    final colTask = labelsMap['col_task'] ?? 'Task';
    final colScheduled = labelsMap['col_scheduled'] ?? 'Scheduled';
    final colCompleted = labelsMap['col_completed'] ?? 'Completed';
    final colPayer = labelsMap['col_payer'] ?? 'Payer';
    final colPrice = labelsMap['col_price'] ?? 'Price';
    final colCurrency = labelsMap['col_currency'] ?? 'Currency';
    final rowTotal = labelsMap['row_total'] ?? 'TOTAL';
    final rowAmountDue = labelsMap['row_amount_due'] ?? 'AMOUNT DUE';
    final encodeError = labelsMap['encode_error'] ?? 'Excel export failed – file is empty.';

    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';

    var rowIndex = 0;

    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    excel.insertRowIterables(
      sheetName,
      [
        TextCellValue(colClient),
        TextCellValue(colReservation),
        TextCellValue(colTask),
        TextCellValue(colScheduled),
        TextCellValue(colCompleted),
        TextCellValue(colPayer),
        TextCellValue(colPrice),
        TextCellValue(colCurrency),
      ],
      rowIndex++,
    );

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final clientName = group.groupKey == 'external'
          ? externalDisplayName
          : group.groupName;

      // Řádky pro úkoly – včetně přesných časů plánu a dokončení.
      // Sloupec Rezervace: jméno hosta + termín pobytu (dd.MM.yyyy - dd.MM.yyyy) pro kompletní kontext účetní.
      final dateFormatShort = DateFormat('dd.MM.yyyy');
      for (final task in group.tasks) {
        final base = task.guestName ?? task.reservationId ?? '';
        final resLabel = formatReservationBlockWithDates(
          baseTitle: base,
          reservationStart: task.reservationStart,
          reservationEnd: task.reservationEnd,
          formatDate: dateFormatShort.format,
        );
        final scheduledStr = task.scheduledStart != null
            ? dateFormat.format(task.scheduledStart!)
            : '';
        final completedStr =
            task.completedAt != null ? dateFormat.format(task.completedAt!) : '';
        final payer = _excelPayer(task.payerType, payerLabels: labelsMap);
        final price = task.chargedPrice.toStringAsFixed(2);
        excel.insertRowIterables(
          sheetName,
          [
            TextCellValue(clientName),
            TextCellValue(resLabel),
            TextCellValue(task.title),
            TextCellValue(scheduledStr),
            TextCellValue(completedStr),
            TextCellValue(payer),
            TextCellValue(price),
            TextCellValue(currency),
          ],
          rowIndex++,
        );
      }

      // Řádek "Uhraveno hosty" – odečet hotovosti vybrané od hostů
      if (group.totalPaidByGuest > 0) {
        excel.insertRowIterables(
          sheetName,
          [
            TextCellValue(clientName),
            TextCellValue(paidByGuestsCat),
            TextCellValue(paidByGuestsDetail),
            TextCellValue(''),
            TextCellValue(''),
            TextCellValue(''),
            TextCellValue((-group.totalPaidByGuest).toStringAsFixed(2)),
            TextCellValue(currency),
          ],
          rowIndex++,
        );
      }

      // Řádky pro náklady k proplacení – detailní rozpis (datum, popis, částka)
      for (final exp in group.expenses) {
        final expDateStr = dateFormatShort.format(exp.date);
        excel.insertRowIterables(
          sheetName,
          [
            TextCellValue(clientName),
            TextCellValue(''),
            TextCellValue(exp.description),
            TextCellValue(''),
            TextCellValue(expDateStr),
            TextCellValue(''),
            TextCellValue(exp.amount.toStringAsFixed(2)),
            TextCellValue(currency),
          ],
          rowIndex++,
        );
      }

      // Řádek s celkovou částkou k úhradě
      excel.insertRowIterables(
        sheetName,
        [
          TextCellValue(clientName),
          TextCellValue(rowTotal),
          TextCellValue(rowAmountDue),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(group.finalToInvoice.toStringAsFixed(2)),
          TextCellValue(currency),
        ],
        rowIndex++,
      );

      // Prázdný řádek mezi klienty (kromě posledního)
      if (i < groups.length - 1) {
        rowIndex++;
      }
    }

    final encoded = excel.encode();
    if (encoded == null || encoded.isEmpty) {
      throw StateError(encodeError);
    }
    return encoded;
  }

  static String _excelPayer(String payerType, {Map<String, String>? payerLabels}) {
    final translated = payerLabels?[payerType];
    if (translated != null && translated.isNotEmpty) return translated;
    switch (payerType) {
      case 'owner':
        return payerLabels?['owner'] ?? 'Owner';
      case 'guest':
        return payerLabels?['guest'] ?? 'Guest';
      case 'client':
        return payerLabels?['client'] ?? 'Client';
      default:
        return payerType.isNotEmpty ? payerType : (payerLabels?['guest'] ?? 'Guest');
    }
  }

  static String _sanitizeFileName(String name, {String fallback = 'client'}) {
    const diacritics = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ů': 'u',
      'ý': 'y', 'ÿ': 'y',
      'č': 'c', 'ć': 'c', 'ç': 'c',
      'ď': 'd', 'ě': 'e', 'ň': 'n', 'ñ': 'n',
      'ř': 'r', 'š': 's', 'ś': 's', 'ť': 't',
      'ž': 'z', 'ź': 'z',
    };
    var result = name.trim().toLowerCase();
    for (final e in diacritics.entries) {
      result = result.replaceAll(e.key, e.value);
    }
    result = result.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    result = result.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    return result.isEmpty ? fallback : result;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
