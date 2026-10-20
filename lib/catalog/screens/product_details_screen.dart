import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';
import '../controllers/catalog_controller.dart';
import '../models/catalog_models.dart';
import '../widgets/cart_badge_icon.dart';
import '../widgets/qty_stepper.dart';
import 'cart_screen.dart';
import '../data/catalog_repo.dart';

class ProductDetailsScreen extends StatefulWidget {
  final CatalogController controller;
  final CatalogRepo repo;
  final CatalogProduct product;

  const ProductDetailsScreen({
    super.key,
    required this.controller,
    required this.repo,
    required this.product,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final p = widget.product;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Scaffold(
      body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Spacer(),
                      CartBadgeIcon(
                        count: c.cartCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CartScreen(controller: c, repo: widget.repo)),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    itemCount: p.demoImageColors.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: p.demoImageColors[i].withOpacity(0.9),
                          border: Border.all(color: GPColors.line),
                        ),
                        child: const Center(child: Icon(Icons.image_rounded, size: 56)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      const SizedBox(height: 8),
                      Text(
                        "₹ ${p.price.toStringAsFixed(0)}  •  ${p.category}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(p.description, style: const TextStyle(color: GPColors.ink2)),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: GPColors.tint.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: GPColors.line),
                        ),
                        child: Row(
                          children: [
                            const Text("Quantity", style: TextStyle(fontWeight: FontWeight.w900)),
                            const Spacer(),
                            QtyStepper(
                              value: qty,
                              min: 1,
                              max: 99,
                              onChanged: (v) => setState(() => qty = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: GPColors.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GPColors.onPrimary,
                            side: const BorderSide(color: GPColors.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            final ok = c.addToCart(p, qty);
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("You can order from only one seller at a time.")),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Added to cart")),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart_outlined),
                          label: const Text("Add to Cart", style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GPColors.primary,
                            foregroundColor: GPColors.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            final ok = c.addToCart(p, qty);
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("You can order from only one seller at a time.")),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CartScreen(controller: c, repo: widget.repo, autoProceed: true),
                              ),
                            );
                          },
                          icon: const Icon(Icons.flash_on_rounded),
                          label: const Text("Buy Now", style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
