import 'package:flutter/material.dart' hide Text;
import '../../../l10n/gtext.dart';
import '../../../theme/gp_colors.dart';
import '../models/invoice_draft.dart';

class InvPartyCard extends StatelessWidget {
  final Party party;
  final bool selected;
  final VoidCallback onTap;

  const InvPartyCard({
    super.key,
    required this.party,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? GPColors.tint.withOpacity(0.75) : GPColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? GPColors.primary : GPColors.line, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: GPColors.primary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.person_rounded, color: GPColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(party.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(party.phone, style: TextStyle(color: GPColors.ink2)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (party.outstanding > 0)
                  Text("₹${party.outstanding.toStringAsFixed(0)} due",
                      style: const TextStyle(fontWeight: FontWeight.w900))
                else
                  Text("No due", style: TextStyle(color: GPColors.ink2)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: GPColors.tint.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: Text(party.gstRegistered ? "GST" : "Non-GST",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
