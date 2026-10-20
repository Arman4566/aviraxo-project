import 'package:flutter/material.dart';
import '../../core/messenger.dart';
import '../../theme/gp_colors.dart';
import '../../data/repositories/party_repo.dart';
import '../../data/models/party_entity.dart';
import '../models/party_model.dart';

class AddEditPartyFlow extends StatefulWidget {
  final PartyModel? initial;
  const AddEditPartyFlow({super.key, required this.initial});

  @override
  State<AddEditPartyFlow> createState() => _AddEditPartyFlowState();
}

class _AddEditPartyFlowState extends State<AddEditPartyFlow> {
  final _repo = PartyRepo();

  final _page = PageController();
  int _step = 0;

  // Step 1
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  PartyType _type = PartyType.customer;

  // Step 2
  bool _gst = false;
  final _gstin = TextEditingController();
  final _state = TextEditingController();
  final _billing = TextEditingController();
  final _shipping = TextEditingController();

  // Step 3
  final _opening = TextEditingController();
  bool _toReceive = true;
  final _creditLimit = TextEditingController();
  String _terms = "Immediate";

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;

    if (p != null) {
      _name.text = p.name;
      _phone.text = p.phone;
      _email.text = p.email;
      _type = p.type;

      _gst = p.gstRegistered;
      _gstin.text = p.gstin;
      _state.text = p.state;
      _billing.text = p.billingAddress;
      _shipping.text = p.shippingAddress;

      _opening.text = p.openingBalance.toStringAsFixed(0);
      _toReceive = p.toReceive;
      _creditLimit.text = p.creditLimit.toStringAsFixed(0);
      _terms = p.paymentTerm;
    } else {
      _opening.text = "0";
      _creditLimit.text = "0";
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _gstin.dispose();
    _state.dispose();
    _billing.dispose();
    _shipping.dispose();
    _opening.dispose();
    _creditLimit.dispose();
    _page.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _step = i);
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? "New Party" : _name.text.trim();

    final model = PartyModel(
      id: widget.initial?.id ?? 0, // ✅ 0 means new; Isar will assign
      name: name,
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      type: _type,
      gstRegistered: _gst,
      gstin: _gst ? _gstin.text.trim() : "",
      state: _state.text.trim(),
      billingAddress: _billing.text.trim(),
      shippingAddress: _shipping.text.trim(),
      openingBalance: double.tryParse(_opening.text) ?? 0,
      toReceive: _toReceive,
      creditLimit: double.tryParse(_creditLimit.text) ?? 0,
      paymentTerm: _terms,
      lastTxn: DateTime.now(),
    );

    // Load base entity if editing so we preserve createdAtMs, etc.
    PartyEntity? base;
    if (_isEdit) {
      base = await _repo.getById(model.id);
    }

    final entity = model.toEntity(base: base);
    final PartyModel savedModel;
    try {
      final savedId = await _repo.upsert(entity);
      savedModel = PartyModel.fromEntity((await _repo.getById(savedId))!);
    } catch (e) {
      AppMessenger.error(e);
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _SuccessSheet(
        isEdit: _isEdit,
        onCreateInvoice: () {
          Navigator.pop(context); // close sheet
          Navigator.pop(context, savedModel); // return to list
        },
        onAddAnother: () {
          Navigator.pop(context);
          if (!_isEdit) {
            _name.clear();
            _phone.clear();
            _email.clear();
            _gst = false;
            _gstin.clear();
            _state.clear();
            _billing.clear();
            _shipping.clear();
            _opening.text = "0";
            _creditLimit.text = "0";
            _toReceive = true;
            _terms = "Immediate";
            _type = PartyType.customer;
            _go(0);
            setState(() {});
          }
        },
        onGoList: () {
          Navigator.pop(context);
          Navigator.pop(context, savedModel);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () =>
                    _step == 0 ? Navigator.pop(context) : _go(_step - 1),
                  ),
                  Expanded(
                    child: Text(
                      _isEdit ? "Edit Party" : "Add Party",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: i == 2 ? 0 : 10),
                      decoration: BoxDecoration(
                        color: i <= _step ? GPColors.primary : GPColors.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _step1(),
                  _step2(),
                  _step3(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GPColors.primary,
                    foregroundColor: GPColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _step < 2 ? _go(_step + 1) : _save(),
                  child: Text(
                    _step < 2 ? "Next" : "Save Party",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _step1() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Basic Info",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          decoration: const InputDecoration(hintText: "Party Name"),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: "Phone Number"),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: "Email (optional)"),
        ),
        const SizedBox(height: 12),
        const Text("Party Type", style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: PartyType.values.map((t) {
            final on = t == _type;
            return ChoiceChip(
              label: Text(t.name),
              selected: on,
              onSelected: (_) => setState(() => _type = t),
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _step2() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          value: _gst,
          onChanged: (v) => setState(() => _gst = v),
          title: const Text("GST Registered"),
        ),
        if (_gst) ...[
          TextField(
            controller: _gstin,
            decoration: const InputDecoration(hintText: "GSTIN"),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _state,
          decoration: const InputDecoration(hintText: "State"),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _billing,
          decoration: const InputDecoration(hintText: "Billing Address"),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _shipping,
          decoration:
          const InputDecoration(hintText: "Shipping Address (optional)"),
        ),
      ],
    );
  }

  Widget _step3() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Credit Settings",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 10),
        TextField(
          controller: _opening,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Opening Balance"),
        ),
        SwitchListTile(
          value: _toReceive,
          onChanged: (v) => setState(() => _toReceive = v),
          title: const Text("To Receive (customer owes you)"),
        ),
        TextField(
          controller: _creditLimit,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Credit Limit"),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField(
          value: _terms,
          items: const ["Immediate", "7 days", "15 days", "30 days"]
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _terms = v as String),
          decoration: const InputDecoration(hintText: "Payment Terms"),
        )
      ],
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onCreateInvoice;
  final VoidCallback onAddAnother;
  final VoidCallback onGoList;

  const _SuccessSheet({
    required this.isEdit,
    required this.onCreateInvoice,
    required this.onAddAnother,
    required this.onGoList,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_rounded,
            color: GPColors.success, size: 44),
        const SizedBox(height: 10),
        Text(isEdit ? "Party updated successfully" : "Party added successfully",
            style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        ElevatedButton(onPressed: onCreateInvoice, child: const Text("Create Invoice")),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onAddAnother, child: const Text("Add another")),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onGoList, child: const Text("Go to Parties")),
      ]),
    );
  }
}
