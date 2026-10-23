import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';

import '../core/api_client.dart';
import '../data/repositories/ai_repo.dart';
import '../theme/gp_colors.dart';
import 'ask_screen.dart';

/// Dashboard card: an AI-written check-up of the business. It only calls the AI when the owner taps,
/// so opening the app never uses up the AI quota. The last result is kept until the app restarts.
class AiSummaryCard extends StatefulWidget {
  const AiSummaryCard({super.key});
  static Map<String, dynamic>? _cached;
  @override
  State<AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends State<AiSummaryCard> {
  final _repo = AiRepo();
  bool _busy = false;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _repo.summary();
      AiSummaryCard._cached = r;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Could not get the AI summary.';
    }
    if (mounted) setState(() => _busy = false);
  }

  static IconData _icon(String k) => k == 'good' ? Icons.trending_up_rounded : (k == 'warn' ? Icons.warning_amber_rounded : Icons.lightbulb_outline_rounded);
  static Color _color(String k) => k == 'good' ? GPColors.success : (k == 'warn' ? GPColors.warning : GPColors.info);

  @override
  Widget build(BuildContext context) {
    final s = AiSummaryCard._cached;
    final points = s == null ? const <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(s['points'] as List);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: GPColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: GPColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, color: GPColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('AI business check-up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskScreen())), child: const Text('Ask AI')),
          ]),
          if (s == null && !_busy && _error == null) ...[
            Text('Get a short summary of what needs your attention today: dues, stock and sales.', style: TextStyle(color: GPColors.ink2)),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.bolt_rounded), label: const Text('Generate check-up')),
          ],
          if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Center(child: CircularProgressIndicator())),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: GPColors.danger)),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
          if (s != null && !_busy) ...[
            Text((s['headline'] as String?) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(_icon(p['kind'] as String), color: _color(p['kind'] as String), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['text'] as String, style: const TextStyle(height: 1.3)),
                      if ((p['action'] as String).isNotEmpty) Text('→ ${p['action']}', style: TextStyle(color: _color(p['kind'] as String), fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ]),
                  ),
                ]),
              ),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Refresh'))),
          ],
        ],
      ),
    );
  }
}
