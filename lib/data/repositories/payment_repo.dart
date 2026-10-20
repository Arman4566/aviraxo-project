import '../../core/api_client.dart';
import '../../core/money.dart';
import 'invoice_repo.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PaymentRepo {
  /// Records money received from a party. With [invoiceId] it is applied to that invoice only;
  /// otherwise the server settles the party's oldest open invoices first (any extra stays as an advance).
  /// Returns true when there was no internet and the payment was saved on the phone to be sent later.
  Future<bool> receive({
    required int partyId,
    required double amount,
    String mode = 'cash',
    DateTime? date,
    String reference = '',
    String notes = '',
    int? invoiceId,
    String? clientRef,
  }) async {
    final paise = toPaise(amount);
    final r = await ApiClient.I.postQueued('/payments', {
      if (clientRef != null) 'client_ref': clientRef,
      'party_id': partyId,
      'amount': paise,
      'mode': mode,
      'payment_date': _ymd(date ?? DateTime.now()),
      'reference_no': reference,
      'notes': notes,
      if (invoiceId != null)
        'allocations': [
          {'invoice_id': invoiceId, 'amount': paise}
        ],
    });
    final queued = r['queued'] == true;
    if (!queued) await InvoiceRepo.refreshAfterChange();
    return queued;
  }
}
