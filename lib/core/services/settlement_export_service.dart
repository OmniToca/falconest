import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/utils/download_helper/download_helper.dart';
import 'package:falconest/features/admin/providers/settlements_provider.dart';

/// Služba pro export historie výplat do PDF – přehled + výplatní pásky s detailem úkolů.
///
/// STRANA 1: Sumární tabulka (Kdo, Typ, Celkem). STRANY 2+: Pro každého příjemce
/// detailní tabulka úkolů (Datum, Úkol, Od–Do, Trvání, Odměna, Spropitné) a shrnutí
/// (celkem hodin, celková odměna, průměrná hodinová mzda).
class SettlementExportService {
  SettlementExportService._();

  /// Vygeneruje PDF s historií výplat pro daný měsíc a spustí stahování souboru.
  ///
  /// [month] – první den měsíce (záhlaví a název souboru).
  /// [monthLabel] – lokalizovaný text měsíce (např. "březen 2026").
  /// [locale] – kód jazyka pro formát data/času (např. "cs", "en", "es").
  /// [data] – seskupené výplaty (PayoutGroup) ze snapshotů; každá skupina může mít [items] s časy a trváním.
  /// [tenantCurrency] – kód měny (EUR, CZK).
  /// [tenantName] – název agentury (volitelné).
  /// [labels] – lokalizované labely včetně report_title, col_*, type_*, export_pdf_payslip_title (s {name}),
  ///   export_pdf_col_date, export_pdf_col_task, export_pdf_col_time_from_to, export_pdf_col_duration,
  ///   export_pdf_col_amount, export_pdf_col_tip, export_pdf_summary_*.
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
    final reportTitle =
        labelsMap['report_title'] ?? 'Settlements and commissions report';
    final colName = labelsMap['col_name'] ?? 'Recipient';
    final colType = labelsMap['col_type'] ?? 'Type';
    final colAmount = labelsMap['col_amount'] ?? 'Total amount';
    final totalLabel = labelsMap['total'] ?? 'Total paid';
    final typeEmployee = labelsMap['type_employee'] ?? 'Employee';
    final typePartner = labelsMap['type_partner'] ?? 'Partner';
    final payslipTitleTemplate =
        labelsMap['export_pdf_payslip_title'] ?? 'Detail: {name}';
    final colDate = labelsMap['export_pdf_col_date'] ?? 'Date';
    final colTask = labelsMap['export_pdf_col_task'] ?? 'Task';
    final colTimeFromTo = labelsMap['export_pdf_col_time_from_to'] ?? 'From – To';
    final colDuration = labelsMap['export_pdf_col_duration'] ?? 'Duration';
    final colAmountDetail = labelsMap['export_pdf_col_amount'] ?? 'Amount';
    final colTip = labelsMap['export_pdf_col_tip'] ?? 'Tip';
    final summaryHours =
        labelsMap['export_pdf_summary_hours'] ?? 'Total hours worked';
    final summaryTotalPay =
        labelsMap['export_pdf_summary_total_pay'] ?? 'Total net pay';
    final summaryHourlyRate =
        labelsMap['export_pdf_summary_hourly_rate'] ?? 'Average hourly rate';

    pw.Font? font;
    try {
      font = await PdfGoogleFonts.robotoRegular();
    } catch (e, st) {
      AppLogger.error('SettlementExportService: načtení PdfGoogleFonts.robotoRegular selhalo', e, st);
    }

    final textStyle = pw.TextStyle(font: font, fontSize: 9);
    final boldStyle =
        pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold);
    final titleStyle =
        pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold);
    final sectionStyle =
        pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold);

    final loc = locale ?? 'en';
    final monthStr = monthLabel ?? DateFormat.yMMMM(loc).format(month);
    final headerText =
        tenantName != null && tenantName.trim().isNotEmpty
            ? '$reportTitle - $monthStr\n$tenantName'
            : '$reportTitle - $monthStr';

    final totalAmount = data.fold<double>(0, (s, g) => s + g.totalAmount);

    final summaryTableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(colName, style: boldStyle)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(colType, style: boldStyle)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(colAmount, style: boldStyle)),
        ],
      ),
      ...data.map(
        (g) => pw.TableRow(
          children: [
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(g.recipientName, style: textStyle)),
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                    g.isEmployee ? typeEmployee : typePartner, style: textStyle)),
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                    '${_formatPrice(g.totalAmount)} $tenantCurrency',
                    style: textStyle)),
          ],
        ),
      ),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(totalLabel, style: boldStyle)),
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: textStyle)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                  '${_formatPrice(totalAmount)} $tenantCurrency',
                  style: pw.TextStyle(
                      font: boldStyle.font,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold))),
        ],
      ),
    ];

    final doc = pw.Document();
    final pageChildren = <pw.Widget>[
      pw.Text(headerText, style: titleStyle),
      pw.SizedBox(height: 16),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(1.5),
        },
        children: summaryTableRows,
      ),
    ];

    for (final g in data) {
      // GDPR: každý příjemce na vlastní stránce – před novou výplatní páskou zalamujeme
      pageChildren.add(pw.NewPage());
      pageChildren.add(pw.SizedBox(height: 24));
      final payslipTitle =
          payslipTitleTemplate.replaceAll('{name}', g.recipientName);
      pageChildren.add(pw.Text(payslipTitle, style: sectionStyle));
      pageChildren.add(pw.SizedBox(height: 8));

      if (g.items.isEmpty) {
        pageChildren.add(pw.Text(
            '-',
            style: textStyle.copyWith(
                color: PdfColors.grey700,
                fontStyle: pw.FontStyle.italic)));
      } else {
        final detailHeader = pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(colDate, style: boldStyle)),
            pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(colTask, style: boldStyle)),
            pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(colTimeFromTo, style: boldStyle)),
            pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(colDuration, style: boldStyle)),
            pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(colAmountDetail, style: boldStyle)),
            pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(colTip, style: boldStyle)),
          ],
        );

        final detailRows = g.items.map((item) {
          final dateStr = item.date != null
              ? DateFormat('dd.MM.yyyy', loc).format(item.date!)
              : 'common.placeholder_dash'.tr();
          final timeFromTo = _formatTimeFromTo(item.scheduledStart, item.scheduledEnd, loc);
          final durationStr = _formatDuration(item.durationMinutes);
          final amountStr = '${_formatPrice(item.amount)} $tenantCurrency';
          final tipStr = item.tipAmount > 0
              ? '${_formatPrice(item.tipAmount)} $tenantCurrency'
              : 'common.placeholder_dash'.tr();
          return pw.TableRow(
            children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(dateStr, style: textStyle)),
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(
                      item.taskTitle.isEmpty ? 'common.placeholder_dash'.tr() : item.taskTitle,
                      style: textStyle,
                      maxLines: 2)),
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(timeFromTo, style: textStyle)),
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(durationStr, style: textStyle)),
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(amountStr, style: textStyle)),
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(tipStr, style: textStyle)),
            ],
          );
        }).toList();

        pageChildren.add(pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(0.9),
            4: const pw.FlexColumnWidth(1.1),
            5: const pw.FlexColumnWidth(0.8),
          },
          children: [detailHeader, ...detailRows],
        ));

        final totalMinutes =
            g.items.fold<int>(0, (s, item) => s + item.durationMinutes);
        final totalHours = totalMinutes / 60.0;
        final totalPay = g.totalAmount;
        final hourlyRate = totalHours > 0 ? totalPay / totalHours : 0.0;
        final hoursStr = _formatHours(totalMinutes);
        final payStr = '${_formatPrice(totalPay)} $tenantCurrency';
        final rateStr = totalHours > 0
            ? '${_formatPrice(hourlyRate)} $tenantCurrency/h'
            : 'common.placeholder_dash'.tr();

        pageChildren.add(pw.SizedBox(height: 12));
        pageChildren.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    summaryHours.replaceAll('{hours}', hoursStr),
                    style: boldStyle),
                pw.SizedBox(height: 4),
                pw.Text(
                    summaryTotalPay.replaceAll('{pay}', payStr),
                    style: boldStyle),
                pw.SizedBox(height: 4),
                pw.Text(
                    summaryHourlyRate.replaceAll('{rate}', rateStr),
                    style: boldStyle),
              ],
            ),
          ),
        );
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pageChildren,
      ),
    );

    final bytes = await doc.save();
    final fileName = 'Settlements_${_pad(month.month)}_${month.year}.pdf';
    await downloadBytesAsFile(bytes, fileName);
  }

  static String _formatPrice(double v) => v.toStringAsFixed(2);
  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _formatTimeFromTo(DateTime? start, DateTime? end, String locale) {
    if (start == null && end == null) return 'common.placeholder_dash'.tr();
    final timeFormat = DateFormat('HH:mm', locale);
    if (start != null && end != null) {
      return '${timeFormat.format(start)} – ${timeFormat.format(end)}';
    }
    if (start != null) return timeFormat.format(start);
    return timeFormat.format(end!);
  }

  static String _formatDuration(int durationMinutes) {
    if (durationMinutes <= 0) return 'common.placeholder_dash'.tr();
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  static String _formatHours(int totalMinutes) {
    if (totalMinutes <= 0) return '0 h';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) return '$h h';
    return '$h h $m m';
  }
}
