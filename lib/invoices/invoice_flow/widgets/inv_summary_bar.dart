import 'package:flutter/material.dart';
import '../../../models/onboarding_data.dart';
import '../../../theme/gp_colors.dart';
import '../models/invoice_draft.dart';

class InvSummaryBar extends StatelessWidget {
  final OnboardingData onboarding;
  final InvoiceDraft draft;
  final VoidCallback onViewSummary;
  final VoidCallback onAddItem;
  final VoidCallback onContinue;

  const InvSummaryBar({
    super.key,
    required this.onboarding,
    required this.draft,
    required this.onViewSummary,
    required this.onAddItem,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final gst = draft.isGst(onboarding);
    final total = draft.grandTotal(gstEnabled: gst);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: GPColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GPColors.tint.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text("Grand Total", style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      Text("₹${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GPColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: onViewSummary,
                  child: const Text("View", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GPColors.primary,
                      foregroundColor: GPColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: onAddItem,
                    child: const Text("➕ Add Item", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: GPColors.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: onContinue,
                    child: const Text("Preview", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
