import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';
import '../widgets/glass.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/messenger.dart';
import '../core/prefs.dart';
import '../data/repositories/ai_repo.dart';
import '../data/repositories/receivables_repo.dart';
import '../l10n/strings.dart';
import '../theme/gp_colors.dart';

/// Bottom sheet for chasing one customer: shows the ready-written message, lets the owner edit the tone,
/// then opens WhatsApp / SMS / email with the text filled in. Also offers UPI, "promise to pay" and pause.
///
/// Pass [prepared] (an item from /reminders/due) or just [partyId] to compose on demand.
Future<bool?> showReminderSheet(BuildContext context, {required int partyId, required String partyName, Map<String, dynamic>? prepared}) {
  return showGlassSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReminderSheet(partyId: partyId, partyName: partyName, prepared: prepared),);
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.partyId, required this.partyName, this.prepared});
  final int partyId;
  final String partyName;
  final Map<String, dynamic>? prepared;
  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  final _repo = ReceivablesRepo();
  final _ai = AiRepo();
  bool _aiBusy = false;
  Map<String, dynamic>? _data;
  String? _error;
  String _tone = 'friendly';
  bool _busy = false;
  final _msg = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.prepared != null) {
      _apply(widget.prepared!);
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> d) {
    _data = d;
    _tone = (d['tone'] as String?) ?? 'friendly';
    _msg.text = (d['message'] as String?) ?? '';
  }

  Future<void> _load({String? tone}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await _repo.compose(widget.partyId, tone: tone, language: AppPrefs.I.language.value);
      if (!mounted) return;
      setState(() {
        _apply(d);
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : '$e';
        _busy = false;
      });
    }
  }

  /// Asks the AI to reword the message. The server keeps every amount and date, and falls back to the plain text if the AI is
  /// unavailable, so this can never lose or change what is owed.
  Future<void> _aiWrite() async {
    setState(() => _aiBusy = true);
    try {
      final d = await _ai.reminderDraft(widget.partyId, tone: _tone, language: AppPrefs.I.language.value);
      if (!mounted) return;
      setState(() {
        _apply(d);
        _tone = (d['tone'] as String?) ?? _tone;
      });
      if (d['ai'] != true) AppMessenger.info('AI is not available right now, so the standard message is shown.');
    } catch (e) {
      AppMessenger.error(e is ApiException ? e.message : e);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  /// The server built the links from its own text; if the owner edited the message we rebuild the link here.
  /// Query values are percent-encoded by hand: Uri.replace(queryParameters) turns spaces into "+", which
  /// mail and SMS apps show literally.
  Uri _link(String channel) {
    final base = (_data?['${channel}_url'] as String?) ?? '';
    if (base.isEmpty) return Uri();
    final text = Uri.encodeComponent(_msg.text);
    final at = base.indexOf('?');
    final head = at < 0 ? base : base.substring(0, at);
    final params = <String>[];
    if (at >= 0) {
      for (final kv in base.substring(at + 1).split('&')) {
        final k = kv.split('=').first;
        if (k == 'text' || k == 'body') continue; // replaced by the edited message
        params.add(kv);
      }
    }
    params.add('${channel == 'whatsapp' ? 'text' : 'body'}=$text');
    return Uri.parse('$head?${params.join('&')}');
  }

  Future<void> _send(String channel) async {
    final d = _data;
    if (d == null) return;
    if (channel != 'email' && d['has_phone'] != true) {
      AppMessenger.info('This customer has no phone number saved.');
      return;
    }
    final uri = _link(channel);
    final ok = uri.toString().isNotEmpty && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      AppMessenger.info('Could not open the app. The message was copied instead.');
      await Clipboard.setData(ClipboardData(text: _msg.text));
      return;
    }
    // Record it only after the other app opened, so "sent" really means the owner got as far as sending.
    try {
      await _repo.logReminder(
        partyId: widget.partyId,
        channel: channel,
        message: _msg.text,
        totalDue: (d['total_due'] as num).toInt(),
        items: List<Map<String, dynamic>>.from((d['items'] as List?) ?? const []),
      );
    } catch (_) {/* logging is best-effort; the message itself was already sent */}
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _promise() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
      helpText: tr('promise_to_pay'),
    );
    if (date == null) return;
    try {
      await _repo.promise(partyId: widget.partyId, date: date);
      AppMessenger.info('Noted. Reminders for ${widget.partyName} pause until ${ymd(date)}.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      AppMessenger.error(e);
    }
  }

  Future<void> _skip() async {
    final d = _data;
    if (d == null) return;
    try {
      await _repo.logReminder(
        partyId: widget.partyId,
        channel: (d['channel'] as String?) ?? 'whatsapp',
        message: '',
        totalDue: (d['total_due'] as num).toInt(),
        items: List<Map<String, dynamic>>.from((d['items'] as List?) ?? const []),
        status: 'skipped',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      AppMessenger.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tr('remind')} ${widget.partyName}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: GPColors.danger)),
              TextButton(onPressed: _load, child: Text(tr('retry'))),
            ] else if (d == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'friendly', label: Text('Friendly')),
                  ButtonSegment(value: 'firm', label: Text('Firm')),
                  ButtonSegment(value: 'final', label: Text('Final')),
                ],
                selected: {_tone},
                onSelectionChanged: _busy ? null : (s) => _load(tone: s.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: _msg, maxLines: 8, minLines: 4, decoration: InputDecoration(labelText: trs('Message (you can edit it)'))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: () => _send('whatsapp'), icon: const Icon(Icons.chat), label: Text(tr('send_whatsapp')))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: () => _send('sms'), icon: const Icon(Icons.sms_outlined), label: Text(tr('send_sms')))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: () => _send('email'), icon: const Icon(Icons.email_outlined), label: Text(tr('send_email')))),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                if ((d['upi_url'] as String?)?.isNotEmpty ?? false)
                  ActionChip(
                    avatar: const Icon(Icons.qr_code_2, size: 18),
                    label: Text(tr('copy_upi')),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: d['upi_url'] as String));
                      AppMessenger.info('UPI payment link copied. Paste it in any chat.');
                    },
                  ),
                ActionChip(
                  avatar: _aiBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Write with AI'),
                  onPressed: _aiBusy ? null : _aiWrite,
                ),
                ActionChip(avatar: const Icon(Icons.event_available, size: 18), label: Text(tr('promise_to_pay')), onPressed: _promise),
                if (widget.prepared != null) ActionChip(avatar: const Icon(Icons.skip_next, size: 18), label: Text(tr('skip_today')), onPressed: _skip),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
