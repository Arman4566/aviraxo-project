import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/gp_app_bar.dart';
import '../../widgets/gp_buttons.dart';
import '../../widgets/gp_chips.dart';
import '../../theme/gp_colors.dart';

class OBBillingScreen extends StatefulWidget {
  final OnboardingData data;
  final String stepLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const OBBillingScreen({
    super.key,
    required this.data,
    required this.stepLabel,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  State<OBBillingScreen> createState() => _OBBillingScreenState();
}

class _OBBillingScreenState extends State<OBBillingScreen> {
  void toggleDoc(String v) {
    setState(() {
      if (widget.data.billingDocs.contains(v)) {
        widget.data.billingDocs.remove(v);
      } else {
        widget.data.billingDocs.add(v);
      }
    });
  }

  void togglePay(String v) {
    setState(() {
      if (widget.data.paymentMethods.contains(v)) {
        widget.data.paymentMethods.remove(v);
      } else {
        widget.data.paymentMethods.add(v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final docs = [if (widget.data.gstRegistered == true) "GST Invoice", "Retail Invoice", "Estimate / Quotation", "Proforma Invoice", "Delivery Challan"];
    final pays = ["Cash", "UPI", "Card", "Bank Transfer", "Credit (Pay Later)"];

    return Column(
      children: [
        GPAppBar(stepLabel: widget.stepLabel, onBack: widget.onBack, onSkip: widget.onSkip),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: ListView(
              children: [
                Text("What do you want to create in Galla Pro?",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: docs.map((d) {
                    return GPMultiChip(
                      label: d,
                      selected: widget.data.billingDocs.contains(d),
                      onTap: () => toggleDoc(d),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                Text("Accepted payment methods",
                    style: TextStyle(fontWeight: FontWeight.w900, color: GPColors.ink)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: pays.map((p) {
                    return GPMultiChip(
                      label: p,
                      selected: widget.data.paymentMethods.contains(p),
                      onTap: () => togglePay(p),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),
                GPPrimaryButton(text: "Next", onPressed: widget.onNext),
                const SizedBox(height: 6),
                Text(
                  "Tip: choose multiple — you can change this later.",
                  style: TextStyle(color: GPColors.ink2),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
