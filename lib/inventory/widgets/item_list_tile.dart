import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../models/inventory_item.dart';
import 'stock_badge.dart';

class ItemListTile extends StatelessWidget {
  final InventoryItem item;
  final bool stockEnabled;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ItemListTile({
    super.key,
    required this.item,
    required this.stockEnabled,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = item.stockStatus;

    return Dismissible(
      key: ValueKey(item.id),
      background: _slideBg(
        alignLeft: true,
        icon: Icons.edit_rounded,
        label: trs("Edit"),
        color: GPColors.tint.withOpacity(0.8),
      ),
      secondaryBackground: _slideBg(
        alignLeft: false,
        icon: Icons.delete_outline_rounded,
        label: trs("Delete"),
        color: Colors.red.withOpacity(0.12),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false;
        } else {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Delete item?"),
              content: Text("“${item.name}” will be removed permanently."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Delete"),
                ),
              ],
            ),
          );

          if (ok == true) {
            onDelete();
            return true;
          }
          return false;
        }
      },
      child: InkWell(
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: GPColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(stockEnabled
                    ? Icons.inventory_2_rounded
                    : Icons.design_services_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text("SKU: ${item.sku}",
                        style: TextStyle(color: GPColors.ink2)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (item.gstEnabled) _pill("GST ${item.gstRate}%"),
                        if (item.gstEnabled) const SizedBox(width: 8),
                        _pill(item.unit),
                      ],
                    )
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("₹${item.sellingPrice.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  if (stockEnabled)
                    Text("${item.stockQty} ${item.unit}",
                        style: TextStyle(
                            color: GPColors.ink2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  StockBadge(status: status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GPColors.tint.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GPColors.line),
      ),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }

  Widget _slideBg({
    required bool alignLeft,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment:
        alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
