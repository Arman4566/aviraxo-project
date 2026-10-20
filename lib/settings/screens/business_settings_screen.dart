import 'package:flutter/material.dart';
import '../../core/messenger.dart';
import '../../data/repositories/app_settings_repo.dart';
import '../../models/onboarding_data.dart';
import '../../theme/gp_colors.dart';

class BusinessSettingsScreen extends StatelessWidget {
  final OnboardingData data;
  const BusinessSettingsScreen({super.key, required this.data});

  static final _gstinRe = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

  /// Edits name, address, pin code and GSTIN. Saved on this phone and on the server.
  Future<void> _edit(BuildContext context) async {
    final name = TextEditingController(text: data.businessName ?? "");
    final addr = TextEditingController(text: data.address ?? "");
    final pin = TextEditingController(text: data.pinCode ?? "");
    final gstin = TextEditingController(text: data.gstin ?? "");
    String? err;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Edit business details", style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: "Business name *")),
              const SizedBox(height: 12),
              TextField(controller: addr, maxLines: 2, decoration: const InputDecoration(labelText: "Address")),
              const SizedBox(height: 12),
              TextField(controller: pin, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: "PIN code", counterText: "")),
              const SizedBox(height: 12),
              TextField(controller: gstin, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "GSTIN (optional)")),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: GPColors.danger))),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final g = gstin.text.trim().toUpperCase();
                    if (name.text.trim().isEmpty) return set(() => err = "Business name is required.");
                    if (pin.text.trim().isNotEmpty && !RegExp(r'^[0-9]{6}$').hasMatch(pin.text.trim())) return set(() => err = "PIN code must be 6 digits.");
                    if (g.isNotEmpty && !_gstinRe.hasMatch(g)) return set(() => err = "GSTIN does not look right. Example: 27ABCDE1234F1Z5");
                    Navigator.pop(c, true);
                  },
                  child: const Text("Save"),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await AppSettingsRepo.I.update((s) {
      final d = s.draft!;
      d.businessName = name.text.trim();
      d.address = addr.text.trim();
      d.pinCode = pin.text.trim();
      final g = gstin.text.trim().toUpperCase();
      d.gstin = g.isEmpty ? null : g;
    });
    AppMessenger.info("Business details saved");
    if (context.mounted) Navigator.pop(context); // reopen to see the new values
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Business Details", style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field("Business Name", data.businessName ?? "Demo Business"),
          _field("Address", data.address ?? "Not set"),
          _field("State", data.state ?? "Not set"),
          _field("Currency", "INR (₹)", locked: true),
          _field("Business Type", data.businessType ?? "-", locked: true),
          _field("Industry", data.industry ?? "-", locked: true),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GPColors.primary),
            onPressed: () => _edit(context),
            child: const Text("Edit Business Details"),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, {bool locked = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: GPColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: GPColors.ink2)),
            ]),
          ),
          if (locked)
            const Tooltip(
              message: "Set during onboarding",
              child: Icon(Icons.lock_outline_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}
