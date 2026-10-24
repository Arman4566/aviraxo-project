import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/gp_colors.dart';
import '../controllers/catalog_controller.dart';

class OrderSuccessScreen extends StatelessWidget {
  final CatalogController controller;
  final String orderId;
  final String buyerPhone;
  final String buyerAddress;
  final String sellerPhone;

  const OrderSuccessScreen({
    super.key,
    required this.controller,
    required this.orderId,
    required this.buyerPhone,
    required this.buyerAddress,
    required this.sellerPhone,
  });

  String _buildMessage() {
    final items = controller.cartLines
        .map((l) => "- ${l.product.name} x${l.qty} = ₹${l.lineTotal.toStringAsFixed(0)}")
        .join("\n");

    return "New Order (Galla Pro)\n"
        "Order ID: $orderId\n"
        "Buyer: $buyerPhone\n"
        "Address: $buyerAddress\n\n"
        "Items:\n$items\n\n"
        "Total: ₹${controller.total.toStringAsFixed(0)}";
  }

  Future<void> _sendWhatsApp(BuildContext context) async {
    final phone = sellerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent(_buildMessage());
    final uri = Uri.parse("https://wa.me/$phone?text=$text");

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open WhatsApp.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: GPColors.tint,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GPColors.line),
                ),
                child: const Icon(Icons.check_circle_rounded, size: 52),
              ),
              const SizedBox(height: 14),
              const Text("Order placed successfully",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              Text("Order ID: $orderId", style: TextStyle(color: GPColors.ink2)),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GPColors.primary,
                    foregroundColor: GPColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _sendWhatsApp(context),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text("Send on WhatsApp", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: GPColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    controller.clearCart();
                    Navigator.pop(context);
                  },
                  child: const Text("Create New Order", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  controller.clearCart();
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
                child: const Text("Go to Dashboard", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
