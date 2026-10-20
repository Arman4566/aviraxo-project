import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';

/// Frame for a real chart on the report screens (replaces the old "Chart Preview" placeholder).
class ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const ChartCard({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GPColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GPColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: GPColors.ink2, fontSize: 12)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class Bucketed {
  final List<String> labels;
  final List<double> values; // in paise, so charts can use compactInr
  const Bucketed(this.labels, this.values);
  bool get hasData => values.any((v) => v != 0);
}

/// Adds up (date, rupees) entries per day (or per month when the range is longer than 62 days), including empty buckets.
Bucketed bucketByDate(Iterable<(DateTime, double)> entries, DateTimeRange range) {
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  final days = end.difference(start).inDays.clamp(1, 4000).toInt();
  final monthly = days > 62;
  final keys = <String>[];
  final labels = <String>[];
  final sums = <String, double>{};
  String keyOf(DateTime d) => monthly ? '${d.year}-${d.month}' : '${d.year}-${d.month}-${d.day}';
  var cur = monthly ? DateTime(start.year, start.month, 1) : start;
  while (cur.isBefore(end)) {
    final k = keyOf(cur);
    keys.add(k);
    labels.add(monthly ? _mon[cur.month - 1] : '${cur.day} ${_mon[cur.month - 1]}');
    sums[k] = 0;
    cur = monthly ? DateTime(cur.year, cur.month + 1, 1) : cur.add(const Duration(days: 1));
  }
  for (final e in entries) {
    final k = keyOf(e.$1);
    if (sums.containsKey(k)) sums[k] = sums[k]! + e.$2 * 100;
  }
  return Bucketed(labels, [for (final k in keys) sums[k]!]);
}
