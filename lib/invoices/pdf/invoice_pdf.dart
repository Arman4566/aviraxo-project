import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/local_db.dart';
import '../../data/models/invoice_entity.dart';

/// Builds the invoice PDF. The look comes from Settings > Billing & Invoice:
///  - template: classic (boxed), modern (coloured header band) or compact (small and dense)
///  - what to show: item discount, notes, terms, GST breakup, HSN/SAC
/// The standard PDF font has no rupee sign, so amounts are written as "Rs".
class InvoicePdf {
  static const _indigo = PdfColor.fromInt(0xFF4F46E5);
  static const _tint = PdfColor.fromInt(0xFFEEF2FF);

  static Future<Uint8List> build({
    required InvoiceEntity inv,
    required List<InvoiceLineEntity> lines,
  }) async {
    final s = await LocalDb.I.getSettings();
    final template = s?.invoiceTemplate ?? 'classic';
    final showDiscount = (s?.showItemDiscount ?? true) && lines.any((l) => l.discountAmount > 0);
    final showNotes = s?.showNotes ?? true;
    final showTerms = s?.showTerms ?? true;
    final showBreakup = s?.showGstBreakup ?? true;
    final showHsn = s?.showHsnSac ?? true;
    final upi = (s?.upiId ?? '').trim();

    final modern = template == 'modern';
    final compact = template == 'compact';
    final base = compact ? 8.5 : 10.0;
    final pad = compact ? 3.0 : 6.0;
    final accent = modern ? _indigo : PdfColors.grey800;

    String money(double v) => "${inv.currency == "INR" ? "Rs " : ""}${v.abs().toStringAsFixed(inv.currency == "INR" ? 2 : 2)}";
    String fmtDate(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
    }

    pw.Widget cell(String t, {bool bold = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
          padding: pw.EdgeInsets.all(pad),
          child: pw.Text(t, textAlign: align, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color, fontSize: base)),
        );

    final docTitle = inv.isCancelled ? "${inv.docType} (CANCELLED)" : inv.docType;

    // ---- header ----
    final businessBlock = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          inv.businessName.isEmpty ? "Business" : inv.businessName,
          style: pw.TextStyle(fontSize: compact ? 13 : 18, fontWeight: pw.FontWeight.bold, color: modern ? PdfColors.white : PdfColors.black),
        ),
        pw.DefaultTextStyle(
          style: pw.TextStyle(fontSize: base, color: modern ? PdfColors.white : PdfColors.black),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (inv.businessAddress.isNotEmpty) pw.Text(inv.businessAddress),
            if (inv.businessPhone.isNotEmpty) pw.Text("Phone: ${inv.businessPhone}"),
            if (inv.gstin.isNotEmpty) pw.Text("GSTIN: ${inv.gstin}"),
            if (inv.state.isNotEmpty && !compact) pw.Text("State: ${inv.state}"),
          ]),
        ),
      ],
    );

    final metaBlock = pw.Column(
      crossAxisAlignment: modern ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(docTitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: modern ? 16 : base + 1, color: modern ? PdfColors.white : PdfColors.black)),
        pw.SizedBox(height: 4),
        pw.DefaultTextStyle(
          style: pw.TextStyle(fontSize: base, color: modern ? PdfColors.white : PdfColors.black),
          child: pw.Column(crossAxisAlignment: modern ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start, children: [
            pw.Text("No: ${inv.invoiceNo}"),
            pw.Text("Date: ${fmtDate(inv.dateMs)}"),
            pw.Text("Payment: ${inv.paymentMethod}"),
            if (inv.paymentMethod == "Credit" && inv.dueDateMs != null) pw.Text("Due: ${fmtDate(inv.dueDateMs!)}"),
          ]),
        ),
      ],
    );

    final header = modern
        ? pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(color: _indigo, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Expanded(child: businessBlock), metaBlock]),
          )
        : compact
            ? pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Expanded(child: businessBlock), metaBlock])
            : pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Expanded(child: businessBlock),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
                  child: metaBlock,
                ),
              ]);

    // ---- bill to ----
    final billTo = pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(compact ? 6 : 10),
      decoration: pw.BoxDecoration(
        color: modern ? _tint : null,
        border: modern ? null : pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("Bill To", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: base, color: accent)),
        pw.SizedBox(height: 3),
        pw.Text(inv.cashCustomer ? "Cash Customer" : (inv.partyName.isEmpty ? "-" : inv.partyName), style: pw.TextStyle(fontSize: base + 1, fontWeight: pw.FontWeight.bold)),
        if (inv.partyPhone.isNotEmpty) pw.Text("Phone: ${inv.partyPhone}", style: pw.TextStyle(fontSize: base)),
        if (!compact) pw.Text(inv.partyGstRegistered ? "GST Registered" : "Non-GST", style: pw.TextStyle(fontSize: base)),
      ]),
    );

    // ---- items ----
    final headers = ["Item", "Qty", "Rate", if (showDiscount) "Disc", if (inv.gstEnabled) "GST", "Total"];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(3.2),
      for (var i = 1; i < headers.length; i++) i: const pw.FlexColumnWidth(1.2),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: modern ? _indigo : PdfColors.grey200),
        children: [
          for (var i = 0; i < headers.length; i++)
            cell(headers[i], bold: true, color: modern ? PdfColors.white : PdfColors.black, align: i == 0 ? pw.TextAlign.left : pw.TextAlign.right),
        ],
      ),
      for (var i = 0; i < lines.length; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: modern && i.isOdd ? _tint : null),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(pad),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(lines[i].name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: base)),
                if (showHsn && lines[i].hsn.isNotEmpty || !compact)
                  pw.Text(
                    [if (showHsn && lines[i].hsn.isNotEmpty) "HSN: ${lines[i].hsn}", if (lines[i].unit.isNotEmpty) lines[i].unit].join(" | "),
                    style: pw.TextStyle(fontSize: base - 1.5, color: PdfColors.grey700),
                  ),
              ]),
            ),
            cell("${lines[i].qty}", align: pw.TextAlign.right),
            cell(money(lines[i].rate), align: pw.TextAlign.right),
            if (showDiscount) cell(lines[i].discountAmount > 0 ? "-${money(lines[i].discountAmount)}" : "", align: pw.TextAlign.right),
            if (inv.gstEnabled) cell("${lines[i].gstSlab}%", align: pw.TextAlign.right),
            cell(money(lines[i].lineTotal), align: pw.TextAlign.right),
          ],
        ),
    ];

    final table = pw.Table(
      border: compact
          ? const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.4), bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.6))
          : modern
              ? const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.4))
              : pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: widths,
      children: rows,
    );

    // ---- totals ----
    pw.Widget tot(String a, double v, {bool bold = false, bool negative = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(a, style: pw.TextStyle(fontSize: base, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
            pw.Text("${negative ? "-" : ""}${money(v)}", style: pw.TextStyle(fontSize: base, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ]),
        );

    final totals = pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: compact ? 200 : 240,
        padding: pw.EdgeInsets.all(compact ? 6 : 10),
        decoration: pw.BoxDecoration(
          color: modern ? _tint : null,
          border: modern ? null : pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(children: [
          tot("Subtotal", inv.subtotal),
          if (inv.discountTotal > 0) tot("Discount", inv.discountTotal, negative: true),
          if (inv.gstEnabled && showBreakup && inv.isInterstate) tot("IGST", inv.igst),
          if (inv.gstEnabled && showBreakup && !inv.isInterstate) tot("CGST", inv.cgst),
          if (inv.gstEnabled && showBreakup && !inv.isInterstate) tot("SGST", inv.sgst),
          if (inv.gstEnabled && !showBreakup) tot("GST", inv.taxTotal),
          if (!inv.gstEnabled && inv.taxTotal > 0) tot("Tax", inv.taxTotal),
          pw.Divider(color: PdfColors.grey400),
          pw.DefaultTextStyle(
            style: pw.TextStyle(color: modern ? _indigo : PdfColors.black),
            child: tot("Grand Total", inv.grandTotal, bold: true),
          ),
          if (inv.affectsBooks && !inv.isCancelled) ...[
            tot("Paid", inv.amountPaid),
            tot("Balance Due", inv.balanceDue, bold: true),
          ],
        ]),
      ),
    );

    final footer = <pw.Widget>[
      if (upi.isNotEmpty && inv.affectsBooks && !inv.isCancelled && inv.balanceDue > 0)
        pw.Padding(padding: const pw.EdgeInsets.only(top: 10), child: pw.Text("Pay by UPI: $upi", style: pw.TextStyle(fontSize: base, fontWeight: pw.FontWeight.bold, color: accent))),
      if (showNotes && inv.notes.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 8), child: pw.Text("Notes: ${inv.notes}", style: pw.TextStyle(fontSize: base))),
      if (showTerms && inv.terms.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text("Terms: ${inv.terms}", style: pw.TextStyle(fontSize: base - 1))),
      pw.SizedBox(height: 14),
      pw.Center(child: pw.Text("Thank you for your business", style: pw.TextStyle(fontSize: base - 1, color: PdfColors.grey600))),
    ];

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(compact ? 18 : 24),
        build: (_) => [
          header,
          pw.SizedBox(height: compact ? 8 : 14),
          billTo,
          pw.SizedBox(height: compact ? 8 : 14),
          table,
          pw.SizedBox(height: compact ? 8 : 12),
          totals,
          ...footer,
        ],
      ),
    );
    return doc.save();
  }
}
