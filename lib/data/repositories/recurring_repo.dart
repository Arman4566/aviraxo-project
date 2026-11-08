import '../../core/api_client.dart';

/// One saved schedule ("Rent, every month from 1 Dec") as returned by the server.
class RecurringSchedule {
  RecurringSchedule({
    required this.id,
    required this.name,
    required this.partyName,
    required this.frequency,
    required this.nextDate,
    required this.endDate,
    required this.isActive,
    required this.runCount,
    required this.lastError,
    required this.total,
  });

  final int id;
  final String name;
  final String partyName;
  final String frequency; // weekly | monthly | quarterly | yearly
  final String nextDate; // YYYY-MM-DD
  final String? endDate;
  final bool isActive;
  final int runCount;
  final String lastError;
  final double total; // rupees, before tax

  factory RecurringSchedule.fromJson(Map<String, dynamic> j) {
    final lines = ((j['template'] as Map?)?['lines'] as List?) ?? const [];
    var sum = 0.0;
    for (final l in lines) {
      final m = l as Map;
      sum += ((m['qty'] ?? 0) as num) * ((m['rate'] ?? 0) as num) / 100.0;
    }
    return RecurringSchedule(
      id: (j['id'] as num).toInt(),
      name: (j['name'] ?? '') as String,
      partyName: (j['party_name'] ?? '') as String,
      frequency: (j['frequency'] ?? 'monthly') as String,
      nextDate: (j['next_date'] ?? '') as String,
      endDate: j['end_date'] as String?,
      isActive: (j['is_active'] ?? true) as bool,
      runCount: ((j['run_count'] ?? 0) as num).toInt(),
      lastError: (j['last_error'] ?? '') as String,
      total: sum,
    );
  }
}

class RecurringRepo {
  List<RecurringSchedule> _parse(Map<String, dynamic> r) =>
      ((r['schedules'] as List?) ?? const []).map((e) => RecurringSchedule.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<RecurringSchedule>> list() async => _parse(await ApiClient.I.get('/recurring'));

  Future<List<RecurringSchedule>> create(Map<String, dynamic> body) async => _parse(await ApiClient.I.post('/recurring', body));

  Future<List<RecurringSchedule>> pause(int id) async => _parse(await ApiClient.I.post('/recurring/$id/pause'));

  Future<List<RecurringSchedule>> resume(int id) async => _parse(await ApiClient.I.post('/recurring/$id/resume'));

  Future<List<RecurringSchedule>> remove(int id) async => _parse(await ApiClient.I.delete('/recurring/$id'));

  /// Creates every invoice that is due. Returns how many were made.
  Future<int> runDue() async {
    final r = await ApiClient.I.post('/recurring/run');
    return ((r['created'] as List?) ?? const []).length;
  }
}
