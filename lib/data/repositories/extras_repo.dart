import '../../core/api_client.dart';

/// Expenses, low stock, insights, team and backup in one small file; each is a thin wrapper over the API.
class ExtrasRepo {
  // ---- Expenses ----
  Future<List<Map<String, dynamic>>> expenses({String? from, String? to, String? kind}) async {
    final q = [if (from != null) 'from=$from', if (to != null) 'to=$to', if (kind != null) 'kind=$kind'].join('&');
    final r = await ApiClient.I.get('/expenses${q.isEmpty ? '' : '?$q'}');
    return List<Map<String, dynamic>>.from(r['expenses'] as List);
  }

  Future<Map<String, dynamic>> expenseSummary(String from, String to) =>
      ApiClient.I.get('/expenses/summary?from=$from&to=$to');

  Future<List<String>> expenseCategories() async {
    final r = await ApiClient.I.get('/expenses/categories');
    return (r['categories'] as List).map((c) => c is Map ? '${c['category'] ?? c['name']}' : '$c').toList();
  }

  /// Queued when offline (see Outbox); returns true when it was saved on the phone instead of the server.
  Future<bool> addExpense(Map<String, dynamic> body) async =>
      (await ApiClient.I.postQueued('/expenses', body))['queued'] == true;

  Future<void> deleteExpense(int id) => ApiClient.I.delete('/expenses/$id');

  // ---- Low stock / barcode ----
  Future<Map<String, dynamic>> lowStock() => ApiClient.I.get('/inventory/low-stock');
  Future<Map<String, dynamic>?> itemByBarcode(String code) async {
    try {
      final r = await ApiClient.I.get('/inventory/barcode/${Uri.encodeComponent(code)}');
      return r['item'] as Map<String, dynamic>?;
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  // ---- Analytics ----
  /// range: 7d, 30d, 90d or 365d. One call returns every number the analytics screen draws.
  Future<Map<String, dynamic>> analytics(String range) => ApiClient.I.get('/analytics/overview?range=$range');

  // ---- Insights ----
  Future<Map<String, dynamic>> insights() => ApiClient.I.get('/insights/summary');
  Future<Map<String, dynamic>> forecast({int days = 28}) => ApiClient.I.get('/insights/forecast?days=$days');

  // ---- Team ----
  Future<Map<String, dynamic>> staff() => ApiClient.I.get('/staff');
  Future<void> invite(String email, String role) => ApiClient.I.post('/staff/invite', {'email': email, 'role': role});
  Future<void> revokeInvite(int id) => ApiClient.I.delete('/staff/invites/$id');
  Future<void> changeRole(int id, String role) => ApiClient.I.put('/staff/$id', {'role': role});
  Future<void> removeMember(int id) => ApiClient.I.delete('/staff/$id');

  // ---- Reports ----
  /// name: profit-loss, cash-flow, cash-bank, gstr1, gstr3b (from+to) or day-book (date).
  Future<Map<String, dynamic>> report(String name, {String? from, String? to, String? date}) =>
      ApiClient.I.get('/reports/$name', query: {'from': from, 'to': to, 'date': date});

  // ---- Backup ----
  Future<Map<String, dynamic>> backupExport() => ApiClient.I.get('/backup/export');
  Future<Map<String, dynamic>> backupRestore(Map<String, dynamic> data) => ApiClient.I.post('/backup/restore', data);

  // ---- Firms ----
  Future<Map<String, dynamic>> me() => ApiClient.I.get('/me');
}
