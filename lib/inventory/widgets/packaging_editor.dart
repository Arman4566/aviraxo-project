import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../models/packaging.dart';

/// Five optional packaging levels. Switch on only the ones this item really comes in;
/// each switched-on level says how many of the next smaller level it holds.
class PackagingEditor extends StatefulWidget {
  const PackagingEditor({super.key, required this.value, required this.onChanged, this.unit = 'pcs'});
  final List<PackTier> value;
  final String unit;
  final ValueChanged<List<PackTier>> onChanged;

  @override
  State<PackagingEditor> createState() => _PackagingEditorState();
}

class _PackagingEditorState extends State<PackagingEditor> {
  late List<PackTier> _t = Packaging.normalize(widget.value);
  bool _open = false;

  void _emit() {
    _t = Packaging.normalize(_t);
    widget.onChanged(_t);
    setState(() {});
  }

  /// The next smaller switched-on level below index i (or the pieces level).
  String _childName(int i) {
    for (var k = i + 1; k < _t.length; k++) {
      if (_t[k].enabled) return _t[k].name;
    }
    return _t.last.name;
  }

  @override
  Widget build(BuildContext context) {
    final active = Packaging.isActive(_t);
    return Container(
      decoration: BoxDecoration(
        color: GPColors.tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GPColors.line),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.inventory_2_rounded),
            title: const Text("Packaging levels", style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(active ? _summary() : trs("Optional: sell or buy by case, carton, box…")),
            trailing: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            onTap: () => setState(() { _open = !_open; }),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (var i = 0; i < _t.length - 1; i++) _row(i),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${trs("Stock is always counted in")} ${_t.last.name.toLowerCase()}s (${widget.unit}).',
                        style: TextStyle(color: GPColors.ink2, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _summary() {
    final on = _t.where((x) => x.enabled && x.tier != 'piece').toList();
    return on.map((x) => '1 ${x.name} = ${x.pieces} ${_t.last.name.toLowerCase()}').join('  ·  ');
  }

  Widget _row(int i) {
    final t = _t[i];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(trs(Packaging.labels[t.tier]!), style: const TextStyle(fontWeight: FontWeight.w800))),
              Switch(value: t.enabled, onChanged: (v) { t.enabled = v; _emit(); }),
            ],
          ),
          if (t.enabled)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: ValueKey('name_${t.tier}'),
                    initialValue: t.name,
                    decoration: InputDecoration(labelText: trs("Name"), isDense: true),
                    onChanged: (v) { t.name = v; widget.onChanged(Packaging.normalize(_t)); },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: ValueKey('per_${t.tier}'),
                    initialValue: '${t.per}',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: '${trs("Holds")} (${_childName(i)})', isDense: true),
                    onChanged: (v) { t.per = int.tryParse(v) ?? 1; _emit(); },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
