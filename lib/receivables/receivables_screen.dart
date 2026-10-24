import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';

import '../core/money.dart';
import '../core/messenger.dart';
import '../data/repositories/receivables_repo.dart';
import '../l10n/strings.dart';
import '../theme/gp_colors.dart';
import 'reminder_rules_screen.dart';
import 'reminder_sheet.dart';

/// "Money to collect": who owes you, how old it is, and one-tap reminders. This is the screen the owner opens every morning.
class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  final _repo = ReceivablesRepo();
  late Future<_Data> _future;
  String _sort = 'overdue';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final r = await Future.wait([_repo.summary(), _repo.parties(sort: _sort), _repo.aging(), _repo.dueToday()]);
    return _Data(
      r[0] as Map<String, dynamic>,
      r[1] as List<Map<String, dynamic>>,
      r[2] as Map<String, dynamic>,
      r[3] as List<Map<String, dynamic>>,
    );
  }

  void _refresh() => setState(() { _future = _load(); });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('receivables')),
          actions: [
            IconButton(
              tooltip: tr('payment_reminders'),
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderRulesScreen())),
            ),
          ],
          bottom: TabBar(tabs: [Tab(text: tr('outstanding')), Tab(text: tr('aging')), Tab(text: tr('reminders'))]),
        ),
        body: FutureBuilder<_Data>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snap.error}'.replaceFirst('Exception: ', '')),
                  TextButton(onPressed: _refresh, child: Text(tr('retry'))),
                ]),
              );
            }
            final d = snap.data!;
            return TabBarView(children: [_outstanding(d), _aging(d), _today(d)]);
          },
        ),
      ),
    );
  }

  // ---------- tab 1 ----------
  Widget _outstanding(_Data d) {
    final s = d.summary;
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _SummaryRow(items: [
          _Stat(tr('to_collect'), inr(s['total_receivable'] ?? 0), null),
          _Stat(tr('overdue'), inr(s['overdue'] ?? 0), GPColors.danger),
        ]),
        const SizedBox(height: 8),
        _SummaryRow(items: [
          _Stat(tr('due_today'), inr(s['due_today'] ?? 0), GPColors.warning),
          _Stat(tr('next_7_days'), inr(s['due_next_7_days'] ?? 0), null),
          _Stat(tr('collected_month'), inr(s['collected_this_month'] ?? 0), GPColors.success),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text('${d.parties.length} customers', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          DropdownButton<String>(
            value: _sort,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'overdue', child: Text('Most overdue')),
              DropdownMenuItem(value: 'amount', child: Text('Biggest amount')),
              DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
              DropdownMenuItem(value: 'risk', child: Text('Highest risk')),
              DropdownMenuItem(value: 'name', child: Text('Name')),
            ],
            onChanged: (v) {
              if (v == null) return;
              _sort = v;
              _refresh();
            },
          ),
        ]),
        if (d.parties.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('nothing_pending')))),
        for (final p in d.parties) _PartyTile(p: p, onChanged: _refresh),
      ]),
    );
  }

  // ---------- tab 2 ----------
  Widget _aging(_Data d) {
    final b = Map<String, dynamic>.from(d.aging['buckets'] as Map);
    const order = [
      ['not_due', 'not_due', GPColors.success],
      ['d1_30', 'days_1_30', GPColors.warning],
      ['d31_60', 'days_31_60', GPColors.warning],
      ['d61_90', 'days_61_90', GPColors.danger],
      ['d90_plus', 'days_90_plus', GPColors.danger],
    ];
    final total = order.fold<num>(0, (a, o) => a + ((b[o[0]] as num?) ?? 0));
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final o in order)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(tr(o[1] as String), style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(inr((b[o[0]] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: total > 0 ? ((b[o[0]] as num?) ?? 0) / total : 0,
                color: o[2] as Color,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ]),
        ),
      if (((b['other'] as num?) ?? 0) != 0)
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Opening balance / advances'), trailing: Text(inr(b['other'] as num))),
      const Divider(),
      Text('Customers', style: Theme.of(context).textTheme.titleMedium),
      for (final p in List<Map<String, dynamic>>.from(d.aging['parties'] as List).where((p) => (p['balance'] as num) > 0))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${p['name']}'),
          subtitle: Text('1-30: ${inr(p['d1_30'])}   31-60: ${inr(p['d31_60'])}   60+: ${inr((p['d61_90'] as num) + (p['d90_plus'] as num))}'),
          trailing: Text(inr(p['balance'] as num), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
    ]);
  }

  // ---------- tab 3 ----------
  Widget _today(_Data d) {
    if (d.today.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr('no_reminders_today'), textAlign: TextAlign.center)));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(tr('reminders_today', {'n': '${d.today.length}'}), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final r in d.today)
        Card(
          child: ListTile(
            title: Text('${r['party_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${(r['invoices'] as List).length} invoice(s) · ${r['tone']}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(inr(r['total_due'] as num), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ]),
            onTap: () async {
              final done = await showReminderSheet(context, partyId: (r['party_id'] as num).toInt(), partyName: '${r['party_name']}', prepared: r);
              if (done == true) _refresh();
            },
          ),
        ),
    ]);
  }
}

class _Data {
  _Data(this.summary, this.parties, this.aging, this.today);
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> parties;
  final Map<String, dynamic> aging;
  final List<Map<String, dynamic>> today;
}

class _Stat {
  _Stat(this.label, this.value, this.color);
  final String label, value;
  final Color? color;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.items});
  final List<_Stat> items;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (final i in items)
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(i.value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: i.color)),
                  ),
                ]),
              ),
            ),
          ),
      ]);
}

class _PartyTile extends StatelessWidget {
  const _PartyTile({required this.p, required this.onChanged});
  final Map<String, dynamic> p;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final risk = '${p['risk_label']}';
    final riskColor = switch (risk) { 'low' => GPColors.success, 'medium' => GPColors.warning, 'high' => GPColors.danger, _ => GPColors.ink2 };
    final overdue = (p['overdue'] as num?) ?? 0;
    final paused = p['reminders_paused'] == true;
    final promise = p['open_promise'] as Map?;
    final pid = (p['party_id'] as num).toInt();
    return Card(
      child: ListTile(
        title: Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (overdue > 0) Text('${tr('overdue')} ${inr(overdue)}', style: const TextStyle(color: GPColors.danger, fontWeight: FontWeight.w700)),
          Text(tr('risk_$risk'), style: TextStyle(color: riskColor, fontWeight: FontWeight.w700)),
          if (promise != null) Text('Promised ${promise['promised_date']}'.split('T').first, style: const TextStyle(color: GPColors.info)),
          if (paused) const Text('Paused', style: TextStyle(fontStyle: FontStyle.italic)),
          if (p['over_credit_limit'] == true) const Text('Over credit limit', style: TextStyle(color: GPColors.danger)),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(inr(p['balance'] as num), style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('Remind', style: TextStyle(color: GPColors.primaryDeep, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
        onTap: () async {
          final done = await showReminderSheet(context, partyId: pid, partyName: '${p['name']}');
          if (done == true) onChanged();
        },
        onLongPress: () async {
          try {
            await ReceivablesRepo().setPaused(pid, !paused);
            AppMessenger.info(paused ? 'Reminders resumed' : 'Reminders paused for ${p['name']}');
            onChanged();
          } catch (e) {
            AppMessenger.error(e);
          }
        },
      ),
    );
  }
}
