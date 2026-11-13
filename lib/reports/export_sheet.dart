import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api_client.dart';
import '../core/messenger.dart';
import '../data/repositories/receivables_repo.dart' show ymd;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';
import '../theme/gp_colors.dart';

/// Which server report to export. `group` only matters for the sales report (day / party / item).
class ExportSpec {
  const ExportSpec(this.report, this.title, {this.hasRange = true, this.group});
  final String report; // profit-loss | sales | tax-summary | stock | receivables
  final String title;
  final bool hasRange;
  final String? group;
}

/// Opens a sheet to pick a period and a format (PDF, Excel or CSV), then shares the file.
Future<void> showExportSheet(BuildContext context, ExportSpec spec) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExportSheet(spec: spec),
  );
}

/// Small app-bar button that opens the export sheet.
class ExportButton extends StatelessWidget {
  const ExportButton({super.key, required this.spec});
  final ExportSpec spec;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: trs('Export'),
        icon: const Icon(Icons.ios_share_rounded),
        onPressed: () => showExportSheet(context, spec),
      );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.spec});
  final ExportSpec spec;
  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  String _period = 'month';
  DateTimeRange? _custom;
  bool _busy = false;

  DateTimeRange get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case 'today':
        return DateTimeRange(start: today, end: today);
      case 'last':
        final first = DateTime(now.year, now.month - 1, 1);
        return DateTimeRange(start: first, end: DateTime(now.year, now.month, 0));
      case 'fy':
        final y = now.month >= 4 ? now.year : now.year - 1;
        return DateTimeRange(start: DateTime(y, 4, 1), end: today);
      case 'custom':
        return _custom ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
      default:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
    }
  }

  Future<void> _pickCustom() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (r != null) setState(() { _custom = r; _period = 'custom'; });
  }

  Future<void> _go(String format) async {
    setState(() { _busy = true; });
    try {
      final spec = widget.spec;
      final r = _range;
      final q = {
        'report': spec.report,
        'format': format == 'pdf' ? 'json' : format,
        if (spec.hasRange) 'from': ymd(r.start),
        if (spec.hasRange) 'to': ymd(r.end),
        if (spec.group != null) 'group': spec.group,
      };
      final base = '${spec.report}${spec.hasRange ? '-${ymd(r.start)}-${ymd(r.end)}' : ''}';
      if (format == 'pdf') {
        final j = await ApiClient.I.get('/reports/export', query: q);
        final bytes = await _pdf(j);
        await Printing.sharePdf(bytes: bytes, filename: '$base.pdf');
      } else {
        final bytes = Uint8List.fromList(await ApiClient.I.getBytes('/reports/export', query: q));
        final mime = format == 'csv' ? 'text/csv' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        await Share.shareXFiles([XFile.fromData(bytes, mimeType: mime)], fileNameOverrides: ['$base.$format']);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      AppMessenger.error(e);
      if (mounted) setState(() { _busy = false; });
    }
  }

  /// Plain table PDF built from the same rows as the Excel / CSV file, so the three always agree.
  Future<Uint8List> _pdf(Map<String, dynamic> j) async {
    final columns = [for (final c in (j['columns'] as List)) '$c'];
    final rows = [
      for (final r in (j['rows'] as List)) [for (final c in (r as List)) c is num ? _fmt(c) : '$c']
    ];
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('${j['title']}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('Generated ${ymd(DateTime.now())} by Aviraxo', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
      ]),
      build: (_) => [
        pw.TableHelper.fromTextArray(
          headers: columns,
          data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
          cellStyle: const pw.TextStyle(fontSize: 9.5),
          cellAlignments: {for (var i = 1; i < columns.length; i++) i: pw.Alignment.centerRight},
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          border: null,
        ),
        if (rows.isEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 20), child: pw.Text('No data for this period.')),
      ],
    ));
    return doc.save();
  }

  String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final r = _range;
    Widget chip(String key, String label) => ChoiceChip(
          label: Text(label),
          selected: _period == key,
          onSelected: _busy ? null : (_) => setState(() { _period = key; }),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${trs("Export")}: ${spec.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if (spec.hasRange) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: [
              chip('today', trs('Today')),
              chip('month', trs('This month')),
              chip('last', trs('Last month')),
              chip('fy', trs('This financial year')),
              ActionChip(label: Text(_period == 'custom' ? '${ymd(r.start)} → ${ymd(r.end)}' : trs('Custom…')), onPressed: _busy ? null : _pickCustom),
            ]),
            const SizedBox(height: 6),
            Text('${ymd(r.start)} → ${ymd(r.end)}', style: TextStyle(color: GPColors.ink2, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          if (_busy)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => _go('pdf'), icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('PDF'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(onPressed: () => _go('xlsx'), icon: const Icon(Icons.table_chart_rounded), label: const Text('Excel'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => _go('csv'), icon: const Icon(Icons.description_outlined), label: const Text('CSV'))),
            ]),
        ],
      ),
    );
  }
}
