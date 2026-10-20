import '../../core/api_client.dart';
import '../../core/money.dart';
import '../models/item_entity.dart';
import '../../inventory/models/inventory_item.dart';
import 'cached_list.dart';

/// Items live on the server. Stock numbers are computed there from the stock ledger.
class InventoryRepo {
  static final CachedList<ItemEntity> _cache = CachedList<ItemEntity>(() async {
    final r = await ApiClient.I.get('/items');
    return (r['items'] as List).map((j) => ItemEntity.fromJson(j as Map<String, dynamic>)).toList();
  });

  /// Forget everything (on sign out / account switch).
  static void reset() => _cache.clear();

  Stream<List<ItemEntity>> watchAll() => _cache.watch();

  Future<void> refresh() => _cache.refresh();

  Future<List<ItemEntity>> getAll() async {
    await _cache.refresh();
    return _cache.latest ?? [];
  }

  Future<ItemEntity?> getById(int id) async {
    try {
      final r = await ApiClient.I.get('/items/$id');
      return ItemEntity.fromJson(r['item'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Map<String, dynamic> _body(InventoryItem m) => {
        'name': m.name.trim(),
        'sku': m.sku.trim(),
        'barcode': m.barcode.trim(),
        'category': m.category.trim(),
        'unit': m.unit.trim().isEmpty ? 'pcs' : m.unit.trim(),
        'purchase_price': toPaise(m.purchasePrice),
        'selling_price': toPaise(m.sellingPrice),
        'price_inclusive': m.priceInclusive,
        'gst_rate': m.gstRate,
        'gst_enabled': m.gstEnabled,
        'stock_enabled': m.stockEnabled,
        'stock_qty': m.stockQty,
        'low_stock_level': m.lowStockLevel,
        'location': m.location.trim(),
      };

  /// Creates (id == 0) or updates an item. When editing, `stockQty` is the new absolute stock.
  Future<int> upsert(InventoryItem m) async {
    final Map<String, dynamic> r = m.id == 0
        ? await ApiClient.I.post('/items', _body(m))
        : await ApiClient.I.put('/items/${m.id}', _body(m));
    await _cache.refresh();
    return (r['item']['id'] as num).toInt();
  }

  Future<void> delete(int id) async {
    await ApiClient.I.delete('/items/$id');
    await _cache.refresh();
  }

  Future<void> applyPurchaseEntry({
    required int id,
    required int addQty,
    required double purchasePrice,
    required double sellingPrice,
  }) async {
    if (addQty <= 0) return;
    await ApiClient.I.post('/items/$id/purchase-entry', {
      'qty': addQty,
      if (purchasePrice >= 0) 'purchase_price': toPaise(purchasePrice),
      if (sellingPrice >= 0) 'selling_price': toPaise(sellingPrice),
    });
    await _cache.refresh();
  }

  /// Add (+) or remove (-) stock with a reason, e.g. damaged goods or a count correction.
  Future<void> adjustStock({required int id, required int qtyChange, String reason = 'correction', String note = ''}) async {
    await ApiClient.I.post('/items/$id/adjust', {'qty_change': qtyChange, 'reason': reason, 'note': note});
    await _cache.refresh();
  }

  /// Sales reduce stock on the server when the invoice is saved - nothing to do here.
  /// Kept so older call sites keep compiling; it only refreshes the list.
  Future<void> applySale({required int id, required int qty}) => _cache.refresh();

  InventoryItem toModel(ItemEntity e) {
    return InventoryItem(
      id: e.id,
      name: e.name,
      sku: e.sku,
      category: e.category,
      unit: e.unit,
      barcodeEnabled: e.barcodeEnabled,
      barcode: e.barcode,
      purchasePrice: e.purchasePrice,
      sellingPrice: e.sellingPrice,
      priceInclusive: e.priceInclusive,
      gstRate: e.gstRate,
      gstEnabled: e.gstEnabled,
      stockEnabled: e.stockEnabled,
      stockQty: e.stockQty,
      lowStockLevel: e.lowStockLevel,
      location: e.location,
      stockInTotal: e.stockInTotal,
      stockOutTotal: e.stockOutTotal,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(e.updatedAtMs),
    );
  }
}
