import 'package:flutter/material.dart';
import '../../core/messenger.dart';
import '../../data/models/app_settings.dart';
import '../../data/repositories/app_settings_repo.dart';
import '../../models/onboarding_data.dart';
import '../../theme/gp_colors.dart';

/// What shows on the invoice, which PDF template to use, and the UPI ID used in payment reminders and "pay now" links.
class BillingSettingsScreen extends StatefulWidget {
  final OnboardingData data;
  const BillingSettingsScreen({super.key, required this.data});

  @override
  State<BillingSettingsScreen> createState() => _BillingSettingsScreenState();
}

class _BillingSettingsScreenState extends State<BillingSettingsScreen> {
  final _repo = AppSettingsRepo.I;
  final _upi = TextEditingController();
  String? _upiError;
  bool _upiLoaded = false;

  static final _upiRe = RegExp(r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z]{2,}$');

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  Future<void> _saveUpi() async {
    final v = _upi.text.trim();
    if (v.isNotEmpty && !_upiRe.hasMatch(v)) {
      setState(() => _upiError = "Enter a valid UPI ID, for example shop@okaxis");
      return;
    }
    setState(() => _upiError = null);
    await _repo.update((s) => s.upiId = v);
    AppMessenger.info(v.isEmpty ? "UPI ID removed" : "UPI ID saved. It will appear on payment reminders.");
  }

  @override
  Widget build(BuildContext context) {
    final pricingStyle = (widget.data.pricingStyle ?? "Inclusive");

    return StreamBuilder<AppSettings>(
      stream: _repo.watchSettings(),
      builder: (context, snap) {
        final s = snap.data;
        if (s != null && !_upiLoaded) {
          _upi.text = s.upiId;
          _upiLoaded = true;
        }
        final template = s?.invoiceTemplate ?? "classic";

        return Scaffold(
          appBar: AppBar(title: const Text("Billing & Invoice", style: TextStyle(fontWeight: FontWeight.w900))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Invoice template", style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final t in const [
                    ("classic", "Classic", Icons.article_outlined),
                    ("modern", "Modern", Icons.view_agenda_outlined),
                    ("compact", "Compact", Icons.receipt_outlined),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _repo.update((x) => x.invoiceTemplate = t.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: template == t.$1 ? GPColors.tint : GPColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: template == t.$1 ? GPColors.primary : GPColors.line, width: template == t.$1 ? 1.8 : 1),
                            ),
                            child: Column(children: [
                              Icon(t.$3, color: template == t.$1 ? GPColors.primary : GPColors.ink2),
                              const SizedBox(height: 6),
                              Text(t.$2, style: TextStyle(fontWeight: FontWeight.w800, color: template == t.$1 ? GPColors.primary : GPColors.ink)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                switch (template) {
                  "modern" => "Coloured header band and clean table. Good for services and offices.",
                  "compact" => "Small, dense layout. Fits more lines per page.",
                  _ => "Traditional boxed layout with all details.",
                },
                style: const TextStyle(color: GPColors.ink2),
              ),

              const Divider(height: 32),

              const Text("Show on invoice", style: TextStyle(fontWeight: FontWeight.w900)),
              SwitchListTile(
                value: s?.showItemDiscount ?? true,
                onChanged: (v) => _repo.update((x) => x.showItemDiscount = v),
                title: const Text("Item discount"),
              ),
              SwitchListTile(
                value: s?.showNotes ?? true,
                onChanged: (v) => _repo.update((x) => x.showNotes = v),
                title: const Text("Notes"),
              ),
              SwitchListTile(
                value: s?.showTerms ?? true,
                onChanged: (v) => _repo.update((x) => x.showTerms = v),
                title: const Text("Terms & conditions"),
              ),

              const Divider(height: 32),

              const Text("Pricing", style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                "Prices are entered ${pricingStyle.toLowerCase()} of tax. This was chosen during setup.",
                style: const TextStyle(color: GPColors.ink2),
              ),

              const Divider(height: 32),

              const Text("Get paid faster", style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              TextField(
                controller: _upi,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: "Your UPI ID",
                  hintText: "shop@okaxis",
                  helperText: "Added to payment reminders as a tap-to-pay link",
                  errorText: _upiError,
                  suffixIcon: IconButton(icon: const Icon(Icons.check_circle_outline), tooltip: "Save", onPressed: _saveUpi),
                ),
                onSubmitted: (_) => _saveUpi(),
              ),
            ],
          ),
        );
      },
    );
  }
}
