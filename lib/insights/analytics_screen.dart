import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';

import '../core/money.dart';
import '../data/repositories/extras_repo.dart';
import '../data/repositories/receivables_repo.dart';
import '../l10n/strings.dart';
import '../theme/gp_colors.dart';
import '../widgets/charts.dart';

/// Business analytics: KPIs against the previous period, trends, rankings and splits.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _repo = ExtrasRepo();
  String _range = '30d';
  late Future<_Bundle> _future = _load();
  int? _sel; // selected point on the trend chart

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  Future<_Bundle> _load() async {
    final a = await _repo.analytics(_range);
    Map<String, dynamic>? aging;
    try {
      aging = await ReceivablesRepo().aging(); // optional card: skipped if this role cannot see receivables
    } catch (_) {}
    return _Bundle(a, aging);
  }

  void _setRange(String r) {
    setState(() {
      _range = r;
      _sel = null;
      _future = _load();
    });
  }

  String _label(String iso, String gran) {
    final p = iso.split('-');
    final m = _months[int.parse(p[1]) - 1];
    return gran == 'month' ? m : '${int.parse(p[2])} $m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: FutureBuilder<_Bundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snap.error}'.replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                  TextButton(onPressed: () => _setRange(_range), child: Text(tr('retry'))),
                ]),
              ),
            );
          }
          return RefreshIndicator(onRefresh: () async => _setRange(_range), child: _body(snap.data!));
        },
      ),
    );
  }

  Widget _body(_Bundle b) {
    final a = b.a;
    final t = Map<String, dynamic>.from(a['totals'] as Map);
    final ch = Map<String, dynamic>.from(a['change_pct'] as Map);
    final gran = a['granularity'] as String;
    final series = List<Map<String, dynamic>>.from(a['series'] as List);
    final labels = [for (final p in series) _label(p['date'] as String, gran)];
    final sales = [for (final p in series) p['sales'] as num];
    final coll = [for (final p in series) p['collected'] as num];
    final hasProfit = t['net_profit'] != null;
    final monthly = List<Map<String, dynamic>>.from(a['monthly'] as List);
    final modes = List<Map<String, dynamic>>.from(a['payment_modes'] as List);
    final cats = List<Map<String, dynamic>>.from(a['expense_categories'] as List);
    final items = List<Map<String, dynamic>>.from(a['top_items'] as List);
    final custs = List<Map<String, dynamic>>.from(a['top_customers'] as List);
    final weekdays = List<Map<String, dynamic>>.from(a['weekdays'] as List);
    final best = a['best_weekday'] as int?;
    final empty = (t['sales'] as num) == 0 && (t['expenses'] as num) == 0 && (t['collected'] as num) == 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final r in const {'7d': '7 days', '30d': '30 days', '90d': '3 months', '365d': '1 year'}.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(r.value), selected: _range == r.key, onSelected: (_) => _setRange(r.key)),
              ),
          ]),
        ),
        const SizedBox(height: 4),
        Text('${a['from']} to ${a['to']}, compared with the ${a['days']} days before', style: TextStyle(fontSize: 12, color: GPColors.ink2)),
        const SizedBox(height: 12),
        if (empty)
          const _Card(title: 'No activity yet', child: Text('Create an invoice or record a payment and your charts will fill in here.')),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _Kpi('Sales', inr(t['sales'] as num), ch['sales'] as num?, GPColors.primary, Icons.trending_up_rounded, sub: '${t['orders']} bills · avg ${compactInr(t['avg_order'] as num)}'),
            _Kpi('Collected', inr(t['collected'] as num), ch['collected'] as num?, GPColors.success, Icons.south_west_rounded),
            _Kpi('Expenses', inr(t['expenses'] as num), ch['expenses'] as num?, GPColors.warning, Icons.north_east_rounded, upIsGood: false),
            if (hasProfit)
              _Kpi('Net profit', inr(t['net_profit'] as num), ch['net_profit'] as num?, (t['net_profit'] as num) >= 0 ? GPColors.accent : GPColors.danger, Icons.savings_outlined,
                  sub: 'margin ${t['margin_pct']}%')
            else
              _Kpi('GST collected', inr(t['tax_collected'] as num), null, GPColors.info, Icons.receipt_long_outlined),
          ],
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Sales and collections',
          trailing: _sel != null && _sel! < series.length
              ? Text('${labels[_sel!]}: ${compactInr(sales[_sel!])} sold, ${compactInr(coll[_sel!])} in', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
              : Text('Touch the chart', style: TextStyle(fontSize: 12, color: GPColors.ink2)),
          child: Column(children: [
            LineChart(series: [sales, coll], labels: labels, colors: [GPColors.primary, GPColors.success], onSelect: (i) => setState(() => _sel = i)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Dot(GPColors.primary, 'Sales'),
              SizedBox(width: 16),
              _Dot(GPColors.success, 'Money received'),
            ]),
          ]),
        ),
        _Card(
          title: 'Last 6 months',
          child: Column(children: [
            BarChart(
              series: [
                [for (final m in monthly) m['sales'] as num],
                [for (final m in monthly) m['expenses'] as num],
              ],
              labels: [for (final m in monthly) _months[int.parse((m['month'] as String).substring(5)) - 1]],
              colors: [GPColors.primary, GPColors.warning],
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Dot(GPColors.primary, 'Sales'),
              SizedBox(width: 16),
              _Dot(GPColors.warning, 'Expenses'),
            ]),
          ]),
        ),
        if (b.aging != null) _agingCard(b.aging!),
        _Card(
          title: 'How customers pay',
          child: modes.isEmpty
              ? Text('No payments in this period.', style: TextStyle(color: GPColors.ink2))
              : DonutChart(
                  centerLabel: 'received',
                  slices: [for (var i = 0; i < modes.length; i++) DonutSlice(_title(modes[i]['mode'] as String), modes[i]['total'] as num, GPColors.series[i % GPColors.series.length])],
                ),
        ),
        _Card(
          title: 'Where the money goes',
          child: cats.isEmpty
              ? Text('No expenses in this period.', style: TextStyle(color: GPColors.ink2))
              : DonutChart(
                  centerLabel: 'spent',
                  slices: [for (var i = 0; i < cats.length; i++) DonutSlice(cats[i]['category'] as String, cats[i]['total'] as num, GPColors.series[(i + 2) % GPColors.series.length])],
                ),
        ),
        _Card(
          title: 'Best-selling items',
          child: RankBars(rows: [for (final i in items) (label: i['name'] as String, value: i['revenue'] as num, sub: '${_qty(i['qty'] as num)} sold')]),
        ),
        _Card(
          title: 'Top customers',
          child: RankBars(
            color: GPColors.accent,
            rows: [for (final c in custs) (label: c['name'] as String, value: c['total'] as num, sub: '${c['orders']} bills')],
          ),
        ),
        _Card(
          title: 'Busiest days',
          trailing: best == null ? null : Text('Best: ${_days[best]}', style: TextStyle(fontWeight: FontWeight.w800, color: GPColors.primary)),
          child: BarChart(
            height: 140,
            series: [[for (final d in weekdays) d['sales'] as num]],
            labels: [for (final d in weekdays) _days[d['dow'] as int].substring(0, 1)],
            colors: const [GPColors.accent],
          ),
        ),
      ],
    );
  }

  Widget _agingCard(Map<String, dynamic> aging) {
    final bk = Map<String, dynamic>.from(aging['buckets'] as Map);
    final parts = [
      ('Not due', (bk['not_due'] as num?) ?? 0, GPColors.success),
      ('1-30 days', (bk['d1_30'] as num?) ?? 0, GPColors.warning),
      ('31-60', (bk['d31_60'] as num?) ?? 0, const Color(0xFFEA580C)),
      ('60+', ((bk['d61_90'] as num?) ?? 0) + ((bk['d90_plus'] as num?) ?? 0), GPColors.danger),
    ];
    final total = parts.fold<num>(0, (s, p) => s + p.$2);
    return _Card(
      title: 'Money still to collect',
      trailing: Text(compactInr(total), style: const TextStyle(fontWeight: FontWeight.w900)),
      child: total <= 0
          ? Text('Nobody owes you money right now.', style: TextStyle(color: GPColors.ink2))
          : Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 14,
                  child: Row(children: [
                    for (final p in parts)
                      if (p.$2 > 0) Expanded(flex: (p.$2 / total * 1000).round().clamp(1, 1000).toInt(), child: Container(color: p.$3)),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 14, runSpacing: 6, children: [for (final p in parts) _Dot(p.$3, '${p.$1} ${compactInr(p.$2)}')]),
            ]),
    );
  }

  String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  String _qty(num q) => q == q.roundToDouble() ? q.round().toString() : q.toStringAsFixed(1);
}

class _Bundle {
  _Bundle(this.a, this.aging);
  final Map<String, dynamic> a;
  final Map<String, dynamic>? aging;
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              if (trailing != null) Flexible(child: trailing!),
            ]),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.pct, this.color, this.icon, {this.sub, this.upIsGood = true});
  final String label, value;
  final num? pct;
  final Color color;
  final IconData icon;
  final String? sub;
  final bool upIsGood;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GPColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: GPColors.ink2))),
            if (label != 'GST collected') DeltaChip(pct: pct, upIsGood: upIsGood),
          ]),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          Text(sub ?? ' ', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: GPColors.ink2)),
        ]),
      );
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.text);
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]);
}
