import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import '../../models/onboarding_data.dart';
import '../../theme/gp_colors.dart';
import '../../widgets/gp_app_bar.dart';
import '../../widgets/gp_buttons.dart';
import '../../widgets/gp_inputs.dart';

class OBBusinessDetailsScreen extends StatefulWidget {
  final OnboardingData data;
  final String stepLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const OBBusinessDetailsScreen({
    super.key,
    required this.data,
    required this.stepLabel,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  State<OBBusinessDetailsScreen> createState() => _OBBusinessDetailsScreenState();
}

class _OBBusinessDetailsScreenState extends State<OBBusinessDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _addr;
  late final TextEditingController _pin;

  final _states = const [
    "Maharashtra",
    "Tamil Nadu",
    "Gujarat",
    "Uttar Pradesh",
    "Karnataka",
    "West Bengal",
    "Rajasthan",
    "Telangana",
    "Andhra Pradesh",
    "Madhya Pradesh",
    "Kerala",
    "Delhi",
    "Haryana",
    "Odisha",
    "Bihar",
    "Punjab",
    "Chhattisgarh",
    "Assam",
    "Jharkhand",
    "Uttarakhand",
    "Himachal Pradesh",
    "Goa",
    "Tripura",
    "Manipur",
    "Meghalaya",
    "Nagaland",
    "Arunachal Pradesh",
    "Mizoram",
    "Sikkim",
    "Jammu and Kashmir",
    "Puducherry",
    "Chandigarh",
    "Andaman and Nicobar Islands",
    "Dadra and Nagar Haveli and Daman and Diu",
    "Ladakh",
    "Lakshadweep",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.data.businessName ?? "");
    _addr = TextEditingController(text: widget.data.address ?? "");
    _pin = TextEditingController(text: widget.data.pinCode ?? "");
  }

  @override
  void dispose() {
    _name.dispose();
    _addr.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _save() {
    widget.data.businessName =
    _name.text.trim().isEmpty ? null : _name.text.trim();
    widget.data.address = _addr.text.trim().isEmpty ? null : _addr.text.trim();
    widget.data.pinCode = _pin.text.trim().isEmpty ? null : _pin.text.trim();
  }

  @override
  Widget build(BuildContext context) {
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
                  "Tell us about your business",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                GPTextField(
                  label: trs("Business Name"),
                  hint: "e.g. Shree Ganesh Traders",
                  controller: _name,
                ),
                const SizedBox(height: 12),

                GPTextField(
                  label: trs("Address"),
                  hint: "Street, area, city",
                  controller: _addr,
                ),
                const SizedBox(height: 12),

                // ✅ SAFE DROPDOWN (NO OVERFLOW EVER)
                _SafeDropdownField(
                  label: trs("State"),
                  hint: "Select state",
                  value: widget.data.state,
                  items: _states,
                  onChanged: (v) => setState(() => widget.data.state = v),
                ),
                const SizedBox(height: 12),

                GPTextField(
                  label: trs("PIN Code"),
                  hint: "e.g. 411001",
                  controller: _pin,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // ✅ SAFE DROPDOWN (NO OVERFLOW EVER)
                _SafeDropdownField(
                  label: trs("Currency"),
                  hint: "Select currency",
                  value: widget.data.currency,
                  items: const ["INR", "USD", "EUR"],
                  onChanged: (v) =>
                      setState(() => widget.data.currency = v ?? "INR"),
                ),

                const SizedBox(height: 18),
                GPPrimaryButton(
                  text: "Next",
                  onPressed: () {
                    _save();
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

/// ✅ A dropdown that will NOT overflow on any screen size / DPI.
/// - Uses DropdownButtonFormField with isExpanded = true
/// - Forces selected text & menu items to ellipsis
/// - Uses padding that matches your input styling
class _SafeDropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _SafeDropdownField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: GPColors.line.withOpacity(0.9)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true, // ✅ KEY: prevents row overflow
          icon: const Icon(Icons.arrow_drop_down_rounded),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: GPColors.tint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: GPColors.ink.withOpacity(0.18)),
            ),
          ),

          // ✅ hint text style
          hint: Text(
            hint,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: GPColors.ink2,
              fontWeight: FontWeight.w700,
            ),
          ),

          // ✅ selected text style
          style: TextStyle(
            color: GPColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),

          // ✅ items with ellipsis to avoid long text overflow
          items: items
              .map(
                (e) => DropdownMenuItem<String>(
              value: e,
              child: Text(
                e,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
              .toList(),

          onChanged: onChanged,
        ),
      ],
    );
  }
}
