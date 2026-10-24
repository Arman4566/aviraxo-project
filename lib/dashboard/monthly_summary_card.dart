import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';
import '../core/money.dart';
import '../data/repositories/receivables_repo.dart';
import '../receivables/receivables_screen.dart';
import '../theme/gp_colors.dart';

/// "Money position" for the month: what customers owe you (lent) and what you owe suppliers (borrowed), plus what was
/// collected and paid so far this month. Hidden quietly when the signed-in role is not allowed to see receivables.
class MonthlySummaryCard extends StatefulWidget {
  const MonthlySummaryCard({super.key});

  @override
  State<MonthlySummaryCard> createState() => _MonthlySummaryCardState();
}

class _MonthlySummaryCardState extends State<MonthlySummaryCard> {
  late Future<Map<String, dynamic>> _future = ReceivablesRepo().monthly();

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  String _monthName(String ym) {
    final p = ym.split('-');
    if (p.length != 2) return '';
    final m = int.tryParse(p[1]) ?? 1;
    return '${_months[(m - 1).clamp(0, 11)]} ${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink(); // loading or not allowed: show nothing
        final d = snap.data!;
        num n(String k) => (d[k] as num?) ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GPColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GPColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.account_balance_wallet_rounded, color: GPColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Money position', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                Text(_monthName('${d['month'] ?? ''}'), style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _Tile(
                    label: 'To collect (money lent)',
                    value: inr(n('to_collect')),
                    note: '${d['customers_owing'] ?? 0} customers',
                    color: GPColors.success,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivablesScreen())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tile(
                    label: 'To pay (money borrowed)',
                    value: inr(n('to_pay')),
                    note: '${d['suppliers_owed'] ?? 0} suppliers',
                    color: GPColors.danger,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                'This month: collected ${inr(n('collected_this_month'))} · paid ${inr(n('paid_this_month'))}',
                style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final Color color;
  final VoidCallback? onTap;
  const _Tile({required this.label, required this.value, required this.note, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: GPColors.ink2, fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: GPColors.ink, fontWeight: FontWeight.w900, fontSize: 20))),
            const SizedBox(height: 2),
            Text(note, style: TextStyle(color: GPColors.ink2, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
