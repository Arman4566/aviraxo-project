import 'package:flutter/material.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/gp_app_bar.dart';
import '../../widgets/gp_buttons.dart';
import '../../widgets/gp_cards.dart';

class OBInventoryScreen extends StatefulWidget {
  final OnboardingData data;
  final String stepLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const OBInventoryScreen({
    super.key,
    required this.data,
    required this.stepLabel,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  State<OBInventoryScreen> createState() => _OBInventoryScreenState();
}

class _OBInventoryScreenState extends State<OBInventoryScreen> {
  void setTrack(bool v) => setState(() => widget.data.trackInventory = v);

  @override
  Widget build(BuildContext context) {
    final track = widget.data.trackInventory;

    return Column(
      children: [
        GPAppBar(
          stepLabel: widget.stepLabel,
          onBack: widget.onBack,
          onSkip: widget.onSkip,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: ListView(
              children: [
                Text(
                  "Do you want to manage stock inventory?",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                GPOptionCard(
                  title: "Yes, track stock",
                  subtitle: "Items + stock levels",
                  icon: Icons.inventory_rounded,
                  selected: track == true,
                  onTap: () => setTrack(true),
                ),
                const SizedBox(height: 10),

                GPOptionCard(
                  title: "No, billing only",
                  subtitle: "Fast invoicing without stock",
                  icon: Icons.flash_on_rounded,
                  selected: track == false,
                  onTap: () => setTrack(false),
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
