import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';
import '../core/messenger.dart';
import '../models/onboarding_data.dart';

import '../data/repositories/inventory_repo.dart';
import '../data/models/item_entity.dart';

import 'models/inventory_item.dart';
import 'screens/items_list_screen.dart';
import 'screens/item_detail_screen.dart';
import 'screens/add_edit_item_flow.dart';
import 'screens/purchase_entry_flow.dart';
import 'widgets/adjust_stock_dialog.dart';

class InventoryScreen extends StatefulWidget {
  final OnboardingData data;
  const InventoryScreen({super.key, required this.data});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryRepo _repo = InventoryRepo();

  final InventoryFilters _filters = InventoryFilters();
  String _search = "";

  bool get _gstEnabled => widget.data.gstRegistered == true;
  bool get _isServices =>
      (widget.data.businessType ?? "").toLowerCase() == "services";

  /// Runs a repo call and shows server errors (e.g. "not enough stock") instead of failing silently.
  Future<bool> _try(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      AppMessenger.error(e);
      return false;
    }
  }

  Future<void> _openAdd() async {
    final created = await Navigator.push<InventoryItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemFlow(
          gstEnabled: _gstEnabled,
          stockEnabled: !_isServices,
          initial: null,
        ),
      ),
    );

    if (created != null) {
      await _try(() async {
        await _repo.upsert(created);
      });
    }
  }

  Future<bool> _openEdit(InventoryItem item) async {
    final updated = await Navigator.push<InventoryItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemFlow(
          gstEnabled: _gstEnabled,
          stockEnabled: !_isServices,
          initial: item.copy(),
        ),
      ),
    );

    if (updated == null) return false;
    return _try(() async {
      await _repo.upsert(updated);
    });
  }

  Future<bool> _openPurchaseEntry(InventoryItem item) async {
    final entry = await Navigator.push<PurchaseEntryResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseEntryFlow(
          item: item,
          stockEnabled: !_isServices,
        ),
      ),
    );

    if (entry == null) return false;
    return _try(() => _repo.applyPurchaseEntry(
          id: item.id,
          addQty: entry.purchasedQty,
          purchasePrice: entry.purchasePrice,
          sellingPrice: entry.sellingPrice,
        ));
  }

  Future<bool> _adjustStock(InventoryItem item) async {
    final a = await showAdjustStockDialog(context,
        itemName: item.name, unit: item.unit, current: item.stockQty);
    if (a == null) return false;
    return _try(() => _repo.adjustStock(id: item.id, qtyChange: a.qtyChange, reason: a.reason, note: a.note));
  }

  /// The detail page shows a snapshot, so close it after a change and the refreshed list shows the result.
  Future<void> _thenClose(Future<bool> Function() action) async {
    final changed = await action();
    if (changed && mounted) Navigator.pop(context);
  }

  Future<void> _openDetails(InventoryItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          item: item,
          onEdit: () => _thenClose(() => _openEdit(item)),
          onDelete: () => _thenClose(() => _deleteItemWithConfirm(item)),
          onPurchaseEntry: () => _thenClose(() => _openPurchaseEntry(item)),
          onAdjustStock: () => _thenClose(() => _adjustStock(item)),
        ),
      ),
    );
  }

  Future<bool> _deleteItemWithConfirm(InventoryItem item) async {
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

    if (ok != true) return false;
    final done = await _try(() => _repo.delete(item.id));
    if (done) AppMessenger.info("${item.name} deleted");
    return done;
  }

  Future<void> _deleteItemFast(InventoryItem item) async {
    if (await _try(() => _repo.delete(item.id))) {
      AppMessenger.info("${item.name} deleted");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ItemEntity>>(
      stream: _repo.watchAll(),
      builder: (context, snap) {
        final entities = snap.data ?? [];
        final items = entities.map(_repo.toModel).toList();

        return ItemsListScreen(
          onboarding: widget.data,
          gstEnabled: _gstEnabled,
          stockEnabled: !_isServices,
          items: items,
          search: _search,
          filters: _filters,
          onSearchChanged: (v) => setState(() => _search = v),
          onOpenItem: _openDetails,
          onAddItem: _openAdd,
          onEditItem: (it) => _openEdit(it),
          onDeleteItem: (it) => _deleteItemFast(it),
          onFiltersChanged: () => setState(() {}),
        );
      },
    );
  }
}
