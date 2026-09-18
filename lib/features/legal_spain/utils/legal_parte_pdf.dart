import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF „parte de viajeros“ / kniha návštěv – 3roční retence je v DB, PDF je pro inspekci.
///
/// PROČ: RD 933/2021 vyžaduje knihu; PDF z aplikace nahradí ruční tisk z Chekinu.
class LegalPartePdf {
  LegalPartePdf._();

  static Future<void> printVisitorBook({
    required String title,
    required List<List<String>> rows,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: rows.isEmpty ? <String>[] : rows.first,
            data: rows.length <= 1 ? <List<String>>[] : rows.sublist(1),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }
}
