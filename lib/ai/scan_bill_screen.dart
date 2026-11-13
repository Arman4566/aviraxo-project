import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/messenger.dart';
import '../core/money.dart';
import '../data/repositories/ai_repo.dart';
import '../data/repositories/inventory_repo.dart';
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';
import '../theme/gp_colors.dart';

/// Photo, PDF, Excel or CSV of a supplier bill -> items -> CHECKED by the person -> stock.
/// The AI can misread, so nothing is saved until every row has been seen: numbers are editable, lines whose
/// maths does not add up are flagged, the bill total is compared with the sum of the lines, and items that
/// already exist get their stock topped up instead of being created twice.
class ScanBillScreen extends StatefulWidget {
  const ScanBillScreen({super.key});
  @override
  State<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _Row {
  _Row(Map<String, dynamic> j)
      : name = TextEditingController(text: (j['name'] ?? '') as String),
        cases = TextEditingController(text: j['cases'] == null ? '' : '${(j['cases'] as num).round()}'),
        perCase = TextEditingController(text: j['units_per_case'] == null ? '' : '${(j['units_per_case'] as num).round()}'),
        qty = TextEditingController(text: '${(j['qty'] as num).round()}'),
        rate = TextEditingController(text: toRupees((j['rate'] ?? 0) as num).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')),
        gst = (j['gst_percent'] as num?)?.round() ?? 0,
        unit = (j['unit'] ?? 'pcs') as String,
        hsn = (j['hsn'] ?? '') as String,
        printedTotal = (j['line_total'] as num?)?.round(),
        flagged = j['needs_check'] == true,
        matchId = (j['match'] as Map?)?['item_id'] as int?,
        matchName = (j['match'] as Map?)?['name'] as String?;

  final TextEditingController name, cases, perCase, qty, rate;
  int gst;
  final String unit, hsn;
  final int? printedTotal;
  bool flagged;
  bool on = true;
  final int? matchId;
  final String? matchName;

  int get qtyN => int.tryParse(qty.text.trim()) ?? 0;
  double get rateN => double.tryParse(rate.text.trim()) ?? 0;
  int get casesN => int.tryParse(cases.text.trim()) ?? 0;
  int get perN => int.tryParse(perCase.text.trim()) ?? 0;
  int get totalPaise => (qtyN * toPaise(rateN) * (1 + gst / 100)).round();

  void dispose() {
    for (final c in [name, cases, perCase, qty, rate]) {
      c.dispose();
    }
  }
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
    for (final r in _rows ?? const <_Row>[]) {
      r.dispose();
    }
    super.dispose();
  }

  void _load(Map<String, dynamic> r) {
    for (final old in _rows ?? const <_Row>[]) {
      old.dispose();
    }
    final items = List<Map<String, dynamic>>.from((r['items'] as List?) ?? const []);
    setState(() {
      _meta = r;
      _rows = [for (final i in items) _Row(i)];
      if (items.isEmpty) _error = 'No items could be read. Try a clearer photo, or another file.';
    });
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
      _rows = null;
    });
    try {
      final r = await job();
      if (mounted) _load(r);
    } catch (e) {
      if (mounted) setState(() { _error = e is ApiException ? e.message : 'Could not read it. Please try again.'; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _pickPhoto(ImageSource src) async {
    final f = await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 75);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final lower = f.path.toLowerCase();
    final mime = lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
    await _run(() => _repo.scanBill(base64Encode(bytes), mime));
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'xlsx', 'csv'], withData: true);
    final f = res?.files.single;
    if (f == null || f.bytes == null) return;
    if (f.bytes!.length > 6 * 1024 * 1024) {
      setState(() { _error = 'That file is bigger than 6 MB. Split it or export fewer rows.'; });
      return;
    }
    final lower = f.name.toLowerCase();
    final mime = lower.endsWith('.pdf') ? 'application/pdf' : (lower.endsWith('.csv') ? 'text/csv' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    await _run(() => _repo.importFile(base64Encode(f.bytes!), f.name, mime));
  }

  /// Cases x units-per-case -> quantity, whenever either box is edited.
  void _syncQty(_Row r) {
    if (r.casesN > 0 && r.perN > 0) r.qty.text = '${r.casesN * r.perN}';
    r.flagged = false;
    setState(() {});
  }

  int get _computedTotal => (_rows ?? const <_Row>[]).where((r) => r.on).fold(0, (s, r) => s + r.totalPaise);

  Future<void> _add() async {
    final chosen = (_rows ?? []).where((r) => r.on).toList();
    if (chosen.isEmpty) return;
    for (final r in chosen) {
      if (r.name.text.trim().isEmpty || r.qtyN <= 0) {
        AppMessenger.error('Every ticked row needs a name and a quantity above zero.');
        return;
      }
    }
    final m = (double.tryParse(_markup.text.trim()) ?? 0).clamp(0, 500).toDouble();
    setState(() { _busy = true; });
    var ok = 0, topped = 0;
    String? firstError;
    for (final r in chosen) {
      final cost = toPaise(r.rateN);
      try {
        if (r.matchId != null) {
          await ApiClient.I.post('/items/${r.matchId}/purchase-entry', {'qty': r.qtyN, if (cost > 0) 'purchase_price': cost});
          topped++;
        } else {
          final hasCase = r.perN > 1;
          await ApiClient.I.post('/items', {
            'name': r.name.text.trim(),
            'unit': r.unit,
            'hsn': r.hsn,
            'purchase_price': cost,
            'selling_price': (cost * (1 + m / 100)).round(),
            'gst_rate': r.gst,
            'gst_enabled': r.gst > 0,
            'stock_enabled': true,
            'stock_qty': r.qtyN,
            // a bill that says "12 per case" also sets up the case level, so the next purchase can be entered in cases
            if (hasCase) 'packaging': [{'tier': 'primary', 'name': 'Case', 'enabled': true, 'per': r.perN}],
          });
          ok++;
        }
      } catch (e) {
        firstError ??= e is ApiException ? e.message : '$e';
      }
    }
    await InventoryRepo().refresh();
    if (!mounted) return;
    setState(() { _busy = false; });
    final done = ok + topped;
    if (firstError != null) {
      AppMessenger.info('Saved $done of ${chosen.length}. Some failed: $firstError');
    } else {
      AppMessenger.info('$ok new items added, stock added to $topped existing.');
    }
    if (done > 0) Navigator.pop(context, true);
  }

  Widget _field(TextEditingController c, String label, {bool number = true, VoidCallback? onChanged, int flex = 1}) => Expanded(
        flex: flex,
        child: TextField(
          controller: c,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(labelText: trs(label), isDense: true),
          onChanged: (_) => onChanged == null ? setState(() {}) : onChanged(),
        ),
      );

  Widget _rowCard(_Row r) {
    final warn = r.flagged;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GPColors.tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warn ? GPColors.warning : GPColors.line, width: warn ? 1.6 : 1),
      ),
      child: Opacity(
        opacity: r.on ? 1 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Checkbox(value: r.on, onChanged: (v) => setState(() { r.on = v ?? false; })),
              Expanded(
                child: TextField(
                  controller: r.name,
                  decoration: InputDecoration(labelText: trs('Item name'), isDense: true),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              _chip(r.matchId != null ? Icons.link_rounded : Icons.add_circle_outline_rounded,
                  r.matchId != null ? '${trs("Adds stock to")} ${r.matchName}' : trs('New item'), r.matchId != null ? GPColors.primary : GPColors.commit),
              if (warn) _chip(Icons.warning_amber_rounded, trs("Line total on the bill does not match — please check"), GPColors.warning),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _field(r.cases, 'Cases', onChanged: () => _syncQty(r)),
              const SizedBox(width: 8),
              _field(r.perCase, 'Pcs / case', onChanged: () => _syncQty(r)),
              const SizedBox(width: 8),
              _field(r.qty, 'Total qty', onChanged: () { r.flagged = false; setState(() {}); }),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _field(r.rate, 'Rate per piece (₹)', flex: 2),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  initialValue: const [0, 5, 12, 18, 28].contains(r.gst) ? r.gst : 0,
                  decoration: InputDecoration(labelText: trs('GST %'), isDense: true),
                  items: [for (final g in const [0, 5, 12, 18, 28]) DropdownMenuItem(value: g, child: Text('$g%'))],
                  onChanged: (v) => setState(() { r.gst = v ?? 0; r.flagged = false; }),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${r.qtyN} × ${inr(toPaise(r.rateN))}${r.gst > 0 ? '  + ${r.gst}% GST' : ''}', style: TextStyle(color: GPColors.ink2, fontSize: 12)),
              Text(inr(r.totalPaise), style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
            if (r.printedTotal != null && (r.printedTotal! - r.totalPaise).abs() > 100)
              Text('${trs("Bill shows")} ${inr(r.printedTotal!)}', style: TextStyle(color: GPColors.warning, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData i, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.withValues(alpha: 0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: c),
          const SizedBox(width: 4),
          Flexible(child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final selected = rows?.where((r) => r.on).length ?? 0;
    final billTotal = (_meta?['bill_total'] as num?)?.round();
    final computed = _computedTotal;
    final mismatch = billTotal != null && (billTotal - computed).abs() > (billTotal * 0.02).clamp(100, double.infinity);
    final anyNew = rows?.any((r) => r.on && r.matchId == null) ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan bill with AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Photo, PDF, Excel or CSV of a supplier bill. The AI reads the lines; you check every number, then add them to your stock.', style: TextStyle(color: GPColors.ink2)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _busy ? null : () => _pickPhoto(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: const Text('Take photo'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _pickPhoto(ImageSource.gallery), icon: const Icon(Icons.photo_library_rounded), label: const Text('Gallery'))),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(onPressed: _busy ? null : _pickFile, icon: const Icon(Icons.upload_file_rounded), label: const Text('Import PDF / Excel / CSV')),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: const TextStyle(color: GPColors.danger))),
          if (rows != null && rows.isNotEmpty && !_busy) ...[
            const SizedBox(height: 16),
            if (_meta?['supplier'] != null || _meta?['bill_no'] != null)
              Text('${_meta?['supplier'] ?? ''} ${_meta?['bill_no'] != null ? '· Bill ${_meta?['bill_no']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (mismatch ? GPColors.warning : GPColors.success).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: (mismatch ? GPColors.warning : GPColors.success).withValues(alpha: 0.5)),
              ),
              child: Row(children: [
                Icon(mismatch ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: mismatch ? GPColors.warning : GPColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    billTotal == null
                        ? '${trs("Total of ticked lines")}: ${inr(computed)}'
                        : mismatch
                            ? '${trs("Bill total")} ${inr(billTotal)} ≠ ${trs("your lines")} ${inr(computed)}. ${trs("Check quantities and rates.")}'
                            : '${trs("Matches the bill total")}: ${inr(computed)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            for (final r in rows) _rowCard(r),
            if (anyNew)
              TextField(
                controller: _markup,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: trs('Selling price markup % for NEW items'), helperText: trs('Existing items keep their selling price')),
              ),
            const SizedBox(height: 14),
            SizedBox(
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: GPColors.commit),
                onPressed: selected == 0 ? null : _add,
                child: Text('Confirm & add $selected items to stock'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
