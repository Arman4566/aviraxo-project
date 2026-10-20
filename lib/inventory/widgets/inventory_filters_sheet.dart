import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';
import '../models/inventory_item.dart';

class InventoryFiltersSheet extends StatefulWidget {
  final bool stockEnabled;
  final bool gstEnabled;
  final List<InventoryItem> items;
  final InventoryFilters initial;

  const InventoryFiltersSheet({
    super.key,
    required this.stockEnabled,
    required this.gstEnabled,
    required this.items,
    required this.initial,
  });

  @override
  State<InventoryFiltersSheet> createState() => _InventoryFiltersSheetState();
}

class _InventoryFiltersSheetState extends State<InventoryFiltersSheet> {
  late InventoryFilters f;

  @override
  void initState() {
    super.initState();
    f = widget.initial.copy();
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{"All", ...widget.items.map((e) => e.category)}.toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 46, height: 5, decoration: BoxDecoration(color: GPColors.line, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 12),
          const Text("Filters", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 14),

          if (widget.stockEnabled) ...[
            _seg("Stock Status", ["All", "In", "Low", "Out"], f.status, (v) => setState(() => f.status = v)),
            const SizedBox(height: 12),
          ],

          _dropdown("Category", categories, f.category, (v) => setState(() => f.category = v)),
          const SizedBox(height: 12),

          if (widget.gstEnabled) ...[
            _seg("GST", ["All", "GST", "Non-GST"], f.gst, (v) => setState(() => f.gst = v)),
            const SizedBox(height: 12),
          ],

          Align(
            alignment: Alignment.centerLeft,
            child: Text("Price range (selling)", style: TextStyle(fontWeight: FontWeight.w900, color: GPColors.ink.withOpacity(0.9))),
          ),
          RangeSlider(
            values: f.priceRange,
            min: 0,
            max: 5000,
            divisions: 50,
            labels: RangeLabels("₹${f.priceRange.start.toStringAsFixed(0)}", "₹${f.priceRange.end.toStringAsFixed(0)}"),
            onChanged: (v) => setState(() => f.priceRange = v),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GPColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: () {
                    final reset = InventoryFilters();
                    Navigator.pop(context, reset);
                  },
                  child: const Text("Reset", style: TextStyle(fontWeight: FontWeight.w900)),
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
                  onPressed: () => Navigator.pop(context, f),
                  child: const Text("Apply", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _seg(String label, List<String> values, String selected, ValueChanged<String> onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: values.map((v) {
            final on = v == selected;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onTap(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? GPColors.tint.withOpacity(0.75) : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: on ? GPColors.primary : GPColors.line),
                ),
                child: Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _dropdown(String label, List<String> values, String selected, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: values.contains(selected) ? selected : values.first,
          items: values.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => onChanged(v ?? "All"),
        ),
      ],
    );
  }
}
