import '../../core/api_client.dart';
import '../../core/money.dart';
import '../models/invoice_entity.dart';
import '../../models/onboarding_data.dart';
import '../../invoices/invoice_flow/models/invoice_draft.dart';
import 'cached_list.dart';
import 'inventory_repo.dart';
import 'party_repo.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Invoices are created and numbered by the server, which also does all the maths
/// (GST split, totals), moves stock and updates the customer's balance.
class InvoiceRepo {
  static final CachedList<InvoiceEntity> _cache = CachedList<InvoiceEntity>(() async {
    final r = await ApiClient.I.get('/invoices', query: {'limit': 500});
    return (r['invoices'] as List).map((j) => InvoiceEntity.fromJson(j as Map<String, dynamic>)).toList();
  });

  static void reset() => _cache.clear();

  /// Newest first. Cancelled invoices are not included.
  Stream<List<InvoiceEntity>> watchAll() => _cache.watch();

  Future<void> refresh() => _cache.refresh();

  /// Everything an invoice change can touch: invoice list, customer balances and stock.
  static Future<void> refreshAfterChange() async {
    await Future.wait([
      _cache.refresh(),
      PartyRepo().refresh(),
      InventoryRepo().refresh(),
    ]);
  }

  /// Full invoice with lines and payments.
  Future<InvoiceEntity?> getById(int id) async {
    try {
      final r = await ApiClient.I.get('/invoices/$id');
      return InvoiceEntity.fromJson(r['invoice'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<List<InvoiceLineEntity>> getLinesFor(InvoiceEntity inv) async {
    if (inv.lines.isNotEmpty) return inv.lines;
    final full = await getById(inv.id);
    return full?.lines ?? [];
  }

  /// Invoices between two dates. [end] is exclusive (midnight after the last day), like DateTimeRange.end.
  Future<List<InvoiceEntity>> listRange(DateTime start, DateTime end) async {
    final last = end.subtract(const Duration(days: 1));
    final r = await ApiClient.I.get('/invoices', query: {'from': _ymd(start), 'to': _ymd(last.isBefore(start) ? start : last), 'limit': 1000});
    return (r['invoices'] as List).map((j) => InvoiceEntity.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<InvoiceEntity>> listForParty(int partyId) async {
    final r = await ApiClient.I.get('/invoices', query: {'party_id': partyId, 'limit': 500});
    return (r['invoices'] as List).map((j) => InvoiceEntity.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// The number the next document of this type will get (shown on the preview; the server assigns the real one).
  Future<String> nextInvoiceNo([InvoiceDocType type = InvoiceDocType.gstInvoice]) async {
    final r = await ApiClient.I.get('/invoices/next-number', query: {'doc_type': type.name});
    return (r['invoice_no'] ?? '') as String;
  }

  /// Sends the draft to the server. Returns the new invoice id, or -1 when saved offline.
  Future<int> saveDraft({
    required OnboardingData onboarding,
    required InvoiceDraft draft,
    String? clientRef,
  }) async {
    final gstEnabled = draft.isGst(onboarding);
    final partyId = (!draft.cashCustomer && draft.party != null && draft.party!.id > 0) ? draft.party!.id : null;

    final body = <String, dynamic>{
      'doc_type': draft.type.name,
      'party_id': partyId,
      'cash_customer': draft.cashCustomer,
      'invoice_date': _ymd(draft.date),
      'due_date': draft.dueDate == null ? null : _ymd(draft.dueDate!),
      'payment_method': draft.paymentMethod,
      'gst_enabled': gstEnabled,
      'notes': draft.notes,
      'terms': draft.terms,
      'lines': draft.lines
          .map((l) => {
                'item_id': l.item.itemId,
                'name': l.item.name,
                'unit': l.item.unit,
                'hsn': l.item.hsn,
                'gst_slab': l.gstSlab,
                'qty': l.qty,
                'rate': toPaise(l.rate),
                'discount_is_percent': l.discountIsPercent,
                'discount_value': l.discountIsPercent ? l.discountValue : toPaise(l.discountValue),
                'tax_inclusive': false,
              })
          .toList(),
    };

    // client_ref makes a retry safe: if the first attempt reached the server but the reply was lost, the server
    // returns the same invoice instead of creating a second one. Offline, the invoice is queued and returns -1.
    final r = await ApiClient.I.postQueued('/invoices', {...body, if (clientRef != null) 'client_ref': clientRef});
    if (r['queued'] == true) return -1;
    await refreshAfterChange();
    return ((r['invoice'] as Map)['id'] as num).toInt();
  }

  Future<InvoiceEntity> cancel(int id, String reason) async {
    final r = await ApiClient.I.post('/invoices/$id/cancel', {'reason': reason});
    await refreshAfterChange();
    return InvoiceEntity.fromJson(r['invoice'] as Map<String, dynamic>);
  }
}
