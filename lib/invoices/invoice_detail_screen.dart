import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';
import 'package:printing/printing.dart';

import '../core/messenger.dart';
import '../data/models/invoice_entity.dart';
import '../data/repositories/invoice_repo.dart';
import '../payments/record_payment_sheet.dart';
import '../theme/gp_colors.dart';
import 'pdf/invoice_pdf.dart';

/// One invoice: totals, lines, payments received, and actions (record payment, PDF, cancel).
class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  final int invoiceId;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _repo = InvoiceRepo();
  InvoiceEntity? _inv;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final inv = await _repo.getById(widget.invoiceId);
      if (mounted) setState(() => _inv = inv);
    } catch (e) {
      AppMessenger.error(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(double v) => '₹${v.toStringAsFixed(2)}';
  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<Uint8List> _pdf() => InvoicePdf.build(inv: _inv!, lines: _inv!.lines);

  Future<void> _print() async {
    try {
      final b = await _pdf();
      await Printing.layoutPdf(onLayout: (_) async => b);
    } catch (e) {
      AppMessenger.error(e);
    }
  }

  Future<void> _share() async {
    try {
      final b = await _pdf();
      await Printing.sharePdf(bytes: b, filename: '${_inv!.invoiceNo}.pdf');
    } catch (e) {
      AppMessenger.error(e);
    }
  }

  Future<void> _recordPayment() async {
    final inv = _inv!;
    final saved = await showRecordPaymentSheet(
      context,
      partyId: inv.partyId!,
      partyName: inv.partyName,
      suggestedAmount: inv.balanceDue,
      invoiceId: inv.id,
    );
    if (saved) await _load();
  }

  Future<void> _cancel() async {
    final reason = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this invoice?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stock goes back to inventory and the amount stops counting as a sale. '
                'Money already received from a customer stays on their account as an advance.'),
            const SizedBox(height: 12),
            TextField(controller: reason, decoration: InputDecoration(labelText: trs('Reason (required)'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep invoice')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel invoice')),
        ],
      ),
    );
    if (go != true) return;
    if (reason.text.trim().length < 3) {
      AppMessenger.error('Please enter a reason (at least 3 characters)');
      return;
    }
    try {
      final updated = await _repo.cancel(widget.invoiceId, reason.text.trim());
      if (mounted) setState(() => _inv = updated);
      AppMessenger.info('Invoice cancelled');
    } catch (e) {
      AppMessenger.error(e);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return GPColors.success;
      case 'partial':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      case 'cancelled':
        return GPColors.ink2;
      default:
        return GPColors.ink2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = _inv;
    return Scaffold(
      appBar: AppBar(title: Text(inv?.invoiceNo ?? 'Invoice')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : inv == null
              ? const Center(child: Text('Invoice not found'))
              : RefreshIndicator(onRefresh: _load, child: _body(inv)),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GPColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GPColors.line),
        ),
        child: child,
      );

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w500))),
            Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      );

  Widget _body(InvoiceEntity inv) {
    final canPay = inv.affectsBooks && !inv.isCancelled && inv.balanceDue > 0.005 && inv.partyId != null;
    final status = inv.affectsBooks ? inv.status : 'document';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(inv.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(inv.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      inv.isOverdue ? 'OVERDUE' : status.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: inv.isOverdue ? Colors.red : _statusColor(inv.status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(inv.cashCustomer ? 'Cash Customer' : (inv.partyName.isEmpty ? '—' : inv.partyName),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${inv.docType} • ${_date(inv.date)} • ${inv.paymentMethod}',
                  style: TextStyle(color: GPColors.ink2)),
              if (inv.dueDateMs != null)
                Text('Due ${_date(DateTime.fromMillisecondsSinceEpoch(inv.dueDateMs!))}',
                    style: TextStyle(color: GPColors.ink2)),
              if (inv.isCancelled && inv.cancelReason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Cancelled: ${inv.cancelReason}', style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              for (final l in inv.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${l.qty} ${l.unit} × ${_money(l.rate)}${l.gstSlab > 0 && inv.gstEnabled ? ' • GST ${l.gstSlab}%' : ''}',
                                style: TextStyle(color: GPColors.ink2, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(_money(l.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _card(
          child: Column(
            children: [
              _row('Subtotal', _money(inv.subtotal)),
              if (inv.discountTotal > 0) _row('Discount', '- ${_money(inv.discountTotal)}'),
              if (inv.gstEnabled && inv.isInterstate) _row('IGST', _money(inv.igst)),
              if (inv.gstEnabled && !inv.isInterstate) _row('CGST', _money(inv.cgst)),
              if (inv.gstEnabled && !inv.isInterstate) _row('SGST', _money(inv.sgst)),
              const Divider(),
              _row('Grand Total', _money(inv.grandTotal), bold: true),
              if (inv.affectsBooks && !inv.isCancelled) ...[
                _row('Paid', _money(inv.amountPaid)),
                _row('Balance Due', _money(inv.balanceDue), bold: true),
              ],
            ],
          ),
        ),
        if (inv.payments.isNotEmpty)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payments received', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                for (final p in inv.payments)
                  _row('${_date(p.date)} • ${p.mode.toUpperCase()}${p.referenceNo.isEmpty ? '' : ' • ${p.referenceNo}'}', _money(p.amount)),
              ],
            ),
          ),
        if (canPay)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GPColors.primary,
                  foregroundColor: GPColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _recordPayment,
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: _print, icon: const Icon(Icons.print_rounded), label: const Text('Print'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.ios_share_rounded), label: const Text('Share PDF'))),
          ],
        ),
        if (!inv.isCancelled)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton(
              onPressed: _cancel,
              child: const Text('Cancel invoice', style: TextStyle(color: Colors.red)),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
