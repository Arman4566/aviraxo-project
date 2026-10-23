import 'dart:typed_data';
import 'package:flutter/material.dart' hide Text;
import '../../../l10n/gtext.dart';
import 'package:printing/printing.dart';

import '../../../theme/gp_colors.dart';
import '../../../data/repositories/invoice_repo.dart';
import '../../pdf/invoice_pdf.dart';

class InvSuccessScreen extends StatefulWidget {
  final int invoiceId;
  final VoidCallback onCreateNew;
  final VoidCallback onGoDashboard;

  const InvSuccessScreen({
    super.key,
    required this.invoiceId,
    required this.onCreateNew,
    required this.onGoDashboard,
  });

  @override
  State<InvSuccessScreen> createState() => _InvSuccessScreenState();
}

class _InvSuccessScreenState extends State<InvSuccessScreen> {
  final _repo = InvoiceRepo();

  Future<Uint8List> _pdfBytes() async {
    final inv = await _repo.getById(widget.invoiceId);
    if (inv == null) throw Exception("Invoice not found");
    final lines = await _repo.getLinesFor(inv);
    return InvoicePdf.build(inv: inv, lines: lines); // ✅ Uint8List now
  }

  Future<void> _print() async {
    final bytes = await _pdfBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _share() async {
    final bytes = await _pdfBytes();
    await Printing.sharePdf(bytes: bytes, filename: "invoice_${widget.invoiceId}.pdf");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          children: [
            const SizedBox(height: 34),
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: GPColors.tint.withOpacity(0.6),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: GPColors.line),
              ),
              child: const Icon(Icons.check_circle_rounded, size: 52, color: GPColors.success),
            ),
            const SizedBox(height: 16),
            const Text("Invoice created successfully",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 8),
            FutureBuilder(
              future: _repo.getById(widget.invoiceId),
              builder: (context, snap) {
                final inv = snap.data;
                return Text(
                  inv == null
                      ? "Invoice saved"
                      : "${inv.invoiceNo} • ₹${inv.grandTotal.toStringAsFixed(2)}"
                          "${inv.balanceDue > 0.005 ? " • Due ₹${inv.balanceDue.toStringAsFixed(2)}" : ""}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GPColors.ink2),
                );
              },
            ),
            const Spacer(),

            _actionButton("Print", Icons.print_rounded, _print),
            const SizedBox(height: 10),
            _actionButton("Share PDF", Icons.ios_share_rounded, _share),
            const SizedBox(height: 10),
            _actionButton("WhatsApp", Icons.chat_rounded, _share), // WhatsApp share via share sheet
            const SizedBox(height: 14),

            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GPColors.primary,
                  foregroundColor: GPColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: widget.onCreateNew,
                child: const Text("➕ Create New Invoice", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: GPColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: widget.onGoDashboard,
                child: const Text("Go to Dashboard", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Future<void> Function() onTap) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: GPColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () async {
          try {
            await onTap();
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed: $label")),
            );
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
