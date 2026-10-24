import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../models/inventory_item.dart';

class PurchaseEntryResult {
  final int purchasedQty;
  final double purchasePrice;
  final double sellingPrice;

  PurchaseEntryResult({
    required this.purchasedQty,
    required this.purchasePrice,
    required this.sellingPrice,
  });
}

class PurchaseEntryFlow extends StatefulWidget {
  final InventoryItem item;
  final bool stockEnabled;

  const PurchaseEntryFlow({
    super.key,
    required this.item,
    required this.stockEnabled,
  });

  @override
  State<PurchaseEntryFlow> createState() => _PurchaseEntryFlowState();
}

class _PurchaseEntryFlowState extends State<PurchaseEntryFlow> {
  final _qty = TextEditingController();
  final _purchase = TextEditingController();
  final _selling = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qty.text = "";
    _purchase.text = widget.item.purchasePrice == 0
        ? ""
        : widget.item.purchasePrice.toStringAsFixed(0);
    _selling.text = widget.item.sellingPrice == 0
        ? ""
        : widget.item.sellingPrice.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _qty.dispose();
    _purchase.dispose();
    _selling.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();

    final addQty = int.tryParse(_qty.text.trim()) ?? 0;
    final p = double.tryParse(_purchase.text.trim()) ?? widget.item.purchasePrice;
    final s = double.tryParse(_selling.text.trim()) ?? widget.item.sellingPrice;

    if (addQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter purchased quantity")),
      );
      return;
    }

    Navigator.pop(
      context,
      PurchaseEntryResult(
        purchasedQty: addQty,
        purchasePrice: p,
        sellingPrice: s,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.stockEnabled) {
      return Scaffold(
      appBar: AppBar(
          backgroundColor: GPColors.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text("Purchase Entry", style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: const Center(
          child: Text("Purchase entry is not available for Services."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GPColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text("Purchase Entry", style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.tint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 6),
                Text("Current stock: ${widget.item.stockQty} ${widget.item.unit}",
                    style: TextStyle(color: GPColors.ink2)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: trs("Purchased quantity"),
              prefixIcon: Icon(Icons.add_circle_outline_rounded),
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _purchase,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: trs("Purchase price (optional)"),
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _selling,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: trs("Selling price (optional)"),
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
          ),

          const SizedBox(height: 16),
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
              onPressed: _save,
              child: const Text("Save Entry", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
