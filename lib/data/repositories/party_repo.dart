import '../../core/api_client.dart';
import '../models/party_entity.dart';
import 'cached_list.dart';

class PartyRepo {
  static final CachedList<PartyEntity> _cache = CachedList<PartyEntity>(() async {
    final r = await ApiClient.I.get('/parties');
    final list = (r['parties'] as List).map((j) => PartyEntity.fromJson(j as Map<String, dynamic>)).toList();
    list.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return list;
  });

  static void reset() => _cache.clear();

  Stream<List<PartyEntity>> watchAll() => _cache.watch();

  Future<void> refresh() => _cache.refresh();

  Future<PartyEntity?> getById(int id) async {
    try {
      final r = await ApiClient.I.get('/parties/$id');
      return PartyEntity.fromJson(r['party'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Creates (id == 0) or updates. Returns the party id.
  Future<int> upsert(PartyEntity p) async {
    final Map<String, dynamic> r = p.id == 0
        ? await ApiClient.I.post('/parties', p.toApi())
        : await ApiClient.I.put('/parties/${p.id}', p.toApi());
    await _cache.refresh();
    return (r['party']['id'] as num).toInt();
  }

  Future<void> deleteById(int id) async {
    await ApiClient.I.delete('/parties/$id');
    await _cache.refresh();
  }

  /// Statement of account: invoices (debit) and payments (credit) with a running balance, in rupees.
  Future<PartyLedger> ledger(int id) async {
    final r = await ApiClient.I.get('/parties/$id/ledger');
    return PartyLedger.fromJson(r);
  }
}
