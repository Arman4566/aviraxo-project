import 'package:flutter/material.dart';

class InventoryItem {
  final int id; // Isar Id

  // Basic
  String name;
  String sku;
  String category;
  String unit;

  // Barcode (kept for DB compatibility; UI hidden)
  bool barcodeEnabled;
  String barcode;

  // Pricing & Tax
  double purchasePrice;
  double sellingPrice;
  bool priceInclusive;
  int gstRate;
  bool gstEnabled;

  // Stock
  bool stockEnabled;
  int stockQty;
  int lowStockLevel;
  String location;

  // Stock movement counters (for future invoice integration)
  int stockInTotal;  // total purchased/added
  int stockOutTotal; // total sold/removed (later from invoices)

  DateTime updatedAt;

  InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.unit,
    required this.barcodeEnabled,
    required this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.priceInclusive,
    required this.gstRate,
    required this.gstEnabled,
    required this.stockEnabled,
    required this.stockQty,
    required this.lowStockLevel,
    required this.location,
    required this.stockInTotal,
    required this.stockOutTotal,
    required this.updatedAt,
  });

  InventoryItem copy() => InventoryItem(
    id: id,
    name: name,
    sku: sku,
    category: category,
    unit: unit,
    barcodeEnabled: barcodeEnabled,
    barcode: barcode,
    purchasePrice: purchasePrice,
    sellingPrice: sellingPrice,
    priceInclusive: priceInclusive,
    gstRate: gstRate,
    gstEnabled: gstEnabled,
    stockEnabled: stockEnabled,
    stockQty: stockQty,
    lowStockLevel: lowStockLevel,
    location: location,
    stockInTotal: stockInTotal,
    stockOutTotal: stockOutTotal,
    updatedAt: updatedAt,
  );

  String get stockStatus {
    if (!stockEnabled) return "N/A";
    if (stockQty <= 0) return "Out";
    if (stockQty <= lowStockLevel) return "Low";
    return "In";
  }

  static String genSku(String name) {
    final base = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(3)
        .map((w) => w.substring(0, w.length.clamp(1, 3)))
        .join();
    return base.isEmpty ? "ITEM" : base;
  }
}

class InventoryFilters {
  String status = "All";
  String category = "All";
  String gst = "All";
  RangeValues priceRange = const RangeValues(0, 5000);

  InventoryFilters copy() {
    final f = InventoryFilters();
    f.status = status;
    f.category = category;
    f.gst = gst;
    f.priceRange = priceRange;
    return f;
  }
}
