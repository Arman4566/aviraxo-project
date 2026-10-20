import 'package:flutter/material.dart';

import '../../theme/gp_colors.dart';

class StockAdjustment {
  StockAdjustment(this.qtyChange, this.reason, this.note);
  final int qtyChange; // + adds, - removes
  final String reason;
  final String note;
}

/// Ask how much stock to add or remove, and why. Returns null if cancelled.
Future<StockAdjustment?> showAdjustStockDialog(BuildContext context, {required String itemName, required String unit, required int current}) {
  return showDialog<StockAdjustment>(
    context: context,
    builder: (_) => _AdjustDialog(itemName: itemName, unit: unit, current: current),
  );
}

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.itemName, required this.unit, required this.current});
  final String itemName;
  final String unit;
  final int current;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  bool _add = true;
  String _reason = 'correction';
  final _qty = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  static const _reasons = ['correction', 'damaged', 'lost', 'found', 'returned', 'other'];

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  void _ok() {
    final q = int.tryParse(_qty.text.trim()) ?? 0;
    if (q <= 0) {
      setState(() => _error = 'Enter a quantity greater than 0');
      return;
    }
    if (!_add && q > widget.current) {
      setState(() => _error = 'Only ${widget.current} ${widget.unit} in stock');
      return;
    }
    Navigator.pop(context, StockAdjustment(_add ? q : -q, _reason, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust stock • ${widget.itemName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current: ${widget.current} ${widget.unit}', style: const TextStyle(color: GPColors.ink2)),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Add')),
                ButtonSegment(value: false, label: Text('Remove')),
              ],
              selected: {_add},
              onSelectionChanged: (s) => setState(() => _add = s.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Quantity (${widget.unit})', errorText: _error),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _reason = v ?? 'correction'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _ok, child: const Text('Save')),
      ],
    );
  }
}
