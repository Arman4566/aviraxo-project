import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/upi.dart';
import '../../data/local_db.dart';
import '../../data/models/invoice_entity.dart';

/// Thermal-printer receipt (58 mm or 80 mm roll). One narrow column, no tables, as long as it needs to be, so it prints
/// on the small Bluetooth/USB receipt printers used at a shop counter. Opened through the system print dialog.
class ReceiptPdf {
  static Future<Uint8List> build({
    required InvoiceEntity inv,
    required List<InvoiceLineEntity> lines,
    int widthMm = 80,
  }) async {
    final s = await LocalDb.I.getSettings();
    final upi = (s?.upiId ?? '').trim();
    final narrow = widthMm <= 58;
    final fs = narrow ? 7.5 : 9.0;
    final mm = PdfPageFormat.mm;
    final format = PdfPageFormat(widthMm * mm, double.infinity, marginAll: (narrow ? 2 : 3) * mm);

    String money(double v) => 'Rs ${v.abs().toStringAsFixed(2)}';
    final d = inv.date;
    final date = '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

    pw.TextStyle st({bool bold = false, double? size}) =>
        pw.TextStyle(fontSize: size ?? fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    pw.Widget center(String t, {bool bold = false, double? size}) =>
        pw.Center(child: pw.Text(t, textAlign: pw.TextAlign.center, style: st(bold: bold, size: size)));
    pw.Widget row(String a, String b, {bool bold = false}) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Expanded(child: pw.Text(a, style: st(bold: bold))), pw.SizedBox(width: 4), pw.Text(b, style: st(bold: bold))],
        );
    final dash = pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Divider(thickness: 0.6, height: 1));

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          center(inv.businessName.isEmpty ? 'Business' : inv.businessName, bold: true, size: fs + 3),
          if (inv.businessAddress.isNotEmpty) center(inv.businessAddress),
          if (inv.businessPhone.isNotEmpty) center('Ph: ${inv.businessPhone}'),
          if (inv.gstin.isNotEmpty) center('GSTIN: ${inv.gstin}'),
          dash,
          center(inv.isCancelled ? '${inv.docType} (CANCELLED)' : inv.docType, bold: true),
          row('No: ${inv.invoiceNo}', date),
          if (!inv.cashCustomer && inv.partyName.isNotEmpty) pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('To: ${inv.partyName}', style: st())),
          dash,
          for (final l in lines) ...[
            pw.Text(l.name, style: st(bold: true)),
            row('${l.qty} ${l.unit} x ${l.rate.toStringAsFixed(2)}', money(l.lineTotal)),
          ],
          dash,
          if (inv.discountTotal > 0) row('Discount', '-${money(inv.discountTotal)}'),
          if (inv.gstEnabled && inv.taxTotal > 0) row('GST', money(inv.taxTotal)),
          row('TOTAL', money(inv.grandTotal), bold: true),
          if (inv.affectsBooks && !inv.isCancelled) ...[
            row('Paid', money(inv.amountPaid)),
            if (inv.balanceDue > 0) row('Balance due', money(inv.balanceDue), bold: true),
          ],
          dash,
          if (upi.isNotEmpty && inv.affectsBooks && !inv.isCancelled && inv.balanceDue > 0) ...[
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: upiPayUrl(upiId: upi, payeeName: inv.businessName, amount: inv.balanceDue, note: inv.invoiceNo),
                width: (widthMm - 14) * mm,
                height: (widthMm - 14) * mm,
              ),
            ),
            center('Scan to pay by UPI'),
            pw.SizedBox(height: 4),
          ],
          center('Thank you! Visit again', bold: true),
        ]),
      ),
    );
    return doc.save();
  }
}
