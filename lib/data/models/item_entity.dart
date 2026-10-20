import '../../core/money.dart';

/// An item as returned by the server (money converted from paise to rupees).
class ItemEntity {
  int id = 0;

  // Basic
  String name = '';
  String sku = '';
  String category = '';
  String unit = 'pcs';
  String hsn = '';

  // Barcode (kept for compatibility, UI hidden)
  bool barcodeEnabled = false;
  String barcode = '';

  // Pricing & Tax
  double purchasePrice = 0;
  double sellingPrice = 0;
  bool priceInclusive = false;
  int gstRate = 0;
  bool gstEnabled = false;

  // Stock (always computed by the server from the stock ledger)
  bool stockEnabled = true;
  int stockQty = 0;
  int lowStockLevel = 0;
  String location = '';
  int stockInTotal = 0;
  int stockOutTotal = 0;

  int updatedAtMs = 0;

  String get nameLower => name.toLowerCase();
  String get skuLower => sku.toLowerCase();

  ItemEntity();

  factory ItemEntity.fromJson(Map<String, dynamic> j) {
    final e = ItemEntity();
    e.id = (j['id'] as num).toInt();
    e.name = (j['name'] ?? '') as String;
    e.sku = (j['sku'] ?? '') as String;
    e.category = (j['category'] ?? '') as String;
    e.unit = (j['unit'] ?? 'pcs') as String;
    e.hsn = (j['hsn'] ?? '') as String;
    e.barcode = (j['barcode'] ?? '') as String;
    e.barcodeEnabled = e.barcode.isNotEmpty;
    e.purchasePrice = toRupees((j['purchase_price'] ?? 0) as num);
    e.sellingPrice = toRupees((j['selling_price'] ?? 0) as num);
    e.priceInclusive = (j['price_inclusive'] ?? false) as bool;
    e.gstRate = ((j['gst_rate'] ?? 0) as num).round();
    e.gstEnabled = (j['gst_enabled'] ?? false) as bool;
    e.stockEnabled = (j['stock_enabled'] ?? true) as bool;
    e.stockQty = ((j['stock_qty'] ?? 0) as num).round();
    e.lowStockLevel = ((j['low_stock_level'] ?? 0) as num).round();
    e.location = (j['location'] ?? '') as String;
    e.stockInTotal = ((j['stock_in_total'] ?? 0) as num).round();
    e.stockOutTotal = ((j['stock_out_total'] ?? 0) as num).round();
    e.updatedAtMs = DateTime.tryParse('${j['updated_at']}')?.millisecondsSinceEpoch ?? 0;
    return e;
  }
}
