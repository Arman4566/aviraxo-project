import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';
import '../../widgets/gp_buttons.dart';

class OBCompleteScreen extends StatelessWidget {
  final VoidCallback onGoDashboard;
  final VoidCallback onAddFirstItem;
  final VoidCallback onCreateFirstInvoice;

  const OBCompleteScreen({
    super.key,
    required this.onGoDashboard,
    required this.onAddFirstItem,
    required this.onCreateFirstInvoice,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: GPColors.tint.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: GPColors.line),
            ),
            child: const Icon(Icons.check_circle_rounded, size: 52, color: GPColors.success),
          ),
          const SizedBox(height: 18),
          Text("Your Galla Pro workspace is ready",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          const Text(
            "Your business is set up.\nLet's head to your dashboard.",
            textAlign: TextAlign.center,
            style: TextStyle(color: GPColors.ink2, height: 1.35),
          ),
          const Spacer(),
          GPPrimaryButton(text: "Go to Dashboard", onPressed: onGoDashboard),
          const SizedBox(height: 12),
          GPSecondaryButton(text: "Add First Item", onPressed: onAddFirstItem),
          const SizedBox(height: 12),
          GPSecondaryButton(text: "Create First Invoice", onPressed: onCreateFirstInvoice),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
