import 'package:flutter/material.dart' hide Text;
import '../../../l10n/gtext.dart';
import '../../../core/outbox.dart';
import '../../../l10n/strings.dart';
import '../../../models/onboarding_data.dart';
import '../../../theme/gp_colors.dart';
import '../../../data/repositories/invoice_repo.dart';
import '../models/invoice_draft.dart';

class InvPreviewScreen extends StatefulWidget {
  final OnboardingData onboarding;
  final InvoiceDraft draft;
  final VoidCallback onEdit;

  /// ✅ Now returns invoiceId to InvoiceFlow
  final ValueChanged<int> onSave;

  final VoidCallback onBack;

  const InvPreviewScreen({
    super.key,
    required this.onboarding,
    required this.draft,
    required this.onEdit,
    required this.onSave,
    required this.onBack,
  });

  @override
  State<InvPreviewScreen> createState() => _InvPreviewScreenState();
}

class _InvPreviewScreenState extends State<InvPreviewScreen> {
  bool _saving = false;
  final String _clientRef = Outbox.newRef(); // same for every tap of Save on this screen, so a double tap cannot bill twice

  Future<void> _handleSave() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final repo = InvoiceRepo();

      // ✅ Send to the server (it numbers the invoice, does the GST maths, updates stock and balance)
      final invoiceId = await repo.saveDraft(
        onboarding: widget.onboarding,
        draft: widget.draft,
        clientRef: _clientRef,
      );

      if (!mounted) return;

      if (invoiceId < 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('offline_saved'))));
        Navigator.of(context).maybePop();
        return;
      }
      widget.onSave(invoiceId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not save invoice: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gst = widget.draft.isGst(widget.onboarding);
    final party = widget.draft.party;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
              const Expanded(
                child: Text(
                  "Preview Invoice",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: GPColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_docLabel(widget.draft.type),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text("Invoice No: ${widget.draft.invoiceNo}",
                          style: TextStyle(color: GPColors.ink2)),
                      const SizedBox(height: 6),
                      Text("Date: ${_fmt(widget.draft.date)}",
                          style: TextStyle(color: GPColors.ink2)),
                      const Divider(height: 24),

                      const Text("Seller", style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),

                      // ✅ Now show actual business name from onboarding if exists
                      Text(
                        (widget.onboarding.businessName ?? "Your Business").trim(),
                        style: TextStyle(color: GPColors.ink2),
                      ),

                      const SizedBox(height: 12),
                      const Text("Buyer", style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        party?.name ?? "Not selected",
                        style: TextStyle(color: GPColors.ink2),
                      ),
                      if (gst) ...[
                        const SizedBox(height: 4),
                        Text(
                          "GST: ${(party?.gstRegistered ?? false) ? "Registered" : "Not Registered"}",
                          style: TextStyle(color: GPColors.ink2),
                        ),
                      ],

                      const Divider(height: 24),

                      const Text("Items", style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),

                      if (widget.draft.lines.isEmpty)
                        Text("No items added.", style: TextStyle(color: GPColors.ink2))
                      else
                        ...widget.draft.lines.map((l) {
                          final total = l.lineTotal(gstEnabled: gst);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${l.item.name}  •  ${l.qty} × ₹${l.rate.toStringAsFixed(0)}",
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  "₹${total.toStringAsFixed(0)}",
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          );
                        }),

                      const Divider(height: 24),

                      _totRow("Subtotal", widget.draft.subtotal),
                      _totRow("Discount", -widget.draft.discountTotal),
                      _totRow(gst ? "GST" : "Tax", widget.draft.taxTotal(gstEnabled: gst)),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: GPColors.tint.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GPColors.line),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "Grand Total",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            Text(
                              "₹${widget.draft.grandTotal(gstEnabled: gst).toStringAsFixed(0)}",
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      const Text("Additional Details", style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text("Payment: ${widget.draft.paymentMethod}",
                          style: TextStyle(color: GPColors.ink2)),
                      if (widget.draft.paymentMethod == "Credit")
                        Text(
                          "Due: ${widget.draft.dueDate == null ? "Not set" : _fmt(widget.draft.dueDate!)}",
                          style: TextStyle(color: GPColors.ink2),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: GPColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: _saving ? null : widget.onEdit,
                  child: const Text("Edit", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GPColors.primary,
                    foregroundColor: GPColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: _saving ? null : _handleSave,
                  child: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Save Invoice", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _totRow(String label, double value) {
    final isNeg = value < 0;
    final abs = value.abs();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            "${isNeg ? "-" : ""}₹${abs.toStringAsFixed(0)}",
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  String _docLabel(InvoiceDocType t) {
    switch (t) {
      case InvoiceDocType.gstInvoice:
        return "GST Invoice";
      case InvoiceDocType.retailInvoice:
        return "Retail Invoice";
      case InvoiceDocType.estimate:
        return "Estimate / Quotation";
      case InvoiceDocType.proforma:
        return "Proforma Invoice";
      case InvoiceDocType.deliveryChallan:
        return "Delivery Challan";
    }
  }

  String _fmt(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
}
