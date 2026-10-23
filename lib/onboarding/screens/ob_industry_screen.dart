import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/gp_app_bar.dart';
import '../../widgets/gp_buttons.dart';
import '../../theme/gp_colors.dart';

class OBIndustryScreen extends StatefulWidget {
  final OnboardingData data;
  final String stepLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const OBIndustryScreen({
    super.key,
    required this.data,
    required this.stepLabel,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  State<OBIndustryScreen> createState() => _OBIndustryScreenState();
}

class _OBIndustryScreenState extends State<OBIndustryScreen> {
  final _search = TextEditingController();

  final List<_Industry> _industries = const [
    _Industry("Electronics", "TV, gadgets, accessories", Icons.electrical_services_rounded),
    _Industry("Mobile & Accessories", "Phones, covers, parts", Icons.phone_iphone_rounded),
    _Industry("FMCG / Grocery", "Daily essentials & food", Icons.shopping_basket_rounded),
    _Industry("Garments & Clothing", "Fashion, textiles", Icons.checkroom_rounded),
    _Industry("Hardware & Tools", "Tools, fittings, supplies", Icons.handyman_rounded),
    _Industry("Pharmacy / Medical", "Medicines & health", Icons.local_hospital_rounded),
    _Industry("Agriculture", "Seeds, fertilizers, produce", Icons.agriculture_rounded),
    _Industry("Stationery", "Books, paper, office", Icons.menu_book_rounded),
    _Industry("Services / Consultancy", "No stock business", Icons.support_agent_rounded),
    _Industry("Other", "Anything else", Icons.category_rounded),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = query.isEmpty
        ? _industries
        : _industries.where((e) => e.name.toLowerCase().contains(query)).toList();

    return Column(
      children: [
        GPAppBar(stepLabel: widget.stepLabel, onBack: widget.onBack, onSkip: widget.onSkip),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Select your industry", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),

                // optional search (Phase-0 allowed)
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: trs("Search industry (optional)"),
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: GridView.builder(
                    itemCount: items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.12,
                    ),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      final selected = widget.data.industry == it.name;

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() => widget.data.industry = it.name),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? GPColors.tint.withValues(alpha: 0.75)
                                : GPColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? GPColors.primary : GPColors.line,
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: GPColors.primary.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(it.icon, color: GPColors.ink),
                              ),
                              const SizedBox(height: 10),
                              Text(it.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text(it.desc, style: TextStyle(color: GPColors.ink2)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                GPPrimaryButton(text: "Next", onPressed: widget.onNext),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Industry {
  final String name;
  final String desc;
  final IconData icon;
  const _Industry(this.name, this.desc, this.icon);
}
