import 'package:flutter/material.dart' hide Text;
import '../../../l10n/auto_translate.dart';
import '../../../l10n/gtext.dart';

import '../../../models/onboarding_data.dart';
import '../../../theme/gp_colors.dart';
import '../../../data/repositories/party_repo.dart';
import '../../../data/models/party_entity.dart';

import '../../../parties/models/party_model.dart';
import '../../../parties/screens/add_edit_party_flow.dart';

import '../models/invoice_draft.dart';
import '../widgets/inv_party_card.dart';

class InvPartyScreen extends StatefulWidget {
  final OnboardingData onboarding;
  final InvoiceDraft draft;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const InvPartyScreen({
    super.key,
    required this.onboarding,
    required this.draft,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<InvPartyScreen> createState() => _InvPartyScreenState();
}

class _InvPartyScreenState extends State<InvPartyScreen> {
  final _search = TextEditingController();
  final _repo = _PartyPickerRepo();

  bool get _isRetail => (widget.onboarding.businessType ?? "").toLowerCase() == "retailer";
  bool get _isWholesaleLike {
    final t = (widget.onboarding.businessType ?? "").toLowerCase();
    return t == "wholesaler" || t == "distributor";
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isSelected(Party p) {
    final sp = widget.draft.party;
    if (sp == null) return false;
    return !widget.draft.cashCustomer && sp.id == p.id;
    // (name+phone match is enough for now)
  }

  Future<void> _addCustomer() async {
    // Open Parties module add screen
    final PartyModel? created = await Navigator.push<PartyModel>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditPartyFlow(initial: null)),
    );

    if (created == null) return;

    // AddEditPartyFlow already saved it on the server; load the saved record.
    final savedEntity = await _repo.getById(created.id);
    if (savedEntity == null) return;

    // Auto-select newly added party in invoice draft
    setState(() {
      widget.draft.cashCustomer = false;
      widget.draft.party = _repo.toInvoiceParty(savedEntity);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${created.name} added")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requireParty = _isWholesaleLike;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
              const Expanded(
                child: Text(
                  "Select Customer",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: trs("Search name / phone"),
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),

          const SizedBox(height: 12),

          // Cash customer (Retail only)
          if (_isRetail && !requireParty) ...[
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  widget.draft.cashCustomer = true;
                  widget.draft.party = Party(
                    name: "Cash Customer",
                    phone: "-",
                    outstanding: 0,
                    gstRegistered: false,
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.draft.cashCustomer ? GPColors.tint : GPColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: widget.draft.cashCustomer ? GPColors.primary : GPColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: GPColors.primary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.person_outline_rounded, color: GPColors.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Cash Customer", style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text("Walk-in retail billing", style: TextStyle(color: GPColors.ink2)),
                        ],
                      ),
                    ),
                    if (widget.draft.cashCustomer)
                      const Icon(Icons.check_circle_rounded, color: GPColors.success),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Real parties list from Isar
          Expanded(
            child: StreamBuilder<List<PartyEntity>>(
              stream: _repo.watchAll(),
              builder: (context, snap) {
                final list = snap.data ?? [];

                final q = _search.text.trim().toLowerCase();
                final filtered = list.where((e) {
                  // In invoice picker we only want customers/both (not pure suppliers)
                  final type = (e.type).toLowerCase();
                  final isCustomerLike = type == "customer" || type == "both" || type.isEmpty;

                  if (!isCustomerLike) return false;

                  if (q.isEmpty) return true;

                  final name = e.name.toLowerCase();
                  final phone = e.phone.replaceAll(" ", "");
                  final qq = q.replaceAll(" ", "");
                  return name.contains(q) || phone.contains(qq);
                }).toList();

                if (filtered.isEmpty) {
                  return _EmptyState(onAdd: _addCustomer);
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final ent = filtered[i];
                    final p = _repo.toInvoiceParty(ent);

                    return InvPartyCard(
                      party: p,
                      selected: _isSelected(p),
                      onTap: () {
                        setState(() {
                          widget.draft.cashCustomer = false;
                          widget.draft.party = p;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Add customer (now real)
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: GPColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _addCustomer,
              child: const Text("➕ Add New Customer", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),

          const SizedBox(height: 12),

          // Continue
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
              onPressed: () {
                if (requireParty && widget.draft.party == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Wholesale requires a customer/party.")),
                  );
                  return;
                }
                widget.onContinue();
              },
              child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GPColors.tint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GPColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_rounded, size: 44),
            const SizedBox(height: 10),
            const Text("No customers found", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text("Add your first customer to continue", style: TextStyle(color: GPColors.ink2)),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GPColors.primary,
                  foregroundColor: GPColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onAdd,
                child: const Text("➕ Add Customer", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// Party picker helper: reads the shared server-backed PartyRepo.
class _PartyPickerRepo {
  final PartyRepo _parties = PartyRepo();

  Stream<List<PartyEntity>> watchAll() => _parties.watchAll();

  Future<PartyEntity?> getById(int id) => _parties.getById(id);

  Party toInvoiceParty(PartyEntity e) {
    // outstanding = what they owe us right now (live ledger balance)
    final outstanding = e.balance > 0 ? e.balance : 0.0;

    return Party(
      id: e.id,
      name: e.name,
      phone: e.phone,
      outstanding: outstanding,
      gstRegistered: e.gstRegistered,
    );
  }
}
