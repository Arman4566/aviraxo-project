import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';
import '../theme/gp_colors.dart';

class GPPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  /// true for the single terminal action of a flow (Save, Finish, Collect): shown in green.
  /// false (default) for ordinary steps such as Next: shown in the brand blue.
  final bool commit;

  const GPPrimaryButton({super.key, required this.text, required this.onPressed, this.commit = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: commit ? GPColors.commit : GPColors.primary,
          foregroundColor: GPColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
          side: BorderSide(color: GPColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
