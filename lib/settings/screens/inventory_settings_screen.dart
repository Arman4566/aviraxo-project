import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../models/onboarding_data.dart';
import '../../theme/gp_colors.dart';
import '../../data/repositories/app_settings_repo.dart';

class InventorySettingsScreen extends StatefulWidget {
  final OnboardingData data;
  const InventorySettingsScreen({super.key, required this.data});

  @override
  State<InventorySettingsScreen> createState() => _InventorySettingsScreenState();
}

class _InventorySettingsScreenState extends State<InventorySettingsScreen> {
  final _repo = AppSettingsRepo.I;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _repo.watchSettings(),
      builder: (context, snap) {
        final s = snap.data;
        final d = s?.draft;

        final trackInventory = d?.trackInventory ?? true;
        final lowAlerts = d?.lowStockAlerts ?? true;
        final barcode = d?.barcodeUsage ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Inventory Settings", style: TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: GPColors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Stock Tracking", style: TextStyle(fontWeight: FontWeight.w900)),
              SwitchListTile(
                value: trackInventory,
                onChanged: (v) => _repo.setTrackInventory(v),
                title: const Text("Enable stock tracking"),
              ),
              SwitchListTile(
                value: lowAlerts,
                onChanged: (v) => _repo.setLowStockAlerts(v),
                title: const Text("Low stock alerts"),
              ),
              SwitchListTile(
                value: s?.allowNegativeStock ?? false,
                onChanged: (v) => _repo.update((x) => x.allowNegativeStock = v),
                title: const Text("Allow selling more than in stock"),
                subtitle: const Text("Off: the server blocks a bill when stock is short"),
              ),

              const Divider(),

              const Text("Item Defaults", style: TextStyle(fontWeight: FontWeight.w900)),
              _dropdown("Default unit", ["pcs", "kg", "box", "litre"], "pcs"),
              _dropdown("Default tax slab", ["0%", "5%", "12%", "18%", "28%"], "18%"),
              SwitchListTile(
                value: barcode,
                onChanged: (v) => _repo.setBarcodeUsage(v),
                title: const Text("Enable barcode support"),
              ),

              const SizedBox(height: 10),
              Text(
                "Some options are auto-configured based on onboarding",
                style: TextStyle(color: GPColors.ink2),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dropdown(String label, List<String> items, String value) {
    return DropdownButtonFormField(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (_) {},
      decoration: InputDecoration(labelText: label),
    );
  }
}
