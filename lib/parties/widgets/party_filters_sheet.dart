import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';

class PartyFiltersSheet extends StatelessWidget {
  const PartyFiltersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("Filters",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 12),
        _chip("Customers"),
        _chip("Suppliers"),
        _chip("With Dues"),
        _chip("GST Registered"),
        const SizedBox(height: 14),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: GPColors.primary),
          onPressed: () => Navigator.pop(context),
          child: const Text("Apply"),
        )
      ]),
    );
  }

  Widget _chip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: FilterChip(label: Text(text), selected: false, onSelected: (_) {}),
    );
  }
}
