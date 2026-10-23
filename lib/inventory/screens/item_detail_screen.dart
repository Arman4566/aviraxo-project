import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/gp_colors.dart';
import '../models/inventory_item.dart';
import '../widgets/stock_badge.dart';

class ItemDetailScreen extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPurchaseEntry;
  final VoidCallback onAdjustStock;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onPurchaseEntry,
    required this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    final stockEnabled = item.stockEnabled;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GPColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            tooltip: trs("Share item"),
            icon: const Icon(Icons.share_rounded),
            onPressed: () => Share.share(
              "${item.name}\nPrice: ₹${item.sellingPrice.toStringAsFixed(0)} / ${item.unit}"
              "${item.stockEnabled ? "\nIn stock: ${item.stockQty} ${item.unit}" : ""}",
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.tint.withOpacity(0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                Text("Category: ${item.category}", style: TextStyle(color: GPColors.ink2)),
                const SizedBox(height: 6),
                Text("Unit: ${item.unit}", style: TextStyle(color: GPColors.ink2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (stockEnabled) StockBadge(status: item.stockStatus),
                    const SizedBox(width: 10),
                    _pill(item.gstEnabled ? "GST ${item.gstRate}%" : "Non-GST"),
                    const SizedBox(width: 10),
                    _pill(item.priceInclusive ? "Inclusive" : "Exclusive"),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const _Title("Stock Info"),
          const SizedBox(height: 10),

          _kv("Current stock", stockEnabled ? "${item.stockQty} ${item.unit}" : "Not applicable"),
          _kv("Total stock IN", stockEnabled ? "${item.stockInTotal} ${item.unit}" : "—"),
          _kv("Total stock OUT", stockEnabled ? "${item.stockOutTotal} ${item.unit}" : "—"),
          _kv("Low stock alert", stockEnabled ? "${item.lowStockLevel}" : "—"),
          _kv("Last updated", _fmt(item.updatedAt)),
          if (item.location.isNotEmpty) _kv("Location", item.location),

          const SizedBox(height: 14),
          const _Title("Pricing"),
          const SizedBox(height: 10),

          _kv("Purchase price", "₹${item.purchasePrice.toStringAsFixed(0)}"),
          _kv("Selling price", "₹${item.sellingPrice.toStringAsFixed(0)}"),
          _kv("Tax", item.gstEnabled ? "GST ${item.gstRate}%" : "Non-GST"),

          const SizedBox(height: 18),
          const _Title("Quick Actions"),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _actionBtn(context, "Purchase Entry", Icons.shopping_cart_rounded, onPurchaseEntry),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionBtn(
                  context,
                  "Adjust Stock",
                  Icons.tune_rounded,
                  onAdjustStock,
                ),
              ),
            ],
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Add to Invoice (later)")),
                );
              },
              child: const Text("🧾 Add to Invoice", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GPColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GPColors.line),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GPColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Row(
        children: [
          Expanded(child: Text(k, style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _actionBtn(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: GPColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
}

class _Title extends StatelessWidget {
  final String t;
  const _Title(this.t);

  @override
  Widget build(BuildContext context) {
    return Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16));
  }
}
