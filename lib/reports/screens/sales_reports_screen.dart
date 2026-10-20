import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';
import '../../data/repositories/invoice_repo.dart';
import '../../data/models/invoice_entity.dart';
import '../widgets/chart_card.dart';
import '../../widgets/charts.dart';
import '../../insights/analytics_screen.dart';
import '../widgets/preview_list_tile.dart';
import '../widgets/metric_strip.dart';

class SalesReportsScreen extends StatelessWidget {
  final String rangeLabel;
  final DateTimeRange range;

  const SalesReportsScreen({
    super.key,
    required this.rangeLabel,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Reports", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<_SalesData>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final d = snap.data!;
          final metrics = [
            ReportMetric("Total Sales", _inr(d.totalSales), rangeLabel, Icons.currency_rupee_rounded),
            ReportMetric("Total Invoices", "${d.invoiceCount}", "Issued", Icons.receipt_long_rounded),
            ReportMetric("Payments Received", _inr(d.paidLikeAmount), "Received", Icons.payments_rounded),
            ReportMetric("Outstanding", _inr(d.outstandingLikeAmount), "To collect", Icons.account_balance_wallet_rounded),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              Text("Overview • $rangeLabel", style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              MetricStrip(metrics: metrics),
              const SizedBox(height: 14),

              ChartCard(
                title: "Sales Trend",
                subtitle: rangeLabel,
                child: d.trend.hasData
                    ? LineChart(series: [d.trend.values], labels: d.trend.labels, colors: const [GPColors.primary])
                    : const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text("No sales in this range yet.", style: TextStyle(color: GPColors.ink2)))),
              ),
              const SizedBox(height: 14),

              const Text("Top Invoices", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),

              if (d.topInvoices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: GPColors.tint.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: const Text("No invoices found in this range.", style: TextStyle(color: GPColors.ink2)),
                )
              else
                ...d.topInvoices.map((inv) {
                  final title =
                      "${inv.invoiceNo} • ${inv.cashCustomer ? "Cash Customer" : (inv.partyName.isEmpty ? "Party" : inv.partyName)}";
                  final subtitle = _paidHint(inv);

                  return PreviewListTile(
                    icon: Icons.receipt_long_rounded,
                    title: title,
                    subtitle: subtitle,
                    trailing: _inr(inv.grandTotal),
                  );
                }),

              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GPColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
                  child: const Text("Open full analytics", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_SalesData> _load() async {
    final all = await InvoiceRepo().listRange(range.start, range.end);
    final list = all.where((i) => i.affectsBooks && !i.isCancelled).toList();

    double totalSales = 0, totalTax = 0, paid = 0, outstanding = 0;
    for (final inv in list) {
      totalSales += inv.grandTotal;
      totalTax += inv.taxTotal;
      paid += inv.amountPaid;
      outstanding += inv.balanceDue;
    }

    list.sort((a, b) => b.grandTotal.compareTo(a.grandTotal));
    return _SalesData(
      invoiceCount: list.length,
      totalSales: totalSales,
      totalTax: totalTax,
      outstandingLikeAmount: outstanding,
      paidLikeAmount: paid,
      topInvoices: list.take(3).toList(),
      trend: bucketByDate(list.map((i) => (i.date, i.grandTotal.toDouble())), range),
    );
  }

  static String _paidHint(InvoiceEntity inv) {
    if (inv.status == "paid") return "Paid";
    if (inv.status == "partial") return "Partly paid • due ₹${inv.balanceDue.toStringAsFixed(0)}";
    return "Unpaid • due ₹${inv.balanceDue.toStringAsFixed(0)}";
  }

  static String _inr(num v) => "₹${v.toStringAsFixed(0)}";
}

class _SalesData {
  final int invoiceCount;
  final double totalSales;
  final double totalTax;
  final double outstandingLikeAmount;
  final double paidLikeAmount;
  final List<InvoiceEntity> topInvoices;
  final Bucketed trend;

  _SalesData({
    required this.invoiceCount,
    required this.totalSales,
    required this.totalTax,
    required this.outstandingLikeAmount,
    required this.paidLikeAmount,
    required this.topInvoices,
    required this.trend,
  });
}
