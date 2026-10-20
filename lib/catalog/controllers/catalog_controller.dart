import 'package:flutter/foundation.dart';
import '../models/catalog_models.dart';

class CatalogController extends ChangeNotifier {
  final bool isRetail;
  final bool gstEnabled;

  CatalogController({
    required this.isRetail,
    required this.gstEnabled,
  });

  // Live products set by stream
  List<CatalogProduct> _products = [];
  List<CatalogProduct> get products => _products;

  void setProducts(List<CatalogProduct> list) {
    _products = list;
    notifyListeners();
  }

  // Categories
  String _category = "All";
  String get category => _category;

  void setCategory(String c) {
    _category = c;
    notifyListeners();
  }

  // Single seller cart lock
  final Map<String, CartLine> _cart = {};
  String? _sellerPhone;

  String? get sellerPhone => _sellerPhone;

  List<CartLine> get cartLines => _cart.values.toList();
  int get cartCount => _cart.values.fold<int>(0, (sum, l) => sum + l.qty);

  /// returns false if blocked by multi-seller rule
  bool addToCart(CatalogProduct p, int qty) {
    if (qty <= 0) return false;

    if (_sellerPhone != null && _sellerPhone != p.sellerPhone) {
      return false;
    }

    _sellerPhone ??= p.sellerPhone;

    final existing = _cart[p.id];
    if (existing == null) {
      _cart[p.id] = CartLine(product: p, qty: qty);
    } else {
      existing.qty += qty;
    }
    notifyListeners();
    return true;
  }

  void setQty(String productId, int qty) {
    final line = _cart[productId];
    if (line == null) return;

    if (qty <= 0) {
      _cart.remove(productId);
      if (_cart.isEmpty) _sellerPhone = null;
    } else {
      line.qty = qty;
    }
    notifyListeners();
  }

  void remove(String productId) {
    _cart.remove(productId);
    if (_cart.isEmpty) _sellerPhone = null;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _sellerPhone = null;
    notifyListeners();
  }

  double get subtotal => _cart.values.fold<double>(0, (sum, l) => sum + l.lineTotal);
  double get discount => 0;
  double get tax => gstEnabled ? 0.0 : 0.0;
  double get total => subtotal - discount + tax;

  List<CatalogProduct> get filteredProducts {
    if (_category == "All") return _products;
    return _products.where((p) => p.category == _category).toList();
  }

  List<String> get categories {
    final set = <String>{};
    for (final p in _products) {
      final c = p.category.trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return ["All", ...list];
  }
}
