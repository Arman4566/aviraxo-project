import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';

import '../core/messenger.dart';
import '../data/repositories/recurring_repo.dart';
import '../theme/gp_colors.dart';

/// Schedules that raise an invoice automatically (rent, subscriptions, retainers).
class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});
  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final _repo = RecurringRepo();
  List<RecurringSchedule> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await _repo.list();
      if (mounted) setState(() { _items = l; });
    } catch (e) {
      AppMessenger.error(e);
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _act(Future<List<RecurringSchedule>> Function() f) async {
    try {
      final l = await f();
      if (mounted) setState(() { _items = l; });
    } catch (e) {
      AppMessenger.error(e);
    }
  }

  Future<void> _runNow() async {
    try {
      final n = await _repo.runDue();
      AppMessenger.info(n == 0 ? trs("Nothing is due today") : '${trs("Invoices created")}: $n');
      await _load();
    } catch (e) {
      AppMessenger.error(e);
    }
  }

  Future<void> _confirmDelete(RecurringSchedule s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete schedule?"),
        content: const Text("Invoices already created are kept."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete")),
        ],
      ),
    );
    if (ok == true) _act(() => _repo.remove(s.id));
  }

  String _freq(String f) {
    switch (f) {
      case 'weekly': return trs("Weekly");
      case 'quarterly': return trs("Quarterly");
      case 'yearly': return trs("Yearly");
      default: return trs("Monthly");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recurring invoices"),
        actions: [IconButton(tooltip: trs("Run now"), icon: const Icon(Icons.play_circle_outline_rounded), onPressed: _runNow)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(trs("No schedules yet. Open any invoice and tap “Repeat” to create one."), textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final s = _items[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: GPColors.tint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                              Text('₹${s.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ]),
                            const SizedBox(height: 4),
                            Text('${s.partyName} • ${_freq(s.frequency)}'),
                            Text(s.isActive ? '${trs("Next")}: ${s.nextDate}' : trs("Paused")),
                            if (s.lastError.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(s.lastError, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _act(() => s.isActive ? _repo.pause(s.id) : _repo.resume(s.id)),
                                  child: Text(s.isActive ? "Pause" : "Resume"),
                                ),
                                TextButton(
                                  onPressed: () => _confirmDelete(s),
                                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
