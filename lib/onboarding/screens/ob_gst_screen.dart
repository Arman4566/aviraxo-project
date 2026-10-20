import 'package:flutter/material.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/gp_app_bar.dart';
import '../../widgets/gp_buttons.dart';
import '../../widgets/gp_cards.dart';
import '../../widgets/gp_chips.dart';
import '../../widgets/gp_inputs.dart';
import '../../theme/gp_colors.dart';

class OBGstScreen extends StatefulWidget {
  final OnboardingData data;
  final String stepLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const OBGstScreen({
    super.key,
    required this.data,
    required this.stepLabel,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  State<OBGstScreen> createState() => _OBGstScreenState();
}

class _OBGstScreenState extends State<OBGstScreen> {
  late final TextEditingController _gstinCtrl;
  String? _gstinError;

  static final _gstinRe = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

  @override
  void initState() {
    super.initState();
    _gstinCtrl = TextEditingController(text: widget.data.gstin ?? "");
  }

  @override
  void dispose() {
    _gstinCtrl.dispose();
    super.dispose();
  }

  void setRegistered(bool v) {
    setState(() {
      widget.data.gstRegistered = v;
      if (!v) {
        widget.data.gstin = null;
        widget.data.gstSlabs.clear();
        widget.data.gstType = "Within State";
        _gstinCtrl.text = "";
      }
    });
  }

  void toggleSlab(int slab) {
    setState(() {
      if (widget.data.gstSlabs.contains(slab)) {
        widget.data.gstSlabs.remove(slab);
      } else {
        widget.data.gstSlabs.add(slab);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final registered = widget.data.gstRegistered;

    return Column(
      children: [
        GPAppBar(stepLabel: widget.stepLabel, onBack: widget.onBack, onSkip: widget.onSkip),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: ListView(
              children: [
                Text("Is your business GST registered?",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),

                GPOptionCard(
                  title: "Yes, GST Registered",
                  subtitle: "We’ll enable GST invoices + slabs",
                  icon: Icons.verified_rounded,
                  selected: registered == true,
                  onTap: () => setRegistered(true),
                ),
                const SizedBox(height: 10),
                GPOptionCard(
                  title: "No",
                  subtitle: "We’ll use non-GST invoices",
                  icon: Icons.block_rounded,
                  selected: registered == false,
                  onTap: () => setRegistered(false),
                ),

                const SizedBox(height: 14),

                if (registered == true) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GPColors.tint.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: GPColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GPTextField(
                          label: "GSTIN",
                          hint: "e.g. 27ABCDE1234F1Z5",
                          controller: _gstinCtrl,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          errorText: _gstinError,
                          helperText: "15 characters. Leave empty to add it later in Settings.",
                          onChanged: (_) => setState(() => _gstinError = null),
                        ),
                        const SizedBox(height: 12),
                        Text("Default GST type", style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: ["Within State", "Outside State", "Both"].map((e) {
                            final sel = widget.data.gstType == e;
                            return GPMultiChip(
                              label: e,
                              selected: sel,
                              onTap: () => setState(() => widget.data.gstType = e),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text("Common GST slabs", style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [0, 5, 12, 18, 28].map((s) {
                            return GPMultiChip(
                              label: "$s%",
                              selected: widget.data.gstSlabs.contains(s),
                              onTap: () => toggleSlab(s),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "You can change all GST settings later in Settings > Tax & GST.",
                    style: TextStyle(color: GPColors.ink2),
                  ),
                ] else if (registered == false) ...[
                  const Text(
                    "We’ll use non-GST invoices.",
                    style: TextStyle(color: GPColors.ink2),
                  ),
                ],

                const SizedBox(height: 18),
                GPPrimaryButton(
                  text: "Next",
                  onPressed: () {
                    final g = _gstinCtrl.text.trim().toUpperCase();
                    if (registered == true && g.isNotEmpty && !_gstinRe.hasMatch(g)) {
                      setState(() => _gstinError = "This GSTIN does not look right. Example: 27ABCDE1234F1Z5");
                      return;
                    }
                    widget.data.gstin = g.isEmpty ? null : g;
                    widget.onNext();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
