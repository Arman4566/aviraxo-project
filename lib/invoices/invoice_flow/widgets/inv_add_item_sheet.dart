import 'package:flutter/material.dart';
import '../../../widgets/barcode_scanner_page.dart';
import '../../../core/messenger.dart';
import '../../../models/onboarding_data.dart';
import '../../../theme/gp_colors.dart';

import '../../../data/models/item_entity.dart';
import '../../../data/repositories/inventory_repo.dart';

import '../../../inventory/models/inventory_item.dart';
import '../../../inventory/screens/add_edit_item_flow.dart';

import '../models/invoice_draft.dart';

class InvAddItemSheet extends StatefulWidget {
  final OnboardingData onboarding;
  final bool gstEnabled;

  const InvAddItemSheet({
    super.key,
    required this.onboarding,
    required this.gstEnabled,
  });

  @override
  State<InvAddItemSheet> createState() => _InvAddItemSheetState();
}

class _InvAddItemSheetState extends State<InvAddItemSheet> {
  final _repo = InventoryRepo();
  final _search = TextEditingController();

  int? _selectedId;

  int _qty = 1;
  double _rate = 0;
  bool _discPercent = true;
  double _discVal = 0;

  bool get _stockEnabled {
    final bt = (widget.onboarding.businessType ?? "").toLowerCase();
    return bt != "services";
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  CatalogItem _toCatalog(ItemEntity e) {
    return CatalogItem(
      itemId: e.id, // lets the server reduce this item's stock when the invoice is saved
      name: e.name,
      unit: e.unit,
      rate: e.sellingPrice,
      gstSlab: e.gstEnabled ? e.gstRate : 0,
      hsn: e.hsn,
    );
  }

  /// Scan a barcode: fills the search box and, when exactly one item matches, selects it so only quantity is left to enter.
  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final all = await _repo.getAll();
    final hits = all.where((i) => i.barcode.trim() == code || i.sku.trim().toLowerCase() == code.toLowerCase()).toList();
    if (!mounted) return;
    setState(() => _search.text = code);
    if (hits.length == 1) {
      _pick(hits.first);
    } else if (hits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No item has barcode $code. Add it with New Item.")));
    }
  }

  void _pick(ItemEntity e) {
    setState(() {
      _selectedId = e.id;
      _qty = 1;
      _rate = e.sellingPrice;
      _discPercent = true;
      _discVal = 0;
    });
  }

  Future<void> _openNewItem() async {
    // open inventory add/edit flow
    final created = await Navigator.push<InventoryItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemFlow(
          gstEnabled: widget.onboarding.gstRegistered == true,
          stockEnabled: _stockEnabled,
          initial: null,
        ),
      ),
    );

    if (created == null) return;

    // Save it on the server
    int newId;
    try {
      newId = await _repo.upsert(created);
    } catch (e) {
      AppMessenger.error(e);
      return;
    }

    // Auto-select newly created item and scroll search clear
    if (!mounted) return;
    setState(() {
      _search.text = "";
      _selectedId = newId;
      _qty = 1;
      _rate = created.sellingPrice;
      _discPercent = true;
      _discVal = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Item saved to inventory")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ItemEntity>>(
      stream: _repo.watchAll(),
      builder: (context, snap) {
        final all = snap.data ?? [];

        final q = _search.text.trim().toLowerCase();
        final items = all.where((it) {
          if (q.isEmpty) return true;
          final phoneSafe = q.replaceAll(" ", "");
          return it.nameLower.contains(q) ||
              it.skuLower.contains(q) ||
              (it.barcode.replaceAll(" ", "").contains(phoneSafe));
        }).toList();

        final selected = _selectedId == null
            ? null
            : all.where((e) => e.id == _selectedId).cast<ItemEntity?>().firstOrNull;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 46, height: 5, decoration: BoxDecoration(color: GPColors.line, borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Expanded(
                    child: Text("Add Item", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  TextButton(
                    onPressed: _openNewItem,
                    child: const Text("➕ New Item", style: TextStyle(fontWeight: FontWeight.w900, color: GPColors.primaryDeep)),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "Search item name / SKU / barcode",
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: "Scan barcode",
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: _scan,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (items.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: GPColors.tint.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: const Text(
                    "No items found in inventory.\nTap “New Item” to add one.",
                    style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700),
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final isSelected = _selectedId == it.id;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _pick(it),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? GPColors.tint.withOpacity(0.75) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? GPColors.primary : GPColors.line),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: GPColors.primary.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.inventory_2_rounded, color: GPColors.ink, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    Text(
                                      "₹${it.sellingPrice.toStringAsFixed(0)} • ${it.unit}"
                                          "${it.gstEnabled ? " • GST ${it.gstRate}%" : " • Non-GST"}",
                                      style: const TextStyle(color: GPColors.ink2),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected) const Icon(Icons.check_circle_rounded, color: GPColors.success),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 12),

              if (selected != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: GPColors.tint.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(selected.name, style: const TextStyle(fontWeight: FontWeight.w900))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: GPColors.line),
                            ),
                            child: Text(selected.unit, style: const TextStyle(fontWeight: FontWeight.w900)),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(child: _QtyStepper(qty: _qty, onChanged: (v) => setState(() => _qty = v))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setState(() => _rate = double.tryParse(v) ?? _rate),
                              controller: TextEditingController(text: _rate.toStringAsFixed(0)),
                              decoration: const InputDecoration(
                                hintText: "Rate",
                                prefixIcon: Icon(Icons.currency_rupee_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setState(() => _discVal = double.tryParse(v) ?? 0),
                              decoration: InputDecoration(
                                hintText: _discPercent ? "Discount %" : "Discount ₹",
                                prefixIcon: const Icon(Icons.discount_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: GPColors.line),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => setState(() => _discPercent = !_discPercent),
                              child: Text(_discPercent ? "% → ₹" : "₹ → %", style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.gstEnabled && selected.gstEnabled
                              ? "GST ${selected.gstRate}% (from inventory)"
                              : "Non-GST invoice / item tax hidden",
                          style: const TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                    final it = selected;
                    if (it == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select an item first")));
                      return;
                    }

                    final catalog = _toCatalog(it);

                    final line = InvoiceLine(
                      item: catalog,
                      qty: _qty,
                      rate: _rate,
                      discountIsPercent: _discPercent,
                      discountValue: _discVal,
                      gstSlab: (widget.gstEnabled && it.gstEnabled) ? it.gstRate : 0,
                    );

                    Navigator.pop(context, line);
                  },
                  child: const Text("Add to invoice", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;

  const _QtyStepper({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GPColors.line),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChanged((qty - 1).clamp(1, 999)),
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Text(
              "$qty",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: () => onChanged((qty + 1).clamp(1, 999)),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// Small helper (so we don’t need collection package)
extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
