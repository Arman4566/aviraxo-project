import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../../data/repositories/invoice_repo.dart';
import '../widgets/chart_card.dart';
import '../../widgets/charts.dart';
import '../../reports/finance_reports_screen.dart';
import '../widgets/report_category_card.dart';

class TaxReportsScreen extends StatelessWidget {
  final DateTimeRange range;
  const TaxReportsScreen({super.key, required this.range});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tax Reports (GST)", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: GPColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<_TaxData>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;

          // NOTE: without place-of-supply logic, we keep a simple split.
          final cgst = d.totalTax / 2;
          final sgst = d.totalTax / 2;
          final igst = 0.0;

          final metrics = [
            _Metric("Total Tax", _inr(d.totalTax), "from invoices", Icons.calculate_rounded),
            _Metric("CGST", _inr(cgst), "estimated", Icons.account_balance_rounded),
            _Metric("SGST", _inr(sgst), "estimated", Icons.account_balance_rounded),
            _Metric("IGST", _inr(igst), "estimated", Icons.account_balance_wallet_rounded),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              _MetricStrip(metrics: metrics),
              const SizedBox(height: 14),
              ChartCard(
                title: "Tax Collected Over Time",
                subtitle: "GST on your sales",
                child: d.trend.hasData
                    ? BarChart(series: [d.trend.values], labels: d.trend.labels, colors: const [GPColors.info])
                    : Text("No GST collected in this range.", style: TextStyle(color: GPColors.ink2)),
              ),
              const SizedBox(height: 14),
              const Text("GST Report Types", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),
              ReportCategoryCard(
                icon: Icons.assignment_rounded,
                title: "GSTR-1 Summary",
                desc: "Outward supplies preview",
                onTap: () => _openGst(context),
              ),
              const SizedBox(height: 10),
              ReportCategoryCard(
                icon: Icons.compare_arrows_rounded,
                title: "B2B vs B2C",
                desc: "Customer split preview",
                onTap: () => _openGst(context),
              ),
              const SizedBox(height: 10),
              ReportCategoryCard(
                icon: Icons.percent_rounded,
                title: "Tax Rate Summary",
                desc: "0/5/12/18/28 split (next)",
                onTap: () => _openGst(context),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GPColors.tint.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: GPColors.line),
                ),
                child: Text(
                  "Note: CGST/SGST/IGST split is estimated for now. We can make it accurate once we use state/place-of-supply logic.",
                  style: TextStyle(color: GPColors.ink2),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Future<_TaxData> _load() async {
    final list = await InvoiceRepo().listRange(range.start, range.end);
    double totalTax = 0;
    final entries = <(DateTime, double)>[];
    for (final inv in list) {
      if (inv.affectsBooks && !inv.isCancelled) {
        totalTax += inv.taxTotal;
        entries.add((inv.date, inv.taxTotal.toDouble()));
      }
    }
    return _TaxData(totalTax: totalTax, trend: bucketByDate(entries, range));
  }

  static void _openGst(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceReportsScreen()));
  }

  static String _inr(num v) => "₹${v.toStringAsFixed(0)}";
}

class _TaxData {
  final double totalTax;
  final Bucketed trend;
  _TaxData({required this.totalTax, required this.trend});
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
