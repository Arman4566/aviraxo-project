import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/party_entity.dart';

/// Party statement (account ledger): opening balance, every invoice and payment with a running balance, closing balance.
/// Sent to a customer or supplier when they ask "how much do I owe / what have I paid". Amounts are written as "Rs".
class StatementPdf {
  static Future<Uint8List> build({
    required String businessName,
    required PartyEntity party,
    required PartyLedger ledger,
  }) async {
    String money(double v) => 'Rs ${v.toStringAsFixed(2)}';
    String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    final today = DateTime.now();
    final closing = ledger.closingBalance;
    final closingText = closing > 0
        ? '${money(closing)} to receive from ${party.name}'
        : closing < 0
            ? '${money(-closing)} payable to ${party.name}'
            : 'Settled (nothing due)';

    pw.Widget cell(String t, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(t, textAlign: align, style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          cell('Date', bold: true),
          cell('Details', bold: true),
          cell('Debit', bold: true, align: pw.TextAlign.right),
          cell('Credit', bold: true, align: pw.TextAlign.right),
          cell('Balance', bold: true, align: pw.TextAlign.right),
        ],
      ),
      if (ledger.openingBalance != 0)
        pw.TableRow(children: [
          cell(''),
          cell('Opening balance'),
          cell(''),
          cell(''),
          cell(money(ledger.openingBalance), align: pw.TextAlign.right),
        ]),
      for (final e in ledger.entries)
        pw.TableRow(children: [
          cell(date(e.date)),
          cell('${e.isInvoice ? 'Invoice' : 'Payment'} ${e.ref}'.trim()),
          cell(e.debit > 0 ? money(e.debit) : '', align: pw.TextAlign.right),
          cell(e.credit > 0 ? money(e.credit) : '', align: pw.TextAlign.right),
          cell(money(e.balance), align: pw.TextAlign.right),
        ]),
    ];

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Text(businessName.isEmpty ? 'Business' : businessName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Account statement', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.Divider(),
          pw.Text(party.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          if (party.phone.isNotEmpty) pw.Text('Phone: ${party.phone}', style: const pw.TextStyle(fontSize: 10)),
          if (party.gstin.isNotEmpty) pw.Text('GSTIN: ${party.gstin}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('As on ${date(today)}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(62),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(1.5),
            },
            children: rows,
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text('Closing balance: $closingText', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
