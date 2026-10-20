import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';
import '../controllers/catalog_controller.dart';
import '../models/catalog_models.dart';
import '../widgets/cart_badge_icon.dart';
import 'product_details_screen.dart';
import 'cart_screen.dart';
import '../data/catalog_repo.dart';

class CatalogHomeScreen extends StatefulWidget {
  final CatalogController controller;
  final CatalogRepo repo;

  const CatalogHomeScreen({super.key, required this.controller, required this.repo});

  @override
  State<CatalogHomeScreen> createState() => _CatalogHomeScreenState();
}

class _CatalogHomeScreenState extends State<CatalogHomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(CatalogProduct p, String q) {
    if (q.isEmpty) return true;
    final name = p.name.toLowerCase();
    final desc = p.description.toLowerCase();
    final cat = p.category.toLowerCase();
    return name.contains(q) || desc.contains(q) || cat.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final q = _search.text.trim().toLowerCase();

        final products = c.filteredProducts.where((p) => _matches(p, q)).toList();

        return Scaffold(
      body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text("Catalog",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      ),
                      CartBadgeIcon(
                        count: c.cartCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CartScreen(controller: c, repo: widget.repo),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Search name, description, category…",
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: GPColors.tint.withOpacity(0.45),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: GPColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: GPColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: GPColors.line),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: c.categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final label = c.categories[i];
                        final selected = c.category == label;

                        return InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => c.setCategory(label),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? GPColors.primary.withOpacity(0.28) : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: selected ? GPColors.primary : GPColors.line),
                            ),
                            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: products.isEmpty
                        ? const _EmptyCatalog()
                        : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: products.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.74,
                      ),
                      itemBuilder: (_, i) => _ProductCard(
                        p: products[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailsScreen(
                              controller: c,
                              repo: widget.repo,
                              product: products[i],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: GPColors.tint.withOpacity(0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GPColors.line),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, size: 48),
            SizedBox(height: 10),
            Text("No products available", style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text("Admin has not added products yet.", style: TextStyle(color: GPColors.ink2)),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final CatalogProduct p;
  final VoidCallback onTap;

  const _ProductCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GPColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: GPColors.tint.withOpacity(0.55),
                  border: Border.all(color: GPColors.line),
                ),
                child: const Center(child: Icon(Icons.image_rounded, size: 36)),
              ),
            ),
            const SizedBox(height: 8),
            Text(p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text("₹ ${p.price.toStringAsFixed(0)}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const Spacer(),
            Text(p.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: GPColors.ink2, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
