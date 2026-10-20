import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';

class ReportMetric {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  const ReportMetric(this.label, this.value, this.sub, this.icon);
}

class MetricStrip extends StatelessWidget {
  final List<ReportMetric> metrics;
  const MetricStrip({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metrics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _MetricCard(m: metrics[i]),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final ReportMetric m;
  const _MetricCard({required this.m});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  color: GPColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(m.icon, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
          const Spacer(),
          Text(m.value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 4),
          Text(m.sub, style: const TextStyle(color: GPColors.ink2)),
        ],
      ),
    );
  }
}
