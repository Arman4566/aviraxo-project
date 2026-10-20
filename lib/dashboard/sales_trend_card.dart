import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repositories/extras_repo.dart';
import '../insights/analytics_screen.dart';
import '../theme/gp_colors.dart';
import '../widgets/charts.dart';

/// "Last 7 days" sales line on the home screen. Tap for the full analytics dashboard.
/// If the server cannot be reached the card hides itself rather than showing an error on the home screen.
class SalesTrendCard extends StatefulWidget {
  const SalesTrendCard({super.key});
  @override
  State<SalesTrendCard> createState() => _SalesTrendCardState();
}

class _SalesTrendCardState extends State<SalesTrendCard> {
  late final Future<Map<String, dynamic>> _future = ExtrasRepo().analytics('7d');
  static const _m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final a = snap.data;
        final series = a == null ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(a['series'] as List);
        final sales = [for (final p in series) p['sales'] as num];
        final labels = [
          for (final p in series) () {
            final d = (p['date'] as String).split('-');
            return '${int.parse(d[2])} ${_m[int.parse(d[1]) - 1]}';
          }()
        ];
        final total = a == null ? 0 : (a['totals'] as Map)['sales'] as num;
        final pct = a == null ? null : (a['change_pct'] as Map)['sales'] as num?;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Sales, last 7 days', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                if (a != null) DeltaChip(pct: pct),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: GPColors.ink2),
              ]),
              const SizedBox(height: 2),
              Text(a == null ? '…' : inr(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: GPColors.primary)),
              const SizedBox(height: 8),
              if (a == null)
                const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))
              else
                LineChart(series: [sales], labels: labels, height: 150, colors: const [GPColors.primary]),
            ]),
          ),
        );
      },
    );
  }
}
