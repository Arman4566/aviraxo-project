import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';

class StockBadge extends StatelessWidget {
  final String status; // In, Low, Out, N/A
  const StockBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String text;

    switch (status) {
      case "In":
        bg = GPColors.success.withOpacity(0.12);
        text = "In Stock";
        break;
      case "Low":
        bg = Colors.orange.withOpacity(0.14);
        text = "Low Stock";
        break;
      case "Out":
        bg = Colors.red.withOpacity(0.12);
        text = "Out of Stock";
        break;
      default:
        bg = GPColors.tint;
        text = "N/A";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GPColors.line),
      ),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}
