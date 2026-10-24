import '../../core/api_client.dart';

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Everything about "who owes me money and how do I get it": summary, aging, reminders, promises.
class ReceivablesRepo {
  Future<Map<String, dynamic>> summary() => ApiClient.I.get('/receivables/summary');
  Future<Map<String, dynamic>> monthly() => ApiClient.I.get('/receivables/monthly');
  Future<Map<String, dynamic>> aging() => ApiClient.I.get('/receivables/aging');

  Future<List<Map<String, dynamic>>> parties({String sort = 'overdue', String? bucket}) async {
    final r = await ApiClient.I.get('/receivables/parties?sort=$sort${bucket != null ? '&bucket=$bucket' : ''}');
    return List<Map<String, dynamic>>.from(r['parties'] as List);
  }

  Future<List<Map<String, dynamic>>> dueToday() async {
    final r = await ApiClient.I.get('/reminders/due');
    return List<Map<String, dynamic>>.from(r['reminders'] as List);
  }

  Future<Map<String, dynamic>> compose(int partyId, {String? tone, String language = 'en', List<int>? invoiceIds}) =>
      ApiClient.I.post('/reminders/compose', {
        'party_id': partyId,
        'language': language,
        if (tone != null) 'tone': tone,
        if (invoiceIds != null) 'invoice_ids': invoiceIds,
      });

  /// Call when the owner actually taps send (or skip) so the same reminder is not shown again today.
  Future<void> logReminder({
    required int partyId,
    required String channel,
    required String message,
    required int totalDue,
    List<Map<String, dynamic>> items = const [],
    String status = 'sent',
  }) =>
      ApiClient.I.post('/reminders/log', {
        'party_id': partyId,
        'channel': channel,
        'status': status,
        'message': message,
        'total_due': totalDue,
        'items': items,
      });

  Future<void> promise({required int partyId, required DateTime date, int amountPaise = 0, String note = ''}) =>
      ApiClient.I.post('/promises', {
        'party_id': partyId,
        'promised_date': ymd(date),
        'amount': amountPaise,
        'note': note,
      });

  Future<void> setPaused(int partyId, bool paused) =>
      ApiClient.I.put('/receivables/parties/$partyId/reminders', {'paused': paused});

  Future<List<Map<String, dynamic>>> rules() async {
    final r = await ApiClient.I.get('/reminders/rules');
    return List<Map<String, dynamic>>.from(r['rules'] as List);
  }

  Future<void> saveRule(Map<String, dynamic> rule, {int? id}) =>
      id == null ? ApiClient.I.post('/reminders/rules', rule) : ApiClient.I.put('/reminders/rules/$id', rule);

  Future<void> deleteRule(int id) => ApiClient.I.delete('/reminders/rules/$id');
}
