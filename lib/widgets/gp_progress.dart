import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';
import '../theme/gp_colors.dart';

/// Shows "Step 3 of 7 · GST" and a filled bar. The text is parsed ("Step n of m") so existing callers keep working.
class GPProgressPill extends StatelessWidget {
  final String text;
  const GPProgressPill({super.key, required this.text});

  double? get _fraction {
    final m = RegExp(r'Step (\d+) of (\d+)').firstMatch(text);
    if (m == null) return null;
    final n = int.parse(m.group(1)!), t = int.parse(m.group(2)!);
    return t == 0 ? null : (n / t).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final f = _fraction;
    return Semantics(
      label: text,
      child: Container(
        height: 38,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: GPColors.tint.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: GPColors.line),
        ),
        child: Stack(alignment: Alignment.center, children: [
          if (f != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: f, child: Container(color: GPColors.primary.withValues(alpha: 0.45))),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, color: GPColors.ink),
            ),
          ),
        ]),
      ),
    );
  }
}
