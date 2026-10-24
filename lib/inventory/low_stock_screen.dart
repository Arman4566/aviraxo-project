import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';

import '../data/repositories/extras_repo.dart';
import '../l10n/strings.dart';
import '../theme/gp_colors.dart';

/// Items that are out of stock or below their alert level, with a suggested reorder quantity.
class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key});
  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  late Future<Map<String, dynamic>> _future = ExtrasRepo().lowStock();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('low_stock'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return Center(child: TextButton(onPressed: () => setState(() { _future = ExtrasRepo().lowStock(); }), child: Text('${snap.error}. ${tr('retry')}')));
          }
          final d = snap.data!;
          final alerts = List<Map<String, dynamic>>.from(d['alerts'] as List);
          if (alerts.isEmpty) return const Center(child: Text('All items are well stocked.'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('${d['out_of_stock']} ${tr('out_of_stock').toLowerCase()} · ${d['low']} running low', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final a in alerts)
              Card(
                child: ListTile(
                  leading: Icon(a['status'] == 'out' ? Icons.error : Icons.warning_amber_rounded, color: a['status'] == 'out' ? GPColors.danger : GPColors.warning),
                  title: Text('${a['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('In stock: ${a['stock_qty']}  ·  sold in 30 days: ${a['sold_30d']}'
                      '${a['days_of_cover'] != null ? '  ·  lasts ~${a['days_of_cover']} days' : ''}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Reorder', style: TextStyle(fontSize: 11)),
                    Text('${a['suggested_reorder']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
