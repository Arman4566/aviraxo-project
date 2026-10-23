import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../../widgets/gp_buttons.dart';

class OBWelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSkip;

  const OBWelcomeScreen({
    super.key,
    required this.onStart,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // ✅ BIGGER, CLEAN LOGO
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.transparent, // ❌ removed yellowish area
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: GPColors.line.withOpacity(0.6),
              ),
            ),
            child: Image.asset(
              'assets/images/galla_pro.png',
              height: 110, // ✅ bigger logo
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 28),

          // ✅ CENTERED HEADLINE (better onboarding UX)
          Text(
            "Set up your business in 2 minutes",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              "Galla Pro configures billing & inventory based on your business.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GPColors.ink2,
                height: 1.4,
                fontSize: 15,
              ),
            ),
          ),

          const Spacer(),

          GPPrimaryButton(
            text: "Start Setup",
            onPressed: onStart,
          ),

          const SizedBox(height: 14),

          GPSecondaryButton(
            text: "Skip (use defaults)",
            onPressed: onSkip,
          ),

          const SizedBox(height: 12),

          Text(
            "You can change all settings later.",
            style: TextStyle(
              color: GPColors.ink2,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
