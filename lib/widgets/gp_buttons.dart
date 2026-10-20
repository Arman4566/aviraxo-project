import 'package:flutter/material.dart';
import '../theme/gp_colors.dart';

class GPPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const GPPrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: GPColors.primary,
          foregroundColor: GPColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class GPSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const GPSecondaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: GPColors.ink,
          side: const BorderSide(color: GPColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
