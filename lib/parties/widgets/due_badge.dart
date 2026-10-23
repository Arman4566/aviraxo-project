import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../models/party_model.dart';

class DueBadge extends StatelessWidget {
  final PartyModel party;
  const DueBadge({super.key, required this.party});

  @override
  Widget build(BuildContext context) {
    final isDue = party.hasDue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDue
            ? Colors.red.withOpacity(0.12)
            : GPColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GPColors.line),
      ),
      child: Text(
        party.balanceLabel,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: isDue ? Colors.red : GPColors.success,
        ),
      ),
    );
  }
}
