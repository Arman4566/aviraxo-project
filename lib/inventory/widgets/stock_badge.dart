import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';

/// Stock chip: green tick = fine, amber triangle = reorder soon, red stop = none left.
/// Each state has its own icon and words, so it still reads for colour-blind users.
class StockBadge extends StatelessWidget {
  final String status; // In, Low, Out, N/A
  const StockBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    String text;
    IconData icon;

    switch (status) {
      case "In":
        c = GPColors.success;
        text = "In Stock";
        icon = Icons.check_circle_rounded;
        break;
      case "Low":
        c = GPColors.warning;
        text = "Low Stock";
        icon = Icons.warning_amber_rounded;
        break;
      case "Out":
        c = GPColors.danger;
        text = "Out of Stock";
        icon = Icons.dangerous_rounded;
        break;
      default:
        c = GPColors.ink2;
        text = "N/A";
        icon = Icons.remove_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: c)),
        ],
      ),
    );
  }
}
