import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:falconest/core/utils/download_helper/download_helper.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';

/// Služba pro generování PDF reportů s fotodokumentací – nezpochybnitelné podklady k fakturaci.
///
/// Používá balíčky [pdf] a [printing]. Obrázky z [BillingTaskItem.mediaUrls] se stahují
/// přes [networkImage] a vykreslují jako miniatury. Selhání jedné fotky neshodí celé PDF.
class BillingPdfService {
  BillingPdfService._();

  /// Vygeneruje PDF report pro jednoho klienta a spustí stahování souboru.
  ///
  /// [group] – BillingGroup klienta s úkoly a výdaji.
  /// [month] – měsíc fakturace.
  /// [tenantCurrency] – kód měny (např. EUR, CZK).
  /// [externalDisplayName] – zobrazovaný název pro skupinu 'external'.
  /// [payerLabels] – mapování payerType → přeložený label (owner, guest, client).
  /// [footerLabels] – všechny popisky (report_title, client_label, guest_label, ...).
  static Future<void> generateAndDownloadPdf(
    BillingGroup group,
    DateTime month,
    String tenantCurrency, {
    required String externalDisplayName,
    Map<String, String>? payerLabels,
    Map<String, String>? footerLabels,
  }) async {
    final clientName = group.groupKey == 'external'
        ? externalDisplayName
        : group.groupName;

    // Font s podporou české diakritiky (Roboto).
    pw.Font? font;
    try {
      font = await PdfGoogleFonts.robotoRegular();
    } catch (_) {
      // Fallback na výchozí font – omezená podpora diakritiky.
    }

    final textStyle = pw.TextStyle(font: font, fontSize: 10);
    final boldStyle = pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold);

    // Přednačtení obrázků – každá fotka v try-catch, aby selhání jedné neshodilo PDF.
    final imageCache = <String, List<pw.ImageProvider>>{};
    for (final task in group.tasks) {
      if (task.mediaUrls.isEmpty) continue;
      final list = <pw.ImageProvider>[];
      for (final url in task.mediaUrls) {
        if (url.isEmpty) continue;
        try {
          final prov = await networkImage(url);
          list.add(prov);
        } catch (_) {
          // Fotku přeskočíme – nesmí shodit celé PDF.
        }
      }
      if (list.isNotEmpty) {
        imageCache[task.taskId] = list;
      }
    }
    final expenseImageCache = <String, List<pw.ImageProvider>>{};
    for (final exp in group.expenses) {
      if (exp.mediaUrls.isEmpty) continue;
      final list = <pw.ImageProvider>[];
      for (final url in exp.mediaUrls) {
        if (url.isEmpty) continue;
        try {
          final prov = await networkImage(url);
          list.add(prov);
        } catch (_) {}
      }
      if (list.isNotEmpty) expenseImageCache[exp.id] = list;
    }

    final doc = pw.Document();
    final monthStr = '${_pad(month.month)}/${month.year}';

    // Rozdělení úkolů podle rezervací a samostatné.
    final tasksWithRes = <String, List<BillingTaskItem>>{};
    final tasksWithoutRes = <BillingTaskItem>[];
    for (final task in group.tasks) {
      final resId = task.reservationId;
      if (resId != null && resId.isNotEmpty) {
        tasksWithRes.putIfAbsent(resId, () => []).add(task);
      } else {
        tasksWithoutRes.add(task);
      }
    }

    final bodyChildren = <pw.Widget>[];

    // Lokalizované labely – fallback anglicky při chybějící mapě (např. Klientská zóna).
    final labels = footerLabels ?? {};
    final labelReportTitle = labels['report_title'] ?? 'Services report for ';
    final labelClient = labels['client_label'] ?? 'Client: ';
    final labelSummary = labels['summary_section'] ?? 'Executive Summary';
    final labelServices = labels['services_breakdown'] ?? 'Breakdown of services provided';
    final labelTotalTurnover = labels['total_turnover'] ?? 'Total turnover for services';
    final labelPaidByGuests = labels['paid_by_guests'] ?? 'Paid by guests (cash)';
    final labelExpenses = labels['expenses_to_reimburse'] ?? 'Costs to reimburse';
    final labelFinalPay = labels['final_pay'] ?? 'AMOUNT DUE (Owner balance)';
    final labelSubtotalPerRes = labels['subtotal_per_reservation'] ?? 'Amount due for reservation';
    final labelTurnoverShort = labels['turnover_short'] ?? 'Turnover';
    final labelGuestPaidShort = labels['guest_paid_short'] ?? 'Paid by guests';
    final labelGuest = labels['guest_label'] ?? 'Guest: ';
    final labelReservation = labels['reservation_prefix'] ?? 'Reservation: ';
    final labelStandalone = labels['standalone_services'] ?? 'Standalone services (No reservation)';
    final labelExpensesSection = labels['expenses_section'] ?? 'Costs to reimburse (Materials and purchases)';
    final labelScheduled = labels['scheduled_label'] ?? 'Scheduled: ';
    final labelCompleted = labels['completed_label'] ?? 'Completed: ';
    final labelDate = labels['date_label'] ?? 'Date: ';
    final fallbackClientName = labels['fallback_client_name'] ?? 'client';

    // Hlavička
    bodyChildren.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$labelReportTitle$monthStr', style: titleStyle),
          pw.SizedBox(height: 4),
          pw.Text('$labelClient$clientName', style: boldStyle),
          pw.SizedBox(height: 16),
        ],
      ),
    );

    // Executive Summary – celková rekapitulace hned na začátku
    bodyChildren.add(pw.Divider(thickness: 1));
    bodyChildren.add(pw.SizedBox(height: 8));
    bodyChildren.add(pw.Text(labelSummary, style: boldStyle));
    bodyChildren.add(pw.SizedBox(height: 8));
    bodyChildren.add(
      pw.Text(
        '$labelFinalPay: ${_formatPrice(group.finalToInvoice)} $tenantCurrency',
        style: pw.TextStyle(
          font: boldStyle.font,
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
    bodyChildren.add(pw.SizedBox(height: 6));
    bodyChildren.add(pw.Text(
      '$labelTotalTurnover: ${_formatPrice(group.totalToInvoice)} $tenantCurrency',
      style: pw.TextStyle(font: textStyle.font, fontSize: 9, color: PdfColors.grey700),
    ));
    if (group.totalPaidByGuest > 0) {
      bodyChildren.add(pw.SizedBox(height: 2));
      bodyChildren.add(pw.Text(
        '$labelPaidByGuests: -${_formatPrice(group.totalPaidByGuest)} $tenantCurrency',
        style: pw.TextStyle(font: textStyle.font, fontSize: 9, color: PdfColors.grey700),
      ));
    }
    if (group.totalExpenses > 0) {
      bodyChildren.add(pw.SizedBox(height: 2));
      bodyChildren.add(pw.Text(
        '$labelExpenses: +${_formatPrice(group.totalExpenses)} $tenantCurrency',
        style: pw.TextStyle(font: textStyle.font, fontSize: 9, color: PdfColors.grey700),
      ));
    }
    bodyChildren.add(pw.SizedBox(height: 16));
    bodyChildren.add(pw.Divider(thickness: 1));
    bodyChildren.add(pw.SizedBox(height: 8));
    bodyChildren.add(pw.Text(labelServices, style: boldStyle));
    bodyChildren.add(pw.SizedBox(height: 12));

    final pdfPayerLabels = payerLabels ??
        {'owner': 'Owner – invoice', 'guest': 'Guest – cash', 'client': 'Client – invoice'};
    final pdfPayerPrefix = labels['payer'] ?? 'Payer';

    // Bloky rezervací – chronologicky podle data první služby (od nejstarší)
    final resIds = tasksWithRes.keys.toList()
      ..sort((a, b) {
        final dateA = _firstTaskDate(tasksWithRes[a]!);
        final dateB = _firstTaskDate(tasksWithRes[b]!);
        return dateA.compareTo(dateB);
      });
    final dateFormatShort = DateFormat('dd.MM.yyyy');
    for (final resId in resIds) {
      final tasks = tasksWithRes[resId]!;
      final first = tasks.first;
      final guestName = first.guestName;
      final shortId = resId.length > 8 ? resId.substring(0, 8) : resId;
      final baseTitle = guestName != null && guestName.isNotEmpty
          ? '$labelGuest$guestName'
          : '$labelReservation$shortId';
      final blockTitle = formatReservationBlockWithDates(
        baseTitle: baseTitle,
        reservationStart: first.reservationStart,
        reservationEnd: first.reservationEnd,
        formatDate: dateFormatShort.format,
      );
      bodyChildren.add(pw.Text(blockTitle, style: boldStyle));
      bodyChildren.add(pw.SizedBox(height: 6));

      for (final task in tasks) {
        bodyChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _taskToPdfWidgets(
                  task, imageCache, textStyle, pdfPayerLabels, pdfPayerPrefix,
                  labelScheduled: labelScheduled, labelCompleted: labelCompleted,
                  tenantCurrency: tenantCurrency),
            ),
          ),
        );
      }
      // Mezisoučet rezervace – obrat, uhrado hosty, k úhradě
      final resTotal = tasks.fold<double>(0, (s, t) => s + t.chargedPrice);
      final resGuestPaid = tasks
          .where((t) => t.payerType == 'guest')
          .fold<double>(0, (s, t) => s + t.chargedPrice);
      final resToPay = resTotal - resGuestPaid;
      bodyChildren.add(pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12, top: 8, bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '$labelSubtotalPerRes: ${_formatPrice(resToPay)} $tenantCurrency',
              style: pw.TextStyle(
                font: boldStyle.font,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (resGuestPaid > 0) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                '$labelTurnoverShort: ${_formatPrice(resTotal)} | $labelGuestPaidShort: -${_formatPrice(resGuestPaid)}',
                style: pw.TextStyle(font: textStyle.font, fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ],
        ),
      ));
      bodyChildren.add(pw.SizedBox(height: 12));
    }

    // Samostatné služby (mimo rezervace)
    if (tasksWithoutRes.isNotEmpty) {
      bodyChildren.add(pw.Divider(thickness: 1));
      bodyChildren.add(pw.SizedBox(height: 8));
      bodyChildren.add(pw.Text(labelStandalone, style: boldStyle));
      bodyChildren.add(pw.SizedBox(height: 6));

      for (final task in tasksWithoutRes) {
        bodyChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _taskToPdfWidgets(
                  task, imageCache, textStyle, pdfPayerLabels, pdfPayerPrefix,
                  labelScheduled: labelScheduled, labelCompleted: labelCompleted,
                  tenantCurrency: tenantCurrency),
            ),
          ),
        );
      }
      bodyChildren.add(pw.SizedBox(height: 12));
    }

    // Náklady k proplacení – detailní rozpis (datum, popis, částka, účtenka)
    if (group.expenses.isNotEmpty) {
      bodyChildren.add(pw.Divider(thickness: 1));
      bodyChildren.add(pw.SizedBox(height: 8));
      bodyChildren.add(pw.Text(labelExpensesSection, style: boldStyle));
      bodyChildren.add(pw.SizedBox(height: 6));
      for (final exp in group.expenses) {
        bodyChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _expenseToPdfWidgets(
                  exp, expenseImageCache, textStyle,
                  labelDate: labelDate, tenantCurrency: tenantCurrency),
            ),
          ),
        );
      }
      bodyChildren.add(pw.SizedBox(height: 12));
    }

    // MultiPage – automatické zalamování na další stránky, když dojde místo na A4.
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => bodyChildren,
      ),
    );

    final bytes = await doc.save();
    final safeName = _sanitizeFileName(clientName, fallback: fallbackClientName);
    final fileName = 'Report_${safeName}_${_pad(month.month)}_${month.year}.pdf';
    await downloadBytesAsFile(bytes, fileName);
  }

  static List<pw.Widget> _taskToPdfWidgets(
    BillingTaskItem task,
    Map<String, List<pw.ImageProvider>> imageCache,
    pw.TextStyle textStyle,
    Map<String, String> payerLabels,
    String payerPrefix, {
    required String labelScheduled,
    required String labelCompleted,
    required String tenantCurrency,
  }) {
    final widgets = <pw.Widget>[];
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    const emptyPlaceholder = '—';
    final scheduledStr = task.scheduledStart != null
        ? dateFormat.format(task.scheduledStart!)
        : emptyPlaceholder;
    final completedStr =
        task.completedAt != null ? dateFormat.format(task.completedAt!) : emptyPlaceholder;
    final timesLine = '$labelScheduled$scheduledStr  |  $labelCompleted$completedStr';
    final payerLabel = '$payerPrefix: ${payerLabels[task.payerType] ?? task.payerType}';
    final grayStyle = pw.TextStyle(
      font: textStyle.font,
      fontSize: 9,
      color: PdfColors.grey700,
    );
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(task.title, style: textStyle),
            pw.SizedBox(height: 2),
            pw.Text(timesLine, style: grayStyle),
            pw.Text(payerLabel, style: grayStyle),
            pw.Text('${task.chargedPrice.toStringAsFixed(2)} $tenantCurrency', style: textStyle),
          ],
        ),
      ),
    );

    final images = imageCache[task.taskId];
    if (images != null && images.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 8),
          child: pw.Wrap(
            spacing: 4,
            runSpacing: 4,
            children: images
                .map((prov) => pw.Container(
                      height: 60,
                      width: 60,
                      child: pw.Image(prov, fit: pw.BoxFit.cover),
                    ))
                .toList(),
          ),
        ),
      );
    }
    return widgets;
  }

  static List<pw.Widget> _expenseToPdfWidgets(
    BillingExpenseItem exp,
    Map<String, List<pw.ImageProvider>> imageCache,
    pw.TextStyle textStyle, {
    required String labelDate,
    required String tenantCurrency,
  }) {
    final widgets = <pw.Widget>[];
    final dateFormat = DateFormat('dd.MM.yyyy');
    final dateStr = dateFormat.format(exp.date);
    final grayStyle = pw.TextStyle(
      font: textStyle.font,
      fontSize: 9,
      color: PdfColors.grey700,
    );
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(exp.description, style: textStyle),
            pw.SizedBox(height: 2),
            pw.Text('$labelDate$dateStr', style: grayStyle),
            pw.Text('${exp.amount.toStringAsFixed(2)} $tenantCurrency', style: textStyle),
          ],
        ),
      ),
    );
    // Účtenky – zvětšené pro čitelnost majitelem jako účetní doklad.
    final images = imageCache[exp.id];
    if (images != null && images.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 8),
          child: pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: images
                .map((prov) => pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Container(
                        height: 200,
                        width: 150,
                        child: pw.Image(prov, fit: pw.BoxFit.contain),
                      ),
                    ))
                .toList(),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Vrací datum první služby v seznamu pro chronologické řazení rezervací.
  static DateTime _firstTaskDate(List<BillingTaskItem> tasks) {
    for (final t in tasks) {
      final d = t.scheduledStart ?? t.completedAt;
      if (d != null) return d;
    }
    return DateTime.utc(1970);
  }

  static String _formatPrice(double v) => v.toStringAsFixed(2);

  static String _pad(int n) => n.toString().padLeft(2, '0');

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
}
