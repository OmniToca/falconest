import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:falconest/features/admin/providers/finance_billing_provider.dart';

/// Služba pro generování PDF vyúčtování z fakturačních podkladů.
///
/// Vstup: seznam BillingApartmentGroup, název tenanta, formátování cen.
/// Výstup: PDF dokument připravený pro Printing.layoutPdf nebo sharePdf.
class PdfBillingService {
  PdfBillingService._();

  /// Vygeneruje PDF dokument z fakturačních dat.
  ///
  /// [groups] – data z billingReportProvider (zgrupované úkoly podle apartmánů).
  /// [tenantName] – název agentury pro hlavičku.
  /// [formatPrice] – funkce pro formátování částky dle měny tenanta (např. "250 Kč", "€ 10.00").
  /// [monthYearLabel] – popis období (např. "Leden 2025") pro podtitul.
  static Future<pw.Document> generateDocument({
    required List<BillingApartmentGroup> groups,
    required String tenantName,
    required String Function(double) formatPrice,
    String? monthYearLabel,
  }) async {
    final doc = pw.Document();

    final totalToInvoice =
        groups.fold<double>(0, (s, g) => s + g.totalToInvoice);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Vyúčtování služeb',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Strana ${context.pageNumber} z ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Vyúčtování služeb',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  tenantName,
                  style: const pw.TextStyle(fontSize: 14),
                ),
                if (monthYearLabel != null && monthYearLabel.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    monthYearLabel,
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
                pw.SizedBox(height: 24),
              ],
            ),
          ),
          ...groups.map((group) => _buildApartmentSection(group, formatPrice)),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Celková suma k fakturaci:',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  formatPrice(totalToInvoice),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc;
  }

  /// Vytvoří sekci pro jeden apartmán: nadpis, tabulka úkolů, mezisoučet.
  static pw.Widget _buildApartmentSection(
    BillingApartmentGroup group,
    String Function(double) formatPrice,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          group.apartmentName,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.8),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Datum', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Název úkolu', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Cena', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...group.tasks.map((t) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        t.completedAt != null
                            ? '${t.completedAt!.day}.${t.completedAt!.month}.${t.completedAt!.year}'
                            : '—',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        t.title,
                        style: const pw.TextStyle(fontSize: 10),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        formatPrice(t.chargedPrice),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                )),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Mezisoučet: ${formatPrice(group.totalToInvoice)}',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }
}
