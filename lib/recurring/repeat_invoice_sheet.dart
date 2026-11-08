import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';

import '../core/messenger.dart';
import '../core/money.dart';
import '../data/models/invoice_entity.dart';
import '../data/repositories/recurring_repo.dart';

/// Bottom sheet that turns an existing invoice into a repeating schedule.
Future<void> showRepeatInvoiceSheet(BuildContext context, InvoiceEntity inv) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RepeatSheet(inv: inv),
  );
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({required this.inv});
  final InvoiceEntity inv;
  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late final _name = TextEditingController(text: widget.inv.partyName);
  final _dueDays = TextEditingController(text: '0');
  String _freq = 'monthly';
  DateTime _start = DateTime.now().add(const Duration(days: 30));
  DateTime? _end;
  bool _busy = false;

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool isEnd) async {
    final d = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_end ?? _start) : _start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d != null) setState(() { if (isEnd) { _end = d; } else { _start = d; } });
  }

  Future<void> _save() async {
    final inv = widget.inv;
    if (inv.partyId == null) {
      AppMessenger.info(trs("Choose a saved customer first (not a cash sale)."));
      return;
    }
    setState(() { _busy = true; });
    try {
      await RecurringRepo().create({
        'name': _name.text.trim().isEmpty ? inv.partyName : _name.text.trim(),
        'party_id': inv.partyId,
        'frequency': _freq,
        'start_date': _iso(_start),
        if (_end != null) 'end_date': _iso(_end!),
        'doc_type': inv.docType,
        'payment_method': inv.paymentMethod,
        'due_days': int.tryParse(_dueDays.text.trim()) ?? 0,
        'gst_enabled': inv.taxTotal > 0,
        'notes': inv.notes,
        'terms': inv.terms,
        'lines': [
          for (final l in inv.lines)
            {
              'name': l.name,
              'unit': l.unit.isEmpty ? 'pcs' : l.unit,
              'hsn': l.hsn,
              'gst_slab': l.gstSlab,
              'qty': l.qty,
              'rate': toPaise(l.rate),
              'discount_is_percent': l.discountIsPercent,
              'discount_value': l.discountIsPercent ? l.discountValue : toPaise(l.discountValue),
              'tax_inclusive': false,
            }
        ],
      });
      if (mounted) Navigator.pop(context);
      AppMessenger.info(trs("Schedule created"));
    } catch (e) {
      AppMessenger.error(e);
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Repeat this invoice", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: InputDecoration(labelText: trs("Schedule name"))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _freq,
              decoration: InputDecoration(labelText: trs("How often")),
              items: [
                DropdownMenuItem(value: 'weekly', child: Text("Weekly")),
                DropdownMenuItem(value: 'monthly', child: Text("Monthly")),
                DropdownMenuItem(value: 'quarterly', child: Text("Quarterly")),
                DropdownMenuItem(value: 'yearly', child: Text("Yearly")),
              ],
              onChanged: (v) => setState(() { _freq = v ?? 'monthly'; }),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("First invoice on"),
              subtitle: Text(_iso(_start)),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: () => _pick(false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Stop after (optional)"),
              subtitle: Text(_end == null ? trs("Never") : _iso(_end!)),
              trailing: _end == null
                  ? const Icon(Icons.calendar_today_rounded)
                  : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() { _end = null; })),
              onTap: () => _pick(true),
            ),
            TextField(
              controller: _dueDays,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: trs("Payment due after (days)")),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? "Saving…" : "Create schedule"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
