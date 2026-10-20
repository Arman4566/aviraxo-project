import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/catalog_models.dart';

class CatalogRepo {
  final FirebaseFirestore _db;
  CatalogRepo({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<CatalogProduct>> watchProducts() {
    return _db
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CatalogProduct.fromDoc(d)).toList());
  }

  Future<String> placeOrder({
    required String buyerPhone,
    required String buyerAddress,
    required String sellerPhone,
    required List<CartLine> lines,
    required double subtotal,
    required double total,
  }) async {
    final ref = await _db.collection('orders').add({
      'buyerPhone': buyerPhone,
      'buyerAddress': buyerAddress,
      'sellerPhone': sellerPhone,
      'status': 'placed',
      'subtotal': subtotal,
      'total': total,
      'createdAt': FieldValue.serverTimestamp(),
      'lines': lines.map((l) => l.toMap()).toList(),
    });
    return ref.id;
  }
}
