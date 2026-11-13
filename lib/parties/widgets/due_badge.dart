import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../models/party_model.dart';

/// Balance chip. Colour is never the only signal: a due balance carries a warning triangle, a clear one a tick.
class DueBadge extends StatelessWidget {
  final PartyModel party;
  const DueBadge({super.key, required this.party});

  @override
  Widget build(BuildContext context) {
    final isDue = party.hasDue;
    final c = isDue ? GPColors.warning : GPColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isDue ? Icons.warning_amber_rounded : Icons.check_circle_rounded, size: 16, color: c),
          const SizedBox(width: 6),
          Text(party.balanceLabel, style: TextStyle(fontWeight: FontWeight.w900, color: c)),
        ],
      ),
    );
  }
}
