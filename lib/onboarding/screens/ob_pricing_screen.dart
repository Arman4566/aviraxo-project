import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/gp_app_bar.dart';
import '../../widgets/gp_buttons.dart';
import '../../widgets/gp_cards.dart';

class OBPricingScreen extends StatefulWidget {
  final OnboardingData data;
  final String stepLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const OBPricingScreen({
    super.key,
    required this.data,
    required this.stepLabel,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  State<OBPricingScreen> createState() => _OBPricingScreenState();
}

class _OBPricingScreenState extends State<OBPricingScreen> {
  void select(String v) => setState(() => widget.data.pricingStyle = v);

  @override
  Widget build(BuildContext context) {
    final sel = widget.data.pricingStyle;

    return Column(
      children: [
        GPAppBar(stepLabel: widget.stepLabel, onBack: widget.onBack, onSkip: widget.onSkip),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: ListView(
              children: [
                Text("Your product prices are usually",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),

                GPOptionCard(
                  title: "Inclusive of tax (MRP style)",
                  subtitle: "Best for retail billing",
                  icon: Icons.receipt_long_rounded,
                  selected: sel == "Inclusive",
                  onTap: () => select("Inclusive"),
                ),
                const SizedBox(height: 10),
                GPOptionCard(
                  title: "Exclusive of tax (B2B style)",
                  subtitle: "Tax added during invoice creation",
                  icon: Icons.calculate_rounded,
                  selected: sel == "Exclusive",
                  onTap: () => select("Exclusive"),
                ),

                const SizedBox(height: 18),
                GPPrimaryButton(text: "Next", onPressed: widget.onNext),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
