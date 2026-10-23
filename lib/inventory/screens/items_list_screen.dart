import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import '../../widgets/glass.dart';
import '../../widgets/barcode_scanner_page.dart';
import '../../models/onboarding_data.dart';
import '../../theme/gp_colors.dart';
import '../models/inventory_item.dart';
import '../widgets/inventory_insights_strip.dart';
import '../widgets/item_list_tile.dart';
import '../widgets/inventory_filters_sheet.dart';

class ItemsListScreen extends StatelessWidget {
  final OnboardingData onboarding;
  final bool gstEnabled;
  final bool stockEnabled;

  final List<InventoryItem> items;
  final String search;
  final InventoryFilters filters;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<InventoryItem> onOpenItem;
  final VoidCallback onAddItem;
  final ValueChanged<InventoryItem> onEditItem;
  final ValueChanged<InventoryItem> onDeleteItem;
  final VoidCallback onFiltersChanged;

  const ItemsListScreen({
    super.key,
    required this.onboarding,
    required this.gstEnabled,
    required this.stockEnabled,
    required this.items,
    required this.search,
    required this.filters,
    required this.onSearchChanged,
    required this.onOpenItem,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onFiltersChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = stockEnabled ? "Items" : "Services";
    final filtered = _applyFilters(items);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                  IconButton(
                    onPressed: () => _openFilters(context),
                    icon: const Icon(Icons.filter_list_rounded),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GPColors.primary,
                        foregroundColor: GPColors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: onAddItem,
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, size: 18),
                          SizedBox(width: 6),
                          Text("Add", style: TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sticky Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _SearchBox(onChanged: onSearchChanged),
            ),

            // Insights strip (Phase-0 visual)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: InventoryInsightsStrip(
                items: items,
                stockEnabled: stockEnabled,
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(
                title: stockEnabled ? "No items added yet" : "No services added yet",
                cta: stockEnabled ? "Add your first item" : "Add your first service",
                onAdd: onAddItem,
              )
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  return ItemListTile(
                    item: item,
                    stockEnabled: stockEnabled,
                    onTap: () => onOpenItem(item),
                    onEdit: () => onEditItem(item),
                    onDelete: () => onDeleteItem(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InventoryItem> _applyFilters(List<InventoryItem> all) {
    final q = search.trim().toLowerCase();

    return all.where((it) {
      // Search
      if (q.isNotEmpty) {
        final ok = it.name.toLowerCase().contains(q) || it.sku.toLowerCase().contains(q) || it.barcode.contains(q);
        if (!ok) return false;
      }

      // Status filter (only if stock enabled)
      if (stockEnabled && filters.status != "All") {
        if (filters.status == "In" && it.stockStatus != "In") return false;
        if (filters.status == "Low" && it.stockStatus != "Low") return false;
        if (filters.status == "Out" && it.stockStatus != "Out") return false;
      }

      // Category
      if (filters.category != "All" && it.category != filters.category) return false;

      // GST filter
      if (filters.gst != "All") {
        if (filters.gst == "GST" && it.gstEnabled != true) return false;
        if (filters.gst == "Non-GST" && it.gstEnabled == true) return false;
      }

      // Price range
      final sp = it.sellingPrice;
      if (sp < filters.priceRange.start || sp > filters.priceRange.end) return false;

      return true;
    }).toList();
  }

  void _openFilters(BuildContext context) async {
    final updated = await showGlassSheet<InventoryFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InventoryFiltersSheet(
        stockEnabled: stockEnabled,
        gstEnabled: gstEnabled,
        items: items,
        initial: filters.copy(),
      ),);

    if (updated != null) {
      filters.status = updated.status;
      filters.category = updated.category;
      filters.gst = updated.gst;
      filters.priceRange = updated.priceRange;
      onFiltersChanged();
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String cta;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.title,
    required this.cta,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GPColors.tint.withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GPColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_rounded, size: 44),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text("Start by adding your first entry.", style: TextStyle(color: GPColors.ink2)),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GPColors.primary,
                  foregroundColor: GPColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onAdd,
                child: Text(cta, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            )
          ],
        ),
      ),
    );
  }
}


/// Search field with a barcode scan button. Scanning fills the field, which filters the list to that item.
class _SearchBox extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _SearchBox({required this.onChanged});

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: trs("Search items (name / SKU / barcode)"),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: trs("Scan barcode"),
          icon: const Icon(Icons.qr_code_scanner_rounded),
          onPressed: () async {
            final code = await scanBarcode(context);
            if (code == null) return;
            _c.text = code;
            widget.onChanged(code);
          },
        ),
      ),
    );
  }
}
