import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';
import '../theme/gp_colors.dart';

class GPMultiChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const GPMultiChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? GPColors.primary.withValues(alpha: 0.25) : GPColors.tint.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? GPColors.primary : GPColors.line),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
