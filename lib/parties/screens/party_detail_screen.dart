import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';

import '../../core/messenger.dart';
import '../../data/models/party_entity.dart';
import '../../data/repositories/party_repo.dart';
import '../../data/repositories/workspace_repo.dart';
import '../../invoices/invoice_detail_screen.dart';
import '../../invoices/invoice_flow/invoice_flow.dart';
import '../../invoices/invoice_flow/models/invoice_draft.dart';
import '../../payments/record_payment_sheet.dart';
import '../../theme/gp_colors.dart';
import '../models/party_model.dart';
import '../widgets/due_badge.dart';
import 'add_edit_party_flow.dart';

class PartyDetailScreen extends StatefulWidget {
  final int partyId;
  const PartyDetailScreen({super.key, required this.partyId});

  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  final _repo = PartyRepo();

  PartyEntity? _party;
  PartyLedger? _ledger;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.getById(widget.partyId), _repo.ledger(widget.partyId)]);
      if (!mounted) return;
      setState(() {
        _party = results[0] as PartyEntity?;
        _ledger = results[1] as PartyLedger;
      });
    } catch (e) {
      AppMessenger.error(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(PartyModel party) async {
    final updated = await Navigator.push<PartyModel>(
      context,
      MaterialPageRoute(builder: (_) => AddEditPartyFlow(initial: party)),
    );
    if (updated != null && mounted) {
      AppMessenger.info("${updated.name} updated");
      await _load();
    }
  }

  Future<void> _delete(PartyModel party) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Party?"),
        content: Text("This will remove ${party.name}. Parties with past invoices are archived so your records stay intact."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _repo.deleteById(party.id);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        AppMessenger.error(e);
      }
    }
  }

  Future<void> _createInvoice(PartyEntity e) async {
    try {
      final data = await WorkspaceRepo().loadWorkspaceData();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceFlow(
            onboarding: data,
            initialParty: Party(
              id: e.id,
              name: e.name,
              phone: e.phone,
              outstanding: e.balance > 0 ? e.balance : 0,
              gstRegistered: e.gstRegistered,
            ),
          ),
        ),
      );
      await _load();
    } catch (err) {
      AppMessenger.error(err);
    }
  }

  Future<void> _recordPayment(PartyEntity e) async {
    final saved = await showRecordPaymentSheet(
      context,
      partyId: e.id,
      partyName: e.name,
      suggestedAmount: e.balance > 0 ? e.balance : null,
    );
    if (saved) await _load();
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final e = _party;
    if (e == null) {
      return const Scaffold(body: Center(child: Text("Party not found")));
    }

    final party = PartyModel.fromEntity(e);
    final entries = _ledger?.entries.reversed.toList() ?? const <LedgerEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(party.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: GPColors.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => _edit(party)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == "delete") _delete(party);
            },
            itemBuilder: (_) => const [PopupMenuItem(value: "delete", child: Text("Delete"))],
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GPColors.tint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: GPColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(party.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 6),
                    Text(party.phone, style: TextStyle(color: GPColors.ink2)),
                    if (party.email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(party.email, style: TextStyle(color: GPColors.ink2)),
                    ],
                    if (party.paymentTerm.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text("Terms: ${party.paymentTerm}", style: TextStyle(color: GPColors.ink2)),
                    ],
                    const SizedBox(height: 10),
                    DueBadge(party: party),
                  ],
                ),
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text("Transactions", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            if (entries.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text("No invoices or payments yet.", style: TextStyle(color: GPColors.ink2))),
              ),
            for (final en in entries)
              ListTile(
                onTap: en.isInvoice
                    ? () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: en.id)),
                        );
                        await _load();
                      }
                    : null,
                leading: CircleAvatar(
                  backgroundColor: (en.isInvoice ? GPColors.primary : GPColors.success).withOpacity(0.15),
                  child: Icon(
                    en.isInvoice ? Icons.receipt_long_rounded : Icons.payments_rounded,
                    color: en.isInvoice ? GPColors.ink : GPColors.success,
                    size: 20,
                  ),
                ),
                title: Text(en.isInvoice ? en.ref : "Payment • ${en.ref.toUpperCase()}",
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text("${_d(en.date)} • Balance ₹${en.balance.toStringAsFixed(2)}"),
                trailing: Text(
                  en.isInvoice ? "+ ₹${en.debit.toStringAsFixed(2)}" : "- ₹${en.credit.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: en.isInvoice ? Colors.red : GPColors.success,
                  ),
                ),
              ),
            if (_ledger != null && _ledger!.openingBalance != 0)
              ListTile(
                title: const Text("Opening balance"),
                trailing: Text("₹${_ledger!.openingBalance.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GPColors.surface,
          border: Border(top: BorderSide(color: GPColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GPColors.primary),
                onPressed: () => _createInvoice(e),
                child: const Text("Create Invoice"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _recordPayment(e),
                child: const Text("Record Payment"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
