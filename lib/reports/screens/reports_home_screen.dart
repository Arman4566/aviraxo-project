import 'package:flutter/material.dart';
import '../../models/onboarding_data.dart';
import '../../theme/gp_colors.dart';
import '../widgets/date_filter_pill.dart';
import '../widgets/report_category_card.dart';
import 'sales_reports_screen.dart';
import 'inventory_reports_screen.dart';
import 'party_reports_screen.dart';
import 'tax_reports_screen.dart';

class ReportsHomeScreen extends StatefulWidget {
  final OnboardingData data;
  const ReportsHomeScreen({super.key, required this.data});

  @override
  State<ReportsHomeScreen> createState() => _ReportsHomeScreenState();
}

class _ReportsHomeScreenState extends State<ReportsHomeScreen> {
  String _range = "This Month";
  DateTimeRange? _customRange;

  bool get _isServices => (widget.data.businessType ?? "").toLowerCase() == "services";
  bool get _gstEnabled => widget.data.gstRegistered == true;

  DateTimeRange get _activeRange {
    final now = DateTime.now();

    if (_range == "Today") {
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      return DateTimeRange(start: start, end: end);
    }

    if (_range == "Custom" && _customRange != null) {
      return _customRange!;
    }

    // This Month (default)
    final start = DateTime(now.year, now.month, 1);
    final end = (now.month == 12)
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    return DateTimeRange(start: start, end: end);
  }

  String get _rangeLabel {
    if (_range == "Custom" && _customRange != null) {
      final s = _fmt(_customRange!.start);
      final e = _fmt(_customRange!.end);
      return "$s → $e";
    }
    return _range;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: GPColors.primaryDeep),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _range = "Custom";
        // make end exclusive-friendly (add 1 day to include end date fully)
        final endExclusive = DateTime(picked.end.year, picked.end.month, picked.end.day).add(const Duration(days: 1));
        _customRange = DateTimeRange(start: picked.start, end: endExclusive);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeRange;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            const Text("Reports", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 10),

            Row(
              children: [
                DateFilterPill(
                  label: "Today",
                  selected: _range == "Today",
                  onTap: () => setState(() => _range = "Today"),
                ),
                const SizedBox(width: 10),
                DateFilterPill(
                  label: "This Month",
                  selected: _range == "This Month",
                  onTap: () => setState(() => _range = "This Month"),
                ),
                const SizedBox(width: 10),
                DateFilterPill(
                  label: "Custom",
                  selected: _range == "Custom",
                  onTap: _pickCustomRange,
                ),
              ],
            ),

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GPColors.tint.withOpacity(0.45),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: GPColors.line),
              ),
              child: Text(
                "Showing: $_rangeLabel",
                style: const TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700),
              ),
            ),

            const SizedBox(height: 16),
            ReportCategoryCard(
              icon: Icons.receipt_long_rounded,
              title: "Sales Reports",
              desc: "Revenue, invoices, outstanding",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SalesReportsScreen(
                    rangeLabel: _rangeLabel,
                    range: active,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (!_isServices) ...[
              ReportCategoryCard(
                icon: Icons.inventory_2_rounded,
                title: "Inventory Reports",
                desc: "Stock, low items",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => InventoryReportsScreen(range: active)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            ReportCategoryCard(
              icon: Icons.groups_rounded,
              title: "Party Reports",
              desc: "Customers & suppliers, dues",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PartyReportsScreen(range: active)),
              ),
            ),
            const SizedBox(height: 12),

            if (_gstEnabled)
              ReportCategoryCard(
                icon: Icons.calculate_rounded,
                title: "Tax Reports (GST)",
                desc: "GST collected from invoices",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaxReportsScreen(range: active)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
}
