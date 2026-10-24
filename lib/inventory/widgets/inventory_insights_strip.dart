import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../models/inventory_item.dart';

class InventoryInsightsStrip extends StatelessWidget {
  final List<InventoryItem> items;
  final bool stockEnabled;

  const InventoryInsightsStrip({super.key, required this.items, required this.stockEnabled});

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final low = items.where((i) => i.stockStatus == "Low").length;
    final out = items.where((i) => i.stockStatus == "Out").length;

    final cards = [
      _MiniCard("Total", "$total", Icons.list_alt_rounded),
      if (stockEnabled) _MiniCard("Low", "$low", Icons.warning_amber_rounded),
      if (stockEnabled) _MiniCard("Out", "$out", Icons.cancel_rounded),
    ];

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: _Card(cards[i])),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _MiniCard {
  final String label;
  final String value;
  final IconData icon;
  _MiniCard(this.label, this.value, this.icon);
}

class _Card extends StatelessWidget {
  final _MiniCard d;
  const _Card(this.d);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GPColors.tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GPColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: GPColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(d.icon, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.value, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(d.label, style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
