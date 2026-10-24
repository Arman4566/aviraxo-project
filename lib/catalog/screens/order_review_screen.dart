import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/gp_colors.dart';
import '../controllers/catalog_controller.dart';
import 'order_success_screen.dart';
import '../data/catalog_repo.dart';

class OrderReviewScreen extends StatefulWidget {
  final CatalogController controller;
  final CatalogRepo repo;

  const OrderReviewScreen({super.key, required this.controller, required this.repo});

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('buyer_phone') ?? '';
    final savedAddress = prefs.getString('buyer_address') ?? '';
    if (!mounted) return;
    _phone.text = savedPhone;
    _address.text = savedAddress;
  }

  Future<void> _savePhone(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('buyer_phone', value);
  }

  Future<void> _saveAddress(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('buyer_address', value);
  }

  String _normalizePhone(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  bool _isValidPhone10(String raw) {
    final x = _normalizePhone(raw);
    return RegExp(r'^\d{10}$').hasMatch(x);
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Review", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: GPColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
        children: [
          const Text("Selected Products", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          for (final l in c.cartLines)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: GPColors.line),
                color: GPColors.surface,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text("${l.product.name}  •  Qty ${l.qty}",
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Text("₹ ${l.lineTotal.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),

          const SizedBox(height: 10),
          const Text("Your Contact Details", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.tint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: trs("Phone number (10 digits, saved)"),
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.tint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: TextField(
              controller: _address,
              keyboardType: TextInputType.streetAddress,
              maxLines: 3,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: trs("Delivery address (saved)"),
                prefixIcon: Icon(Icons.location_on_rounded),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.tint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: Column(
              children: [
                _row("Subtotal", "₹ ${c.subtotal.toStringAsFixed(0)}"),
                _row("Discount", "₹ ${c.discount.toStringAsFixed(0)}"),
                _row("Tax", "₹ ${c.tax.toStringAsFixed(0)}"),
                const Divider(),
                _row("Grand Total", "₹ ${c.total.toStringAsFixed(0)}", bold: true),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: GPColors.surface,
          border: Border(top: BorderSide(color: GPColors.line)),
        ),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GPColors.primary,
              foregroundColor: GPColors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _loading
                ? null
                : () async {
              final rawPhone = _phone.text.trim();
              final rawAddress = _address.text.trim();

              if (!_isValidPhone10(rawPhone)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter a valid 10-digit phone number.")),
                );
                return;
              }
              if (rawAddress.isEmpty || rawAddress.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid address.")),
                );
                return;
              }

              final buyerPhone = _normalizePhone(rawPhone);
              final buyerAddress = rawAddress;
              final sellerPhone = c.sellerPhone ?? "";

              if (sellerPhone.isEmpty || c.cartLines.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cart is empty.")),
                );
                return;
              }

              setState(() => _loading = true);
              try {
                await _savePhone(buyerPhone);
                await _saveAddress(buyerAddress);

                final orderId = await widget.repo.placeOrder(
                  buyerPhone: buyerPhone,
                  buyerAddress: buyerAddress,
                  sellerPhone: sellerPhone,
                  lines: c.cartLines,
                  subtotal: c.subtotal,
                  total: c.total,
                );

                if (!mounted) return;

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderSuccessScreen(
                      controller: c,
                      orderId: orderId,
                      buyerPhone: buyerPhone,
                      buyerAddress: buyerAddress,
                      sellerPhone: sellerPhone,
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to place order: $e")),
                );
                setState(() => _loading = false);
              }
            },
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Place Order", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w800);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(a, style: style)),
          Text(b, style: style),
        ],
      ),
    );
  }
}
