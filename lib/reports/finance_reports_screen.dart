import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';

import '../core/money.dart';
import '../data/repositories/extras_repo.dart';
import '../data/repositories/receivables_repo.dart' show ymd;
import '../l10n/strings.dart';

/// Profit & loss, cash flow and GST working figures for a chosen period.
/// GST figures are working numbers to help fill the return, not a filed return; ITC is estimated from expense GST.
class FinanceReportsScreen extends StatefulWidget {
  const FinanceReportsScreen({super.key});
  @override
  State<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends State<FinanceReportsScreen> {
  final _repo = ExtrasRepo();
  String _report = 'profit-loss';
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    final f = _report == 'day-book'
        ? _repo.report('day-book', date: ymd(_to))
        : _repo.report(_report, from: ymd(_from), to: ymd(_to));
    setState(() {
      _future = f;
    });
  }

  Future<void> _pick(bool from) async {
    final d = await showDatePicker(context: context, initialDate: from ? _from : _to, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d == null) return;
    _from = from ? d : _from;
    _to = from ? _to : d;
    if (_from.isAfter(_to)) _from = _to;
    _run();
  }

  /// Shows a report generically: top-level numbers (paise) as rows, nested maps as sections. Lists show their length.
  List<Widget> _render(Map<String, dynamic> m, [int depth = 0]) {
    final out = <Widget>[];
    m.forEach((k, v) {
      final label = k.replaceAll('_', ' ');
      if (v is Map) {
        out.add(Padding(
          padding: EdgeInsets.only(top: 12, left: depth * 8.0),
          child: Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        ));
        out.addAll(_render(Map<String, dynamic>.from(v), depth + 1));
      } else if (v is num) {
        final isCount = k.contains('count') || k.contains('days') || k.endsWith('_no') || k == 'rate';
        out.add(Padding(
          padding: EdgeInsets.only(left: depth * 8.0),
          child: ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(label), trailing: Text(isCount ? '$v' : inr(v), style: const TextStyle(fontWeight: FontWeight.w800))),
        ));
      } else if (v is List) {
        out.add(Padding(
          padding: EdgeInsets.only(left: depth * 8.0),
          child: ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(label), trailing: Text('${v.length} rows')),
        ));
      } else if (v is String && k != 'as_of' && v.length < 60) {
        out.add(Padding(padding: EdgeInsets.only(left: depth * 8.0), child: ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(label), trailing: Text(v))));
      }
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final reports = {
      'profit-loss': tr('profit_loss'),
      'cash-flow': tr('cash_flow'),
      'cash-bank': tr('cash_bank'),
      'day-book': tr('day_book'),
      'gstr1': 'GSTR-1',
      'gstr3b': 'GSTR-3B',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Financial reports')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          value: _report,
          decoration: InputDecoration(labelText: trs('Report')),
          items: [for (final e in reports.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) {
            _report = v ?? _report;
            _run();
          },
        ),
        const SizedBox(height: 8),
        Row(children: [
          if (_report != 'day-book') Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text('From ${ymd(_from)}'))),
          if (_report != 'day-book') const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text('${_report == 'day-book' ? 'Date' : 'To'} ${ymd(_to)}'))),
        ]),
        const SizedBox(height: 8),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            if (snap.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text('${snap.error}'.replaceFirst('Exception: ', '')));
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _render(snap.data!));
          },
        ),
        if (_report.startsWith('gstr')) const Padding(padding: EdgeInsets.only(top: 16), child: Text('Working figures to help you file. Check them with your CA before filing.')),
      ]),
    );
  }
}
