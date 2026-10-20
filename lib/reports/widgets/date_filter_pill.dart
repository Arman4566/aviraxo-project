import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';

class DateFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DateFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? GPColors.tint.withOpacity(0.75) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? GPColors.primary : GPColors.line),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
