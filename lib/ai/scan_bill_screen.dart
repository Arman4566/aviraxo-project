import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/messenger.dart';
import '../core/money.dart';
import '../data/repositories/ai_repo.dart';
import '../data/repositories/inventory_repo.dart';
import '../theme/gp_colors.dart';

/// Photo of a supplier bill or price list -> list of items -> added to inventory with stock.
/// The AI can misread, so every row is shown for checking: untick rows you do not want, then add.
class ScanBillScreen extends StatefulWidget {
  const ScanBillScreen({super.key});
  @override
  State<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _Row {
  final Map<String, dynamic> j;
  bool on = true;
  _Row(this.j);
}

class _ScanBillScreenState extends State<ScanBillScreen> {
  final _repo = AiRepo();
  final _picker = ImagePicker();
  final _markup = TextEditingController(text: '20');
  List<_Row>? _rows;
  Map<String, dynamic>? _meta;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _markup.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final f = await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 75);
      if (f == null) return;
      setState(() {
        _busy = true;
        _error = null;
        _rows = null;
      });
      final bytes = await f.readAsBytes();
      final lower = f.path.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
      final r = await _repo.scanBill(base64Encode(bytes), mime);
      final items = List<Map<String, dynamic>>.from((r['items'] as List?) ?? const []);
      if (!mounted) return;
      setState(() {
        _meta = r;
        _rows = [for (final i in items) _Row(i)];
        if (items.isEmpty) _error = 'No items could be read. Try a clearer, well-lit photo of the bill.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not read the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final chosen = (_rows ?? []).where((r) => r.on).toList();
    if (chosen.isEmpty) return;
    final m = (double.tryParse(_markup.text.trim()) ?? 0).clamp(0, 500).toDouble();
    setState(() => _busy = true);
    var ok = 0;
    String? firstError;
    for (final r in chosen) {
      final j = r.j;
      final cost = (j['rate'] as num).toInt();
      final gst = (j['gst_percent'] as num).toInt();
      try {
        await ApiClient.I.post('/items', {
          'name': j['name'],
          'unit': j['unit'],
          'hsn': j['hsn'],
          'purchase_price': cost,
          'selling_price': (cost * (1 + m / 100)).round(),
          'gst_rate': gst,
          'gst_enabled': gst > 0,
          'stock_enabled': true,
          'stock_qty': j['qty'],
        });
        ok++;
      } catch (e) {
        firstError ??= e is ApiException ? e.message : '$e';
      }
    }
    await InventoryRepo().refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    if (firstError != null) {
      AppMessenger.info('Added $ok of ${chosen.length}. Some failed: $firstError');
    } else {
      AppMessenger.info('Added $ok items to your inventory.');
    }
    if (ok > 0) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final selected = rows?.where((r) => r.on).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan bill with AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Take a photo of a supplier bill or price list. The AI reads the items; you check them and add them to your stock.', style: TextStyle(color: GPColors.ink2)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _busy ? null : () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: const Text('Take photo'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_rounded), label: const Text('From gallery'))),
          ]),
          if (_busy) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: const TextStyle(color: GPColors.danger))),
          if (rows != null && rows.isNotEmpty && !_busy) ...[
            const SizedBox(height: 16),
            if (_meta?['supplier'] != null || _meta?['bill_no'] != null)
              Text('${_meta?['supplier'] ?? ''} ${_meta?['bill_no'] != null ? '· Bill ${_meta?['bill_no']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final r in rows)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: r.on,
                onChanged: (v) => setState(() => r.on = v ?? false),
                title: Text(r.j['name'] as String),
                subtitle: Text('${r.j['qty']} ${r.j['unit']}  ×  ${inr((r.j['rate'] as num).toInt())}'
                    '${(r.j['gst_percent'] as num) > 0 ? '  ·  GST ${r.j['gst_percent']}%' : ''}'),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _markup,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: trs('Selling price markup % over bill price'), helperText: trs('You can change each selling price later in Inventory')),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: selected == 0 ? null : _add, child: Text('Add $selected items to inventory')),
          ],
        ],
      ),
    );
  }
}
