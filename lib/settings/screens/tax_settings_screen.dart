import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../models/onboarding_data.dart';
import '../../theme/gp_colors.dart';
import '../../data/repositories/app_settings_repo.dart';

class TaxSettingsScreen extends StatefulWidget {
  final OnboardingData data;
  const TaxSettingsScreen({super.key, required this.data});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  final _repo = AppSettingsRepo.I;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _repo.watchSettings(),
      builder: (context, snap) {
        final gstType = snap.data?.draft?.gstType ?? "Within State";

        return Scaffold(
          appBar: AppBar(
            title: const Text("Tax & GST", style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("GST Details", style: TextStyle(fontWeight: FontWeight.w900)),
              _field("GSTIN", widget.data.gstin ?? "Not set"),
              _field("Business State", widget.data.state ?? "Not set"),

              const Divider(),

              const Text("GST Behavior", style: TextStyle(fontWeight: FontWeight.w900)),
              RadioListTile(
                value: "Within State",
                groupValue: gstType,
                onChanged: (v) => _repo.setGstType(v ?? "Within State"),
                title: const Text("CGST + SGST (Within State)"),
              ),
              RadioListTile(
                value: "Inter State",
                groupValue: gstType,
                onChanged: (v) => _repo.setGstType(v ?? "Inter State"),
                title: const Text("IGST (Inter State)"),
              ),

              const Divider(),

              const Text("Invoice Tax Display", style: TextStyle(fontWeight: FontWeight.w900)),
              SwitchListTile(
                value: snap.data?.showGstBreakup ?? true,
                onChanged: (v) => _repo.update((x) => x.showGstBreakup = v),
                title: const Text("Show CGST / SGST / IGST breakup"),
                subtitle: const Text("On the invoice PDF"),
              ),
              SwitchListTile(
                value: snap.data?.showHsnSac ?? true,
                onChanged: (v) => _repo.update((x) => x.showHsnSac = v),
                title: const Text("Show HSN / SAC code"),
                subtitle: const Text("Under each item on the invoice PDF"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _field(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GPColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: GPColors.ink2)),
      ]),
    );
  }
}
