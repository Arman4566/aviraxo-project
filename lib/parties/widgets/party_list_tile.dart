import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../models/party_model.dart';
import 'due_badge.dart';

class PartyListTile extends StatelessWidget {
  final PartyModel party;
  final VoidCallback onTap;

  const PartyListTile({super.key, required this.party, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GPColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GPColors.line),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: GPColors.primary.withOpacity(0.25),
              child: const Icon(Icons.person_rounded),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(party.name,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(party.phone,
                      style: TextStyle(color: GPColors.ink2)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _pill(
                        party.type == PartyType.customer
                            ? "Customer"
                            : party.type == PartyType.supplier
                            ? "Supplier"
                            : "Both",
                      ),
                      if (party.gstRegistered) ...[
                        const SizedBox(width: 8),
                        _pill("GST"),
                      ],
                    ],
                  )
                ],
              ),
            ),

            DueBadge(party: party),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GPColors.tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GPColors.line),
      ),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}
