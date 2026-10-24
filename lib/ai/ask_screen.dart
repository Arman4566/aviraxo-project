import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';

import '../core/api_client.dart';
import '../data/repositories/ai_repo.dart';
import '../theme/gp_colors.dart';

/// "Ask Galla": a chat that answers questions about the shop's own numbers (sales, dues, stock, expenses).
/// The server hands the AI a fresh summary of the business each time; it is told never to invent figures.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key});
  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _Msg {
  final bool mine;
  final String text;
  final bool error;
  _Msg(this.mine, this.text, {this.error = false});
}

class _AskScreenState extends State<AskScreen> {
  final _repo = AiRepo();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[];
  bool _busy = false;

  static const _suggestions = [
    'Who owes me the most money?',
    'How are my sales this month compared to last month?',
    'Which items should I restock first?',
    'What is my best-selling item?',
    'Which day of the week do I sell the most?',
    'Mera sabse bada udhaar kiska hai?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.length < 2 || _busy) return;
    final history = [
      for (final m in _msgs.where((m) => !m.error)) {'role': m.mine ? 'user' : 'assistant', 'text': m.text}
    ];
    setState(() {
      _msgs.add(_Msg(true, q));
      _busy = true;
      _input.clear();
    });
    _toEnd();
    try {
      final a = await _repo.ask(q, history);
      if (!mounted) return;
      setState(() => _msgs.add(_Msg(false, a)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _msgs.add(_Msg(false, e is ApiException ? e.message : 'Something went wrong. Please try again.', error: true)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _toEnd();
    }
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Galla AI')),
      body: Column(
        children: [
          Expanded(
            child: _msgs.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 12),
                      Icon(Icons.auto_awesome_rounded, size: 40, color: GPColors.primary),
                      const SizedBox(height: 12),
                      const Text('Ask anything about your business', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('Answers come from your own sales, dues and stock. You can ask in English or Hindi.', textAlign: TextAlign.center, style: TextStyle(color: GPColors.ink2)),
                      const SizedBox(height: 20),
                      for (final s in _suggestions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
                            onPressed: () => _send(s),
                            child: Text(s),
                          ),
                        ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _msgs.length + (_busy ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _msgs.length) {
                        return const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))));
                      }
                      final m = _msgs[i];
                      return Align(
                        alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                          decoration: BoxDecoration(
                            color: m.mine ? GPColors.primary : (m.error ? GPColors.danger.withOpacity(0.16) : GPColors.tint),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(m.text, style: TextStyle(color: m.mine ? Colors.white : (m.error ? GPColors.danger : GPColors.ink), height: 1.35)),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(hintText: trs('Type your question…'), counterText: trs('')),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _busy ? null : () => _send(_input.text), icon: const Icon(Icons.send_rounded)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
