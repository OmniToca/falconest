import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/utils/download_helper/download_helper.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';

/// Služba pro generování PDF reportů s fotodokumentací – nezpochybnitelné podklady k fakturaci.
///
/// Používá balíčky [pdf] a [printing]. Obrázky z [BillingTaskItem.mediaUrls] se stahují
/// přes [networkImage] a vykreslují jako miniatury. Selhání jedné fotky neshodí celé PDF.
///
/// **PROČ nepoužíváme EasyLocalization `.tr()`:** překlady pro PDF předává UI/service helpery jako hotové řetězce
/// v konkrétním jazyce exportu; třída zůstává čistě „PDF builder“ bez závislosti na aktuálním locale aplikace.
class BillingPdfService {
  BillingPdfService._();

  /// Vygeneruje PDF report pro jednoho klienta a spustí stahování souboru.
  ///
  /// [exportLocale] řídí formátování datumů ([DateFormat] s jazykovým kódem).
  /// [payerLabels] a [footerLabels] musí být kompletní — žádné fallbacky v angličtině uvnitř této služby.
  static Future<void> generateAndDownloadPdf(
    BillingGroup group,
    DateTime month,
    String tenantCurrency, {
    required Locale exportLocale,
    required String externalDisplayName,
    required Map<String, String> payerLabels,
    required Map<String, String> footerLabels,
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
        } catch (e, st) {
          AppLogger.error('BillingPdfService: stažení obrázku výdaje do PDF selhalo', e, st);
        }
      }
      if (list.isNotEmpty) expenseImageCache[exp.id] = list;
    }

    final doc = pw.Document();
    final lang = exportLocale.languageCode;
    final monthPeriod = DateTime(month.year, month.month, 1);
    final monthStr = DateFormat.yMMMM(lang).format(monthPeriod);

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

    final labelReportTitle = _req(footerLabels, 'report_title');
    final labelClient = _req(footerLabels, 'client_label');
    final labelSummary = _req(footerLabels, 'summary_section');
    final labelServices = _req(footerLabels, 'services_breakdown');
    final labelTotalTurnover = _req(footerLabels, 'total_turnover');
    final labelPaidByGuests = _req(footerLabels, 'paid_by_guests');
    final labelExpenses = _req(footerLabels, 'expenses_to_reimburse');
    final labelFinalPay = _req(footerLabels, 'final_pay');
    final labelSubtotalPerRes = _req(footerLabels, 'subtotal_per_reservation');
    final labelTurnoverShort = _req(footerLabels, 'turnover_short');
    final labelGuestPaidShort = _req(footerLabels, 'guest_paid_short');
    final labelGuest = _req(footerLabels, 'guest_label');
    final labelReservation = _req(footerLabels, 'reservation_prefix');
    final labelApartmentBoundServices =
        _req(footerLabels, 'apartment_bound_services');
    final labelExternalServices = _req(footerLabels, 'external_services');
    final labelExpensesSection = _req(footerLabels, 'expenses_section');
    final labelScheduled = _req(footerLabels, 'scheduled_label');
    final labelCompleted = _req(footerLabels, 'completed_label');
    final labelDate = _req(footerLabels, 'date_label');
    final fallbackClientName = _req(footerLabels, 'fallback_client_name');
    final labelMonthlyManagementFee = _req(footerLabels, 'monthly_management_fee');
    final labelTaskPrice = _req(footerLabels, 'task_price_label');
    final labelGuestPaid = _req(footerLabels, 'task_guest_paid_label');
    final labelShortfallDue = _req(footerLabels, 'task_shortfall_due_label');
    final placeholderDash = _req(footerLabels, 'placeholder_dash');
    final fileNamePrefix = _req(footerLabels, 'file_name_prefix');

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
    if (group.monthlyManagementFee > 0) {
      bodyChildren.add(pw.SizedBox(height: 2));
      bodyChildren.add(pw.Text(
        '$labelMonthlyManagementFee: +${_formatPrice(group.monthlyManagementFee)} $tenantCurrency',
        style: pw.TextStyle(font: textStyle.font, fontSize: 9, color: PdfColors.grey700),
      ));
    }
    bodyChildren.add(pw.SizedBox(height: 16));
    bodyChildren.add(pw.Divider(thickness: 1));
    bodyChildren.add(pw.SizedBox(height: 8));
    bodyChildren.add(pw.Text(labelServices, style: boldStyle));
    bodyChildren.add(pw.SizedBox(height: 12));

    // Řádek položky: Měsíční paušál za správu (pokud > 0)
    if (group.monthlyManagementFee > 0) {
      bodyChildren.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(labelMonthlyManagementFee, style: textStyle),
            pw.Text('${_formatPrice(group.monthlyManagementFee)} $tenantCurrency', style: boldStyle),
          ],
        ),
      ));
      bodyChildren.add(pw.SizedBox(height: 8));
    }

    final pdfPayerPrefix = _req(footerLabels, 'payer');
    final pdfPayerLabels = {
      'owner': _req(payerLabels, 'owner'),
      'guest': _req(payerLabels, 'guest'),
      'client': _req(payerLabels, 'client'),
    };

    // Bloky rezervací – chronologicky podle data první služby (od nejstarší)
    final resIds = tasksWithRes.keys.toList()
      ..sort((a, b) {
        final dateA = _firstTaskDate(tasksWithRes[a]!);
        final dateB = _firstTaskDate(tasksWithRes[b]!);
        return dateA.compareTo(dateB);
      });
    final dateFormatShort = DateFormat.yMd(lang);
    final taskDateTimeFormat = DateFormat.yMd(lang).add_Hm();
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
                task,
                imageCache,
                textStyle,
                pdfPayerLabels,
                pdfPayerPrefix,
                exportLocale: exportLocale,
                labelScheduled: labelScheduled,
                labelCompleted: labelCompleted,
                tenantCurrency: tenantCurrency,
                labelTaskPrice: labelTaskPrice,
                labelGuestPaid: labelGuestPaid,
                labelShortfallDue: labelShortfallDue,
                emptyPlaceholder: placeholderDash,
                taskDateTimeFormat: taskDateTimeFormat,
              ),
            ),
          ),
        );
      }
      // Mezisoučet rezervace – obrat, skutečně uhrazeno hosty, k úhradě (stejná logika jako BillingGroup.totalPaidByGuest)
      final resTotal = tasks.fold<double>(0, (s, t) => s + t.chargedPrice);
      final resGuestPaid = tasks.where((t) => t.payerType == 'guest').fold<double>(0, (s, t) {
        final price = t.chargedPrice;
        if (t.isShortfallResolved &&
            t.cashShortfallMissingAmount != null &&
            t.cashShortfallMissingAmount! > 0) {
          return s + (price - t.cashShortfallMissingAmount!);
        }
        return s + price;
      });
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

    // Úkoly mimo rezervaci – vázané na apartmán vs. externí služba (podle tasks.apartment_id).
    final standaloneSplit = splitBillingTasksWithoutReservation(tasksWithoutRes);
    _appendPdfTaskSection(
      bodyChildren,
      sectionTitle: labelApartmentBoundServices,
      tasks: standaloneSplit.apartmentBoundServices,
      imageCache: imageCache,
      textStyle: textStyle,
      boldStyle: boldStyle,
      pdfPayerLabels: pdfPayerLabels,
      pdfPayerPrefix: pdfPayerPrefix,
      exportLocale: exportLocale,
      labelScheduled: labelScheduled,
      labelCompleted: labelCompleted,
      tenantCurrency: tenantCurrency,
      labelTaskPrice: labelTaskPrice,
      labelGuestPaid: labelGuestPaid,
      labelShortfallDue: labelShortfallDue,
      placeholderDash: placeholderDash,
      taskDateTimeFormat: taskDateTimeFormat,
    );
    _appendPdfTaskSection(
      bodyChildren,
      sectionTitle: labelExternalServices,
      tasks: standaloneSplit.externalServices,
      imageCache: imageCache,
      textStyle: textStyle,
      boldStyle: boldStyle,
      pdfPayerLabels: pdfPayerLabels,
      pdfPayerPrefix: pdfPayerPrefix,
      exportLocale: exportLocale,
      labelScheduled: labelScheduled,
      labelCompleted: labelCompleted,
      tenantCurrency: tenantCurrency,
      labelTaskPrice: labelTaskPrice,
      labelGuestPaid: labelGuestPaid,
      labelShortfallDue: labelShortfallDue,
      placeholderDash: placeholderDash,
      taskDateTimeFormat: taskDateTimeFormat,
    );

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
                exp,
                expenseImageCache,
                textStyle,
                labelDate: labelDate,
                tenantCurrency: tenantCurrency,
                exportLanguageCode: lang,
              ),
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
    final fileName = '${fileNamePrefix}_${safeName}_${_pad(month.month)}_${month.year}.pdf';
    await downloadBytesAsFile(bytes, fileName);
  }

  static String _req(Map<String, String> map, String key) {
    final v = map[key];
    if (v == null || v.trim().isEmpty) {
      throw ArgumentError('Chybí povinný řetězec pro PDF: $key');
    }
    return v;
  }

  /// Vykreslí jednu sekci úkolů mimo rezervaci (vázané na apartmán / externí služba).
  ///
  /// PROČ: Stejné rozdělení jako v admin UI – odpovídá typům úkolů v aplikaci (TaskFormMode).
  static void _appendPdfTaskSection(
    List<pw.Widget> bodyChildren, {
    required String sectionTitle,
    required List<BillingTaskItem> tasks,
    required Map<String, List<pw.ImageProvider>> imageCache,
    required pw.TextStyle textStyle,
    required pw.TextStyle boldStyle,
    required Map<String, String> pdfPayerLabels,
    required String pdfPayerPrefix,
    required Locale exportLocale,
    required String labelScheduled,
    required String labelCompleted,
    required String tenantCurrency,
    required String labelTaskPrice,
    required String labelGuestPaid,
    required String labelShortfallDue,
    required String placeholderDash,
    required DateFormat taskDateTimeFormat,
  }) {
    if (tasks.isEmpty) return;
    bodyChildren.add(pw.Divider(thickness: 1));
    bodyChildren.add(pw.SizedBox(height: 8));
    bodyChildren.add(pw.Text(sectionTitle, style: boldStyle));
    bodyChildren.add(pw.SizedBox(height: 6));
    for (final task in tasks) {
      bodyChildren.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: _taskToPdfWidgets(
              task,
              imageCache,
              textStyle,
              pdfPayerLabels,
              pdfPayerPrefix,
              exportLocale: exportLocale,
              labelScheduled: labelScheduled,
              labelCompleted: labelCompleted,
              tenantCurrency: tenantCurrency,
              labelTaskPrice: labelTaskPrice,
              labelGuestPaid: labelGuestPaid,
              labelShortfallDue: labelShortfallDue,
              emptyPlaceholder: placeholderDash,
              taskDateTimeFormat: taskDateTimeFormat,
            ),
          ),
        ),
      );
    }
    bodyChildren.add(pw.SizedBox(height: 12));
  }

  static List<pw.Widget> _taskToPdfWidgets(
    BillingTaskItem task,
    Map<String, List<pw.ImageProvider>> imageCache,
    pw.TextStyle textStyle,
    Map<String, String> payerLabels,
    String payerPrefix, {
    required Locale exportLocale,
    required String labelScheduled,
    required String labelCompleted,
    required String tenantCurrency,
    required String labelTaskPrice,
    required String labelGuestPaid,
    required String labelShortfallDue,
    required String emptyPlaceholder,
    required DateFormat taskDateTimeFormat,
  }) {
    final widgets = <pw.Widget>[];
    final scheduledStr = task.scheduledStart != null
        ? taskDateTimeFormat.format(task.scheduledStart!)
        : emptyPlaceholder;
    final completedStr =
        task.completedAt != null ? taskDateTimeFormat.format(task.completedAt!) : emptyPlaceholder;
    final timesLine = '$labelScheduled$scheduledStr  |  $labelCompleted$completedStr';
    final payerType = task.payerType;
    final payerResolved = payerLabels[payerType];
    if (payerResolved == null || payerResolved.trim().isEmpty) {
      throw ArgumentError('Neznámý nebo ne přeložený payerType: $payerType');
    }
    final payerLabel = '$payerPrefix: $payerResolved';
    final grayStyle = pw.TextStyle(
      font: textStyle.font,
      fontSize: 9,
      color: PdfColors.grey700,
    );
    final isGuestWithResolvedShortfall = task.payerType == 'guest' &&
        task.isShortfallResolved &&
        task.cashShortfallMissingAmount != null &&
        task.cashShortfallMissingAmount! > 0;
    // PROČ: Stejná logika jako v [billingTaskTitleForPdfExport] – PDF musí respektovat jazyk z dialogu exportu.
    final taskTitleForPdf = billingTaskTitleForPdfExport(task, exportLocale);
    final priceChildren = <pw.Widget>[
      pw.Text(taskTitleForPdf, style: textStyle),
      pw.SizedBox(height: 2),
      pw.Text(timesLine, style: grayStyle),
      pw.Text(payerLabel, style: grayStyle),
    ];
    if (isGuestWithResolvedShortfall) {
      final paid = task.chargedPrice - task.cashShortfallMissingAmount!;
      final due = task.cashShortfallMissingAmount!;
      priceChildren.add(pw.Text(
        '$labelTaskPrice: ${_formatPrice(task.chargedPrice)} $tenantCurrency',
        style: textStyle,
      ));
      priceChildren.add(pw.SizedBox(height: 2));
      priceChildren.add(pw.Text(
        '$labelGuestPaid: ${_formatPrice(paid)} $tenantCurrency → $labelShortfallDue: ${_formatPrice(due)} $tenantCurrency',
        style: grayStyle,
      ));
    } else {
      priceChildren.add(pw.Text(
        '${_formatPrice(task.chargedPrice)} $tenantCurrency',
        style: textStyle,
      ));
    }
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: priceChildren,
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
    required String exportLanguageCode,
  }) {
    final widgets = <pw.Widget>[];
    final dateFormat = DateFormat.yMd(exportLanguageCode);
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

  static String _sanitizeFileName(String name, {required String fallback}) {
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
