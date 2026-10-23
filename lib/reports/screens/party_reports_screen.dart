import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../../data/repositories/party_repo.dart';
import '../../data/models/party_entity.dart';
import '../widgets/chart_card.dart';
import '../../widgets/charts.dart';
import '../widgets/preview_list_tile.dart';

class PartyReportsScreen extends StatelessWidget {
  final DateTimeRange range; // reserved for future party statement range
  const PartyReportsScreen({super.key, required this.range});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Party Reports", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: GPColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<_PartyData>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(child: _sum("Customers", "${d.customers}")),
                  const SizedBox(width: 10),
                  Expanded(child: _sum("Suppliers", "${d.suppliers}")),
                ],
              ),
              const SizedBox(height: 14),

              ChartCard(
                title: "Dues Snapshot",
                subtitle: "Who owes you the most",
                child: RankBars(
                  emptyText: "No dues. Everyone has paid.",
                  color: GPColors.danger,
                  rows: [
                    for (final p in d.topDues.where((p) => p.toReceive && p.balance > 0).take(6))
                      (label: p.name, value: p.balance * 100, sub: null),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              const Text("Top Parties with Dues", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),

              if (d.topDues.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: GPColors.tint.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: Text("No dues found.", style: TextStyle(color: GPColors.ink2)),
                )
              else
                ...d.topDues.take(5).map((p) {
                  final due = p.balance;
                  final isDue = p.toReceive && due > 0;
                  final label = isDue ? "Due" : "Advance";
                  return PreviewListTile(
                    icon: Icons.person_rounded,
                    title: p.name,
                    subtitle: label,
                    trailing: "₹${due.toStringAsFixed(0)}",
                  );
                }),

              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: GPColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Party statements screen can be added next.")),
                    );
                  },
                  child: const Text("View Party Statements", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Future<_PartyData> _load() async {
    final repo = PartyRepo();
    await repo.refresh();
    final parties = await repo.watchAll().first;

    int customers = 0;
    int suppliers = 0;

    // count based on stored "type" string (customer/supplier/both)
    for (final p in parties) {
      final t = p.type.toLowerCase();
      if (t == "customer") customers++;
      else if (t == "supplier") suppliers++;
      else if (t == "both") {
        customers++;
        suppliers++;
      }
    }

    final dues = parties.where((p) => p.balance > 0).toList();
    dues.sort((a, b) => b.balance.compareTo(a.balance));

    return _PartyData(
      customers: customers,
      suppliers: suppliers,
      topDues: dues,
    );
  }
}

class _PartyData {
  final int customers;
  final int suppliers;
  final List<PartyEntity> topDues;

  _PartyData({
    required this.customers,
    required this.suppliers,
    required this.topDues,
  });
}

class _sum extends StatelessWidget {
  final String label;
  final String value;
  const _sum(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GPColors.tint.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
