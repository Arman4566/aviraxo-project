import 'package:flutter/material.dart';

import '../core/messenger.dart';
import '../core/money.dart';
import '../data/repositories/extras_repo.dart';
import '../data/repositories/receivables_repo.dart' show ymd;
import '../l10n/strings.dart';
import '../theme/gp_colors.dart';

/// Expenses and other income. Works offline: an entry made without internet is queued and sent later.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _repo = ExtrasRepo();
  late Future<List<Map<String, dynamic>>> _future;
  late final DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => _repo.expenses(from: ymd(_from), to: ymd(DateTime.now()));
  void _reload() => setState(() => _future = _load());

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ExpenseForm(),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('expenses'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: Text(tr('add_expense'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: TextButton(onPressed: _reload, child: Text('${snap.error}. ${tr('retry')}')));
          final rows = snap.data!;
          num spent = 0, earned = 0;
          for (final r in rows) {
            (r['kind'] == 'income' ? (earned += (r['amount'] as num)) : (spent += (r['amount'] as num)));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
              Row(children: [
                Expanded(child: _tile('Spent this month', inr(spent), GPColors.danger)),
                const SizedBox(width: 8),
                Expanded(child: _tile(tr('other_income'), inr(earned), GPColors.success)),
              ]),
              const SizedBox(height: 12),
              if (rows.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No entries this month yet.'))),
              for (final r in rows)
                Dismissible(
                  key: ValueKey(r['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(color: GPColors.danger, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                  confirmDismiss: (_) async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete this entry?'),
                        content: Text('${r['category']} · ${inr(r['amount'] as num)}'),
                        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('cancel'))), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
                      ),
                    );
                    if (ok != true) return false;
                    try {
                      await _repo.deleteExpense((r['id'] as num).toInt());
                      return true;
                    } catch (e) {
                      AppMessenger.error(e);
                      return false;
                    }
                  },
                  onDismissed: (_) => _reload(),
                  child: Card(
                    child: ListTile(
                      leading: Icon(r['kind'] == 'income' ? Icons.south_west : Icons.north_east, color: r['kind'] == 'income' ? GPColors.success : GPColors.danger),
                      title: Text('${r['category']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${r['entry_date']}'.split('T').first + ((r['note'] ?? '') != '' ? ' · ${r['note']}' : '') + (r['recurring'] != null ? ' · repeats ${r['recurring']}' : '')),
                      trailing: Text(inr(r['amount'] as num), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }

  Widget _tile(String label, String value, Color c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c))),
          ]),
        ),
      );
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  static const _cats = ['Rent', 'Salary', 'Electricity', 'Transport', 'Raw material', 'Marketing', 'Repairs', 'Tea & snacks', 'Internet & phone', 'Other'];
  final _amount = TextEditingController();
  final _gst = TextEditingController();
  final _note = TextEditingController();
  String _kind = 'expense', _cat = 'Rent', _mode = 'cash';
  String? _recurring;
  DateTime _date = DateTime.now();
  String? _err;
  bool _busy = false;

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim());
    final gst = _gst.text.trim().isEmpty ? 0.0 : double.tryParse(_gst.text.trim());
    if (amt == null || amt <= 0) return setState(() => _err = 'Enter the amount, for example 1500.');
    if (gst == null || gst < 0 || gst > amt) return setState(() => _err = 'GST must be a number that is not more than the amount.');
    setState(() {
      _err = null;
      _busy = true;
    });
    try {
      final queued = await ExtrasRepo().addExpense({
        'kind': _kind,
        'category': _cat,
        'amount': toPaise(amt),
        'gst_amount': toPaise(gst),
        'mode': _mode,
        'entry_date': ymd(_date),
        'note': _note.text.trim(),
        if (_recurring != null) 'recurring': _recurring,
      });
      if (queued) AppMessenger.info(tr('offline_saved'));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _err = '$e'.replaceFirst('Exception: ', '');
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('add_expense'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [ButtonSegment(value: 'expense', label: Text(tr('expenses'))), ButtonSegment(value: 'income', label: Text(tr('other_income')))],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₹)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _cat,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [for (final c in _cats) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _cat = v ?? _cat),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _mode,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: [for (final m in ['cash', 'upi', 'card', 'bank', 'cheque', 'other']) DropdownMenuItem(value: m, child: Text(m))],
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _gst, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'GST included (₹)'))),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _recurring,
            decoration: const InputDecoration(labelText: 'Repeats'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Does not repeat')),
              DropdownMenuItem(value: 'weekly', child: Text('Every week')),
              DropdownMenuItem(value: 'monthly', child: Text('Every month')),
              DropdownMenuItem(value: 'yearly', child: Text('Every year')),
            ],
            onChanged: (v) => setState(() => _recurring = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(ymd(_date)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
              if (d != null) setState(() => _date = d);
            },
          ),
          if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_err!, style: const TextStyle(color: GPColors.danger))),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _save, child: Text(tr('save')))),
        ]),
      ),
    );
  }
}
