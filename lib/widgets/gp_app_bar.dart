import 'package:flutter/material.dart';
import '../theme/gp_colors.dart';
import 'gp_progress.dart';

class GPAppBar extends StatelessWidget {
  final String stepLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const GPAppBar({
    super.key,
    required this.stepLabel,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: "Back",
          ),
          Expanded(
            child: GPProgressPill(text: stepLabel),
          ),
          TextButton(
            onPressed: onSkip,
            child: const Text(
              "Skip",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: GPColors.primaryDeep,
              ),
            ),
          )
        ],
      ),
    );
  }
}
