import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';
import '../widgets/glass.dart';

import '../core/messenger.dart';
import '../data/repositories/receivables_repo.dart';
import '../l10n/strings.dart';

/// Rules decide when a reminder shows up: e.g. 3 days before due, on the due date, then every 7 days after.
class ReminderRulesScreen extends StatefulWidget {
  const ReminderRulesScreen({super.key});
  @override
  State<ReminderRulesScreen> createState() => _ReminderRulesScreenState();
}

class _ReminderRulesScreenState extends State<ReminderRulesScreen> {
  final _repo = ReceivablesRepo();
  late Future<List<Map<String, dynamic>>> _future = _repo.rules();

  void _reload() => setState(() => _future = _repo.rules());

  String _describe(Map<String, dynamic> r) {
    final n = r['offset_days'];
    final rep = r['repeat_every_days'];
    final when = switch (r['trigger_type']) {
      'before_due' => '$n day(s) before the due date',
      'on_due' => 'On the due date',
      _ => '$n day(s) after the due date${rep != null ? ', then every $rep days' : ''}',
    };
    return '$when · ${r['channel']} · ${r['tone']}';
  }

  Future<void> _edit([Map<String, dynamic>? rule]) async {
    final saved = await showGlassSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RuleForm(rule: rule),);
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('payment_reminders'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add), label: const Text('Add rule')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: TextButton(onPressed: _reload, child: Text('${snap.error}. ${tr('retry')}')));
          final rules = snap.data!;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
            const Text('Each day the app lists the customers who match a rule. You tap once to send on WhatsApp, SMS or email. '
                'Customers who promised a date, or are paused, are skipped.'),
            const SizedBox(height: 12),
            for (final r in rules)
              Card(
                child: SwitchListTile(
                  title: Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(_describe(r)),
                  value: r['is_active'] == true,
                  onChanged: (v) async {
                    try {
                      await _repo.saveRule({'is_active': v}, id: (r['id'] as num).toInt());
                      _reload();
                    } catch (e) {
                      AppMessenger.error(e);
                    }
                  },
                  secondary: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(r)),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _RuleForm extends StatefulWidget {
  const _RuleForm({this.rule});
  final Map<String, dynamic>? rule;
  @override
  State<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<_RuleForm> {
  final _name = TextEditingController();
  final _offset = TextEditingController(text: '0');
  final _repeat = TextEditingController();
  String _trigger = 'after_due', _channel = 'whatsapp', _tone = 'friendly', _lang = 'en';
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    if (r != null) {
      _name.text = '${r['name']}';
      _offset.text = '${r['offset_days']}';
      _repeat.text = r['repeat_every_days'] == null ? '' : '${r['repeat_every_days']}';
      _trigger = '${r['trigger_type']}';
      _channel = '${r['channel']}';
      _tone = '${r['tone']}';
      _lang = '${r['language']}';
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final offset = int.tryParse(_offset.text.trim());
    final rep = _repeat.text.trim().isEmpty ? null : int.tryParse(_repeat.text.trim());
    if (name.isEmpty) return setState(() => _err = 'Give the rule a name, for example "Gentle nudge".');
    if (offset == null || offset < 0 || offset > 365) return setState(() => _err = 'Days must be a number from 0 to 365.');
    if (_repeat.text.trim().isNotEmpty && (rep == null || rep < 1 || rep > 90)) return setState(() => _err = 'Repeat every must be 1 to 90 days, or empty.');
    setState(() {
      _err = null;
      _busy = true;
    });
    try {
      await ReceivablesRepo().saveRule({
        'name': name,
        'trigger_type': _trigger,
        'offset_days': _trigger == 'on_due' ? 0 : offset,
        'repeat_every_days': _trigger == 'after_due' ? rep : null,
        'channel': _channel,
        'tone': _tone,
        'language': _lang,
      }, id: widget.rule == null ? null : (widget.rule!['id'] as num).toInt());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _err = '$e'.replaceFirst('Exception: ', '');
        _busy = false;
      });
    }
  }

  Widget _drop(String label, String value, Map<String, String> opts, ValueChanged<String> on) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: label),
          items: [for (final e in opts.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => v == null ? null : setState(() => on(v)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.rule == null ? 'New reminder rule' : 'Edit rule', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(labelText: trs('Rule name'))),
          const SizedBox(height: 12),
          _drop('When', _trigger, {'before_due': 'Before the due date', 'on_due': 'On the due date', 'after_due': 'After the due date'}, (v) => _trigger = v),
          if (_trigger != 'on_due')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(controller: _offset, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: trs('How many days'))),
            ),
          if (_trigger == 'after_due')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _repeat,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: trs('Repeat every (days, optional)'), helperText: trs('Keeps reminding until the invoice is paid')),
              ),
            ),
          _drop('Send on', _channel, {'whatsapp': 'WhatsApp', 'sms': 'SMS', 'email': 'Email'}, (v) => _channel = v),
          _drop('Tone', _tone, {'friendly': 'Friendly', 'firm': 'Firm', 'final': 'Final notice'}, (v) => _tone = v),
          _drop('Message language', _lang, {'en': 'English', 'hi': 'हिन्दी'}, (v) => _lang = v),
          if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_err!, style: const TextStyle(color: Colors.red))),
          Row(children: [
            if (widget.rule != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await ReceivablesRepo().deleteRule((widget.rule!['id'] as num).toInt());
                        if (mounted) Navigator.pop(context, true);
                      },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
            FilledButton(onPressed: _busy ? null : _save, child: Text(tr('save'))),
          ]),
        ]),
      ),
    );
  }
}
