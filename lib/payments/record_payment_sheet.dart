import 'package:flutter/material.dart';

import '../core/messenger.dart';
import '../l10n/strings.dart';
import '../data/repositories/payment_repo.dart';
import '../theme/gp_colors.dart';

/// Bottom sheet to record money received from a party.
/// Returns true when a payment was saved.
///
/// - [invoiceId] set: the payment is applied to that invoice.
/// - otherwise the server settles the party's oldest open invoices first; any extra stays as an advance.
Future<bool> showRecordPaymentSheet(
  BuildContext context, {
  required int partyId,
  required String partyName,
  double? suggestedAmount,
  int? invoiceId,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _RecordPaymentSheet(
      partyId: partyId,
      partyName: partyName,
      suggestedAmount: suggestedAmount,
      invoiceId: invoiceId,
    ),
  );
  return ok == true;
}

class _RecordPaymentSheet extends StatefulWidget {
  const _RecordPaymentSheet({
    required this.partyId,
    required this.partyName,
    this.suggestedAmount,
    this.invoiceId,
  });

  final int partyId;
  final String partyName;
  final double? suggestedAmount;
  final int? invoiceId;

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  late final TextEditingController _amount;
  final _ref = TextEditingController();
  String _mode = 'cash';
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _modes = ['cash', 'upi', 'card', 'bank', 'cheque', 'other'];

  @override
  void initState() {
    super.initState();
    final s = widget.suggestedAmount;
    _amount = TextEditingController(text: (s != null && s > 0) ? s.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '') : '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      AppMessenger.error('Enter an amount greater than 0');
      return;
    }
    setState(() => _saving = true);
    try {
      final queued = await PaymentRepo().receive(
        partyId: widget.partyId,
        amount: amount,
        mode: _mode,
        date: _date,
        reference: _ref.text.trim(),
        invoiceId: widget.invoiceId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      AppMessenger.info(queued ? tr('offline_saved') : 'Payment of ₹${amount.toStringAsFixed(2)} recorded');
    } catch (e) {
      AppMessenger.error(e);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = '${_date.day.toString().padLeft(2, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.year}';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(color: GPColors.line, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 4),
          Text('From ${widget.partyName}', style: const TextStyle(color: GPColors.ink2)),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount received (₹)'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _modes
                .map((m) => ChoiceChip(
                      label: Text(m.toUpperCase()),
                      selected: _mode == m,
                      onSelected: (_) => setState(() => _mode = m),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ref,
            decoration: const InputDecoration(labelText: 'Reference / UTR / cheque no. (optional)'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded),
            label: Text('Date: $d'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GPColors.primary,
                foregroundColor: GPColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Payment', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
