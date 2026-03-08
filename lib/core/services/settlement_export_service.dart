import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:falconest/core/utils/download_helper/download_helper.dart';
import 'package:falconest/features/admin/providers/settlements_provider.dart';

/// Služba pro export historie výplat do PDF (případně Excelu).
///
/// PROČ: Admin potřebuje předat podklady účetní – exportované PDF s tabulkou
/// vyplacených odměn a provizí v daném měsíci.
class SettlementExportService {
  SettlementExportService._();

  /// Vygeneruje PDF s historií výplat pro daný měsíc a spustí stahování souboru.
  ///
  /// [month] – první den měsíce (určuje rok a měsíc pro záhlaví a název souboru).
  /// [monthLabel] – lokalizovaný text měsíce (např. "březen 2026"). Pokud null, použije se [locale].
  /// [locale] – kód jazyka pro formát data při chybějícím monthLabel (např. "cs", "en", "es").
  /// [data] – seskupené výplaty a provize (PayoutGroup).
  /// [tenantCurrency] – kód měny (např. EUR, CZK).
  /// [tenantName] – název agentury (volitelné, zobrazí se v hlavičce).
  /// [labels] – lokalizované labely (report_title, col_name, col_type, col_amount, total, type_employee, type_partner).
  static Future<void> exportPayoutHistoryToPdf({
    required DateTime month,
    String? monthLabel,
    String? locale,
    required List<PayoutGroup> data,
    required String tenantCurrency,
    String? tenantName,
    Map<String, String>? labels,
  }) async {
    final labelsMap = labels ?? {};
    // Fallback v angličtině, aby PDF nikdy neobsahovalo natvrdo češtinu při chybějících labelech.
    final reportTitle =
        labelsMap['report_title'] ?? 'Settlements and commissions report';
    final colName = labelsMap['col_name'] ?? 'Recipient';
    final colType = labelsMap['col_type'] ?? 'Type';
    final colAmount = labelsMap['col_amount'] ?? 'Total amount';
    final totalLabel = labelsMap['total'] ?? 'Total paid';
    final typeEmployee = labelsMap['type_employee'] ?? 'Employee';
    final typePartner = labelsMap['type_partner'] ?? 'Partner';

    // Font s podporou diakritiky (Roboto).
    pw.Font? font;
    try {
      font = await PdfGoogleFonts.robotoRegular();
    } catch (_) {}

    final textStyle = pw.TextStyle(font: font, fontSize: 10);
    final boldStyle =
        pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold);
    final titleStyle =
        pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold);

    final monthStr = monthLabel ?? DateFormat.yMMMM(locale ?? 'en').format(month);
    final headerText =
        tenantName != null && tenantName.trim().isNotEmpty
            ? '$reportTitle - $monthStr\n$tenantName'
            : '$reportTitle - $monthStr';

    final totalAmount =
        data.fold<double>(0, (s, g) => s + g.totalAmount);

    final tableRows = <pw.TableRow>[
      // Hlavička tabulky
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey300,
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(colName, style: boldStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(colType, style: boldStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(colAmount, style: boldStyle),
          ),
        ],
      ),
      // Data řádky
      ...data.map(
        (g) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(g.recipientName, style: textStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                g.isEmployee ? typeEmployee : typePartner,
                style: textStyle,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                '${_formatPrice(g.totalAmount)} $tenantCurrency',
                style: textStyle,
              ),
            ),
          ],
        ),
      ),
      // Součet
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey200,
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(totalLabel, style: boldStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text('', style: textStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              '${_formatPrice(totalAmount)} $tenantCurrency',
              style: pw.TextStyle(
                font: boldStyle.font,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ];

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          pw.Text(headerText, style: titleStyle),
          pw.SizedBox(height: 16),
          pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400),
    columnWidths: {
      0: const pw.FlexColumnWidth(3),
      1: const pw.FlexColumnWidth(1.5),
      2: const pw.FlexColumnWidth(1.5),
    },
    children: tableRows,
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final fileName = 'Settlements_${_pad(month.month)}_${month.year}.pdf';
    await downloadBytesAsFile(bytes, fileName);
  }

  static String _formatPrice(double v) => v.toStringAsFixed(2);
  static String _pad(int n) => n.toString().padLeft(2, '0');
}
