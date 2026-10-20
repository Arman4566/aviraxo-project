import 'package:flutter/material.dart';
import '../models/onboarding_data.dart';

import 'controllers/catalog_controller.dart';
import 'data/catalog_repo.dart';
import 'screens/catalog_home_screen.dart';

class CatalogScreen extends StatefulWidget {
  final OnboardingData data;
  const CatalogScreen({super.key, required this.data});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final CatalogController controller;
  final CatalogRepo repo = CatalogRepo();

  @override
  void initState() {
    super.initState();
    controller = CatalogController(
      isRetail: (widget.data.businessType ?? "").toLowerCase() == "retailer",
      gstEnabled: widget.data.gstRegistered == true,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: repo.watchProducts(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final products = snap.data ?? [];
        controller.setProducts(products);

        return CatalogHomeScreen(controller: controller, repo: repo);
      },
    );
  }
}
