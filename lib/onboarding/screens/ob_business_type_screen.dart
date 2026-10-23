import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/gp_app_bar.dart';
import '../../widgets/gp_buttons.dart';
import '../../widgets/gp_cards.dart';

class OBBusinessTypeScreen extends StatefulWidget {
  final OnboardingData data;
  final String stepLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const OBBusinessTypeScreen({
    super.key,
    required this.data,
    required this.stepLabel,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  State<OBBusinessTypeScreen> createState() => _OBBusinessTypeScreenState();
}

class _OBBusinessTypeScreenState extends State<OBBusinessTypeScreen> {
  void select(String v) => setState(() => widget.data.businessType = v);

  @override
  Widget build(BuildContext context) {
    final sel = widget.data.businessType;

    return Column(
      children: [
        GPAppBar(stepLabel: widget.stepLabel, onBack: widget.onBack, onSkip: widget.onSkip),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: ListView(
              children: [
                Text("What type of business do you run?",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),

                GPOptionCard(
                  title: "Retailer",
                  subtitle: "Sell directly to customers",
                  icon: Icons.storefront_rounded,
                  selected: sel == "Retailer",
                  onTap: () => select("Retailer"),
                ),
                const SizedBox(height: 10),
                GPOptionCard(
                  title: "Wholesaler",
                  subtitle: "Sell in bulk to retailers",
                  icon: Icons.inventory_2_rounded,
                  selected: sel == "Wholesaler",
                  onTap: () => select("Wholesaler"),
                ),
                const SizedBox(height: 10),
                GPOptionCard(
                  title: "Distributor",
                  subtitle: "Supply branded goods",
                  icon: Icons.local_shipping_rounded,
                  selected: sel == "Distributor",
                  onTap: () => select("Distributor"),
                ),
                const SizedBox(height: 10),
                GPOptionCard(
                  title: "Manufacturer",
                  subtitle: "Produce & sell goods",
                  icon: Icons.factory_rounded,
                  selected: sel == "Manufacturer",
                  onTap: () => select("Manufacturer"),
                ),
                const SizedBox(height: 10),
                GPOptionCard(
                  title: "Services",
                  subtitle: "No physical inventory",
                  icon: Icons.support_agent_rounded,
                  selected: sel == "Services",
                  onTap: () => select("Services"),
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
