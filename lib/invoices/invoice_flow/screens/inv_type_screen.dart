import 'package:flutter/material.dart';
import '../../../models/onboarding_data.dart';
import '../../../theme/gp_colors.dart';
import '../models/invoice_draft.dart';

class InvTypeScreen extends StatefulWidget {
  final OnboardingData onboarding;
  final InvoiceDraft draft;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const InvTypeScreen({
    super.key,
    required this.onboarding,
    required this.draft,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<InvTypeScreen> createState() => _InvTypeScreenState();
}

class _InvTypeScreenState extends State<InvTypeScreen> {
  late InvoiceDocType _type;

  @override
  void initState() {
    super.initState();
    _type = widget.draft.type;
  }

  void _set(InvoiceDocType t) => setState(() => _type = t);

  @override
  Widget build(BuildContext context) {
    final cards = [
      _TypeCard("GST Invoice", "Tax invoice with GST breakup", Icons.verified_rounded, InvoiceDocType.gstInvoice),
      _TypeCard("Retail Invoice", "Fast billing for walk-in", Icons.flash_on_rounded, InvoiceDocType.retailInvoice),
      _TypeCard("Estimate / Quotation", "Send a quotation", Icons.request_quote_rounded, InvoiceDocType.estimate),
      _TypeCard("Proforma Invoice", "Before final invoice", Icons.description_rounded, InvoiceDocType.proforma),
      _TypeCard("Delivery Challan", "Goods delivery note", Icons.local_shipping_rounded, InvoiceDocType.deliveryChallan),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          _TopBar(title: "Create Invoice", onBack: widget.onBack),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerLeft,
            child: Text("Choose invoice type", style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView.separated(
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = cards[i];
                final selected = _type == c.type;

                // If onboarding GST not registered, still show GST option but visually "less relevant"
                final gstAllowed = widget.onboarding.gstRegistered == true;
                final dimGstCard = (c.type == InvoiceDocType.gstInvoice && !gstAllowed);

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _set(c.type),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected ? GPColors.tint.withOpacity(0.75) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? GPColors.primary : GPColors.line,
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Opacity(
                      opacity: dimGstCard ? 0.8 : 1,
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: GPColors.primary.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(c.icon, color: GPColors.ink),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(c.sub, style: const TextStyle(color: GPColors.ink2)),
                                if (dimGstCard) ...[
                                  const SizedBox(height: 4),
                                  const Text("GST is not enabled for this business (turn it on in Settings > Tax)",
                                      style: TextStyle(color: GPColors.ink2, fontSize: 12)),
                                ]
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded, color: GPColors.success)
                          else
                            const Icon(Icons.circle_outlined, color: GPColors.line),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GPColors.primary,
                foregroundColor: GPColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                widget.draft.type = _type;
                widget.onContinue();
              },
              child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
        Expanded(
          child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _TypeCard {
  final String title;
  final String sub;
  final IconData icon;
  final InvoiceDocType type;
  _TypeCard(this.title, this.sub, this.icon, this.type);
}
