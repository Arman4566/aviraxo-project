import 'package:flutter/material.dart' hide Text;
import '../../../l10n/auto_translate.dart';
import '../../../l10n/gtext.dart';
import '../../../widgets/glass.dart';
import '../../../models/onboarding_data.dart';
import '../../../theme/gp_colors.dart';
import '../models/invoice_draft.dart';
import '../widgets/inv_add_item_sheet.dart';
import '../widgets/inv_item_row.dart';
import '../widgets/inv_summary_bar.dart';

class InvItemsScreen extends StatefulWidget {
  final OnboardingData onboarding;
  final InvoiceDraft draft;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const InvItemsScreen({
    super.key,
    required this.onboarding,
    required this.draft,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<InvItemsScreen> createState() => _InvItemsScreenState();
}

class _InvItemsScreenState extends State<InvItemsScreen> {
  bool get _gstEnabled => widget.draft.isGst(widget.onboarding);

  void _openAddItemSheet() async {
    final line = await showGlassSheet<InvoiceLine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InvAddItemSheet(
        onboarding: widget.onboarding,
        gstEnabled: _gstEnabled,
      ),);

    if (line != null) {
      setState(() {
        widget.draft.lines.add(line);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${line.item.name} added")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.draft.lines;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
                  const Expanded(
                    child: Text("Add Items", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  TextButton(
                    onPressed: widget.onContinue,
                    child: Text("Preview", style: TextStyle(fontWeight: FontWeight.w900, color: GPColors.primaryDeep)),
                  ),
                ],
              ),
            ),

            // Invoice header strip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GPColors.tint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: GPColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _HeaderMini(
                        label: trs("Invoice No"),
                        value: widget.draft.invoiceNo,
                        icon: Icons.confirmation_number_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeaderMini(
                        label: trs("Date"),
                        value: _formatDate(widget.draft.date),
                        icon: Icons.calendar_month_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Items list
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: lines.isEmpty
                    ? _EmptyItems(onAdd: _openAddItemSheet)
                    : ListView.separated(
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final l = lines[i];
                    return InvItemRow(
                      line: l,
                      gstEnabled: _gstEnabled,
                      onQtyChanged: (q) => setState(() => l.qty = q),
                      onRateChanged: (r) => setState(() => l.rate = r),
                      onToggleDiscountMode: () => setState(() => l.discountIsPercent = !l.discountIsPercent),
                      onDiscountChanged: (v) => setState(() => l.discountValue = v),
                      onDelete: () => setState(() => lines.removeAt(i)),
                    );
                  },
                ),
              ),
            ),

            // Sticky summary bar
            InvSummaryBar(
              onboarding: widget.onboarding,
              draft: widget.draft,
              onViewSummary: () {
                showGlassSheet(
                  context: context,
                  builder: (_) => _SummarySheet(onboarding: widget.onboarding, draft: widget.draft),);
              },
              onAddItem: _openAddItemSheet,
              onContinue: widget.onContinue,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
}

class _HeaderMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeaderMini({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: GPColors.primary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: GPColors.ink, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyItems extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyItems({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GPColors.tint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GPColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add_rounded, size: 40, color: GPColors.ink),
            const SizedBox(height: 10),
            const Text("Add items to invoice", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text("Tap below to search and add items.", style: TextStyle(color: GPColors.ink2)),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GPColors.primary,
                  foregroundColor: GPColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onAdd,
                child: const Text("➕ Add Item", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySheet extends StatelessWidget {
  final OnboardingData onboarding;
  final InvoiceDraft draft;
  const _SummarySheet({required this.onboarding, required this.draft});

  @override
  Widget build(BuildContext context) {
    final gst = draft.isGst(onboarding);
    final subtotal = draft.subtotal;
    final disc = draft.discountTotal;
    final tax = draft.taxTotal(gstEnabled: gst);
    final total = draft.grandTotal(gstEnabled: gst);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 46, height: 5, decoration: BoxDecoration(color: GPColors.line, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 14),
          const Text("Price Summary", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          _row("Subtotal", "₹ ${subtotal.toStringAsFixed(0)}"),
          _row("Discount", "- ₹ ${disc.toStringAsFixed(0)}"),
          _row(gst ? "GST (demo)" : "Tax", "₹ ${tax.toStringAsFixed(0)}"),
          const Divider(height: 24),
          _row("Grand Total", "₹ ${total.toStringAsFixed(0)}", bold: true),
          const SizedBox(height: 8),
          Text("Final totals, tax and discounts are calculated on the next step.", style: TextStyle(color: GPColors.ink2)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) {
    final st = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(a, style: st)),
          Text(b, style: st),
        ],
      ),
    );
  }
}
