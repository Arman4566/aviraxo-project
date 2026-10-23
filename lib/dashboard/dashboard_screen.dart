import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';
import '../core/outbox.dart';
import '../insights/analytics_screen.dart';
import '../ai/ai_summary_card.dart';
import '../ai/ask_screen.dart';
import '../ai/scan_bill_screen.dart';
import 'sales_trend_card.dart';
import '../receivables/receivables_screen.dart';
import '../expenses/expenses_screen.dart';
import '../inventory/low_stock_screen.dart';
import '../insights/insights_screen.dart';
import '../reports/finance_reports_screen.dart';


import '../models/onboarding_data.dart';
import '../theme/gp_colors.dart';
import '../invoices/invoice_flow/invoice_flow.dart';

import '../core/api_client.dart';
import '../core/money.dart';
import '../data/models/invoice_entity.dart';

class DashboardScreen extends StatefulWidget {
  final OnboardingData data;
  const DashboardScreen({super.key, required this.data});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _DashDataLoader.load(isServices: _isServices);
    Outbox.I.flush().then((n) {
      if (n > 0 && mounted) _reload(); // offline entries were sent: refresh the numbers
    });
  }

  void _reload() {
    Outbox.I.flush();
    setState(() => _future = _DashDataLoader.load(isServices: _isServices));
  }

  bool get _isServices => (widget.data.businessType ?? "").toLowerCase() == "services";

  String get _variant {
    final t = (widget.data.businessType ?? "").toLowerCase();
    if (t == "retailer") return "Retailer";
    if (t == "wholesaler" || t == "distributor") return "Wholesale/Distribution";
    if (t == "manufacturer") return "Manufacturer";
    if (t == "services") return "Services";
    return "General";
  }

  void _openNewInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceFlow(onboarding: widget.data)),
    ).then((_) {
      // refresh dashboard after invoice flow returns
      if (mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final businessName = (widget.data.businessName ?? "").trim();
    final titleName = businessName.isEmpty ? "Your Business" : businessName;

    return FutureBuilder<_DashData>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _reload, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }
        final loading = !snap.hasData;
        final d = snap.data ?? _DashData.empty();

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future.catchError((_) => _DashData.empty());
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            children: [
              // First-time banner: show only if no invoices exist
              if (!loading && d.totalInvoices == 0) ...[
                _FirstTimeBanner(onCreateInvoice: _openNewInvoice),
                const SizedBox(height: 12),
              ],

              _WorkspaceHeader(
                title: titleName,
                subtitle: "Overview • $_variant",
                salesToday: loading ? null : d.salesToday,
                toCollect: loading ? null : d.receivables,
                overdue: loading ? null : d.overdueAmount,
              ),
              const SizedBox(height: 12),

              _WorkspaceConfigStrip(data: widget.data),
              const SizedBox(height: 16),

              _QuickStats(
                data: widget.data,
                variant: _variant,
                isServices: _isServices,
                dash: d,
                loading: loading,
              ),
              const SizedBox(height: 16),

              const SalesTrendCard(),
              const SizedBox(height: 16),

              const AiSummaryCard(),
              const SizedBox(height: 16),

              _QuickActions(
                variant: _variant,
                isServices: _isServices,
                onNewInvoice: _openNewInvoice,
              ),
              const SizedBox(height: 16),

              const _SectionTitle(title: "Recent Activity"),
              const SizedBox(height: 10),
              loading
                  ? const _LoadingCard()
                  : (d.recentInvoices.isEmpty ? const _EmptyActivity() : _RecentInvoicesList(invoices: d.recentInvoices)),
              const SizedBox(height: 16),

              const _SectionTitle(title: "Smart Tips"),
              const SizedBox(height: 10),
              _InsightsFromConfig(data: widget.data, variant: _variant, dash: d, isServices: _isServices),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

/* ----------------------------- DASH DATA ----------------------------- */

class _DashData {
  final int totalInvoices;
  final double salesToday;
  final double salesThisMonth;

  final int totalItems;
  final int inStock;
  final int lowStock;
  final int outOfStock;

  final List<InvoiceEntity> recentInvoices;

  /// Money still to collect from customers, the part that is overdue, and what came in today.
  final double receivables;
  final double overdueAmount;
  final int overdueCount;
  final double collectedToday;

  const _DashData({
    this.receivables = 0,
    this.overdueAmount = 0,
    this.overdueCount = 0,
    this.collectedToday = 0,
    required this.totalInvoices,
    required this.salesToday,
    required this.salesThisMonth,
    required this.totalItems,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
    required this.recentInvoices,
  });

  factory _DashData.empty() => const _DashData(
    totalInvoices: 0,
    salesToday: 0,
    salesThisMonth: 0,
    totalItems: 0,
    inStock: 0,
    lowStock: 0,
    outOfStock: 0,
    recentInvoices: [],
  );
}

class _DashDataLoader {
  /// One request: the server computes every number on this screen.
  static Future<_DashData> load({required bool isServices}) async {
    final r = await ApiClient.I.get('/dashboard');
    final sales = r['sales'] as Map<String, dynamic>;
    final inv = r['inventory'] as Map<String, dynamic>;
    final rec = r['receivables'] as Map<String, dynamic>;

    return _DashData(
      totalInvoices: (r['total_invoices'] as num).toInt(),
      salesToday: toRupees(sales['today'] as num),
      salesThisMonth: toRupees(sales['this_month'] as num),
      totalItems: isServices ? 0 : (inv['total_items'] as num).toInt(),
      inStock: isServices ? 0 : (inv['in_stock'] as num).toInt(),
      lowStock: isServices ? 0 : (inv['low_stock'] as num).toInt(),
      outOfStock: isServices ? 0 : (inv['out_of_stock'] as num).toInt(),
      recentInvoices: (r['recent_invoices'] as List)
          .map((j) => InvoiceEntity.fromJson(j as Map<String, dynamic>))
          .toList(),
      receivables: toRupees(rec['total'] as num),
      overdueAmount: toRupees(rec['overdue_amount'] as num),
      overdueCount: (rec['overdue_count'] as num).toInt(),
      collectedToday: toRupees(r['collected_today'] as num),
    );
  }
}

/* ----------------------------- UI SECTIONS ----------------------------- */

class _QuickStats extends StatelessWidget {
  final OnboardingData data;
  final String variant;
  final bool isServices;
  final _DashData dash;
  final bool loading;

  const _QuickStats({
    required this.data,
    required this.variant,
    required this.isServices,
    required this.dash,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final currency = (data.currency.isEmpty ? "INR" : data.currency);
    String money(double v) {
      // simple formatting for Phase-0
      return "₹${v.toStringAsFixed(0)}";
    }

    final cards = <_MetricCardData>[
      _MetricCardData(
        "Sales Today",
        loading ? "…" : money(dash.salesToday),
        "Live from server",
        Icons.today_rounded,
      ),
      _MetricCardData(
        "This Month",
        loading ? "…" : money(dash.salesThisMonth),
        "Live from server",
        Icons.calendar_month_rounded,
      ),
      _MetricCardData(
        "Invoices",
        loading ? "…" : "${dash.totalInvoices}",
        "Created",
        Icons.receipt_long_rounded,
      ),
      _MetricCardData(
        "To Collect",
        loading ? "…" : money(dash.receivables),
        dash.overdueCount > 0 ? "${money(dash.overdueAmount)} overdue" : "Nothing overdue",
        Icons.account_balance_wallet_rounded,
      ),
      _MetricCardData(
        "Collected Today",
        loading ? "…" : money(dash.collectedToday),
        "Payments received",
        Icons.payments_rounded,
      ),
    ];

    if (!isServices) {
      cards.addAll([
        _MetricCardData(
          "Items",
          loading ? "…" : "${dash.totalItems}",
          "In inventory",
          Icons.inventory_2_rounded,
        ),
        _MetricCardData(
          "In Stock",
          loading ? "…" : "${dash.inStock}",
          "Available",
          Icons.check_circle_rounded,
        ),
        _MetricCardData(
          "Low Stock",
          loading ? "…" : "${dash.lowStock}",
          "Needs restock",
          Icons.warning_amber_rounded,
        ),
        _MetricCardData(
          "Out",
          loading ? "…" : "${dash.outOfStock}",
          "Out of stock",
          Icons.cancel_rounded,
        ),
      ]);
    } else {
      // keep 4 cards look even for services
      cards.add(
        _MetricCardData(
          "Currency",
          currency,
          "Workspace",
          Icons.currency_exchange_rounded,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: "Live Overview"),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _MetricCard(cards[i]),
          ),
        ),
      ],
    );
  }
}

/// First-time CTA
class _FirstTimeBanner extends StatelessWidget {
  final VoidCallback onCreateInvoice;
  const _FirstTimeBanner({required this.onCreateInvoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GPColors.tint.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: GPColors.primary.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: GPColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Workspace ready", style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  "Create your first invoice to start tracking real data.",
                  style: TextStyle(color: GPColors.ink2),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCreateInvoice,
            child: Text(
              "Create",
              style: TextStyle(fontWeight: FontWeight.w900, color: GPColors.primaryDeep),
            ),
          )
        ],
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double? salesToday;
  final double? toCollect;
  final double? overdue;
  const _WorkspaceHeader({required this.title, required this.subtitle, this.salesToday, this.toCollect, this.overdue});

  String _m(double? v) => v == null ? "…" : "₹${v.round()}";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GPColors.primary, GPColors.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: GPColors.primary.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: GPColors.surface.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.store_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white)),
                    Text(subtitle, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _stat("Sales today", _m(salesToday), null)),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivablesScreen())),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: _stat("To collect", _m(toCollect), (overdue ?? 0) > 0 ? "${_m(overdue)} overdue" : null),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String? note) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
          if (note != null) Text(note, style: const TextStyle(color: Color(0xFFFECACA), fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      );
}

/// Workspace config cards (from onboarding)
class _WorkspaceConfigStrip extends StatelessWidget {
  final OnboardingData data;
  const _WorkspaceConfigStrip({required this.data});

  @override
  Widget build(BuildContext context) {
    final gst = data.gstRegistered == true;
    final inventory = data.trackInventory == true;
    final pricing = (data.pricingStyle ?? "Not set");
    final currency = (data.currency.isEmpty ? "INR" : data.currency);
    final payCount = data.paymentMethods.length;
    final docCount = data.billingDocs.length;

    final cards = <_MetricCardData>[
      _MetricCardData(
        "GST",
        gst ? "Enabled" : "Not registered",
        gst ? (data.gstin?.isNotEmpty == true ? "GSTIN saved" : "GSTIN not added") : "Non-GST invoices",
        Icons.verified_rounded,
      ),
      _MetricCardData(
        "Inventory",
        inventory ? "Tracking ON" : "Billing only",
        inventory ? "Alerts: ${data.lowStockAlerts ? "ON" : "OFF"}" : "No stock features",
        Icons.inventory_2_rounded,
      ),
      _MetricCardData(
        "Pricing",
        pricing,
        "Tax style",
        Icons.calculate_rounded,
      ),
      _MetricCardData(
        "Currency",
        currency,
        data.state?.isNotEmpty == true ? "State: ${data.state}" : "State not set",
        Icons.currency_exchange_rounded,
      ),
      _MetricCardData(
        "Docs",
        "$docCount selected",
        "Invoice formats",
        Icons.receipt_long_rounded,
      ),
      _MetricCardData(
        "Payments",
        "$payCount selected",
        "Methods selected (no module)",
        Icons.payments_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: "Workspace Settings"),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _MetricCard(cards[i]),
          ),
        ),
      ],
    );
  }
}

class _MetricCardData {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  _MetricCardData(this.label, this.value, this.sub, this.icon);
}

class _MetricCard extends StatelessWidget {
  final _MetricCardData d;
  const _MetricCard(this.d);

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GPColors.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(d.icon, color: GPColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
          const Spacer(),
          Text(d.value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 4),
          Text(d.sub, style: TextStyle(color: GPColors.ink2)),
        ],
      ),
    );
  }
}

Widget? _screenFor(String title) {
  switch (title) {
    case "Analytics":
      return const AnalyticsScreen();
    case "Ask AI":
      return const AskScreen();
    case "Scan Bill":
      return const ScanBillScreen();
    case "Collect Payments":
      return const ReceivablesScreen();
    case "Expenses":
      return const ExpensesScreen();
    case "Insights":
      return const InsightsScreen();
    case "Overdue List":
    case "Pending Invoices":
      return const ReceivablesScreen();
    case "Stock Summary":
    case "Raw Stock":
      return const LowStockScreen();
    case "Reports":
    case "View Reports":
    case "Day Report":
      return const FinanceReportsScreen();
  }
  return null;
}

/// Quick Actions
class _QuickActions extends StatelessWidget {
  final String variant;
  final bool isServices;
  final VoidCallback onNewInvoice;

  const _QuickActions({
    required this.variant,
    required this.isServices,
    required this.onNewInvoice,
  });

  @override
  Widget build(BuildContext context) {
    List<_ActionItem> actions;

    if (variant == "Retailer") {
      actions = [
        _ActionItem("New Invoice", Icons.add_circle_rounded, primary: true),
        _ActionItem("Add Item", Icons.add_box_rounded),
        _ActionItem("Stock Summary", Icons.inventory_rounded),
        _ActionItem("Day Report", Icons.receipt_rounded),
        _ActionItem("Add Customer", Icons.person_add_alt_rounded),
        _ActionItem("Reports", Icons.bar_chart_rounded),
      ];
    } else if (variant == "Wholesale/Distribution") {
      actions = [
        _ActionItem("New Invoice", Icons.add_circle_rounded, primary: true),
        _ActionItem("Add Customer", Icons.person_add_alt_rounded),
        _ActionItem("Purchase Entry", Icons.shopping_cart_rounded),
        _ActionItem("Overdue List", Icons.warning_rounded),
        _ActionItem("Reports", Icons.bar_chart_rounded),
      ];
    } else if (variant == "Manufacturer") {
      actions = [
        _ActionItem("Production Entry", Icons.factory_rounded, primary: true),
        _ActionItem("New Invoice", Icons.add_circle_rounded),
        _ActionItem("Purchase Raw", Icons.shopping_bag_rounded),
        _ActionItem("Raw Stock", Icons.inventory_2_rounded),
        _ActionItem("Finished Goods", Icons.widgets_rounded),
        _ActionItem("Dispatch", Icons.local_shipping_rounded),
      ];
    } else if (variant == "Services") {
      actions = [
        _ActionItem("New Invoice", Icons.add_circle_rounded, primary: true),
        _ActionItem("Add Client", Icons.person_add_alt_rounded),
        _ActionItem("Pending Invoices", Icons.schedule_rounded),
        _ActionItem("Reports", Icons.bar_chart_rounded),
      ];
    } else {
      actions = [
        _ActionItem("New Invoice", Icons.add_circle_rounded, primary: true),
        if (!isServices) _ActionItem("Add Item", Icons.add_box_rounded),
        _ActionItem("Add Customer", Icons.person_add_alt_rounded),
        _ActionItem("View Reports", Icons.bar_chart_rounded),
        if (!isServices) _ActionItem("Purchase Entry", Icons.shopping_cart_rounded),
        if (!isServices) _ActionItem("Stock Summary", Icons.inventory_rounded),
      ];
    }

    actions.addAll([
      _ActionItem("Ask AI", Icons.auto_awesome_rounded),
      _ActionItem("Analytics", Icons.insights_rounded),
      if (!isServices) _ActionItem("Scan Bill", Icons.document_scanner_rounded),
      _ActionItem("Collect Payments", Icons.account_balance_wallet_rounded),
      _ActionItem("Expenses", Icons.money_off_rounded),
      _ActionItem("Insights", Icons.auto_graph_rounded),
    ]);

    if (isServices) {
      actions = actions.where((a) {
        final t = a.title.toLowerCase();
        return !(t.contains("stock") || t.contains("item") || t.contains("purchase") || t.contains("raw"));
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: "Quick Actions"),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (_, i) => _ActionTile(
            actions[i],
            onTap: () {
              if (actions[i].title == "New Invoice") {
                onNewInvoice();
              } else {
                final screen = _screenFor(actions[i].title);
                if (screen != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${actions[i].title} is coming soon")),
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ActionItem {
  final String title;
  final IconData icon;
  final bool primary;
  _ActionItem(this.title, this.icon, {this.primary = false});
}

class _ActionTile extends StatelessWidget {
  final _ActionItem item;
  final VoidCallback onTap;

  const _ActionTile(this.item, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = item.primary ? GPColors.primary.withOpacity(0.26) : Colors.white;
    final border = item.primary ? GPColors.primary : GPColors.line;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: GPColors.tint.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: GPColors.ink),
            ),
            const Spacer(),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text("Tap to open", style: TextStyle(color: GPColors.ink2)),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- RECENT INVOICES ----------------------------- */

class _RecentInvoicesList extends StatelessWidget {
  final List<InvoiceEntity> invoices;
  const _RecentInvoicesList({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: invoices.map((inv) => _InvoiceTile(inv: inv)).toList(),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final InvoiceEntity inv;
  const _InvoiceTile({required this.inv});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(inv.dateMs);
    final date = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
    final party = inv.cashCustomer ? "Cash Customer" : (inv.partyName.isEmpty ? "-" : inv.partyName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GPColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: GPColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.receipt_long_rounded, color: GPColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${inv.invoiceNo} • $party", style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(date, style: TextStyle(color: GPColors.ink2)),
              ],
            ),
          ),
          Text("₹${inv.grandTotal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/* ----------------------------- ACTIVITY & TIPS ----------------------------- */

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GPColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: GPColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.history_rounded, color: GPColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("No activity yet", style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  "Once you create invoices and add items, activity will appear here.",
                  style: TextStyle(color: GPColors.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsFromConfig extends StatelessWidget {
  final OnboardingData data;
  final String variant;
  final _DashData dash;
  final bool isServices;

  const _InsightsFromConfig({
    required this.data,
    required this.variant,
    required this.dash,
    required this.isServices,
  });

  @override
  Widget build(BuildContext context) {
    final tips = <_Tip>[
      if (dash.totalInvoices == 0)
        const _Tip("Start with one invoice", "Create your first invoice to see reports & trends", Icons.receipt_long_rounded),
      if (!isServices && data.trackInventory == true && dash.lowStock > 0)
        _Tip("Low stock detected", "${dash.lowStock} items are below low stock level", Icons.warning_amber_rounded),
      if (data.gstRegistered != true)
        const _Tip("GST not enabled", "You can enable GST later from Settings", Icons.verified_rounded),
      if (data.trackInventory == true && data.lowStockAlerts == false)
        const _Tip("Low stock alerts OFF", "Turn ON alerts to avoid stockouts", Icons.notifications_active_rounded),
      if ((data.businessName ?? "").trim().isEmpty)
        const _Tip("Business name missing", "Add it for better invoice branding", Icons.store_rounded),
    ];

    if (tips.isEmpty) {
      return const _TipCard(_Tip("All set", "Your workspace settings look good", Icons.check_circle_rounded));
    }

    return Column(
      children: tips.map((t) => _TipCard(t)).toList(),
    );
  }
}

class _Tip {
  final String title;
  final String desc;
  final IconData icon;
  const _Tip(this.title, this.desc, this.icon);
}

class _TipCard extends StatelessWidget {
  final _Tip t;
  const _TipCard(this.t);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GPColors.tint.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: GPColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(t.icon, color: GPColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(t.desc, style: TextStyle(color: GPColors.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GPColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Row(
        children: const [
          SizedBox(width: 10),
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(width: 12),
          Expanded(
            child: Text("Loading dashboard…", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16));
  }
}
