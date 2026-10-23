import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';

import '../core/money.dart';
import '../data/repositories/extras_repo.dart';
import '../l10n/strings.dart';
import '../theme/gp_colors.dart';

/// Plain-language cards about the business plus a 4-week cash forecast. All numbers come from the owner's own data.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final _repo = ExtrasRepo();
  late Future<List<Map<String, dynamic>>> _future = Future.wait([_repo.insights(), _repo.forecast()]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('insights'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return Center(child: TextButton(onPressed: () => setState(() => _future = Future.wait([_repo.insights(), _repo.forecast()])), child: Text('${snap.error}. ${tr('retry')}')));
          }
          final cards = List<Map<String, dynamic>>.from(snap.data![0]['insights'] as List);
          final f = snap.data![1];
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${tr('cash_forecast')} (${f['days']} days)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _kv('Expected in', inr(f['expected_in'] as num), GPColors.success)),
                    Expanded(child: _kv('Expected out', inr(f['expected_out'] as num), GPColors.danger)),
                    Expanded(child: _kv('Net', inr(f['net'] as num), null)),
                  ]),
                  const SizedBox(height: 8),
                  Text('${f['method']}', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            if (cards.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Add a few invoices and expenses and tips will appear here.')),
            for (final c in cards)
              Card(
                child: ListTile(
                  leading: Icon(
                    switch (c['severity']) { 'good' => Icons.trending_up, 'warn' => Icons.warning_amber_rounded, _ => Icons.lightbulb_outline },
                    color: switch (c['severity']) { 'good' => GPColors.success, 'warn' => GPColors.warning, _ => GPColors.info },
                  ),
                  title: Text('${c['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${c['detail'] ?? ''}'),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Widget _kv(String k, String v, Color? c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: Theme.of(context).textTheme.bodySmall),
        FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c))),
      ]);
}
