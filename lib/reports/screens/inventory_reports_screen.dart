import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../../data/repositories/inventory_repo.dart';
import '../../data/models/item_entity.dart';
import '../widgets/chart_card.dart';
import '../../widgets/charts.dart';
import '../widgets/preview_list_tile.dart';

class InventoryReportsScreen extends StatelessWidget {
  final DateTimeRange range; // kept for future trend charts (currently counts are all-time)
  const InventoryReportsScreen({super.key, required this.range});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory Reports", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: GPColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<_InvData>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;

          final metrics = [
            _Metric("Total Items", "${d.total}", "all items", Icons.list_alt_rounded),
            _Metric("In Stock", "${d.inStock}", "available", Icons.check_circle_rounded),
            _Metric("Low Stock", "${d.low}", "needs restock", Icons.warning_amber_rounded),
            _Metric("Out of Stock", "${d.out}", "urgent", Icons.cancel_rounded),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              _MetricStrip(metrics: metrics),
              const SizedBox(height: 14),
              ChartCard(
                title: "Stock Status",
                subtitle: "${d.total} items",
                child: d.total == 0
                    ? Text("Add items to see your stock split.", style: TextStyle(color: GPColors.ink2))
                    : DonutChart(
                        centerValue: "${d.total}",
                        centerLabel: "items",
                        slices: [
                          DonutSlice("In stock", d.inStock, GPColors.success),
                          DonutSlice("Low stock", d.low, GPColors.warning),
                          DonutSlice("Out of stock", d.out, GPColors.danger),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              const Text("Low Stock Items", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),

              if (d.lowItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: GPColors.tint,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: Text("No low stock items right now.", style: TextStyle(color: GPColors.ink2)),
                )
              else
                ...d.lowItems.take(5).map((it) {
                  final stock = "${it.stockQty} ${it.unit}";
                  return PreviewListTile(
                    icon: Icons.inventory_2_rounded,
                    title: it.name,
                    subtitle: "Stock: $stock • Low",
                    trailing: "⚠️",
                  );
                }),

              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GPColors.primary,
                    foregroundColor: GPColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Go to Inventory", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_InvData> _load() async {
    final items = await InventoryRepo().getAll();

    int total = items.length;
    int inStock = 0;
    int low = 0;
    int out = 0;

    final lowItems = <ItemEntity>[];

    for (final it in items) {
      // stockEnabled false => treat as in-stock (service)
      final stockEnabled = it.stockEnabled;
      if (!stockEnabled) {
        inStock++;
        continue;
      }

      if (it.stockQty <= 0) {
        out++;
      } else if (it.stockQty <= it.lowStockLevel) {
        low++;
        lowItems.add(it);
      } else {
        inStock++;
      }
    }

    // sort low items by qty asc
    lowItems.sort((a, b) => a.stockQty.compareTo(b.stockQty));

    return _InvData(
      total: total,
      inStock: inStock,
      low: low,
      out: out,
      lowItems: lowItems,
    );
  }
}

class _InvData {
  final int total;
  final int inStock;
  final int low;
  final int out;
  final List<ItemEntity> lowItems;

  _InvData({
    required this.total,
    required this.inStock,
    required this.low,
    required this.out,
    required this.lowItems,
  });
}

class _Metric {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  const _Metric(this.label, this.value, this.sub, this.icon);
}

class _MetricStrip extends StatelessWidget {
  final List<_Metric> metrics;
  const _MetricStrip({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metrics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final m = metrics[i];
          return Container(
            width: 190,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: GPColors.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(m.icon, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w800))),
                ]),
                const Spacer(),
                Text(m.value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 4),
                Text(m.sub, style: TextStyle(color: GPColors.ink2)),
              ],
            ),
          );
        },
      ),
    );
  }
}
