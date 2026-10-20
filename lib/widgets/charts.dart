import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../theme/gp_colors.dart';

/// Small chart kit drawn with CustomPainter, so the app needs no chart package.
/// All values are paise (integers from the API); labels are formatted with compactInr.

double _niceCeil(double v) {
  if (v <= 0) return 1;
  final e = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final f = v / e;
  final nf = f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10;
  return nf * e;
}

void _text(Canvas c, String s, Offset at, {Color color = GPColors.ink2, double size = 10, TextAlign align = TextAlign.left, double maxWidth = 80}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
  )..layout(maxWidth: maxWidth);
  final dx = align == TextAlign.right ? at.dx - tp.width : align == TextAlign.center ? at.dx - tp.width / 2 : at.dx;
  tp.paint(c, Offset(dx, at.dy));
}

/// One or more lines over the same x labels. Drag or tap to read exact values (reported through [onSelect]).
class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.series,
    required this.labels,
    this.colors = const [GPColors.primary, GPColors.accent, GPColors.warning],
    this.height = 190,
    this.onSelect,
  });

  /// Each inner list has one value per label.
  final List<List<num>> series;
  final List<String> labels;
  final List<Color> colors;
  final double height;
  final ValueChanged<int?>? onSelect;

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  int? _sel;

  void _pick(Offset p, double width) {
    final n = widget.labels.length;
    if (n == 0) return;
    const left = 46.0, right = 10.0;
    final w = width - left - right;
    final i = n == 1 ? 0 : ((p.dx - left) / w * (n - 1)).round().clamp(0, n - 1).toInt();
    if (i != _sel) {
      setState(() => _sel = i);
      widget.onSelect?.call(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _pick(d.localPosition, box.maxWidth),
        onHorizontalDragUpdate: (d) => _pick(d.localPosition, box.maxWidth),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LinePainter(widget.series, widget.labels, widget.colors, _sel, Theme.of(context).dividerColor),
          ),
        ),
      );
    });
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.series, this.labels, this.colors, this.sel, this.grid);
  final List<List<num>> series;
  final List<String> labels;
  final List<Color> colors;
  final int? sel;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0, right = 10.0, top = 10.0, bottom = 22.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    final n = labels.length;
    if (n == 0 || w <= 0 || h <= 0) return;

    var maxV = 0.0;
    for (final s in series) {
      for (final v in s) {
        if (v > maxV) maxV = v.toDouble();
      }
    }
    final yMax = _niceCeil(maxV);
    double x(int i) => left + (n == 1 ? w / 2 : i * w / (n - 1));
    double y(num v) => top + h - (v / yMax) * h;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      final gy = top + h - h * g / 4;
      canvas.drawLine(Offset(left, gy), Offset(left + w, gy), gridPaint);
      _text(canvas, compactInr(yMax * g / 4), Offset(left - 6, gy - 6), align: TextAlign.right, maxWidth: left - 8);
    }

    // x labels: at most 5, evenly spread
    final step = math.max(1, ((n - 1) / 4).ceil());
    for (var i = 0; i < n; i += step) {
      _text(canvas, labels[i], Offset(x(i), top + h + 6), align: TextAlign.center, maxWidth: 60);
    }

    for (var si = 0; si < series.length; si++) {
      final s = series[si];
      if (s.isEmpty) continue;
      final color = colors[si % colors.length];
      final path = Path();
      for (var i = 0; i < s.length && i < n; i++) {
        final p = Offset(x(i), y(s[i]));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          // smooth the line with a gentle curve between points
          final prev = Offset(x(i - 1), y(s[i - 1]));
          final mid = (prev.dx + p.dx) / 2;
          path.cubicTo(mid, prev.dy, mid, p.dy, p.dx, p.dy);
        }
      }
      if (si == 0) {
        final area = Path.from(path)
          ..lineTo(x(math.min(s.length, n) - 1), top + h)
          ..lineTo(x(0), top + h)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
            ).createShader(Rect.fromLTWH(left, top, w, h)),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    if (sel != null && sel! < n) {
      final sx = x(sel!);
      canvas.drawLine(Offset(sx, top), Offset(sx, top + h), Paint()..color = GPColors.ink2.withValues(alpha: 0.5)..strokeWidth = 1);
      for (var si = 0; si < series.length; si++) {
        if (sel! >= series[si].length) continue;
        final c = colors[si % colors.length];
        canvas.drawCircle(Offset(sx, y(series[si][sel!])), 5, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(sx, y(series[si][sel!])), 3.5, Paint()..color = c);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.series != series || old.sel != sel || old.labels != labels;
}

/// Grouped vertical bars: one group per label, one bar per series.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.series,
    required this.labels,
    this.colors = const [GPColors.primary, GPColors.danger],
    this.height = 180,
  });
  final List<List<num>> series;
  final List<String> labels;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _BarPainter(series, labels, colors, Theme.of(context).dividerColor)),
      );
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.series, this.labels, this.colors, this.grid);
  final List<List<num>> series;
  final List<String> labels;
  final List<Color> colors;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0, right = 6.0, top = 10.0, bottom = 22.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    final n = labels.length;
    if (n == 0 || w <= 0 || h <= 0) return;
    var maxV = 0.0;
    for (final s in series) {
      for (final v in s) {
        if (v > maxV) maxV = v.toDouble();
      }
    }
    final yMax = _niceCeil(maxV);
    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      final gy = top + h - h * g / 4;
      canvas.drawLine(Offset(left, gy), Offset(left + w, gy), gridPaint);
      _text(canvas, compactInr(yMax * g / 4), Offset(left - 6, gy - 6), align: TextAlign.right, maxWidth: left - 8);
    }
    final group = w / n;
    final bars = series.length;
    final barW = math.min(22.0, (group * 0.7) / bars);
    for (var i = 0; i < n; i++) {
      final startX = left + i * group + (group - barW * bars) / 2;
      for (var si = 0; si < bars; si++) {
        final v = i < series[si].length ? series[si][i].toDouble() : 0.0;
        final bh = v / yMax * h;
        final r = RRect.fromRectAndCorners(
          Rect.fromLTWH(startX + si * barW, top + h - bh, barW - 2, bh),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        );
        canvas.drawRRect(r, Paint()..color = colors[si % colors.length]);
      }
      _text(canvas, labels[i], Offset(left + i * group + group / 2, top + h + 6), align: TextAlign.center, maxWidth: group);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.series != series || old.labels != labels;
}

class DonutSlice {
  const DonutSlice(this.label, this.value, this.color);
  final String label;
  final num value;
  final Color color;
}

/// Ring chart with the total in the middle and a legend that shows each share.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 130, this.centerLabel = 'Total', this.centerValue});
  final List<DonutSlice> slices;
  final double size;
  final String centerLabel;

  /// Text in the middle of the ring. Defaults to the total as rupees; pass a count for non-money charts.
  final String? centerValue;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<num>(0, (a, s) => a + s.value);
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(slices, total),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(centerValue ?? compactInr(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                Text(centerLabel, style: const TextStyle(fontSize: 10, color: GPColors.ink2)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(total > 0 ? '${(s.value / total * 100).round()}%' : '0%', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.total);
  final List<DonutSlice> slices;
  final num total;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = GPColors.line;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.value / total) * math.pi * 2;
      if (sweep <= 0) continue;
      final gap = slices.length > 1 ? 0.03 : 0.0;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0, sweep - gap),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = s.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}

/// Ranked horizontal bars (top items, top customers): label, bar scaled to the biggest, value.
class RankBars extends StatelessWidget {
  const RankBars({super.key, required this.rows, this.color = GPColors.primary, this.emptyText = 'Nothing to show for this period.'});
  final List<({String label, num value, String? sub})> rows;
  final Color color;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(emptyText, style: const TextStyle(color: GPColors.ink2)));
    }
    final maxV = rows.fold<num>(0, (a, r) => r.value > a ? r.value : a);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(compactInr(r.value), style: const TextStyle(fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: maxV > 0 ? (r.value / maxV).toDouble() : 0,
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
              if (r.sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(r.sub!, style: const TextStyle(fontSize: 11, color: GPColors.ink2))),
            ]),
          ),
      ],
    );
  }
}

/// Little coloured pill like "▲ 12.5%" (good) or "▼ 8%" (bad). [upIsGood] false for costs.
class DeltaChip extends StatelessWidget {
  const DeltaChip({super.key, required this.pct, this.upIsGood = true});
  final num? pct;
  final bool upIsGood;

  @override
  Widget build(BuildContext context) {
    if (pct == null) {
      return const Text('new', style: TextStyle(fontSize: 11, color: GPColors.ink2, fontWeight: FontWeight.w700));
    }
    final up = pct! >= 0;
    final good = pct == 0 ? null : (up == upIsGood);
    final c = good == null ? GPColors.ink2 : (good ? GPColors.success : GPColors.danger);
    final shown = pct!.abs() >= 100 ? pct!.abs().round().toString() : pct!.abs().toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text('${pct == 0 ? '' : (up ? '▲ ' : '▼ ')}$shown%', style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w800)),
    );
  }
}
