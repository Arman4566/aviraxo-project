import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';

class QtyStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const QtyStepper({
    super.key,
    required this.value,
    this.min = 1,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDec = value > min;
    final canInc = value < max;

    Widget btn(IconData icon, bool enabled, VoidCallback onTap) {
      return InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? GPColors.tint.withOpacity(0.6) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GPColors.line),
          ),
          child: Icon(icon, size: 20),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove_rounded, canDec, () => onChanged(value - 1)),
        const SizedBox(width: 10),
        Text("$value", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(width: 10),
        btn(Icons.add_rounded, canInc, () => onChanged(value + 1)),
      ],
    );
  }
}
