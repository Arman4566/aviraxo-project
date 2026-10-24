import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../controllers/catalog_controller.dart';
import '../widgets/qty_stepper.dart';
import 'order_review_screen.dart';
import '../data/catalog_repo.dart';

class CartScreen extends StatelessWidget {
  final CatalogController controller;
  final CatalogRepo repo;
  final bool autoProceed;

  const CartScreen({
    super.key,
    required this.controller,
    required this.repo,
    this.autoProceed = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final lines = controller.cartLines;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (autoProceed && lines.isNotEmpty && ModalRoute.of(context)?.isCurrent == true) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderReviewScreen(controller: controller, repo: repo)),
            );
          }
        });

        return Scaffold(
      appBar: AppBar(
            title: const Text("Cart", style: TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: GPColors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          body: lines.isEmpty
              ? Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: GPColors.tint,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: GPColors.line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 46),
                  SizedBox(height: 10),
                  Text("Your cart is empty", style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text("Add items from Catalog to place order.", style: TextStyle(color: GPColors.ink2)),
                ],
              ),
            ),
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
            children: [
              for (final line in lines)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GPColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: GPColors.tint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GPColors.line),
                        ),
                        child: const Icon(Icons.image_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text("₹ ${line.lineTotal.toStringAsFixed(0)}",
                                style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          QtyStepper(
                            value: line.qty,
                            min: 1,
                            max: 99,
                            onChanged: (v) => controller.setQty(line.product.id, v),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => controller.remove(line.product.id),
                            child: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              _Summary(controller: controller),
            ],
          ),
          bottomSheet: lines.isEmpty
              ? null
              : Container(
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderReviewScreen(controller: controller, repo: repo)),
                  );
                },
                child: const Text("Proceed to Order", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final CatalogController controller;
  const _Summary({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GPColors.tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Column(
        children: [
          _row("Subtotal", "₹ ${controller.subtotal.toStringAsFixed(0)}"),
          _row("Discount", "₹ ${controller.discount.toStringAsFixed(0)}"),
          _row("Tax", "₹ ${controller.tax.toStringAsFixed(0)}"),
          const Divider(),
          _row("Grand Total", "₹ ${controller.total.toStringAsFixed(0)}", bold: true),
        ],
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
