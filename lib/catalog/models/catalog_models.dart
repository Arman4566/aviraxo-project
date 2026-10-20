import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CatalogProduct {
  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final String sellerPhone;
  final bool isActive;

  // Phase-0: no image upload, show placeholder colors
  final List<Color> demoImageColors;

  const CatalogProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.sellerPhone,
    required this.isActive,
    this.demoImageColors = const [Color(0xFFFFF9C4), Color(0xFFFFD7C7)],
  });

  factory CatalogProduct.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CatalogProduct(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? 'More').toString(),
      description: (data['description'] ?? '').toString(),
      price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
      sellerPhone: (data['sellerPhone'] ?? '').toString(),
      isActive: (data['isActive'] ?? true) == true,
      demoImageColors: const [Color(0xFFFFF9C4), Color(0xFFFFE0B2)],
    );
  }
}

class CartLine {
  final CatalogProduct product;
  int qty;

  CartLine({required this.product, required this.qty});

  double get lineTotal => qty * product.price;

  Map<String, dynamic> toMap() => {
    'productId': product.id,
    'name': product.name,
    'price': product.price,
    'qty': qty,
    'lineTotal': lineTotal,
  };
}
