import 'package:flutter/material.dart';
import '../../../theme/gp_colors.dart';
import '../models/invoice_draft.dart';

class InvItemRow extends StatelessWidget {
  final InvoiceLine line;
  final bool gstEnabled;

  final ValueChanged<int> onQtyChanged;
  final ValueChanged<double> onRateChanged;
  final VoidCallback onToggleDiscountMode;
  final ValueChanged<double> onDiscountChanged;
  final VoidCallback onDelete;

  const InvItemRow({
    super.key,
    required this.line,
    required this.gstEnabled,
    required this.onQtyChanged,
    required this.onRateChanged,
    required this.onToggleDiscountMode,
    required this.onDiscountChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lineTotal = line.lineTotal(gstEnabled: gstEnabled);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              _qtyStepper(),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onRateChanged(double.tryParse(v) ?? line.rate),
                  controller: TextEditingController(text: line.rate.toStringAsFixed(0)),
                  decoration: const InputDecoration(
                    hintText: "Rate",
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onDiscountChanged(double.tryParse(v) ?? 0),
                  controller: TextEditingController(text: line.discountValue == 0 ? "" : line.discountValue.toStringAsFixed(0)),
                  decoration: InputDecoration(
                    hintText: line.discountIsPercent ? "Discount %" : "Discount ₹",
                    prefixIcon: const Icon(Icons.discount_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GPColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onToggleDiscountMode,
                  child: Text(line.discountIsPercent ? "% → ₹" : "₹ → %", style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  gstEnabled ? "GST ${line.gstSlab}% • ${line.item.unit}" : "Non-GST • ${line.item.unit}",
                  style: const TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                "₹${lineTotal.toStringAsFixed(0)}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyStepper() {
    return Container(
      height: 48,
      width: 140,
      decoration: BoxDecoration(
        color: GPColors.tint.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GPColors.line),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onQtyChanged((line.qty - 1).clamp(1, 999)),
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Text("${line.qty}", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          IconButton(
            onPressed: () => onQtyChanged((line.qty + 1).clamp(1, 999)),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
