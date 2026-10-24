import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import '../../widgets/glass.dart';
import '../../widgets/barcode_scanner_page.dart';
import '../../theme/gp_colors.dart';
import '../models/inventory_item.dart';

class AddEditItemFlow extends StatefulWidget {
  final bool gstEnabled;
  final bool stockEnabled;
  final InventoryItem? initial;

  const AddEditItemFlow({
    super.key,
    required this.gstEnabled,
    required this.stockEnabled,
    required this.initial,
  });

  @override
  State<AddEditItemFlow> createState() => _AddEditItemFlowState();
}

class _AddEditItemFlowState extends State<AddEditItemFlow> {
  final _page = PageController();
  int _step = 0;

  // Step 1
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  String _category = "Electronics";
  String _unit = "pcs";

  // Step 2
  final _purchase = TextEditingController();
  final _selling = TextEditingController();
  bool _inclusive = true;
  int _gst = 18;

  // Step 3
  final _openingStock = TextEditingController();
  final _lowStock = TextEditingController();
  final _location = TextEditingController();

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();

    final it = widget.initial;
    if (it != null) {
      _name.text = it.name;
      _sku.text = it.sku;
      _barcode.text = it.barcode;
      _category = it.category;
      _unit = it.unit;

      _purchase.text =
      it.purchasePrice == 0 ? "" : it.purchasePrice.toStringAsFixed(0);
      _selling.text =
      it.sellingPrice == 0 ? "" : it.sellingPrice.toStringAsFixed(0);
      _inclusive = it.priceInclusive;
      _gst = it.gstRate;

      _openingStock.text = it.stockQty.toString();
      _lowStock.text = it.lowStockLevel.toString();
      _location.text = it.location;
    } else {
      _lowStock.text = "5";
      _openingStock.text = "0";
      _location.text = "Main Store";
      // ✅ prices remain empty by default (placeholders only)
      _purchase.text = "";
      _selling.text = "";
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _purchase.dispose();
    _selling.dispose();
    _openingStock.dispose();
    _lowStock.dispose();
    _location.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() => _step = step);
    _page.animateToPage(
      step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step < 2) _go(_step + 1);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step > 0) {
      _go(_step - 1);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final name = _name.text.trim().isEmpty ? "New Item" : _name.text.trim();
    final sku =
    _sku.text.trim().isEmpty ? InventoryItem.genSku(name) : _sku.text.trim();

    final purchase = double.tryParse(_purchase.text.trim()) ?? 0;
    final selling = double.tryParse(_selling.text.trim()) ?? 0;

    final opening = int.tryParse(_openingStock.text.trim()) ?? 0;
    final low = int.tryParse(_lowStock.text.trim()) ?? 5;

    final item = InventoryItem(
      id: widget.initial?.id ?? 0,
      name: name,
      sku: sku,
      category: _category,
      unit: _unit,

      barcodeEnabled: _barcode.text.trim().isNotEmpty,
      barcode: _barcode.text.trim(),

      purchasePrice: purchase,
      sellingPrice: selling,
      priceInclusive: _inclusive,
      gstRate: widget.gstEnabled ? _gst : 0,
      gstEnabled: widget.gstEnabled,

      stockEnabled: widget.stockEnabled,
      stockQty: widget.stockEnabled ? opening : 0,
      lowStockLevel: widget.stockEnabled ? low : 0,
      location: _location.text.trim(),

      // keep counters stable
      stockInTotal: widget.initial?.stockInTotal ?? 0,
      stockOutTotal: widget.initial?.stockOutTotal ?? 0,

      updatedAt: DateTime.now(),
    );

    await showGlassSheet(
      context: context,
      builder: (_) => _SuccessSheet(
        isEdit: _isEdit,
        onAddAnother: () {
          Navigator.pop(context);
          if (!_isEdit) {
            _name.clear();
            _sku.clear();
            _purchase.clear();
            _selling.clear();
            _openingStock.text = "0";
            _lowStock.text = "5";
            setState(() {});
            _go(0);
          }
        },
        onGoInventory: () {
          Navigator.pop(context);
          Navigator.pop(context, item);
        },
        onAddToInvoice: () {
          Navigator.pop(context);
          Navigator.pop(context, item);
        },
      ),);
  }

  @override
  Widget build(BuildContext context) {
    final title =
    _isEdit ? "Edit Item" : (widget.stockEnabled ? "Add Item" : "Add Service");

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: List.generate(3, (i) {
                  final on = i <= _step;
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: i == 2 ? 0 : 10),
                      decoration: BoxDecoration(
                        color: on ? GPColors.primary : GPColors.line,
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
                  _step1Basic(),
                  _step2Pricing(),
                  _step3Stock(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GPColors.primary,
                    foregroundColor: GPColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _step < 2 ? _next() : _save(),
                  child: Text(
                    _step < 2 ? "Next" : "Save Item",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step1Basic() {
    final categories = const [
      "Electronics",
      "Mobile",
      "FMCG",
      "Garments",
      "Hardware",
      "Pharmacy",
      "Stationery",
      "Other"
    ];
    final units =
    widget.stockEnabled ? const ["pcs", "kg", "box", "litre"] : const ["service", "job", "hour"];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Text("Basic Info",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: widget.stockEnabled ? "Item Name" : "Service Name",
            prefixIcon: const Icon(Icons.text_fields_rounded),
          ),
          onChanged: (v) {
            if (!_isEdit && _sku.text.trim().isEmpty && v.trim().length >= 3) {
              _sku.text = InventoryItem.genSku(v);
              setState(() {});
            }
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _sku,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: trs("Item Code / SKU"),
            prefixIcon: Icon(Icons.qr_code_rounded),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _barcode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: trs("Barcode (scan or type)"),
            prefixIcon: const Icon(Icons.barcode_reader),
            suffixIcon: IconButton(
              tooltip: trs("Scan barcode"),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () async {
                final code = await scanBarcode(context);
                if (code != null && mounted) setState(() => _barcode.text = code);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _category,
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _category = v ?? _category),
          decoration: InputDecoration(
            hintText: trs("Category"),
            prefixIcon: Icon(Icons.category_rounded),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _unit,
          items: units
              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
              .toList(),
          onChanged: (v) => setState(() => _unit = v ?? _unit),
          decoration: InputDecoration(
            hintText: trs("Unit"),
            prefixIcon: Icon(Icons.straighten_rounded),
          ),
        ),
      ],
    );
  }

  Widget _step2Pricing() {
    final gstRates = const [0, 5, 12, 18, 28];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Text("Pricing & Tax",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 10),
        TextField(
          controller: _purchase,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: trs("Purchase Price"),
            prefixIcon: Icon(Icons.currency_rupee_rounded),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _selling,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: trs("Selling Price"),
            prefixIcon: Icon(Icons.currency_rupee_rounded),
          ),
        ),
        const SizedBox(height: 12),
        const Text("Pricing type", style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _chip("Inclusive of tax", _inclusive, () => setState(() => _inclusive = true))),
            const SizedBox(width: 10),
            Expanded(child: _chip("Exclusive of tax", !_inclusive, () => setState(() => _inclusive = false))),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.gstEnabled) ...[
          const Text("GST Rate", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: gstRates.map((r) {
              final on = _gst == r;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => _gst = r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? GPColors.tint : GPColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: on ? GPColors.primary : GPColors.line),
                  ),
                  child: Text("$r%", style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              );
            }).toList(),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.tint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: Text("GST not enabled in onboarding.",
                style: TextStyle(color: GPColors.ink2)),
          ),
        ],
      ],
    );
  }

  Widget _step3Stock() {
    if (!widget.stockEnabled) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text("Service Details",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.tint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: Text("Stock fields are hidden for Services business.",
                style: TextStyle(color: GPColors.ink2)),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Text("Stock Details",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 10),
        TextField(
          controller: _openingStock,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: trs("Opening stock"),
            prefixIcon: Icon(Icons.inventory_rounded),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _lowStock,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: trs("Low stock alert level"),
            prefixIcon: Icon(Icons.warning_amber_rounded),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _location,
          decoration: InputDecoration(
            hintText: trs("Warehouse / Location"),
            prefixIcon: Icon(Icons.location_on_rounded),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, bool on, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? GPColors.tint : GPColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? GPColors.primary : GPColors.line),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onAddAnother;
  final VoidCallback onGoInventory;
  final VoidCallback onAddToInvoice;

  const _SuccessSheet({
    required this.isEdit,
    required this.onAddAnother,
    required this.onGoInventory,
    required this.onAddToInvoice,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: GPColors.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          const Icon(Icons.check_circle_rounded,
              color: GPColors.success, size: 44),
          const SizedBox(height: 10),
          Text(isEdit ? "Item updated successfully" : "Item added successfully",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: GPColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onAddAnother,
              child:
              const Text("Add another", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
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
              onPressed: onGoInventory,
              child: const Text("Go to inventory",
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: GPColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onAddToInvoice,
              child: const Text("Add to invoice",
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
